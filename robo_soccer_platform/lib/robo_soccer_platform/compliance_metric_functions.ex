defmodule RoboSoccerPlatform.CooperationMetricFunctions do
  alias RoboSoccerPlatform.GameController

  @type signature :: ([GameController.player_input()], float(), float() -> float())

  @doc "returns value from range [0, 1]; 0 - best cooperation, 1 - worst cooperation"
  @spec euclidean_distance([GameController.player_input()], float(), float()) :: float()
  def euclidean_distance([], _, _), do: 0.0
  def euclidean_distance([_player_input], _, _), do: 0.0
  def euclidean_distance(player_inputs, aggregated_x, aggregated_y) do
    player_inputs
    |> Enum.reduce(0.0, fn %{x: x, y: y}, acc ->
      acc + :math.sqrt(:math.pow(x - aggregated_x, 2) + :math.pow(y - aggregated_y, 2))
    end)
    |> Kernel./(length(player_inputs))
    |> Kernel./(:math.sqrt(2))
  end
end
