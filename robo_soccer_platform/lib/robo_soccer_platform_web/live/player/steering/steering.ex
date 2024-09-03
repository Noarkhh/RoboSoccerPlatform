defmodule RoboSoccerPlatformWeb.Player.Steering do
  use RoboSoccerPlatformWeb, :live_view

  alias RoboSoccerPlatform.Player

  @game_state "game_state"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_state)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    player = %Player{id: params["id"], team: params["team"], username: params["username"]}

    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @controller, "register_player", player)

    {:noreply, assign(socket, player: player)}
  end

  def render(assigns) do
    ~H"""
    <div
      id="joystick"
      phx-hook="JoyStick"
      phx-update="ignore"
      class="fixed w-[min(70vw,70vh)] h-[min(70vw,70vh)] left-0 top-0 right-0 bottom-0 m-auto"
    >
      <!-- joystick will be rendered here -->
    </div>
    """
  end

  def handle_event("update_joystick_position", %{"x" => x_str, "y" => y_str}, socket) do
    {x, ""} = Integer.parse(x_str)
    {y, ""} = Integer.parse(y_str)

    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @controller, "joystick_position", %{
      x: x / 100,
      y: y / 100,
      id: socket.assigns.player.id
    })

    {:noreply, socket}
  end

  def handle_info(%{topic: @game_state, event: "start_game"}, socket) do
    {:noreply, push_event(socket, "game_started", %{})}
  end

  def handle_info(%{topic: @game_state, event: "stop_game"}, socket) do
    {:noreply, push_event(socket, "game_stopped", %{})}
  end
end
