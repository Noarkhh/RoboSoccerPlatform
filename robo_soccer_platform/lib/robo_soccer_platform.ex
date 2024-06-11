defmodule RoboSoccerPlatform do
  @moduledoc """
  RoboSoccerPlatform keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defmodule Player do
    @type t :: %__MODULE__{
            id: String.t(),
            username: String.t(),
            team: atom()
          }

    @enforce_keys [:id, :username, :team]
    defstruct @enforce_keys ++ []
  end
end
