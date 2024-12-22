defmodule RoboSoccerPlatform.RobotConnection do
  @type t :: module()

  @callback start(RoboSoccerPlatform.team(), robot_connection_config :: term()) ::
              {:ok, pid()} | {:error, term()}
  @callback send_instruction(pid(), %{x: float(), y: float()}) :: :ok
end
