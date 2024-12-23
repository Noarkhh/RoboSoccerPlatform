defmodule RoboSoccerPlatformWeb.GameDashboard.Components do
  use RoboSoccerPlatformWeb, :component

  alias RoboSoccerPlatformWeb.GameDashboard.Utils

  attr :teams, :map, required: true
  attr :room_code, :string, required: true
  attr :wifi_ssid, :string, required: true
  attr :wifi_psk, :string, required: true
  attr :ip, :string, required: true
  attr :port, :string, required: true
  attr :wifi_qr_svg, :string, required: true
  attr :player_url_qr_svg, :string, required: true

  def before_game_view(assigns) do
    ~H"""
    <div class="flex justify-evenly items-center col-span-2 ">
      <div class="flex flex-col items-center gap-4">
        <div class="text-7xl">WiFi</div>
        {@wifi_qr_svg}
        <div class="text-xl">nazwa: {@wifi_ssid} | hasło: {@wifi_psk}</div>
      </div>
      <div class="flex flex-col text-center gap-8">
        <div class="text-5xl">Kod Pokoju</div>
        <div class="text-9xl">{@room_code}</div>
      </div>
      <div class="flex flex-col items-center gap-4">
        <div class="text-7xl">Strona</div>
        {@player_url_qr_svg}
        <div class="text-xl">http://{@ip}:{@port}</div>
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
  attr :wifi_ssid, :string, required: true
  attr :wifi_psk, :string, required: true
  attr :ip, :string, required: true
  attr :port, :string, required: true
  attr :wifi_qr_svg, :string, required: true
  attr :player_url_qr_svg, :string, required: true

  def in_game_view(assigns) do
    green_direction = Utils.point_to_direction(assigns.teams["green"].current_instruction)
    green_cooperation_metric = assigns.teams["green"].current_cooperation_metric

    red_direction = Utils.point_to_direction(assigns.teams["red"].current_instruction)
    red_cooperation_metric = assigns.teams["red"].current_cooperation_metric

    assigns =
      assigns
      |> assign(green_direction: green_direction)
      |> assign(green_cooperation_metric: green_cooperation_metric)
      |> assign(red_direction: red_direction)
      |> assign(red_cooperation_metric: red_cooperation_metric)

    ~H"""
    <div class="flex flex-col flex-1 gap-2">
      <div class="grid grid-flow-col auto-cols-fr w-full gap-2">
        <div class="flex flex-col flex-1 gap-4">
          <.cooperation_metrics
            red_cooperation_metric={@red_cooperation_metric}
            green_cooperation_metric={@green_cooperation_metric}
          />

          <div class="flex gap-8">
            <.time_left seconds={@seconds_left} />
            <.directions_and_score
              red_direction={@red_direction}
              green_direction={@green_direction}
              red_goals={@teams["red"].goals}
              green_goals={@teams["green"].goals}
              class="flex flex-1"
            />
          </div>
          <.teams
            red_players={@teams["red"].player_inputs}
            green_players={@teams["green"].player_inputs}
            game_stopped?={@game_state == :stopped}
          />
        </div>

        <div class="flex flex-col">
          <div class="flex flex-col items-center text-7xl gap-8">
            <div class="flex flex-col text-center text-palette-500 gap-2">
              <div class="text-5xl">Kod Pokoju</div>
              <div class="text-9xl">{@room_code}</div>
            </div>
            <div class="flex text-center gap-16">
              <div class="flex flex-col items-center gap-4">
                <div class="text-5xl">WiFi</div>
                {@wifi_qr_svg}
                <div class="text-xl">nazwa: {@wifi_ssid} | hasło: {@wifi_psk}</div>
              </div>
              <div class="flex flex-col items-center gap-4">
                <div class="text-5xl">Strona</div>
                {@player_url_qr_svg}
                <div class="text-xl">http://{@ip}:{@port}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-center gap-16">
      <.button
        phx-click={if @game_state == :started, do: "stop_game", else: "start_game"}
        class="bg-palette-400 !text-palette-100 !text-4xl hover:bg-palette-500"
      >
        {if @game_state == :started, do: "STOP", else: "START"}
      </.button>

      <.button
        phx-click="goal"
        phx-value-team="red"
        class="bg-light-red !text-black !text-4xl hover:bg-dark-red"
      >
        GOL CZERWONI
      </.button>

      <.button
        phx-click="goal"
        phx-value-team="green"
        class="bg-light-green !text-black !text-4xl hover:bg-dark-green"
      >
        GOL ZIELONI
      </.button>

      <.button
        phx-click="reset_score"
        class="bg-palette-400 !text-palette-100 !text-4xl hover:bg-palette-500"
      >
        ZRESETUJ WYNIK
      </.button>

      <.button
        phx-click="new_room"
        class="bg-palette-400 !text-palette-100 !text-4xl hover:bg-palette-500"
      >
        NOWY POKÓJ
      </.button>

      <.button
        phx-click="show_stats"
        class="bg-palette-400 !text-palette-100 !text-4xl hover:bg-palette-500"
      >
        STATYSTYKI
      </.button>

      <.button
        phx-click="reset_stats"
        class="bg-palette-100 !text-palette-400 !text-4xl hover:bg-palette-300"
      >
        ZRESETUJ STATYSTYKI
      </.button>
    </div>
    """
  end

  attr :total_cooperation_metrics, :map, required: true
  attr :teams, :map, required: true
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}

  def game_stats_modal(assigns) do
    assigns =
      assigns
      |> assign(
        green_current_cooperation_metric: assigns.teams["green"].current_cooperation_metric
      )
      |> assign(red_current_cooperation_metric: assigns.teams["red"].current_cooperation_metric)
      |> assign(
        green_total_cooperation_metric:
          average_cooperation_metrics(
            assigns.teams["green"].total_cooperation_metrics,
            assigns.number_of_aggregations
          )
      )
      |> assign(
        red_total_cooperation_metric:
          average_cooperation_metrics(
            assigns.teams["red"].total_cooperation_metrics,
            assigns.number_of_aggregations
          )
      )

    ~H"""
    <.modal
      id={@id}
      show
      on_cancel={@on_cancel}
      class="bg-palette-100"
      container_class="flex flex-col gap-4"
    >
      <div class="text-center text-2xl">
        Aktualny poziom zgodności drużyn
      </div>
      <.cooperation_metrics
        red_cooperation_metric={@red_current_cooperation_metric}
        green_cooperation_metric={@green_current_cooperation_metric}
      />

      <div class="text-center text-2xl">
        Średni poziom zgodności drużyn
      </div>
      <.cooperation_metrics
        red_cooperation_metric={@red_total_cooperation_metric}
        green_cooperation_metric={@green_total_cooperation_metric}
      />
    </.modal>
    """
  end

  @spec average_cooperation_metrics(float(), integer()) :: float()
  defp average_cooperation_metrics(_total_coop, 0), do: 0.00

  defp average_cooperation_metrics(total_coop, number_of_measures) do
    total_coop / number_of_measures
  end

  attr :red_players, :list, required: true
  attr :green_players, :list, required: true
  attr :game_stopped?, :boolean, default: false

  defp teams(assigns) do
    ~H"""
    <div class="flex flex-1">
      <.team
        players={@red_players}
        title="Drużyna czerwona"
        class="rounded-tl-3xl bg-gradient-to-r from-light-red to-palette-300"
        player_class="bg-light-red"
        container_class="rounded-bl-3xl bg-palette-400"
        game_stopped?={@game_stopped?}
      />
      <.team
        players={@green_players}
        title="Drużyna zielona"
        class="rounded-tr-3xl bg-gradient-to-l from-light-green to-palette-300"
        player_class="bg-light-green"
        container_class="rounded-br-3xl bg-palette-400"
        game_stopped?={@game_stopped?}
      />
    </div>
    """
  end

  attr :players, :list, required: true
  attr :title, :string, required: true
  attr :game_stopped?, :boolean, required: true
  attr :class, :string, default: ""
  attr :container_class, :string, default: ""
  attr :player_class, :string, default: ""

  defp team(assigns) do
    players_number_display =
      case length(assigns.players) do
        1 -> "1 gracz"
        number_of_players -> "#{number_of_players} graczy"
      end

    assigns = assign(assigns, players_number_display: players_number_display)

    ~H"""
    <div class="flex flex-col flex-1 min-w-0">
      <div class={"text-center font-bold #{@class} p-2"}>
        {@title} ({@players_number_display})
      </div>

      <div class={"flex flex-col px-8 py-8 #{@container_class}"}>
        <div class="flex flex-col grow-0 shrink-0 basis-96 gap-2 overflow-auto">
          <.player
            :for={player <- @players}
            class={@player_class}
            player={player}
            game_stopped?={@game_stopped?}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :game_stopped?, :boolean, required: true
  attr :class, :string, default: ""

  defp player(assigns) do
    direction_icon =
      if assigns.game_stopped? do
        "pan_tool"
      else
        Utils.point_to_direction(%{x: assigns.player.x, y: assigns.player.y})
      end

    assigns = assign(assigns, direction_icon: direction_icon)

    ~H"""
    <div class={"flex rounded-lg gap-4 px-2 #{@class}"}>
      <div
        phx-click="kick"
        phx-value-player_id={@player.player.id}
        type="button"
        class="cursor-pointer "
      >
        <img src="/images/remove.svg" alt="remove" class="mx-auto w-6 h-6 p-0.5" />
      </div>

      <div class="flex-1 truncate">
        <div class="truncate font-bold">
          {@player.player.username}
        </div>
      </div>

      <span class="material-icons-outlined">
        {@direction_icon}
      </span>
    </div>
    """
  end

  attr :seconds, :integer, required: true
  attr :class, :string, default: ""

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
    <div class="w-40 min-w-40 max-w-40 bg-palette-400 text-5xl text-palette-100 border border-solid border-black rounded-3xl m-auto py-4 text-center">
      {@minutes}:{@seconds}
    </div>
    """
  end

  attr :red_direction, :string, required: true
  attr :green_direction, :string, required: true
  attr :red_goals, :integer, default: 0
  attr :green_goals, :integer, default: 0
  attr :class, :string, default: ""

  defp directions_and_score(assigns) do
    ~H"""
    <div class={"bg-palette-400 px-4 py-2 border border-solid border-black rounded-3xl min-w-0 #{@class}"}>
      <div class="flex-1 bg-gradient-to-r from-light-red to-palette-400 p-4 rounded-l-3xl"></div>

      <div class="flex-1 p-4 flex items-center justify-center whitespace-nowrap">
        <span class="material-icons-outlined text-light-red !text-5xl">
          {@red_direction}
        </span>
      </div>

      <div class="flex-1 p-4 flex items-center justify-center text-5xl whitespace-nowrap text-palette-100">
        {@red_goals} : {@green_goals}
      </div>

      <div class="flex-1 p-4 flex items-center justify-center whitespace-nowrap">
        <span class="material-icons-outlined text-light-green !text-5xl">
          {@green_direction}
        </span>
      </div>

      <div class="flex-1 bg-gradient-to-l from-light-green to-palette-400 p-4 rounded-r-3xl"></div>
    </div>
    """
  end

  attr :red_cooperation_metric, :string, required: true
  attr :green_cooperation_metric, :string, required: true

  defp cooperation_metrics(assigns) do
    assigns =
      assigns
      |> assign(red_cooperation_metric: float_to_string_percent(assigns.red_cooperation_metric))
      |> assign(
        green_cooperation_metric: float_to_string_percent(assigns.green_cooperation_metric)
      )

    ~H"""
    <div class="bg-palette-400 px-4 py-2 border border-solid border-black rounded-3xl">
      <div class="flex min-w-0">
        <div class="flex-1 bg-gradient-to-r from-light-red to-palette-400 p-4 rounded-l-3xl"></div>

        <span class="material-icons-outlined text-palette-100 !text-5xl my-auto">
          handshake
        </span>

        <div class="flex-1 p-4 flex items-center justify-center text-5xl whitespace-nowrap text-palette-100">
          {@red_cooperation_metric} %
        </div>

        <div class="flex-1 p-4 flex items-center justify-center text-5xl whitespace-nowrap text-palette-100">
          {@green_cooperation_metric} %
        </div>

        <span class="material-icons-outlined text-palette-100 !text-5xl my-auto">
          handshake
        </span>

        <div class="flex-1 bg-gradient-to-l from-light-green to-palette-400 p-4 rounded-r-3xl"></div>
      </div>
    </div>
    """
  end

  @spec float_to_string_percent(float()) :: String.t()
  defp float_to_string_percent(float) do
    percent = Float.round(100 * float, 2)

    decimals = if percent == 100, do: 1, else: 2

    :erlang.float_to_binary(percent, decimals: decimals)
  end

  @spec pad_to_two_digits(integer()) :: String.t()
  defp pad_to_two_digits(number) do
    number
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end
end
