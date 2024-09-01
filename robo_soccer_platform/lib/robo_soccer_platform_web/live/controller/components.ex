defmodule RoboSoccerPlatformWeb.Controller.Components do
  use RoboSoccerPlatformWeb, :component

  attr :red_team, :list, default: []
  attr :green_team, :list, default: []

  def before_game_view(assigns) do
    ~H"""
    <.teams red_team={@red_team} green_team={@green_team} />

    <div class="flex justify-center">
      <.button
        phx-click="start_game"
        class="bg-white !text-black !text-4xl"
      >
        START
      </.button>
    </div>
    """
  end

  attr :red_team, :list, required: true
  attr :green_team, :list, required: true
  attr :seconds_left, :integer, required: true
  attr :red_goals, :integer, required: true
  attr :green_goals, :integer, required: true
  attr :time_is_over, :boolean, required: true

  def in_game_view(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.teams red_team={@red_team} green_team={@green_team} />

      <div class="flex flex-col flex-1">
      </div>

      <div class="flex flex-col flex-1 items-center gap-8">
        <.time_left seconds={@seconds_left} time_is_over={@time_is_over} />
        <.score red_goals={@red_goals} green_goals={@green_goals} />
      </div>
    </div>

    <div class="flex justify-center gap-32">
      <.button
        phx-click="stop_game"
        class="bg-white !text-black !text-4xl"
      >
        STOP
      </.button>

      <.button
        phx-click="goal_red"
        class="bg-red-500 !text-black !text-4xl"
      >
        GOL CZERWONI
      </.button>

      <.button
        phx-click="goal_green"
        class="bg-green-500 !text-black !text-4xl"
      >
        GOL ZIELONI
      </.button>

      <.button
        phx-click="reset_score"
        class="bg-white !text-black !text-4xl"
      >
        ZRESETUJ WYNIK
      </.button>
    </div>
    """
  end

  attr :red_team, :list, required: true
  attr :green_team, :list, required: true

  defp teams(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.team players={@red_team} color={:red} class="rounded-tl-3xl" container_class="rounded-bl-3xl bg-light-red"/>
      <.team players={@green_team} color={:green} class="rounded-tr-3xl" container_class="rounded-br-3xl bg-light-green"/>
    </div>
    """
  end

  attr :players, :list, required: true
  attr :color, :atom, required: true
  attr :class, :string, default: ""
  attr :container_class, :string, default: ""

  defp team(assigns) do
    ~H"""
    <div class="flex flex-col flex-1">
      <div class={"text-center #{@class} bg-light-orange p-2"}>
        druzyna <%= if @color == :red, do: "czerwona", else: "zielona" %>
      </div>
      <div class={"flex flex-col flex-1 px-16 py-8 gap-5 #{@container_class}"}>
        <div class="text-center bg-sky-blue" :for={player <- @players}>
          <%= player.username %>
        </div>
      </div>
    </div>
    """
  end

  attr :seconds, :integer, required: true
  attr :time_is_over, :boolean, required: true

  defp time_left(assigns) do
    minutes =
      assigns.seconds
      |> div(60)
      |> pad_to_two_digits()

    seconds =
      assigns.seconds
      |> rem(60)
      |> pad_to_two_digits()

    assigns =
      assigns
      |> assign(minutes: minutes)
      |> assign(seconds: seconds)

    ~H"""
    <div class={"#{if @time_is_over, do: "bg-red-500", else: "bg-white"} px-16 py-2 text-3xl border border-solid border-black"}>
      <%= @minutes %>:<%= @seconds %>
    </div>
    """
  end

  attr :red_goals, :integer, default: 0
  attr :green_goals, :integer, default: 0

  defp score(assigns) do
    ~H"""
    <div class="bg-white px-4 py-2 text-3xl border border-solid border-black">
      <div class="flex min-w-0">
        <div class="flex-1 bg-red-500 p-4">
        </div>
        <div class="flex-1 p-4 flex items-center justify-center text-3xl whitespace-nowrap">
          <%= @red_goals %> : <%= @green_goals %>
        </div>
        <div class="flex-1 bg-green-500 p-4">
        </div>
      </div>
    </div>
    """
  end

  defp pad_to_two_digits(number) do
    number
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end
end