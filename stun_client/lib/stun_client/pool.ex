defmodule StunClient.Pool do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, server_ip} =
      "STUN_SERVER_IP"
      |> System.fetch_env!()
      |> to_charlist()
      |> :inet.parse_ipv4_address()

    server_port = get_int_env("STUN_SERVER_PORT")
    num_clients = get_int_env("STUN_CLIENT_COUNT")

    worker_args = [server_ip: server_ip, server_port: server_port]
    children = Enum.map(1..num_clients, &(worker_spec(&1, worker_args)))
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp worker_spec(id, worker_args) do
    child_spec = {StunClient.Worker, worker_args}
    Supervisor.child_spec(child_spec, id: id)
  end

  defp get_int_env(env_var) do
    env_var |> System.fetch_env!() |> String.to_integer()
  end
end
