defmodule RoboSoccerPlatform.RobotConnection do
  require Logger
  use GenServer

  @type option :: {:team, RoboSoccerPlatform.team()} | {:ip_address, :inet.ip4_address()}
  @type options :: [option()]

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            team: RoboSoccerPlatform.team(),
            local_port: :inet.port_number(),
            socket: :gen_tcp.socket(),
            phase: :listening | :connected
          }

    @enforce_keys [:team, :local_port, :socket]
    defstruct @enforce_keys ++
                [
                  phase: :listening
                ]
  end

  @spec start_link(RoboSoccerPlatform.team(), :inet.port_number(), :inet.ip4_address()) ::
          GenServer.on_start()
  def start_link(team, local_port, robot_ip_address) do
    GenServer.start_link(__MODULE__, {team, local_port, robot_ip_address})
  end

  @spec send_instruction(pid(), %{x: float(), y: float()}) :: :ok
  def send_instruction(robot_connection, instruction) do
    GenServer.cast(robot_connection, {:send_instruction, instruction})
  end

  @impl true
  def init({team, local_port, robot_ip_address}) do
    {:ok, listening_socket} = :gen_tcp.listen(local_port, mode: :binary, reuseaddr: true)
    {:ok, {socket_address, socket_port}} = :inet.sockname(listening_socket)

    Logger.info(
      "Socket for robot #{team} listening on #{:inet.ntoa(socket_address)}:#{socket_port}"
    )

    state = %State{
      team: team,
      local_port: local_port,
      socket: listening_socket,
      phase: :listening
    }

    {:ok, state, {:continue, robot_ip_address}}
  end

  @impl true
  def handle_continue(robot_ip_address, state) do
    {:ok, connected_socket} = :gen_tcp.accept(state.socket)
    {:ok, {peer_ip_address, _peer_port}} = :inet.peername(connected_socket)

    if peer_ip_address != robot_ip_address do
      :gen_tcp.close(connected_socket)

      Logger.warning(
        "Unrecognized connection attempt from address #{:inet.ntoa(peer_ip_address)}"
      )

      {:ok, listening_socket} = :gen_tcp.listen(state.local_port, mode: :binary, reuseaddr: true)
      {:noreply, {:continue, %State{state | socket: listening_socket}}}
    else
      Logger.info(
        "Connection with #{state.team} robot established (robot address: #{:inet.ntoa(peer_ip_address)})"
      )

      {:noreply, %State{state | socket: connected_socket, phase: :connected}}
    end
  end

  @impl true
  def handle_cast(
        {:send_instruction, %{x: x, y: y} = instruction},
        %State{phase: :connected} = state
      ) do
    Logger.info("Sending instruction #{inspect(instruction)} to #{state.team} robot")
    packet = <<x::float, y::float>>

    case :gen_tcp.send(state.socket, packet) do
      :ok -> {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.socket)
  end
end
