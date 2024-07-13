defmodule RoboSoccerPlatformWeb.Player.Assigns do
  import Phoenix.Component, only: [assign: 2]

  def assign_form_errors(form) do
    errors =
      if Map.get(form, "username", "") == "" do
        ["Przed dołączeniem do drużyny podaj swoją nazwę"]
      else
        []
      end

    Map.put(form, "errors", errors)
  end
end
