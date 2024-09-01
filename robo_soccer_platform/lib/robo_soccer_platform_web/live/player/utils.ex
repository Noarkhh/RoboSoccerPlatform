defmodule RoboSoccerPlatformWeb.Player.Utils do
  def put_form_errors(form) do
    errors =
      if Map.get(form, "username", "") == "" do
        ["Przed dołączeniem do drużyny podaj swoją nazwę"]
      else
        []
      end

    Map.put(form, "errors", errors)
  end
end
