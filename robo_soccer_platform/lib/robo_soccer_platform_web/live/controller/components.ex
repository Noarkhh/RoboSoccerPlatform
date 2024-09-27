defmodule RoboSoccerPlatformWeb.Controller.Components do
  use RoboSoccerPlatformWeb, :component

  alias RoboSoccerPlatformWeb.Controller.Utils

  attr :teams, :map, required: true
  attr :room_code, :string, required: true

  def before_game_view(assigns) do
    ~H"""
    <div class="text-center text-3xl">
      ROOM CODE: <%= @room_code %>
    </div>

    <.teams red_players={@teams.red.players} green_players={@teams.green.players} />

    <div class="flex justify-center">
      <.button phx-click="start_game" class="bg-white !text-black !text-4xl">
        START
      </.button>
    </div>
    """
  end

  attr :teams, :map, required: true
  attr :game_state, :atom, required: true
  attr :seconds_left, :integer, required: true
  attr :room_code, :string, required: true

  def in_game_view(assigns) do
    green_direction =
      Utils.point_to_direction(%{
        x: assigns.teams.green.instruction.x,
        y: assigns.teams.green.instruction.y
      })

    red_direction =
      Utils.point_to_direction(%{
        x: assigns.teams.red.instruction.x,
        y: assigns.teams.red.instruction.y
      })

    assigns =
      assigns
      |> assign(green_direction: green_direction)
      |> assign(red_direction: red_direction)

    ~H"""
    <div class="flex flex-1">
      <div class="grid grid-flow-col auto-cols-fr w-full">
        <div class="flex flex-col flex-1 col-span-2">
          <.teams red_players={@teams.red.players} green_players={@teams.green.players} />
        </div>

        <div class="col-span-2 text-center text-3xl">
          ROOM CODE: <%= @room_code %>
        </div>

        <div class="flex flex-col flex-1 items-center gap-8">
          <.time_left seconds={@seconds_left} />
          <.score red_goals={@teams.red.goals} green_goals={@teams.green.goals} />
          <.directions red_direction={@red_direction} green_direction={@green_direction} />
        </div>
      </div>
    </div>

    <div class="flex justify-center gap-32">
      <.button
        phx-click={if @game_state == :started, do: "stop_game", else: "start_game"}
        class="bg-white !text-black !text-4xl"
      >
        <%= if @game_state == :started, do: "STOP", else: "START" %>
      </.button>

      <.button phx-click="goal" phx-value-team="red" class="bg-red-500 !text-black !text-4xl">
        GOL CZERWONI
      </.button>

      <.button phx-click="goal" phx-value-team="green" class="bg-green-500 !text-black !text-4xl">
        GOL ZIELONI
      </.button>

      <.button phx-click="reset_score" class="bg-white !text-black !text-4xl">
        ZRESETUJ WYNIK
      </.button>
    </div>
    """
  end

  attr :red_players, :list, required: true
  attr :green_players, :list, required: true

  defp teams(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.team
        players={@red_players}
        color={:red}
        class="rounded-tl-3xl"
        container_class="rounded-bl-3xl bg-light-red"
      />
      <.team
        players={@green_players}
        color={:green}
        class="rounded-tr-3xl"
        container_class="rounded-br-3xl bg-light-green"
      />
    </div>
    """
  end

  attr :players, :list, required: true
  attr :color, :atom, required: true
  attr :class, :string, default: ""
  attr :container_class, :string, default: ""

  defp team(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 min-w-0">
      <div class={"text-center #{@class} bg-light-orange p-2"}>
        druzyna <%= if @color == :red, do: "czerwona", else: "zielona" %>
      </div>
      <div class={"flex flex-1 flex-col px-8 py-8 gap-2 #{@container_class}"}>
        <div :for={player <- @players} class="flex bg-sky-blue gap-4">
          <.player player={player} />
        </div>
      </div>
    </div>
    """
  end

  attr :player, :map, required: true

  defp player(assigns) do
    direction = Utils.point_to_direction(%{x: assigns.player.x, y: assigns.player.y})

    assigns = assign(assigns, direction: direction)

    ~H"""
    <div class="flex-1 truncate">
      <div class="truncate">
        <%= @player.username %>
      </div>
    </div>

    <span class="material-icons-outlined">
      <%= @direction %>
    </span>
    """
  end

  attr :seconds, :integer, required: true

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
    <div class="bg-white px-16 py-2 text-3xl border border-solid border-black">
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
        <div class="flex-1 bg-red-500 p-4"></div>

        <div class="flex-1 p-4 flex items-center justify-center text-3xl whitespace-nowrap">
          <%= @red_goals %> : <%= @green_goals %>
        </div>

        <div class="flex-1 bg-green-500 p-4"></div>
      </div>
    </div>
    """
  end

  attr :red_direction, :string, required: true
  attr :green_direction, :string, required: true

  defp directions(assigns) do
    ~H"""
    <div class="bg-white px-4 py-2 text-3xl border border-solid border-black">
      <div class="flex min-w-0">
        <div class="flex-1 bg-red-500 p-4"></div>

        <div class="flex-1 p-4 flex items-center justify-center text-3xl whitespace-nowrap">
          <span class="material-icons-outlined">
            <%= @red_direction %>
          </span>
        </div>

        <div class="flex-1 p-4 flex items-center justify-center text-3xl whitespace-nowrap">
          <span class="material-icons-outlined">
            <%= @green_direction %>
          </span>
        </div>

        <div class="flex-1 bg-green-500 p-4"></div>
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
