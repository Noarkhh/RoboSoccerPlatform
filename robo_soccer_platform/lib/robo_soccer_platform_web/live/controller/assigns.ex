defmodule RoboSoccerPlatformWeb.Controller.Assigns do
  import Phoenix.Component, only: [assign: 2]

  def assign_red_team(socket) do
    red_team =
      socket.assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "red" end)
      |> Map.values()

    assign(socket, red_team: red_team)
  end

  def assign_green_team(socket) do
    green_team =
      socket.assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "green" end)
      |> Map.values()

    assign(socket, green_team: green_team)
  end
end
