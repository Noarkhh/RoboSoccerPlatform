defmodule RoboSoccerPlatformWeb.Player.Steering do
  use RoboSoccerPlatformWeb, :live_view

  require Logger
  alias RoboSoccerPlatform.Player
  alias RoboSoccerPlatformWeb.Endpoint

  @game_state "game_state"

  @impl true
  def mount(
        %{"id" => id, "team" => team, "username" => username, "room_code" => room_code},
        _session,
        socket
      ) do
    Endpoint.subscribe(@game_state)

    player = %Player{id: id, team: team, username: username}

    if connected?(socket) do
      RoboSoccerPlatform.GameController.register_player(player, self())
    end

    if RoboSoccerPlatform.GameController.room_code_correct?(room_code) do
      case RoboSoccerPlatform.GameController.get_game_state() do
        :started -> push_event(socket, "game_started", %{})
        _not_started -> push_event(socket, "game_stopped", %{})
      end
      |> assign(player: player)
      |> then(&{:ok, &1})
    else
      {:ok, push_navigate(socket, to: "/player")}
    end
  end

  @impl true
  def mount(_bad_params, _session, socket) do
    {:ok, push_navigate(socket, to: "/player")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="container" phx-hook="Storage">
      <div
        id="joystick"
        phx-hook="JoyStick"
        phx-update="ignore"
        class="fixed w-[min(70vw,70vh)] h-[min(70vw,70vh)] left-0 top-0 right-0 bottom-0 m-auto"
      >
        <!-- joystick will be rendered here -->
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_joystick_position", %{"x" => x_str, "y" => y_str}, socket) do
    {x, ""} = Integer.parse(x_str)
    {y, ""} = Integer.parse(y_str)

    RoboSoccerPlatform.GameController.update_player_input(
      socket.assigns.player.id,
      x / 100,
      y / 100
    )

    {:noreply, socket}
  end

  def handle_info(%{topic: @game_state, event: "start_game"}, socket) do
    socket
    |> push_event("game_started", %{})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, socket) do
    socket
    |> push_event("game_stopped", %{})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "new_room"}, socket) do
    {:noreply, push_navigate(socket, to: "/player")}
  end
end
