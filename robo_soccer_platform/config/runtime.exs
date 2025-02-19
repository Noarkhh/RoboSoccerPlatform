import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/robo_soccer_platform start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
#
red_robot_connection_type =
  System.fetch_env!("RED_ROBOT_CONNECTION_TYPE") |> String.downcase() |> String.to_atom()

green_robot_connection_type =
  System.fetch_env!("GREEN_ROBOT_CONNECTION_TYPE") |> String.downcase() |> String.to_atom()

config :robo_soccer_platform, RoboSoccerPlatform.GameController,
  aggregation_interval_ms: System.get_env("AGGREGATION_INTERVAL_MS", "10") |> String.to_integer(),
  aggregation_function_name:
    System.get_env("AGGREGATION_FUNCTION_NAME", "AVERAGE")
    |> String.downcase()
    |> String.to_atom(),
  cooperation_metric_function_name:
    System.get_env("COOPERATION_METRIC_FUNCTION_NAME", "EUCLIDEAN_DISTANCE")
    |> String.downcase()
    |> String.to_atom(),
  speed_coefficient: System.get_env("SPEED_COEFFICIENT", "0.5") |> String.to_float(),
  robot_configs: %{
    "red" => RoboSoccerPlatform.ConfigUtils.get_robot_config("RED"),
    "green" => RoboSoccerPlatform.ConfigUtils.get_robot_config("GREEN")
  }

config :robo_soccer_platform, RoboSoccerPlatformWeb.GameDashboard,
  wifi_ssid: System.fetch_env!("WIFI_SSID"),
  wifi_psk: System.fetch_env!("WIFI_PSK"),
  ip: System.fetch_env!("SERVER_IP"),
  port: System.get_env("PHX_PORT", "4000")

if System.get_env("PHX_SERVER") do
  config :robo_soccer_platform, RoboSoccerPlatformWeb.Endpoint, server: true
end

config :robo_soccer_platform, RoboSoccerPlatformWeb.Router,
  username: System.fetch_env!("CONTROLLER_USERNAME"),
  password: System.fetch_env!("CONTROLLER_PASSWORD")

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "0.0.0.0"
  port = String.to_integer(System.get_env("PHX_PORT") || "4000")

  config :robo_soccer_platform, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :robo_soccer_platform, RoboSoccerPlatformWeb.Endpoint,
    check_origin: false,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :robo_soccer_platform, RoboSoccerPlatformWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :robo_soccer_platform, RoboSoccerPlatformWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
