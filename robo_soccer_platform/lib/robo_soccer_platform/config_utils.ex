defmodule RoboSoccerPlatform.ConfigUtils do
  alias RoboSoccerPlatform.RobotConnection
  @type robot_connection_type :: :tcp_server_socket | :bluetooth

  @spec parse_ip_address!(String.t()) :: :inet.ip_address()
  def parse_ip_address!(address_string) do
    case address_string |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} ->
        address

      {:error, error} ->
        raise "Error parsing address #{inspect(address_string)}, error: #{inspect(error)}"
    end
  end

  @spec get_robot_config(RoboSoccerPlatform.team()) ::
          RoboSoccerPlatform.GameController.robot_config()
  def get_robot_config(team) do
    connection_type = System.fetch_env!("#{team}_ROBOT_CONNECTION_TYPE")

    speed_coefficient =
      System.get_env("#{team}_ROBOT_SPEED_COEFFICIENT", "0.5") |> String.to_float()

    {connection_module, connection_config} =
      case connection_type do
        "TCP_SERVER_SOCKET" ->
          {
            RobotConnection.TCPServerSocketConnection,
            %{
              local_port: System.fetch_env!("#{team}_ROBOT_SERVER_PORT") |> String.to_integer()
            }
          }

        "BLUETOOTH" ->
          {
            RobotConnection.BluetoothConnection,
            %{
              bluetooth_serial_port: System.fetch_env!("#{team}_ROBOT_BLUETOOTH_SERIAL_PORT")
            }
          }
      end

    %{
      speed_coefficient: speed_coefficient,
      connection_module: connection_module,
      connection_config: connection_config
    }
  end
end
