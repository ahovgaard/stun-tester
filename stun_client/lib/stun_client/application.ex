defmodule StunClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    case System.fetch_env("LOG_LEVEL") do
      {:ok, level} -> Logger.configure(level: String.to_existing_atom(level))
      :error       -> :ok
    end

    children = [
      StunClient.Pool
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StunClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
