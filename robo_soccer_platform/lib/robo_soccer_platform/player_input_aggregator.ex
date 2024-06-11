defmodule RoboSoccerPlatform.PlayerInputAggregator do
  use GenServer

  require Logger
  alias RoboSoccerPlatform.Player

  @controller "controller"
  @game_start "game_start"

  @default_aggregation_interval_ms 100
  @default_aggregation_function_name :median

  @type option :: {:aggregation_interval_ms, pos_integer()} | {:aggregation_function_name, atom()}
  @type options :: [option()]

  defmodule State do
    @type player_input :: %{player: Player.t(), x: integer(), y: integer()}

    @type t :: %__MODULE__{
            player_inputs: %{(player_id :: String.t()) => player_input()},
            game_started: boolean(),
            aggregation_timer: reference() | nil,
            aggregation_interval_ms: pos_integer(),
            aggregation_function: ([integer()] -> float())
          }

    @enforce_keys [:aggregation_interval_ms, :aggregation_function]
    defstruct @enforce_keys ++
                [
                  player_inputs: %{},
                  game_started: false,
                  aggregation_timer: nil
                ]
  end

  @spec start_link(options()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)
    RoboSoccerPlatformWeb.Endpoint.subscribe(@game_start)

    {:ok,
     %State{
       aggregation_interval_ms:
         opts[:aggregation_interval_ms] || @default_aggregation_interval_ms,
       aggregation_function:
         Function.capture(
           __MODULE__,
           opts[:aggregation_function_name] ||
             @default_aggregation_function_name,
           1
         )
     }}
  end

  @impl true
  def handle_info(%{topic: @game_start, event: "start_game"}, state) do
    {:noreply,
     %{
       state
       | game_started: true,
         aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)
     }}
  end

  @impl true
  def handle_info(
        %{topic: @controller, event: "register", payload: player},
        %{game_started: false} = state
      ) do
    player_inputs = Map.put(state.player_inputs, player.id, %{player: player, x: 0, y: 0})
    {:noreply, %{state | player_inputs: player_inputs}}
  end

  @impl true
  def handle_info(
        %{topic: @controller, event: "joystick_position", payload: %{x: x, y: y, id: id}},
        %{game_started: true} = state
      ) do
    player_input = %{state.player_inputs[id] | x: x, y: y}
    state = %{state | player_inputs: %{state.player_inputs | id => player_input}}
    {:noreply, state}
  end

  @impl true
  def handle_info(:aggregate, state) do
    aggregated_inputs =
      Map.values(state.player_inputs)
      |> Enum.group_by(& &1.player.team)
      |> Enum.map(fn {team, player_inputs} ->
        {team, aggregate_player_inputs(player_inputs, state.aggregation_function)}
      end)
      |> Enum.into(%{})

    Logger.info("""
    Aggregating inputs: #{inspect(state.player_inputs)}
    Aggregated inputs: #{inspect(aggregated_inputs)}
    """)

    {:noreply,
     %{state | aggregation_timer: start_aggregation_timer(state.aggregation_interval_ms)}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("""
    Unhandled message: #{inspect(msg)}
    State: #{inspect(state)}
    """)

    {:noreply, state}
  end

  @spec aggregate_player_inputs([State.player_input()], ([integer()] -> float())) ::
          %{x: float(), y: float()}
  def aggregate_player_inputs(player_inputs, aggregation_function) do
    x = Enum.map(player_inputs, & &1.x) |> then(aggregation_function)
    y = Enum.map(player_inputs, & &1.y) |> then(aggregation_function)
    %{x: x, y: y}
  end

  @spec start_aggregation_timer(pos_integer()) :: reference()
  defp start_aggregation_timer(aggregation_interval_ms) do
    Process.send_after(self(), :aggregate, aggregation_interval_ms)
  end

  @spec median([integer()]) :: float()
  def median([]) do
    0.0
  end

  def median(integers) do
    sorted = Enum.sort(integers)
    list_length = length(sorted)

    if rem(list_length, 2) == 1 do
      Enum.at(sorted, div(list_length, 2)) * 1.0
    else
      (Enum.at(sorted, div(list_length, 2) - 1) + Enum.at(sorted, div(list_length, 2))) * 0.5
    end
  end
end
