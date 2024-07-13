defmodule RoboSoccerPlatformWeb.Controller.Assigns do
  import Phoenix.Component, only: [assign: 2]

  def assign_red_team(assigns) do
    red_team =
      assigns.players
      |> Enum.map(fn {_key, player} -> player end)
      |> Enum.filter(fn player -> player.team == "red" end)

    assign(assigns, red_team: red_team)
  end

  def assign_green_team(assigns) do
    green_team =
      assigns.players
      |> Enum.map(fn {_key, player} -> player end)
      |> Enum.filter(fn player -> player.team == "green" end)

    assign(assigns, green_team: green_team)
  end
end
