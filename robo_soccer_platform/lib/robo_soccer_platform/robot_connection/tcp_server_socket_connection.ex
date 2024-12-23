defmodule RoboSoccerPlatform.RobotConnection.TCPServerSocketConnection do
  require Logger
  use GenServer
  @behaviour RoboSoccerPlatform.RobotConnection

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            team: RoboSoccerPlatform.team(),
            local_port: :inet.port_number(),
            listening_socket: :gen_tcp.socket(),
            socket: :gen_tcp.socket() | nil
          }

    @enforce_keys [:team, :local_port, :listening_socket]
    defstruct @enforce_keys ++
                [
                  socket: nil
                ]
  end

  @impl true
  def start(team, %{local_port: local_port}) do
    GenServer.start(__MODULE__, {team, local_port})
  end

  @impl true
  def send_instruction(robot_connection, instruction) do
    GenServer.cast(robot_connection, {:send_instruction, instruction})
  end

  @impl true
  def init({team, local_port}) do
    {:ok, listening_socket} = :gen_tcp.listen(local_port, mode: :binary, reuseaddr: true)

    state = %State{
      team: team,
      local_port: local_port,
      listening_socket: listening_socket
    }

    {:ok, state, {:continue, :initialize_connection}}
  end

  @impl true
  def handle_continue(:initialize_connection, state) do
    Logger.info(
      "Connection process listening for #{state.team} robot on port #{state.local_port}"
    )

    {:ok, connected_socket} = :gen_tcp.accept(state.listening_socket)

    Logger.info("Connection with #{state.team} robot established")

    {:noreply, %State{state | socket: connected_socket}}
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
    Logger.warning("[#{inspect(__MODULE__)}] Ignoring message: #{inspect(message)}")

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.socket)
  end
end
