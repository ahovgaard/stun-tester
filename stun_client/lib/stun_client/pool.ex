defmodule StunClient.Pool do
  def child_spec(_) do
    :poolboy.child_spec(:worker, poolboy_config())
  end

  defp poolboy_config do
    [
      name: {:local, :worker},
      worker_module: StunClient.Worker,
      size: 2
    ]
  end
end
