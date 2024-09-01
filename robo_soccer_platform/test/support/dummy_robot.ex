defmodule RoboSoccerPlatform.DummyRobot do
  use GenServer

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    :gen_tcp.connect(opts[:address], opts[:port], mode: :binary, active: true)
    {:ok, opts}
  end

  @impl true
  def handle_info({:tcp, _from, data}, state) do
    <<x::float, y::float, _rest::binary>> = data
    log = "[#{System.os_time(:millisecond)}] x: #{x}, y: #{y}"
    File.write("dupa.txt", log <> "\n", [:append])
    IO.puts(log)
    {:noreply, state}
  end
end
