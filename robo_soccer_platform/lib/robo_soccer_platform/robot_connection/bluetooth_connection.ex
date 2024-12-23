defmodule RoboSoccerPlatform.RobotConnection.BluetoothConnection do
  require Logger
  use GenServer
  @behaviour RoboSoccerPlatform.RobotConnection

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
    Circuits.UART.open(state.uart_gen_server, state.bluetooth_serial_port,
      speed: 115_200,
      active: true
    )

    IO.inspect("connected")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_instruction, instruction}, state) do
    command = create_wheels_speeds_command(instruction)
    IO.inspect(command, label: "sending")
    :ok = Circuits.UART.write(state.uart_gen_server, command)
    {:noreply, state}
  end

  @spec create_wheels_speeds_command(%{x: float(), y: float()}) :: String.t()
  defp create_wheels_speeds_command(%{x: x, y: y}) do
    left_wheel_speed = y * 200 + x * 25
    right_wheel_speed = y * 200 - x * 25
    "[=#{trunc(left_wheel_speed)},#{trunc(right_wheel_speed)}]"
  end
end
