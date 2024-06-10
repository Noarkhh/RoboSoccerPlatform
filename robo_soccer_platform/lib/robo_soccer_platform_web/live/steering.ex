defmodule RoboSoccerPlatformWeb.Player.Steering do
  use RoboSoccerPlatformWeb, :live_view

  @game_start "game_start"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_start)

    socket =
      socket
      |> assign(x: 0)
      |> assign(y: 0)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(team: params["team"])
      |> assign(username: params["username"])

    {:noreply, socket}
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

    <div>
      <div>
        X: <%= @x %>
      </div>
      <div>
        Y: <%= @y %>
      </div>
    </div>
    """
  end

  def handle_event("update_joystick_position", %{"x" => x, "y" => y}, socket) do
    socket =
      socket
      |> assign(x: x)
      |> assign(y: y)

    # TODO przesylanie x i y na serwer (ewentualnie jeszcze zmienianie je na jakis format przed wyslaniem)

    {:noreply, socket}
  end

  def handle_info(%{topic: @game_start}, socket) do
    {:noreply, push_event(socket, "game_started", %{})}
  end
end
