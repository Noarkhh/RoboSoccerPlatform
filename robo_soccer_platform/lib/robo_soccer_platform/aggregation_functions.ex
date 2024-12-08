defmodule RoboSoccerPlatform.AggregationFunctions do
  @type signature :: ([float()] -> float())

  @spec median([float()]) :: float()
  def median([]) do
    0.0
  end

  def median(integers) do
    sorted = Enum.sort(integers)
    list_length = length(sorted)

    if rem(list_length, 2) == 1 do
      Enum.at(sorted, div(list_length, 2)) * 1.0
    else
      (Enum.at(sorted, div(list_length, 2) - 1) + Enum.at(sorted, div(list_length, 2))) * 0.5
    end
  end

  @spec average([float()]) :: float()
  def average([]) do
    0.0
  end

  def average(integers) do
    Enum.sum(integers) / length(integers)
  end
end
