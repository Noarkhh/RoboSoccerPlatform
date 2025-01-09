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
    robot_connection_type = System.fetch_env!("#{team}_ROBOT_CONNECTION_TYPE")

    get_robot_config(team, robot_connection_type)
  end

  @spec get_robot_config(RoboSoccerPlatform.team(), String.t()) ::
          RoboSoccerPlatform.GameController.robot_config()
  def get_robot_config(team, robot_connection_type) do
    case robot_connection_type do
      "TCP_SERVER_SOCKET" ->
        connection_config = %{
          local_port: System.fetch_env!("#{team}_ROBOT_SERVER_PORT") |> String.to_integer()
        }

        {RobotConnection.TCPServerSocketConnection, connection_config}

      "BLUETOOTH" ->
        connection_config = %{
          bluetooth_serial_port: System.fetch_env!("#{team}_ROBOT_BLUETOOTH_SERIAL_PORT")
        }

        {RobotConnection.BluetoothConnection, connection_config}
    end
  end
end
