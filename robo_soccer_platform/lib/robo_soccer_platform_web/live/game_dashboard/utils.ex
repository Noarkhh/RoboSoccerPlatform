defmodule RoboSoccerPlatformWeb.GameDashboard.Utils do
  @type point :: %{x: x :: float(), y: y :: float()}

  @spec point_to_direction(point :: point()) :: String.t()
  def point_to_direction(%{x: x, y: y}) when x == 0 and y == 0 do
    # icon name for no action
    "pan_tool"
  end

  def point_to_direction(%{x: _, y: _} = point) do
    point
    |> point_to_angle()
    |> angle_to_direction()
  end

  defp point_to_angle(%{x: x, y: y}) do
    y
    |> :math.atan2(x)
    |> radians_to_degrees()
    |> normalize_angle()
  end

  defp radians_to_degrees(radians) do
    radians * 180 / :math.pi()
  end

  defp normalize_angle(degrees) when degrees < 0, do: degrees + 360
  defp normalize_angle(degrees), do: degrees

  defp angle_to_direction(angle) do
    cond do
      angle <= 22.5 -> "east"
      angle <= 67.5 -> "north_east"
      angle <= 112.5 -> "north"
      angle <= 157.5 -> "north_west"
      angle <= 202.5 -> "west"
      angle <= 247.5 -> "south_west"
      angle <= 292.5 -> "south"
      angle <= 337.5 -> "south_east"
      angle <= 360 -> "east"
    end
  end
end
