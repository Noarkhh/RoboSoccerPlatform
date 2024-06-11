defmodule RoboSoccerPlatform.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RoboSoccerPlatformWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:robo_soccer_platform, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RoboSoccerPlatform.PubSub},
      # Start a worker by calling: RoboSoccerPlatform.Worker.start_link(arg)
      # {RoboSoccerPlatform.Worker, arg},
      # Start to serve requests, typically the last entry
      RoboSoccerPlatformWeb.Endpoint,
      {RoboSoccerPlatform.PlayerInputAggregator,
       Application.get_env(:robo_soccer_platform, RoboSoccerPlatform.PlayerInputAggregator)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RoboSoccerPlatform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RoboSoccerPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
