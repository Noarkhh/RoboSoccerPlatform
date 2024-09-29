defmodule RoboSoccerPlatform.GameController do
  use GenServer

  require Logger
  alias RoboSoccerPlatform.{Player, RobotConnection}

  @player_inputs "player_inputs"
  @game_state "game_state"

  @default_aggregation_interval_ms 100
  @default_aggregation_function_name :average
  @default_speed_coefficient 1.0

  @type robot_config :: %{robot_ip_address: String.t(), local_port: String.t()}
  @type option ::
          {:aggregation_interval_ms, pos_integer()}
          | {:aggregation_function_name, atom()}
          | {:robot_configs, %{RoboSoccerPlatform.team() => robot_config()}}
          | {:speed_coefficient, float()}
  @type options :: [option()]
  @type game_state :: :lobby | :started | :stopped | :finished
  @type player_input :: %{player: Player.t(), x: float(), y: float()}

  defmodule State do
    alias RoboSoccerPlatform.GameController

    @type t :: %__MODULE__{
            aggregation_interval_ms: pos_integer(),
            aggregation_function: ([float()] -> float()),
            robot_connections: %{RoboSoccerPlatform.team() => pid()},
            robot_instructions: %{RoboSoccerPlatform.team() => %{x: float(), y: float()}},
            player_inputs: %{(player_id :: String.t()) => GameController.player_input()},
            player_pids: %{pid() => player_id :: String.t()},
            game_state: GameController.game_state(),
            aggregation_timer: reference() | nil,
            room_code: String.t(),
            game_controller_web_pid: pid() | nil
          }

    @enforce_keys [
      :aggregation_interval_ms,
      :aggregation_function,
      :robot_connections,
      :speed_coefficient,
      :room_code
    ]
    defstruct @enforce_keys ++
                [
                  robot_instructions: %{},
                  player_inputs: %{},
                  player_pids: %{},
                  game_state: :lobby,
                  aggregation_timer: nil,
                  game_controller_web_pid: nil
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

  @spec get_init_data(pid()) ::
          {room_code :: String.t(), RoboSoccerPlatformWeb.GameController.steering_state()}
  def get_init_data(game_controller_web_pid) do
    GenServer.call(:game_controller, {:get_init_data, game_controller_web_pid})
  end

  @spec register_player(pid(), Player.t()) :: :ok
  def register_player(pid, player) do
    GenServer.cast(:game_controller, {:register_player, pid, player})
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
  def handle_call({:get_init_data, game_controller_web_pid}, _from, state) do
    robot_instructions =
      state.robot_connections
      |> Map.new(fn {team, _robot_connection} -> {team, %{x: 0.0, y: 0.0}} end)

    steering_state = %{
      player_inputs: state.player_inputs,
      robot_instructions: robot_instructions
    }

    {:reply, {state.room_code, steering_state},
     %{state | game_controller_web_pid: game_controller_web_pid}}
  end

  @impl true
  def handle_cast({:register_player, pid, player}, state) do
    player_inputs = Map.put(state.player_inputs, player.id, %{player: player, x: 0.0, y: 0.0})
    Process.monitor(pid)
    player_pids = Map.put(state.player_pids, pid, player.id)

    RoboSoccerPlatformWeb.GameController.update_steering_state(state.game_controller_web_pid, %{
      player_inputs: player_inputs,
      robot_instructions: state.robot_instructions
    })

    Logger.debug("""
    New player registered: #{inspect(player)}
    Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
    Processes currently monitored: #{inspect(player_pids)}
    """)

    {:noreply, %{state | player_inputs: player_inputs, player_pids: player_pids}}
  end

  @impl true
  def handle_cast({:update_player_input, player_id, x, y}, state) do
    state =
      if Map.has_key?(state.player_inputs, player_id) do
        Bunch.Struct.update_in(state, [:player_inputs, player_id], &%{&1 | x: x, y: y})
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

  # @impl true
  # def handle_info(
  # %{topic: @player_inputs, event: "register_player", payload: player},
  # state
  # ) do
  # player_inputs = Map.put(state.player_inputs, player.id, %{player: player, x: 0.0, y: 0.0})

  # Logger.debug("""
  # New player registered: #{inspect(player)}
  # Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
  # """)

  # {:noreply, %{state | player_inputs: player_inputs}}
  # end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, state) do
    robot_instructions =
      state.robot_connections
      |> Map.new(fn {team, robot_connection} ->
        RobotConnection.send_instruction(robot_connection, %{x: 0.0, y: 0.0})
        {team, %{x: 0.0, y: 0.0}}
      end)

    if state.aggregation_timer, do: Process.cancel_timer(state.aggregation_timer)

    {:noreply,
     %{
       state
       | robot_instructions: robot_instructions,
         game_state: :stopped,
         aggregation_timer: nil
     }}
  end

  # @impl true
  # def handle_info(%{topic: @player_inputs, event: "unregister_player", payload: player_id}, state) do
  # player_inputs =
  # case Map.pop(state.player_inputs, player_id) do
  # {%{player: player}, player_inputs} ->
  # Logger.debug("""
  # Player unregistered: #{inspect(player)}
  # Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
  # """)

  # player_inputs

  # {nil, player_inputs} ->
  # player_inputs
  # end

  # {:noreply, %{state | player_inputs: player_inputs}}
  # end

  @impl true
  def handle_info({:DOWN, _ref, :process, player_pid, _reason}, state) do
    case Map.pop(state.player_pids, player_pid) do
      {nil, _player_pids} ->
        Logger.warning(
          "Tried to unregister a player that's not registered, pid: #{inspect(player_pid)}"
        )

        {:noreply, state}

      {player_id, player_pids} ->
        if player_pids |> Map.values() |> Enum.member?(player_id) do
          Logger.warning("Duplicate player, not unregistering, pid: #{inspect(player_pid)}")
          {:noreply, %{state | player_pids: player_pids}}
        else
          {player_input, player_inputs} = Map.pop(state.player_inputs, player_id)

          Logger.debug("""
          Player unregistered: #{inspect(player_input.player)}
          Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
          """)

          RoboSoccerPlatformWeb.GameController.update_steering_state(
            state.game_controller_web_pid,
            %{
              player_inputs: player_inputs,
              robot_instructions: state.robot_instructions
            }
          )

          {:noreply, %{state | player_inputs: player_inputs, player_pids: player_pids}}
        end
    end
  end

  @impl true
  def handle_info(
        %{topic: @player_inputs, event: "joystick_position", payload: %{x: x, y: y, id: id}},
        %State{player_inputs: player_inputs} = state
      )
      when is_map_key(player_inputs, id) do
    player_input = %{state.player_inputs[id] | x: x, y: y}
    state = %{state | player_inputs: %{state.player_inputs | id => player_input}}
    {:noreply, state}
  end

  @impl true
  def handle_info(:aggregate, %State{game_state: :started} = state) do
    robot_instructions =
      state.robot_connections
      |> Map.new(fn {team, robot_connection} ->
        instruction =
          state.player_inputs
          |> Map.values()
          |> Enum.filter(&(&1.player.team == team))
          |> aggregate_player_inputs(
            state.aggregation_function,
            state.speed_coefficient
          )

        RobotConnection.send_instruction(robot_connection, instruction)
        {team, instruction}
      end)

    RoboSoccerPlatformWeb.GameController.update_steering_state(state.game_controller_web_pid, %{
      player_inputs: state.player_inputs,
      robot_instructions: robot_instructions
    })

    {:noreply,
     %{
       state
       | robot_instructions: robot_instructions,
         aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)
     }}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("""
    PLAYER INPUT AGGREGATOR:  Ignoring message: #{inspect(msg)}
    State: #{inspect(state)}
    """)

    {:noreply, state}
  end

  @spec init_state(options()) :: State.t()
  defp init_state(opts) do
    aggregation_interval_ms =
      Keyword.get(opts, :aggregation_interval_ms, @default_aggregation_interval_ms)

    aggregation_function_name =
      Keyword.get(opts, :aggregation_function_name, @default_aggregation_function_name)

    speed_coefficient =
      Keyword.get(opts, :speed_coefficient, @default_speed_coefficient)

    robot_connections =
      opts
      |> Keyword.fetch!(:robot_configs)
      |> Map.new(fn {team, %{robot_ip_address: ip_address, local_port: local_port}} ->
        {:ok, ip_address} = ip_address |> String.to_charlist() |> :inet.parse_address()
        {local_port, ""} = Integer.parse(local_port)

        case RobotConnection.start(team, local_port, ip_address) do
          {:ok, pid} ->
            Logger.info("Started RobotConnection for team #{team} with pid #{inspect(pid)}")
            {team, pid}

          {:error, reason} ->
            raise "Failed starting RobotConnection for team #{team}, reason: #{reason}"
        end
      end)

    robot_instructions =
      Map.new(robot_connections, fn {team, _robot_connection} -> {team, %{x: 0.0, y: 0.0}} end)

    %State{
      robot_instructions: robot_instructions,
      robot_connections: robot_connections,
      aggregation_interval_ms: aggregation_interval_ms,
      speed_coefficient: speed_coefficient,
      room_code: Enum.random(1000..9999) |> to_string,
      aggregation_function:
        Function.capture(RoboSoccerPlatform.AggregationFunctions, aggregation_function_name, 1)
    }
  end

  @spec aggregate_player_inputs([player_input()], ([integer()] -> float()), float()) ::
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

  @spec start_aggregation_timer(pos_integer()) :: reference()
  defp start_aggregation_timer(aggregation_interval_ms) do
    Process.send_after(self(), :aggregate, aggregation_interval_ms)
  end
end