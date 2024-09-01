defmodule RoboSoccerPlatformWeb.Controller.Assigns do
  import Phoenix.Component, only: [assign: 2]

  def assign_teams(socket) do
    red_players =
      socket.assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "red" end)
      |> Map.values()

    green_players =
      socket.assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "green" end)
      |> Map.values()

    teams =
      socket.assigns.teams
      |> put_in([:red, :players], red_players)
      |> put_in([:green, :players], green_players)

    assign(socket, teams: teams)
  end
end
