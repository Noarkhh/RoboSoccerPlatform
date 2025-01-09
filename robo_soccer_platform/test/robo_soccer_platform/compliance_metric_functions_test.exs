defmodule RoboSoccerPlatform.ComplianceMetricFunctionsTest do
  use RoboSoccerPlatformWeb.ConnCase

  alias RoboSoccerPlatform.CooperationMetricFunctions
  alias RoboSoccerPlatform.Player

  test "euclidean_distance returns perfect cooperation for empty team" do
    assert CooperationMetricFunctions.euclidean_distance([], 0.0, 0.0) == 1.0
  end

  test "euclidean_distance returns perfect cooperation for team with one player" do
    player_inputs = [
      %{
        player: %Player{id: "id1", username: "user", team: "red"},
        x: 0.5,
        y: 0.5
      }
    ]

    assert CooperationMetricFunctions.euclidean_distance(player_inputs, 0.5, 0.5) == 1.0
  end

   test "euclidean_distance returns correct cooperation team with 2+ players" do
    player_inputs = [
      %{x: 0.5, y: 0.5},
      %{x: 0.1, y: 0.1}
    ]

    aggregated_x = 0.75
    aggregated_y = 0.75

    assert CooperationMetricFunctions.euclidean_distance(
      player_inputs,
      aggregated_x,
      aggregated_y
    ) == 0.55
  end
end
