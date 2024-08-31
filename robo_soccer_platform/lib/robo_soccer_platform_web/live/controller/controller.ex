defmodule RoboSoccerPlatformWeb.Controller do
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.Controller.Assigns

  @game_start "game_start"
  @controller "controller"

  def mount(_params, _session, socket) do
    RoboSoccerPlatformWeb.Endpoint.subscribe(@controller)

    socket
    |> assign(game_started: false)
    |> assign(players: %{})
    |> assign(green_team: [])
    |> assign(red_team: [])
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view red_team={@red_team} green_team={@green_team} :if={@game_started}/>
      <.in_game_view red_team={@red_team} green_team={@green_team} :if={not @game_started}/>
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "start_game", nil)
    {:noreply, assign(socket, game_started: true)}
  end

  def handle_event("stop_game", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("goal_red", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("goal_green", _params, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{
          topic: @controller,
          event: "register_player",
          payload: %{id: id, team: team, username: username}
        },
        socket
      ) do
    # allow registering only before game start
    if socket.assigns.game_started do
      {:noreply, socket}
    else
      players = Map.put(socket.assigns.players, id, %{team: team, username: username, x: 0, y: 0})

      socket
      |> assign(players: players)
      |> assign_red_team()
      |> assign_green_team()
      |> then(&{:noreply, &1})
    end
  end

  def handle_info(
        %{
          topic: @controller,
          event: "joystick_position",
          payload: %{x: x, y: y, id: id}
        },
        socket
      ) do
    if Map.has_key?(socket.assigns.players, id) do
      updated_player =
        socket.assigns.players
        |> Map.get(id)
        |> Map.merge(%{x: x, y: y})

      players = Map.put(socket.assigns.players, id, updated_player)

      socket
      |> assign(players: players)
      |> assign_red_team()
      |> assign_green_team()
      |> then(&{:noreply, &1})
    else
      {:noreply, socket}
    end
  end

  attr :red_team, :list, default: []
  attr :green_team, :list, default: []

  defp before_game_view(assigns) do
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

  attr :red_team, :list, default: []
  attr :green_team, :list, default: []

  defp in_game_view(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.teams red_team={@red_team} green_team={@green_team} />

      <div class="flex flex-col flex-1">
      </div>

      <div class="flex flex-col flex-1 items-center gap-8">
        <.time_left minutes={5} seconds={0} />
        <.score red_goals={0} green_goals={0} />
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

  attr :minutes, :integer, required: true
  attr :seconds, :integer, required: true

  defp time_left(assigns) do
    assigns =
      assigns
      |> assign(minutes: pad_to_two_digits(assigns.minutes))
      |> assign(seconds: pad_to_two_digits(assigns.seconds))

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
