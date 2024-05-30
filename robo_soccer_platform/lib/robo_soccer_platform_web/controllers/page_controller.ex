defmodule RoboSoccerPlatformWeb.PageController do
  use RoboSoccerPlatformWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/player")
  end
end
