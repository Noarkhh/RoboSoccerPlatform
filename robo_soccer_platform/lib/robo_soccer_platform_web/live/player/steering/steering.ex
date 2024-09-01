defmodule RoboSoccerPlatformWeb.Player.Steering do
  use RoboSoccerPlatformWeb, :live_view

  @game_state "game_state"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_state)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    id = params["id"]
    team = params["team"]
    username = params["username"]

    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @controller, "register_player", %{
      id: id,
      team: team,
      username: username
    })

    socket
    |> assign(id: id)
    |> assign(team: team)
    |> assign(username: username)
    |> then(&{:noreply, &1})
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

  def handle_event("update_joystick_position", %{"x" => x, "y" => y}, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @controller, "joystick_position", %{
      x: x,
      y: y,
      id: socket.assigns.id
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
