defmodule RoboSoccerPlatformWeb.Player.Steering do
  use RoboSoccerPlatformWeb, :live_view

  require Logger
  alias RoboSoccerPlatformWeb.Endpoint
  alias RoboSoccerPlatform.GameController
  alias RoboSoccerPlatform.Player

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
      GameController.register_player(player, self())
    end

    if GameController.room_code_correct?(room_code) do
      game_state = GameController.get_game_state()

      case game_state do
        :started -> push_event(socket, "game_started", %{})
        _not_started -> push_event(socket, "game_stopped", %{})
      end
      |> assign(game_state: game_state)
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
    {inner_joystick_color, outer_joystick_color, team_display} = case assigns.player.team do
      "green" -> {"#00FF1A", "#008A0E", "Drużyna Zielona"}
      "red" -> {"#FF3737", "#C40000", "Drużyna Czerwona"}
    end

    assigns =
      assigns
      |> assign(inner_joystick_color: inner_joystick_color)
      |> assign(outer_joystick_color: outer_joystick_color)
      |> assign(team_display: team_display)

    ~H"""
    <div class="flex flex-col gap-4">
      <div class="text-3xl text-center">
        <%= @team_display %>
      </div>
      <div class="text-3xl text-center">
        <%= @player.username %>
      </div>

      <div id="container">
        <div
          id="joystick"
          phx-hook="JoyStick"
          phx-update="ignore"
          data-inner_joystick_color={@inner_joystick_color}
          data-outer_joystick_color={@outer_joystick_color}
          class={"w-[min(70vw,70vh)] h-[min(70vw,70vh)] m-auto"}
        >
          <!-- joystick will be rendered here -->
        </div>
      </div>

      <div :if={@game_state == :stopped} class="absolute left-0 top-6 right-0 bottom-0 bg-sky-blue">
        <div class="text-3xl font-bold text-center mt-64">
          Rozgrywka wstrzymana przez organizatora.
        </div>
        <div class="text-3xl font-bold text-center">
          Proszę czekać...
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_joystick_position", %{"x" => x_str, "y" => y_str}, socket) do
    {x, ""} = Integer.parse(x_str)
    {y, ""} = Integer.parse(y_str)

    GameController.update_player_input(
      socket.assigns.player.id,
      x / 100,
      y / 100
    )

    {:noreply, socket}
  end

  def handle_info(%{topic: @game_state, event: "start_game"}, socket) do
    socket
    |> assign(game_state: :started)
    |> push_event("game_started", %{})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, socket) do
    socket
    |> assign(game_state: :stopped)
    |> push_event("game_stopped", %{})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "new_room"}, socket) do
    {:noreply, push_navigate(socket, to: "/player")}
  end
end
