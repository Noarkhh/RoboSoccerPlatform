defmodule RoboSoccerPlatform.AggregaationFunctionsTest do
  use RoboSoccerPlatformWeb.ConnCase

  alias RoboSoccerPlatform.AggregationFunctions

  test "median/1" do
    assert AggregationFunctions.median([]) == 0.0

    assert AggregationFunctions.median([1.3]) == 1.3

    assert AggregationFunctions.median([1.3, 4, 6.1, 1.44, 5, 1.22, 3]) == 3.0
  end

  test "average/1" do
    assert AggregationFunctions.median([]) == 0.0

    assert AggregationFunctions.median([1.3]) == 1.3

    assert_in_delta(
      AggregationFunctions.average([1.3, 4, 6.1, 1.44, 5, 1.22, 3]),
      3.1514,
      0.0001
    )
  end
end
