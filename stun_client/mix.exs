defmodule StunClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :stun_client,
      version: "0.1.14",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {StunClient.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:stun, "~> 1.0"},
      {:gen_state_machine, "~> 3.0.0"}
    ]
  end

  defp releases do
    [
      stun_client: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
