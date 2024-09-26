defmodule RoboSoccerPlatform.RobotConnection do
  require Logger
  use GenServer

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            team: RoboSoccerPlatform.team(),
            local_port: :inet.port_number(),
            robot_ip_address: :inet.ip4_address(),
            listening_socket: :gen_tcp.socket(),
            socket: :gen_tcp.socket() | nil
          }

    @enforce_keys [:team, :local_port, :robot_ip_address, :listening_socket]
    defstruct @enforce_keys ++
                [
                  socket: nil
                ]
  end

  @spec start(RoboSoccerPlatform.team(), :inet.port_number(), :inet.ip4_address()) ::
          GenServer.on_start()
  def start(team, local_port, robot_ip_address) do
    GenServer.start(__MODULE__, {team, local_port, robot_ip_address})
  end

  @spec send_instruction(pid(), %{x: float(), y: float()}) :: :ok
  def send_instruction(robot_connection, instruction) do
    GenServer.cast(robot_connection, {:send_instruction, instruction})
  end

  @impl true
  def init({team, local_port, robot_ip_address}) do
    {:ok, listening_socket} = :gen_tcp.listen(local_port, mode: :binary, reuseaddr: true)

    state = %State{
      team: team,
      local_port: local_port,
      robot_ip_address: robot_ip_address,
      listening_socket: listening_socket
    }

    {:ok, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_continue(:initialize_connection, state) do
    {:ok, {socket_address, socket_port}} = :inet.sockname(state.listening_socket)

    Logger.info(
      "Connection process listening for #{state.team} robot on #{:inet.ntoa(socket_address)}:#{socket_port}"
    )

    {:ok, connected_socket} = :gen_tcp.accept(state.listening_socket)
    {:ok, {peer_ip_address, _peer_port}} = :inet.peername(connected_socket)

    if peer_ip_address != state.robot_ip_address do
      :gen_tcp.close(connected_socket)

      Logger.warning(
        "Unrecognized connection attempt from address #{:inet.ntoa(peer_ip_address)}"
      )

      {:noreply, state, {:continue, :initialize_connection}}
    else
      Logger.info(
        "Connection with #{state.team} robot established (robot address: #{:inet.ntoa(peer_ip_address)})"
      )

      {:noreply, %State{state | socket: connected_socket}}
    end
  end

  @impl true
  def handle_cast({:send_instruction, %{x: x, y: y}}, %State{socket: socket} = state)
      when not is_nil(socket) do
    packet = <<x::float, y::float>>

    case :gen_tcp.send(state.socket, packet) do
      :ok ->
        {:noreply, state}

      {:error, :closed} ->
        Logger.warning("Connection with #{state.team} robot severed, retrying")
        {:noreply, state, {:continue, :initialize_connection}}
    end
  end

  @impl true
  def handle_cast(request, state) do
    Logger.warning("""
    Unhandled cast: #{inspect(request)}
    State: #{inspect(state)}
    """)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.warning("Connection with #{state.team} robot severed, retrying")
    {:noreply, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_info({:tcp_error, socket, error}, %{socket: socket} = state) do
    Logger.warning(
      "connection with #{state.team} robot severed with error #{inspect(error)}, retrying"
    )

    {:noreply, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_info(message, state) do
    Logger.warning("Ignoring message: #{inspect(message)}")

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.socket)
  end
end
