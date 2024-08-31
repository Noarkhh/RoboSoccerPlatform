defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Assigns
  import RoboSoccerPlatformWeb.Controller.Components, only: [before_game_view: 1, in_game_view: 1]

  @game_start "game_start"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)

    socket
    |> assign(game_started: false)
    |> assign(players: %{})
    |> assign(green_team: [])
    |> assign(red_team: [])
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view red_team={@red_team} green_team={@green_team} :if={@game_started}/>
      <.in_game_view red_team={@red_team} green_team={@green_team} :if={not @game_started}/>
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "start_game", nil)
    {:noreply, assign(socket, game_started: true)}
  end

  def handle_event("stop_game", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("goal_red", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("goal_green", _params, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{
          topic: @controller,
          event: "register_player",
          payload: %{id: id, team: team, username: username}
        },
        socket
      ) do
    # allow registering only before game start
    if socket.assigns.game_started do
      {:noreply, socket}
    else
      players = Map.put(socket.assigns.players, id, %{team: team, username: username, x: 0, y: 0})

      socket
      |> assign(players: players)
      |> assign_red_team()
      |> assign_green_team()
      |> then(&{:noreply, &1})
    end
  end

  def handle_info(
        %{
          topic: @controller,
          event: "joystick_position",
          payload: %{x: x, y: y, id: id}
        },
        socket
      ) do
    if Map.has_key?(socket.assigns.players, id) do
      updated_player =
        socket.assigns.players
        |> Map.get(id)
        |> Map.merge(%{x: x, y: y})

      players = Map.put(socket.assigns.players, id, updated_player)

      socket
      |> assign(players: players)
      |> assign_red_team()
      |> assign_green_team()
      |> then(&{:noreply, &1})
    else
      {:noreply, socket}
    end
  end
end
