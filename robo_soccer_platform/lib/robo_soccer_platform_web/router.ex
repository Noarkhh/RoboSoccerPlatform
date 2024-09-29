defmodule RoboSoccerPlatformWeb.Router do
  use RoboSoccerPlatformWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {RoboSoccerPlatformWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :game_controller do
    plug(:browser)
    plug(:auth)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/dashboard", RoboSoccerPlatformWeb do
    pipe_through(:game_controller)

    live "/", GameDashboard
  end

  scope "/", RoboSoccerPlatformWeb do
    pipe_through(:browser)

    get "/", PageController, :home
    live "/player", Player
    live "/player/steering", Player.Steering
  end

  # Other scopes may use custom stacks.
  # scope "/api", RoboSoccerPlatformWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:robo_soccer_platform, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: RoboSoccerPlatformWeb.Telemetry)
    end
  end

  defp auth(conn, _opts) do
    username = System.fetch_env!("CONTROLLER_USERNAME")
    password = System.fetch_env!("CONTROLLER_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
