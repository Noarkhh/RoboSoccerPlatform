defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  @topic "clicks"
  @game_start "game_start"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@topic)
    socket = assign(socket, number_of_clicks: 0)
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      CURRENT NUMBER OF CLICKS: <%= @number_of_clicks %>
    </div>
    <.button phx-click="start_game">
      START GAME
    </.button>
    <%!-- <%= for mess <- @total_messages do %>
      <div>
        <%= mess %>
      </div>
    <% end %> --%>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "hello", 1)
    {:noreply, socket}
  end

  def handle_info(%{topic: @topic}, socket) do
    IO.inspect("HELLO THERE")
    # total_messages_updated = [new_number_of_clicks | socket.assigns.total_messages]
    new_number_of_clicks = socket.assigns.number_of_clicks + 1
    {:noreply, assign(socket, number_of_clicks: new_number_of_clicks)}
  end
end
