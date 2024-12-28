defmodule RoboSoccerPlatform.RobotConnection.BluetoothConnection do
  require Logger
  use GenServer
  @behaviour RoboSoccerPlatform.RobotConnection

  @backoff_time_ms 2000
  @base_speed_coefficient 300
  @base_turn_coefficient 35

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            team: RoboSoccerPlatform.team(),
            bluetooth_serial_port: String.t(),
            uart_gen_server: pid()
          }

    @enforce_keys [:team, :bluetooth_serial_port, :uart_gen_server]
    defstruct @enforce_keys
  end

  @impl true
  def start(team, %{bluetooth_serial_port: bluetooth_serial_port}) do
    GenServer.start(__MODULE__, {team, bluetooth_serial_port})
  end

  @impl true
  def send_instruction(robot_connection, instruction) do
    GenServer.cast(robot_connection, {:send_instruction, instruction})
  end

  @impl true
  def init({team, bluetooth_serial_port}) do
    {:ok, uart_gen_server} = Circuits.UART.start_link()

    state = %State{
      team: team,
      bluetooth_serial_port: bluetooth_serial_port,
      uart_gen_server: uart_gen_server
    }

    {:ok, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_continue(:initialize_connection, state) do
    case Circuits.UART.open(state.uart_gen_server, state.bluetooth_serial_port,
           speed: 115_200,
           active: true
         ) do
      :ok ->
        Logger.info("Bluetooth connection with #{state.team} robot established")

      {:error, error} ->
        Logger.warning(
          "Error establishing bluetooth connection with #{state.team} robot severed with error #{inspect(error)}, retrying in #{@backoff_time_ms} ms"
        )

        Process.send_after(self(), :initialize_connection, @backoff_time_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_instruction, instruction}, state) do
    command = create_wheels_speeds_command(instruction)

    case Circuits.UART.write(state.uart_gen_server, command) do
      :ok ->
        {:noreply, state}

      {:error, :ebadf} ->
        Logger.warning(
          "UART port closed, bluetooth connection with #{state.team} robot severed, retrying in #{@backoff_time_ms} ms"
        )

        Process.send_after(self(), :initialize_connection, @backoff_time_ms)

      {:error, error} ->
        Logger.warning(
          "Bluetooth connection with #{state.team} robot severed with error #{inspect(error)}, retrying in #{@backoff_time_ms} ms"
        )

        Process.send_after(self(), :initialize_connection, @backoff_time_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:circuits_uart, _bt_serial_port, {:error, :eio}}, state) do
    Logger.warning(
      "Bluetooth connection with #{state.team} robot severed, retrying in #{@backoff_time_ms} ms"
    )

    Process.send_after(self(), :initialize_connection, @backoff_time_ms)

    {:noreply, state}
  end

  @impl true
  def handle_info(:initialize_connection, state) do
    {:ok, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_info(message, state) do
    Logger.warning("[#{inspect(__MODULE__)}] Ignoring message: #{inspect(message)}")

    {:noreply, state}
  end

  @spec create_wheels_speeds_command(%{x: float(), y: float()}) :: String.t()
  defp create_wheels_speeds_command(%{x: x, y: y}) do
    left_wheel_speed = y * @base_speed_coefficient + x * @base_turn_coefficient
    right_wheel_speed = y * @base_speed_coefficient - x * @base_turn_coefficient
    "[=#{trunc(left_wheel_speed)},#{trunc(right_wheel_speed)}]"
  end
end
