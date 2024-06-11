# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :robo_soccer_platform, RoboSoccerPlatform.PlayerInputAggregator,
  aggregation_interval_ms: 2000,
  aggregation_function_name: :median

config :robo_soccer_platform,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :robo_soccer_platform, RoboSoccerPlatformWeb.Endpoint,
  url: [host: "0.0.0.0"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RoboSoccerPlatformWeb.ErrorHTML, json: RoboSoccerPlatformWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RoboSoccerPlatform.PubSub,
  live_view: [signing_salt: "QeHFERz6"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  robo_soccer_platform: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  robo_soccer_platform: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
