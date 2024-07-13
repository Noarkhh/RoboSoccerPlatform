defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Assigns

  @game_start "game_start"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)

    socket =
      socket
      |> assign(game_started: false)
      |> assign(players: %{})
      |> assign(green_team: [])
      |> assign(red_team: [])

    {:ok, socket}
  end

  def render(assigns) do
    assigns =
      assigns
      |> assign_red_team()
      |> assign_green_team()

    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <div class="flex flex-1" :if={not @game_started}>
        <div class="flex flex-col flex-1">
          <div class="text-center rounded-tl-3xl bg-light-orange p-2">
            druzyna czerwona
          </div>
          <div class="flex flex-col flex-1 rounded-bl-3xl bg-light-red px-16 py-8 gap-5">
            <div class="text-center bg-sky-blue" :for={player <- @red_team}>
              <%= player.username %>
            </div>
          </div>
        </div>
        <div class="flex flex-col flex-1">
          <div class="text-center rounded-tr-3xl bg-light-orange p-2">
            druzyna zielona
          </div>
          <div class="flex flex-col flex-1 rounded-br-3xl bg-light-green px-16 py-8 gap-5">
            <div class="text-center bg-sky-blue" :for={player <- @green_team}>
              <%= player.username %>
            </div>
          </div>
        </div>
      </div>
      <div class="flex justify-center">
        <.button
          :if={not @game_started}
          phx-click="start_game"
          class="bg-white !text-black !text-4xl"
        >
          START
        </.button>
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
          payload: %{id: id, team: team, username: username}
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
