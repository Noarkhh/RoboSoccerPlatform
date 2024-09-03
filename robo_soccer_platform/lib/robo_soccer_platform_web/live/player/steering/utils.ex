defmodule RoboSoccerPlatformWeb.Player.Steering.Utils do
  alias RoboSoccerPlatformWeb.Endpoint

  def restore_from_token(nil), do: {:ok, nil}

  def restore_from_token(token) do
    salt = get_signing_salt()
    # Max age is 1 day = 86,400 seconds
    case Phoenix.Token.decrypt(Endpoint, salt, token, max_age: 86_400) do
      {:ok, data} ->
        {:ok, data}

      {:error, reason} ->
        {:error, "#{inspect(reason)}"}
    end
  end

  def serialize_to_token(data) do
    salt = get_signing_salt()
    Phoenix.Token.encrypt(Endpoint, salt, data)
  end

  defp get_signing_salt() do
    Application.get_env(:robo_soccer_platform, Endpoint)[:live_view][:signing_salt]
  end
end
