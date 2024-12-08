defmodule RoboSoccerPlatform.ConfigUtils do
  @spec parse_ip_address!(String.t()) :: :inet.ip_address()
  def parse_ip_address!(address_string) do
    case address_string |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} ->
        address

      {:error, error} ->
        raise "Error parsing address #{inspect(address_string)}, error: #{inspect(error)}"
    end
  end
end
