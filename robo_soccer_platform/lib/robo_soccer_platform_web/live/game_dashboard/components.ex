defmodule RoboSoccerPlatformWeb.GameDashboard.Components do
  use RoboSoccerPlatformWeb, :component

  alias RoboSoccerPlatformWeb.GameDashboard.Utils

  attr :teams, :map, required: true
  attr :room_code, :string, required: true

  def before_game_view(assigns) do
    assigns =
      assigns
      |> assign(wifi_ssid: System.fetch_env!("WIFI_SSID"))
      |> assign(wifi_psk: System.fetch_env!("WIFI_PSK"))
      |> assign(ip: System.fetch_env!("SERVER_IP"))
      |> assign(port: System.get_env("PHX_PORT", "4000"))

    ~H"""
    <div class="flex justify-evenly items-center col-span-2 ">
      <div class="flex flex-col items-center gap-4">
        <div class="text-7xl">WiFi</div>
        <img src="images/qr_wifi.png" class="w-[260px]" />
        <div class="text-xl">nazwa: <%= @wifi_ssid %> | hasło: <%= @wifi_psk %></div>
      </div>
      <div class="flex flex-col text-center gap-8">
        <div class="text-5xl">Kod Pokoju</div>
        <div class="text-9xl"><%= @room_code %></div>
      </div>
      <div class="flex flex-col items-center gap-4">
        <div class="text-7xl">Strona</div>
        <img src="images/qr_player_link.png" class="w-[260px]" />
        <div class="text-xl">http://<%= @ip %>:<%= @port %></div>
      </div>
    </div>

    <.teams red_players={@teams["red"].player_inputs} green_players={@teams["green"].player_inputs} />

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
    green_direction = Utils.point_to_direction(assigns.teams["green"].robot_instruction)
    red_direction = Utils.point_to_direction(assigns.teams["red"].robot_instruction)

    assigns =
      assigns
      |> assign(green_direction: green_direction)
      |> assign(red_direction: red_direction)
      |> assign(wifi_ssid: System.fetch_env!("WIFI_SSID"))
      |> assign(wifi_psk: System.fetch_env!("WIFI_PSK"))
      |> assign(ip: System.fetch_env!("SERVER_IP"))
      |> assign(port: System.get_env("PHX_PORT", "4000"))

    ~H"""
    <div class="flex flex-1">
      <div class="grid grid-flow-col auto-cols-fr w-full gap-2">
        <div class="flex flex-col flex-1 col-span-2 gap-4">
          <.score red_goals={@teams["red"].goals} green_goals={@teams["green"].goals} />
          <.directions red_direction={@red_direction} green_direction={@green_direction} />
          <.teams
            red_players={@teams["red"].player_inputs}
            green_players={@teams["green"].player_inputs}
            game_stopped?={@game_state == :stopped}
          />
        </div>

        <div class="flex flex-col items-center gap-16 col-span-2">
          <div class="flex flex-col items-center text-7xl gap-8">
            <div class="flex flex-col text-center gap-8">
              <div class="text-5xl">Kod Pokoju</div>
              <div class="text-9xl"><%= @room_code %></div>
            </div>
            <div class="flex text-center gap-16">
              <div class="flex flex-col items-center gap-4">
                <div class="text-7xl">WiFi</div>
                <img src="images/qr_wifi.png" class="w-[260px]" />
                <div class="text-xl">nazwa: <%= @wifi_ssid %> | hasło: <%= @wifi_psk %></div>
              </div>
              <div class="flex flex-col items-center gap-4">
                <div class="text-7xl">Strona</div>
                <img src="images/qr_player_link.png" class="w-[260px]" />
                <div class="text-xl">http://<%= @ip %>:<%= @port %></div>
              </div>
            </div>
          </div>
        </div>
        <div class="flex flex-col flex-1 items-center gap-8">
          <.time_left seconds={@seconds_left} />
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

      <.button phx-click="new_room" class="bg-white !text-black !text-4xl">
        NOWY POKÓJ
      </.button>
    </div>
    """
  end

  attr :red_players, :list, required: true
  attr :green_players, :list, required: true
  attr :game_stopped?, :boolean, default: false

  defp teams(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.team
        players={@red_players}
        color={:red}
        class="rounded-tl-3xl"
        container_class="rounded-bl-3xl bg-light-red"
        game_stopped?={@game_stopped?}
      />
      <.team
        players={@green_players}
        color={:green}
        class="rounded-tr-3xl"
        container_class="rounded-br-3xl bg-light-green"
        game_stopped?={@game_stopped?}
      />
    </div>
    """
  end

  attr :players, :list, required: true
  attr :color, :atom, required: true
  attr :game_stopped?, :boolean, required: true
  attr :class, :string, default: ""
  attr :container_class, :string, default: ""

  defp team(assigns) do
    players_number_display = case length(assigns.players) do
      1 -> "1 gracz"
      number_of_players -> "#{number_of_players} graczy"
    end

    assigns = assign(assigns, players_number_display: players_number_display)

    ~H"""
    <div class="flex flex-col flex-1 min-w-0">
      <div class={"text-center #{@class} bg-light-orange p-2"}>
        Drużyna <%= if @color == :red, do: "czerwona", else: "zielona" %> (<%= @players_number_display %>)
      </div>
      <div class={"flex flex-1 flex-col px-8 py-8 gap-2 #{@container_class}"}>
        <div :for={player <- @players} class="flex bg-sky-blue gap-4">
          <.player player={player} game_stopped?={@game_stopped?}/>
        </div>
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :game_stopped?, :boolean, required: true

  defp player(assigns) do
    direction_icon = if assigns.game_stopped? do
      "pan_tool"
    else
      Utils.point_to_direction(%{x: assigns.player.x, y: assigns.player.y})
    end

    assigns = assign(assigns, direction_icon: direction_icon)

    ~H"""
    <div class="flex-1 truncate">
      <div class="truncate">
        <%= @player.player.username %>
      </div>
    </div>

    <span class="material-icons-outlined">
      <%= @direction_icon %>
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
        <div class="flex-1 bg-light-red p-4"></div>

        <div class="flex-1 p-4 flex items-center justify-center text-3xl whitespace-nowrap">
          <%= @red_goals %> : <%= @green_goals %>
        </div>

        <div class="flex-1 bg-light-green p-4"></div>
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
        <div class="flex-1 bg-light-red p-4"></div>

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

        <div class="flex-1 bg-light-green p-4"></div>
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
