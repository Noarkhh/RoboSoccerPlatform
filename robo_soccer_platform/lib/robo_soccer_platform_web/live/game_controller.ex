defmodule RoboSoccerPlatformWeb.GameController do
  require Logger
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.GameController.Components,
    only: [before_game_view: 1, in_game_view: 1]

  alias RoboSoccerPlatformWeb.Endpoint

  @game_state "game_state"
  @type steering_state :: %{
          player_inputs: %{
            (player_id :: String.t()) => RoboSoccerPlatform.GameController.player_input()
          },
          robot_instructions: %{RoboSoccerPlatform.team() => %{x: float(), y: float()}}
        }
  @type teams :: %{
          RoboSoccerPlatform.team() => %{
            player_inputs: [RoboSoccerPlatform.GameController.player_input()],
            robot_instruction: %{x: float(), y: float()},
            goals: non_neg_integer()
          }
        }

  @spec update_steering_state(pid(), steering_state()) :: :ok
  def update_steering_state(pid, steering_state) do
    GenServer.cast(pid, {:update_steering_state, steering_state})
  end

  @impl true
  def mount(_params, _session, socket) do
    {room_code, steering_state} = RoboSoccerPlatform.GameController.get_init_data(self())

    # Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)

    socket
    |> assign(room_code: room_code)
    |> assign(teams: init_teams(steering_state))
    |> assign(game_state: :lobby)
    |> assign(seconds_left: 10 * 60)
    |> then(&{:ok, &1})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view :if={@game_state == :lobby} teams={@teams} room_code={@room_code} />

      <.in_game_view
        :if={@game_state != :lobby}
        teams={@teams}
        game_state={@game_state}
        seconds_left={@seconds_left}
        room_code={@room_code}
      />
    </div>
    """
  end

  @impl true
  def handle_cast({:update_steering_state, steering_state}, socket) do
    socket
    |> assign(teams: update_teams(socket.assigns.teams, steering_state))
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "start_game", nil)

    Process.send_after(self(), :tick, 1000)

    socket
    |> assign(game_state: :started)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("stop_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)

    socket
    |> assign(game_state: :stopped)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("goal", %{"team" => team}, socket) do
    teams = update_in(socket.assigns.teams, [team, :goals], &(&1 + 1))

    socket
    |> assign(teams: teams)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("reset_score", _params, socket) do
    teams =
      socket.assigns.teams
      |> Map.new(fn {team, team_data} -> {team, %{team_data | goals: 0}} end)

    socket
    |> assign(teams: teams)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info(:tick, socket) when socket.assigns.game_state != :started,
    do: {:noreply, socket}

  @impl true
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

  @impl true
  def handle_info(message, socket) do
    Logger.warning("[#{inspect(__MODULE__)}] Ignoring message: #{inspect(message)}")
    {:noreply, socket}
  end

  @spec init_teams(steering_state()) :: teams()
  defp init_teams(steering_state) do
    update_teams(%{}, steering_state)
  end

  @spec update_teams(teams(), steering_state()) :: teams()
  defp update_teams(teams, steering_state) do
    steering_state.robot_instructions
    |> Map.new(fn {team, robot_instruction} ->
      team_player_inputs =
        steering_state.player_inputs
        |> Map.values()
        |> Enum.filter(&(&1.player.team == team))

      {
        team,
        %{
          player_inputs: team_player_inputs,
          robot_instruction: robot_instruction,
          goals: get_in(teams, [team, :goals]) || 0
        }
      }
    end)
  end
end
