defmodule RoboSoccerPlatformWeb.Player.PlayersMonitor do
  alias RoboSoccerPlatformWeb.Player.Steering
  use GenServer

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec monitor(pid(), String.t()) :: :ok
  def monitor(pid, player_id) do
    GenServer.call(:players_monitor, {:monitor, pid, player_id})
  end

  def init(_args) do
    Process.register(self(), :players_monitor)
    {:ok, %{players: %{}}}
  end

  def handle_call({:monitor, pid, player_id}, _, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | players: Map.put(state.players, pid, player_id)}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {player_id, new_players} = Map.pop(state.players, pid)
    Steering.unregister(player_id)
    {:noreply, %{state | players: new_players}}
  end
end
