use Mix.Config

config :logger,
  level: if(Mix.env() == :prod, do: :warning, else: :debug)
