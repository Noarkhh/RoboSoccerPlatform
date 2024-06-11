defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  alias RoboSoccerPlatform.Player

  @game_start "game_start"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)

    socket =
      socket
      |> assign(game_started: false)
      |> assign(players: %{})

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-[80vh] items-center">
      <.button
        :if={not @game_started}
        phx-click="start_game"
        class="h-[40vh] bg-light-green w-full !text-black !text-4xl"
      >
        START GAME
      </.button>
      <%!-- just for debugging purposes - might delete later --%>
      <div class="flex flex-col">
        <div :for={{_player_id, player} <- @players}>
          USERNAME: <%= player.username %> TEAM: <%= player.team %> X: <%= player[:x] %>, Y: <%= player[
            :y
          ] %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "start_game", nil)
    {:noreply, assign(socket, game_started: true)}
  end

  def handle_info(
        %{
          topic: @controller,
          event: "register",
          payload: %Player{id: id, team: team, username: username}
        },
        socket
      ) do
    # allow registering only before game start

    if socket.assigns.game_started do
      {:noreply, socket}
    else
      players = Map.put(socket.assigns.players, id, %{team: team, username: username})
      {:noreply, assign(socket, players: players)}
    end
  end

  def handle_info(
        %{topic: @controller, event: "joystick_position", payload: %{x: x, y: y, id: id}},
        socket
      ) do
    if Map.has_key?(socket.assigns.players, id) do
      player = Map.get(socket.assigns.players, id, %{})
      updated_player = Map.merge(player, %{x: x, y: y})

      players = Map.put(socket.assigns.players, id, updated_player)

      {:noreply, assign(socket, players: players)}
    else
      {:noreply, socket}
    end
  end
end
