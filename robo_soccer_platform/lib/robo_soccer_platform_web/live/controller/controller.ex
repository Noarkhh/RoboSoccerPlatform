defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Components, only: [before_game_view: 1, in_game_view: 1]

  alias RoboSoccerPlatformWeb.Controller.Assigns

  @game_state "game_state"
  @controller "controller"
  @is_game_started "is_game_started"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)
    RoboSoccerPlatformWeb.Endpoint.subscribe(@is_game_started)

    socket
    |> assign(game_state: :before_start)
    |> assign(players: %{})
    |> assign(teams: %{
      green: %{players: [], goals: 0},
      red: %{players: [], goals: 0}
    })
    |> assign(seconds_left: 10 * 60)
    |> assign(time_is_over: false)
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view
        :if={@game_state == :before_start}
        teams={@teams}
      />

      <.in_game_view
        :if={@game_state != :before_start}
        teams={@teams}
        game_state={@game_state}
        seconds_left={@seconds_left}
        time_is_over={@time_is_over}
      />
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_state, "started", nil)

    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(game_state: :started)
    |> then(&{:noreply, &1})
  end

  def handle_event("stop_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_state, "stopped", nil)

    socket
    |> assign(game_state: :stopped)
    |> then(&{:noreply, &1})
  end

  def handle_event("goal", %{"team" => team_color}, socket) do
    team_color_as_atom = String.to_existing_atom(team_color)

    teams = update_in(socket.assigns.teams, [team_color_as_atom, :goals], &(&1 + 1))

    socket
    |> assign(teams: teams)
    |> then(&{:noreply, &1})
  end

  def handle_event("reset_score", _params, socket) do
    teams =
      socket.assigns.teams
      |> put_in([:red, :goals], 0)
      |> put_in([:green, :goals], 0)

    socket
    |> assign(teams: teams)
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

  # disable registering when game is started
  def handle_info(%{topic: @controller, event: "register_player"}, socket) when socket.assigns.game_state == :started do
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
    |> Assigns.assign_teams()
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
      |> Assigns.assign_teams()
      |> then(&{:noreply, &1})
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{topic: @is_game_started, event: "request", payload: %{id: id, team: team}}, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(
      self(),
      @is_game_started,
      "response",
      %{state: socket.assigns.game_state, id: id, team: team}
    )

    {:noreply, socket}
  end
end
