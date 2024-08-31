defmodule RoboSoccerPlatformWeb.Controller.Assigns do
  import Phoenix.Component, only: [assign: 2]

  def assign_red_team(assigns) do
    red_team =
      assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "red" end)
      |> Map.values()

    assign(assigns, red_team: red_team)
  end

  def assign_green_team(assigns) do
    green_team =
      assigns.players
      |> Map.filter(fn {_player_id, player} -> player.team == "green" end)
      |> Map.values()

    assign(assigns, green_team: green_team)
  end
end
