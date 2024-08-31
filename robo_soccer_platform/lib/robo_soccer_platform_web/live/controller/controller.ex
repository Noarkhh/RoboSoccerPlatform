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
    assigns =
      assigns
      |> assign_red_team()
      |> assign_green_team()

    ~H"""
    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view red_team={@red_team} green_team={@green_team} :if={not @game_started}/>
    </div>
    """
  end

  def handle_event("start_game", _params, socket) do
    RoboSoccerPlatformWeb.Endpoint.broadcast_from(self(), @game_start, "start_game", nil)
    {:noreply, assign(socket, game_started: true)}
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
      players = Map.put(socket.assigns.players, id, %{team: team, username: username})

      socket
      |> assign(players: players)
      |> then(&{:noreply, &1})
    end
  end

  def handle_info(
        %{topic: @controller, event: "joystick_position", payload: %{x: x, y: y, id: id}},
        socket
      ) do
    if Map.has_key?(socket.assigns.players, id) do
      player = Map.get(socket.assigns.players, id, %{})
      updated_player = Map.merge(player, %{x: x, y: y})

      players = Map.put(socket.assigns.players, id, updated_player)

      {:noreply, assign(socket, players: players)}
    else
      {:noreply, socket}
    end
  end

  attr :red_team, :list, default: []
  attr :green_team, :list, default: []

  defp before_game_view(assigns) do
    ~H"""
    <div class="flex flex-1" >
      <.team players={@red_team} color={:red} class="rounded-tl-3xl" container_class="rounded-bl-3xl bg-light-red"/>
      <.team players={@green_team} color={:green} class="rounded-tr-3xl" container_class="rounded-br-3xl bg-light-green"/>
    </div>

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

  attr :players, :list, required: true
  attr :color, :atom, required: true
  attr :class, :string, default: ""

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
end
