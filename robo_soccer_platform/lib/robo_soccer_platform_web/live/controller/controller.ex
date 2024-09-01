defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Assigns
  import RoboSoccerPlatformWeb.Controller.Components, only: [before_game_view: 1, in_game_view: 1]

  @game_start "game_start"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)

    socket
    |> assign(game_state: :before_start)
    |> assign(players: %{})
    |> assign(green_team: [])
    |> assign(red_team: [])
    |> assign(green_goals: 0)
    |> assign(red_goals: 0)
    |> assign(seconds_left: 0)
    |> assign(time_is_over: false)
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view
        :if={@game_state == :before_start}
        red_team={@red_team}
        green_team={@green_team}
      />

      <.in_game_view
        :if={@game_state != :before_start}
        game_state={@game_state}
        red_team={@red_team}
        green_team={@green_team}
        seconds_left={@seconds_left}
        red_goals={@red_goals}
        green_goals={@green_goals}
        time_is_over={@time_is_over}
      />
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "start_game", nil)

    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(seconds_left: 10 * 60)
    |> assign(time_is_over: false)
    |> assign(game_state: :started)
    |> then(&{:noreply, &1})
  end

  def handle_event("start_game_again", _params, socket) do
    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(game_state: :started)
    |> then(&{:noreply, &1})
  end

  def handle_event("stop_game", _params, socket) do
    socket
    |> assign(game_state: :stopped)
    |> then(&{:noreply, &1})
  end

  def handle_event("goal_red", _params, socket) do
    socket
    |> assign(red_goals: socket.assigns.red_goals + 1)
    |> then(&{:noreply, &1})
  end

  def handle_event("goal_green", _params, socket) do
    socket
    |> assign(green_goals: socket.assigns.green_goals + 1)
    |> then(&{:noreply, &1})
  end

  def handle_event("reset_score", _params, socket) do
    socket
    |> assign(green_goals: 0)
    |> assign(red_goals: 0)
    |> then(&{:noreply, &1})
  end

  def handle_info(:tick, socket) when socket.assigns.game_state != :started, do: {:noreply, socket}

  def handle_info(:tick, socket) do
    seconds_left = socket.assigns.seconds_left - 1

    if seconds_left > 0 do
      Process.send_after(self(), :tick, 1000)

      socket
      |> assign(seconds_left: seconds_left)
      |> then(&{:noreply, &1})
    else
      socket
      |> assign(seconds_left: seconds_left)
      |> assign(time_is_over: true)
      |> then(&{:noreply, &1})
    end
  end

  # allow registering only before game start
  def handle_info(%{topic: @controller, event: "register_player"}, socket) when socket.assigns.game_state != :before_start do
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
    players = Map.put(socket.assigns.players, id, %{team: team, username: username, x: 0, y: 0})

    socket
    |> assign(players: players)
    |> assign_red_team()
    |> assign_green_team()
    |> then(&{:noreply, &1})
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
