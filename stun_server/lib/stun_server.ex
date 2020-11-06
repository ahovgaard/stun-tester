defmodule StunServer do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    :stun_listener.add_listener({0, 0, 0, 0}, 3478, :udp, [])
    {:ok, %{}}
  end
end
