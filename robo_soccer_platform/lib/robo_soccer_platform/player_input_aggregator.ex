defmodule RoboSoccerPlatform.PlayerInputAggregator do
  use GenServer

  require Logger
  alias RoboSoccerPlatform.{Player, RobotConnection}

  @controller "controller"
  @game_state "game_state"
  @controller_robots_only "controller_robots_only"

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

  defmodule State do
    @type player_input :: %{player: Player.t(), x: float(), y: float()}

    @type t :: %__MODULE__{
            aggregation_interval_ms: pos_integer(),
            aggregation_function: ([float()] -> float()),
            robot_connections: %{RoboSoccerPlatform.team() => pid()},
            player_inputs: %{(player_id :: String.t()) => player_input()},
            game_started: boolean(),
            aggregation_timer: reference() | nil
          }

    @enforce_keys [
      :aggregation_interval_ms,
      :aggregation_function,
      :robot_connections,
      :speed_coefficient
    ]
    defstruct @enforce_keys ++
                [
                  player_inputs: %{},
                  game_started: false,
                  aggregation_timer: nil
                ]
  end

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_state)

    {:ok, init_state(opts)}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "start_game"}, state) do
    {:noreply,
     %{
       state
       | game_started: true,
         aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)
     }}
  end

  @impl true
  def handle_info(%{topic: @game_state, event: "stop_game"}, state) do
    Map.values(state.player_inputs)
    |> Enum.group_by(& &1.player.team)
    |> Enum.each(fn {team, _player_inputs} ->
      RobotConnection.send_instruction(state.robot_connections[team], %{x: 0.0, y: 0.0})
    end)

    Process.cancel_timer(state.aggregation_timer)

    {:noreply, %{state | game_started: false, aggregation_timer: nil}}
  end

  @impl true
  def handle_info(
        %{topic: @controller, event: "register_player", payload: player},
        %State{game_started: false} = state
      ) do
    player_inputs = Map.put(state.player_inputs, player.id, %{player: player, x: 0.0, y: 0.0})

    Logger.debug("""
    New player registered: #{inspect(player)}
    Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
    """)

    {:noreply, %{state | player_inputs: player_inputs}}
  end

  @impl true
  def handle_info(%{topic: @controller, event: "unregister_player", payload: player_id}, state) do
    player_inputs =
      case Map.pop(state.player_inputs, player_id) do
        {%{player: player}, player_inputs} ->
          Logger.debug("""
          Player unregistered: #{inspect(player)}
          Players currently registered: #{inspect(Enum.map(player_inputs, fn {_id, input} -> input.player end))}
          """)

          player_inputs

        {nil, player_inputs} ->
          player_inputs
      end

    {:noreply, %{state | player_inputs: player_inputs}}
  end

  @impl true
  def handle_info(
        %{topic: @controller, event: "joystick_position", payload: %{x: x, y: y, id: id}},
        %State{game_started: true, player_inputs: player_inputs} = state
      )
      when is_map_key(player_inputs, id) do
    player_input = %{state.player_inputs[id] | x: x, y: y}
    state = %{state | player_inputs: %{state.player_inputs | id => player_input}}
    {:noreply, state}
  end

  @impl true
  def handle_info(:aggregate, %State{game_started: true} = state) do
    Map.values(state.player_inputs)
    |> Enum.group_by(& &1.player.team)
    |> Enum.each(fn {team, player_inputs} ->
      instruction =
        aggregate_player_inputs(
          player_inputs,
          state.aggregation_function,
          state.speed_coefficient
        )

      RoboSoccerPlatformWeb.Endpoint.broadcast_from(
        self(),
        @controller_robots_only,
        "new_instructions",
        %{x: instruction.x, y: instruction.y, team: team}
      )

      RobotConnection.send_instruction(state.robot_connections[team], instruction)
    end)

    {:noreply,
     %{state | aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("""
    Ignoring message: #{inspect(msg)}
    State: #{inspect(state)}
    """)

    {:noreply, state}
  end

  @spec init_state(options()) :: State.t()
  def init_state(opts) do
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

    %State{
      robot_connections: robot_connections,
      aggregation_interval_ms: aggregation_interval_ms,
      speed_coefficient: speed_coefficient,
      aggregation_function:
        Function.capture(RoboSoccerPlatform.AggregationFunctions, aggregation_function_name, 1)
    }
  end

  @spec aggregate_player_inputs([State.player_input()], ([integer()] -> float()), float()) ::
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
