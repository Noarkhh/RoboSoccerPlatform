defmodule RoboSoccerPlatform.GameController do
  use GenServer

  require Logger

  alias Hex.State

  alias RoboSoccerPlatform.{
    AggregationFunctions,
    CooperationMetricFunctions,
    Player,
    RobotConnection
  }

  alias RoboSoccerPlatformWeb.GameDashboard

  @game_state "game_state"

  @type robot_config ::
          {RobotConnection.TCPServerSocketConnection, %{local_port: :inet.port_number()}}
          | {RobotConnection.BluetoothConnection, %{bluetooth_serial_port: String.t()}}
  @type option ::
          {:aggregation_interval_ms, pos_integer()}
          | {:aggregation_function_name, atom()}
          | {:cooperation_metric_function_name, atom()}
          | {:robot_configs, %{RoboSoccerPlatform.team() => robot_config()}}
          | {:speed_coefficient, float()}
  @type options :: [option()]
  @type game_state :: :lobby | :started | :stopped
  @type player_input :: %{player: Player.t(), x: float(), y: float()}

  defmodule State do
    @moduledoc false
    defmodule TeamState do
      @type t :: %__MODULE__{
              robot_connection: pid(),
              robot_connection_module: RoboSoccerPlatform.RobotConnection.t(),
              current_instruction: %{x: float(), y: float()},
              current_cooperation_metric: float(),
              total_cooperation_metric: float()
            }

      @enforce_keys [:robot_connection, :robot_connection_module]
      defstruct @enforce_keys ++
                  [
                    current_instruction: %{x: 0.0, y: 0.0},
                    current_cooperation_metric: 0.0,
                    total_cooperation_metric: 0.0
                  ]
    end

    alias RoboSoccerPlatform.GameController

    @type t :: %__MODULE__{
            aggregation_interval_ms: pos_integer(),
            cooperation_metric_function: CooperationMetricFunctions.signature(),
            speed_coefficient: float(),
            aggregation_function: AggregationFunctions.signature(),
            number_of_aggregations: integer(),
            team_states: %{RoboSoccerPlatform.team() => TeamState.t()},
            player_inputs: %{(player_id :: String.t()) => GameController.player_input()},
            player_pids: %{pid() => player_id :: String.t()},
            game_state: GameController.game_state(),
            aggregation_timer: reference() | nil,
            room_code: String.t(),
            game_dashboard_pid: pid() | nil
          }

    @enforce_keys [
      :aggregation_interval_ms,
      :aggregation_function,
      :cooperation_metric_function,
      :speed_coefficient,
      :room_code,
      :team_states
    ]
    defstruct @enforce_keys ++
                [
                  player_inputs: %{},
                  player_pids: %{},
                  game_state: :lobby,
                  aggregation_timer: nil,
                  game_dashboard_pid: nil,
                  number_of_aggregations: 0
                ]
  end

  @spec get_game_state() :: game_state()
  def get_game_state() do
    GenServer.call(:game_controller, :get_game_state)
  end

  @spec room_code_correct?(String.t()) :: boolean()
  def room_code_correct?(room_code) do
    GenServer.call(:game_controller, {:room_code_correct?, room_code})
  end

  @spec init_game_dashboard(pid()) ::
          {room_code :: String.t(), GameDashboard.steering_state(), game_state()}
  def init_game_dashboard(game_dashboard_pid) do
    GenServer.call(:game_controller, {:init_game_dashboard, game_dashboard_pid})
  end

  @spec reset_stats() :: :ok
  def reset_stats() do
    GenServer.cast(:game_controller, :reset_stats)
  end

  @spec register_player(Player.t(), pid()) :: :ok
  def register_player(player, player_pid) do
    GenServer.cast(:game_controller, {:register_player, player, player_pid})
  end

  @spec update_player_input(String.t(), float(), float()) :: :ok
  def update_player_input(player_id, x, y) do
    GenServer.cast(:game_controller, {:update_player_input, player_id, x, y})
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_state)
    Process.register(self(), :game_controller)

    {:ok, init_state(opts)}
  end

  @impl true
  def handle_call(:get_game_state, _from, state) do
    {:reply, state.game_state, state}
  end

  @impl true
  def handle_call({:room_code_correct?, room_code}, _from, state) do
    {:reply, state.room_code == room_code, state}
  end

  @impl true
  def handle_call({:init_game_dashboard, game_dashboard_pid}, _from, state) do
    steering_state = %{
      player_inputs: state.player_inputs,
      team_states: state.team_states,
      number_of_aggregations: state.number_of_aggregations
    }

    {:reply, {state.room_code, steering_state, state.game_state},
     %State{state | game_dashboard_pid: game_dashboard_pid}}
  end

  @impl true
  def handle_cast(:reset_stats, state) do
    {:noreply,
     %State{
       state
       | team_states: reset_team_states(state.team_states),
         number_of_aggregations: 0
     }}
  end

  @impl true
  def handle_cast({:register_player, player, player_pid}, state) do
    player_inputs = Map.put(state.player_inputs, player.id, %{player: player, x: 0.0, y: 0.0})
    Process.monitor(player_pid)
    player_pids = Map.put(state.player_pids, player_pid, player.id)

    Logger.debug("""
    New player registered: #{inspect(player)}
    Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
    Processes currently monitored: #{inspect(player_pids)}
    """)

    state = %State{state | player_inputs: player_inputs, player_pids: player_pids}
    update_dashboard_steering_state(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_player_input, player_id, x, y}, state) do
    state =
      if Map.has_key?(state.player_inputs, player_id) do
        update_in(state.player_inputs[player_id], &%{&1 | x: x, y: y})
      else
        Logger.warning("Tried to update input for not registered player #{inspect(player_id)}")
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "start_game"}, state) do
    {:noreply,
     %{
       state
       | game_state: :started,
         aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)
     }}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, state) do
    team_states =
      state.team_states
      |> Map.new(fn {team, team_state} ->
        team_state.robot_connection_module.send_instruction(
          team_state.robot_connection,
          %{x: 0.0, y: 0.0}
        )

        {team,
         %State.TeamState{
           team_state
           | current_instruction: %{x: 0.0, y: 0.0},
             current_cooperation_metric: 0.0
         }}
      end)

    if state.aggregation_timer, do: Process.cancel_timer(state.aggregation_timer)

    {:noreply,
     %State{
       state
       | team_states: team_states,
         game_state: :stopped,
         aggregation_timer: nil
     }}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "new_room"}, state) do
    Logger.debug("Creating a new room, generating new room code")

    if state.aggregation_timer, do: Process.cancel_timer(state.aggregation_timer)

    state = %State{
      state
      | game_state: :lobby,
        aggregation_timer: nil,
        room_code: generate_room_code(),
        team_states: reset_team_states(state.team_states),
        number_of_aggregations: 0
    }

    GameDashboard.update_room(state.game_dashboard_pid, state.room_code)
    update_dashboard_steering_state(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "kick", payload: %{player_id: player_id}}, state) do
    {player_input, _} = Map.pop(state.player_inputs, player_id)

    Logger.debug("Player kicked: #{inspect(player_input.player)}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, player_pid, _reason}, state) do
    case Map.pop(state.player_pids, player_pid) do
      {nil, _player_pids} ->
        Logger.warning(
          "Tried to unregister a player that's not registered, pid: #{inspect(player_pid)}"
        )

        {:noreply, state}

      {player_id, player_pids} ->
        state = %State{state | player_pids: player_pids}

        if player_id in Map.values(player_pids) do
          Logger.warning("Duplicate player, not unregistering, pid: #{inspect(player_pid)}")
          {:noreply, state}
        else
          {:noreply, unregister_player(player_id, state)}
        end
    end
  end

  @impl true
  def handle_info(:aggregate, %State{game_state: :started} = state) do
    team_states =
      state.team_states
      |> Map.new(fn {team, team_state} ->
        team_player_inputs =
          state.player_inputs
          |> Map.values()
          |> Enum.filter(&(&1.player.team == team))

        instruction =
          team_player_inputs
          |> aggregate_player_inputs(state.aggregation_function, state.speed_coefficient)

        current_cooperation_metric =
          team_player_inputs
          |> calculate_cooperation_metric(
            instruction.x,
            instruction.y / state.speed_coefficient,
            state.cooperation_metric_function
          )

        team_state.robot_connection_module.send_instruction(
          team_state.robot_connection,
          instruction
        )

        total_cooperation_metric =
          team_state.total_cooperation_metric + current_cooperation_metric

        team_state = %State.TeamState{
          team_state
          | current_instruction: instruction,
            current_cooperation_metric: current_cooperation_metric,
            total_cooperation_metric: total_cooperation_metric
        }

        {team, team_state}
      end)

    state = %State{
      state
      | team_states: team_states,
        aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms),
        number_of_aggregations: state.number_of_aggregations + 1
    }

    update_dashboard_steering_state(state)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("""
    [#{inspect(__MODULE__)}] Ignoring message: #{inspect(msg)}
    State: #{inspect(state)}
    """)

    {:noreply, state}
  end

  @spec init_state(options()) :: State.t()
  defp init_state(opts) do
    aggregation_interval_ms = opts[:aggregation_interval_ms]
    aggregation_function_name = opts[:aggregation_function_name]
    cooperation_metric_function_name = opts[:cooperation_metric_function_name]
    speed_coefficient = opts[:speed_coefficient]

    team_states =
      opts
      |> Keyword.fetch!(:robot_configs)
      |> Map.new(fn {team, {robot_connection_module, robot_connection_config}} ->
        {:ok, pid} = robot_connection_module.start(team, robot_connection_config)
        Logger.info("Started RobotConnection for team #{team} with pid #{inspect(pid)}")

        team_state = %State.TeamState{
          robot_connection: pid,
          robot_connection_module: robot_connection_module
        }

        {team, team_state}
      end)

    aggregation_function =
      if {aggregation_function_name, 1} in AggregationFunctions.__info__(:functions) do
        Function.capture(AggregationFunctions, aggregation_function_name, 1)
      else
        raise "Provided aggregation function not implemented: RoboSoccerPlatform.AggregationFunctions.#{Atom.to_string(aggregation_function_name)}/1"
      end

    cooperation_metric_function =
      if {cooperation_metric_function_name, 3} in CooperationMetricFunctions.__info__(:functions) do
        Function.capture(CooperationMetricFunctions, cooperation_metric_function_name, 3)
      else
        raise "Provided cooperation metric function not implemented: RoboSoccerPlatform.CooperationMetricFunctions.#{Atom.to_string(cooperation_metric_function_name)}/3"
      end

    %State{
      team_states: team_states,
      aggregation_interval_ms: aggregation_interval_ms,
      speed_coefficient: speed_coefficient,
      room_code: generate_room_code(),
      aggregation_function: aggregation_function,
      cooperation_metric_function: cooperation_metric_function
    }
  end

  @spec aggregate_player_inputs([player_input()], AggregationFunctions.signature(), float()) ::
          %{x: float(), y: float()}
  defp aggregate_player_inputs(player_inputs, aggregation_function, speed_coefficient) do
    %{
      x:
        Enum.map(player_inputs, & &1.x)
        |> then(aggregation_function),
      y:
        Enum.map(player_inputs, & &1.y)
        |> then(aggregation_function)
        |> Kernel.*(speed_coefficient)
    }
  end

  @spec calculate_cooperation_metric(
          [player_input()],
          float(),
          float(),
          CooperationMetricFunctions.signature()
        ) :: float()
  defp calculate_cooperation_metric(
         player_inputs,
         aggregated_x,
         aggregated_y,
         cooperation_metric_function
       ) do
    cooperation_metric_function.(player_inputs, aggregated_x, aggregated_y)
  end

  @spec update_dashboard_steering_state(State.t()) :: :ok
  defp update_dashboard_steering_state(state) do
    GameDashboard.update_steering_state(state.game_dashboard_pid, %{
      player_inputs: state.player_inputs,
      team_states: state.team_states,
      number_of_aggregations: state.number_of_aggregations
    })
  end

  @spec start_aggregation_timer(pos_integer()) :: reference()
  defp start_aggregation_timer(aggregation_interval_ms) do
    Process.send_after(self(), :aggregate, aggregation_interval_ms)
  end

  @spec unregister_player(String.t(), State.t()) :: State.t()
  defp unregister_player(player_id, state) do
    {player_input, player_inputs} = Map.pop(state.player_inputs, player_id)

    Logger.debug("""
    Player unregistered: #{inspect(player_input.player)}
    Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
    """)

    GameDashboard.update_steering_state(
      state.game_dashboard_pid,
      %{
        player_inputs: player_inputs,
        team_states: state.team_states,
        number_of_aggregations: state.number_of_aggregations
      }
    )

    %State{state | player_inputs: player_inputs}
  end

  @spec generate_room_code() :: String.t()
  defp generate_room_code() do
    Enum.random(1000..9999) |> to_string
  end

  @spec reset_team_states(%{RoboSoccerPlatform.team() => State.TeamState.t()}) ::
          %{RoboSoccerPlatform.team() => State.TeamState.t()}
  defp reset_team_states(team_states) do
    Map.new(team_states, fn {team, team_state} ->
      {team, %State.TeamState{team_state | total_cooperation_metric: 0.0}}
    end)
  end
end
