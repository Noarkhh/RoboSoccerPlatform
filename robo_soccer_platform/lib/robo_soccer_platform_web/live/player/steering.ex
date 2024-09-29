defmodule RoboSoccerPlatformWeb.Player.Steering do
  require Logger
  use RoboSoccerPlatformWeb, :live_view

  alias RoboSoccerPlatform.Player
  alias RoboSoccerPlatformWeb.Endpoint
  alias RoboSoccerPlatformWeb.Player.Steering.Utils

  require Logger

  @game_state "game_state"
  @controller "controller"
  @disconnect "disconnect"

  # @spec unregister(String.t()) :: :ok
  # def unregister(player_id) do
  # Logger.debug("Unregistering player #{player_id}")

  # RoboSoccerPlatformWeb.Endpoint.broadcast_from(
  # self(),
  # @controller,
  # "unregister_player",
  # player_id
  # )
  # end

  @impl true
  def mount(params, _session, socket) do
    Endpoint.subscribe(@game_state)
    # Endpoint.subscribe(@disconnect)

    player = %Player{id: params["id"], team: params["team"], username: params["username"]}

    if connected?(socket) do
      RoboSoccerPlatform.GameController.register_player(self(), player)
    end

    if RoboSoccerPlatform.GameController.room_code_correct?(params["room_code"]) do
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
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
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

    # Endpoint.broadcast_from(self(), @controller, "joystick_position", %{
    # x: x / 100,
    # y: y / 100,
    # id: socket.assigns.player.id,
    # room_code: socket.assigns.room_code
    # })

    RoboSoccerPlatform.GameController.update_player_input(
      socket.assigns.player.id,
      x / 100,
      y / 100
    )

    {:noreply, socket}
  end

  def handle_event("restoreState", token_data, socket) when is_binary(token_data) do
    Endpoint.broadcast_from(self(), @controller, "register_player", socket.assigns.player)
    RoboSoccerPlatformWeb.Player.PlayersMonitor.monitor(self(), socket.assigns.player.id)

    case Utils.restore_from_token(token_data) do
      {:ok, nil} ->
        socket

      {:ok, %{game_state: game_state}} ->
        case game_state do
          "started" ->
            push_event(socket, "game_started", %{})

          "stopped" ->
            push_event(socket, "game_stopped", %{})
        end

      {:error, reason} ->
        Logger.debug("Error while restoring state: #{reason}")

        socket
        |> put_flash(:error, reason)
        |> clear_browser_storage()
    end
    |> then(&{:noreply, &1})
  end

  def handle_event("restoreState", _token_data, socket) do
    Endpoint.broadcast_from(self(), @controller, "register_player", socket.assigns.player)
    RoboSoccerPlatformWeb.Player.PlayersMonitor.monitor(self(), socket.assigns.player.id)

    {:noreply, socket}
  end

  def handle_info(%{topic: @game_state, event: "start_game"}, socket) do
    socket
    |> store(%{game_state: "started"})
    |> push_event("game_started", %{})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, socket) do
    socket
    |> store(%{game_state: "stopped"})
    |> push_event("game_stopped", %{})
    |> then(&{:noreply, &1})
  end

  def handle_info(%{topic: @disconnect, event: "disconnect", payload: %{id: id}}, socket)
      when id != socket.assigns.id do
    {:noreply, socket}
  end

  def handle_info(%{topic: @disconnect, event: "disconnect", payload: %{id: id}}, socket) do
    {:noreply, push_navigate(socket, to: "/player")}
  end

  defp store(socket, data) do
    push_event(socket, "store", %{
      key: socket.assigns.player.id,
      data: Utils.serialize_to_token(data)
    })
  end

  defp restore(socket, event \\ "restoreState") do
    push_event(socket, "restore", %{
      key: socket.assigns.player.id,
      event: event
    })
  end

  defp clear_browser_storage(socket) do
    push_event(socket, "clear", %{key: socket.assigns.player.id})
  end
end
