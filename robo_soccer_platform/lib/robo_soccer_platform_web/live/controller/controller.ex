defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Components, only: [before_game_view: 1, in_game_view: 1]

  alias RoboSoccerPlatformWeb.Controller.Assigns
  alias RoboSoccerPlatformWeb.Endpoint

  @game_state "game_state"
  @controller "controller"
  @is_game_started "is_game_started"
  @controller_robots_only "controller_robots_only"
  @disconnect "disconnect"

  def mount(_params, _session, socket) do
    Endpoint.subscribe(@controller)
    Endpoint.subscribe(@controller_robots_only)
    Endpoint.subscribe(@is_game_started)

    socket
    |> assign(room_code: get_random_room_code())
    |> assign(game_state: :before_start)
    |> assign(players: %{})
    |> assign(teams: %{
      green: %{players: [], goals: 0, instruction: %{x: 0, y: 0}},
      red: %{players: [], goals: 0, instruction: %{x: 0, y: 0}}
    })
    |> assign(seconds_left: 10 * 60)
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view
        :if={@game_state == :before_start}
        teams={@teams}
        room_code={@room_code}
      />

      <.in_game_view
        :if={@game_state != :before_start}
        teams={@teams}
        game_state={@game_state}
        seconds_left={@seconds_left}
        room_code={@room_code}
      />
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "start_game", nil)

    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(game_state: :started)
    |> then(&{:noreply, &1})
  end

  def handle_event("stop_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)

    socket
    |> assign(game_state: :stopped)
    |> then(&{:noreply, &1})
  end

  def handle_event("start_game_again", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "start_game", nil)
    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(game_state: :started)
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
      Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)

      socket
      |> assign(game_state: :stopped)
      |> assign(seconds_left: 10 * 60)
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
          payload: %{id: id, room_code: room_code}
        },
        socket
      ) when room_code != socket.assigns.room_code do
    Endpoint.broadcast_from(self(), @disconnect, "disconnect", %{id: id})

    {:noreply, socket}
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

  # handle wrong room code passed
  def handle_info(%{topic: @is_game_started, event: "request", payload: %{id: id, code: code}}, socket) when code != socket.assigns.room_code do
    Endpoint.broadcast_from(
      self(),
      @is_game_started,
      "response",
      %{state: socket.assigns.game_state, id: id, code: :error}
    )

    {:noreply, socket}
  end

  def handle_info(%{topic: @is_game_started, event: "request", payload: %{id: id, team: team}}, socket) do
    Endpoint.broadcast_from(
      self(),
      @is_game_started,
      "response",
      %{state: socket.assigns.game_state, id: id, team: team}
    )

    {:noreply, socket}
  end

  def handle_info(%{topic: @controller_robots_only, event: "new_instructions", payload: %{x: x, y: y, team: team}}, socket) do
    team_atom = String.to_existing_atom(team)

    teams = put_in(socket.assigns.teams, [team_atom, :instruction], %{x: x, y: y})

    {:noreply, assign(socket, teams: teams)}
  end

  defp get_random_room_code() do
    Enum.random(10000..99999)
    |> to_string()
  end
end
