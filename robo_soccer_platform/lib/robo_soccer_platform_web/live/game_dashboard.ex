defmodule RoboSoccerPlatformWeb.GameDashboard do
  require Logger
  alias Phoenix.Endpoint
  use RoboSoccerPlatformWeb, :live_view

  import RoboSoccerPlatformWeb.GameDashboard.Components,
    only: [before_game_view: 1, in_game_view: 1, game_stats_modal: 1]

  alias RoboSoccerPlatformWeb.Endpoint

  @game_state "game_state"
  @type steering_state :: %{
          player_inputs: %{
            (player_id :: String.t()) => RoboSoccerPlatform.GameController.player_input()
          },
          robot_instructions: %{RoboSoccerPlatform.team() => %{x: float(), y: float(), current_cooperation_metric: float()}}
        }
  @type teams :: %{
          RoboSoccerPlatform.team() => %{
            player_inputs: [RoboSoccerPlatform.GameController.player_input()],
            robot_instruction: %{x: float(), y: float()},
            goals: non_neg_integer()
          }
        }

  @spec update_steering_state(pid(), steering_state()) :: :ok
  def update_steering_state(game_dashboard_pid, steering_state) do
    GenServer.cast(game_dashboard_pid, {:update_steering_state, steering_state})
  end

  @spec update_room(pid(), String.t()) :: :ok
  def update_room(game_dashoard_pid, room_code) do
    GenServer.cast(game_dashoard_pid, {:update_room, room_code})
  end

  @impl true
  def mount(_params, _session, socket) do
    {room_code, steering_state, game_state} =
      RoboSoccerPlatform.GameController.init_game_dashboard(self())

    config = Application.fetch_env!(:robo_soccer_platform, RoboSoccerPlatformWeb.GameDashboard)

    wifi_qr_svg = render_wifi_qr_code(config[:wifi_ssid], config[:wifi_psk])
    player_url_qr_svg = render_player_url_qr_code(config[:ip], config[:port], room_code)

    socket
    |> assign(config)
    |> assign(room_code: room_code)
    |> assign(wifi_qr_svg: wifi_qr_svg)
    |> assign(player_url_qr_svg: player_url_qr_svg)
    |> assign(teams: init_teams(steering_state))
    |> assign(game_state: game_state)
    |> assign(seconds_left: 10 * 60)
    |> assign(timer: nil)
    |> assign(stats_visible: false)
    |> assign(total_cooperation_metrics: %{"green" => 1.0, "red" => 1.0, number_of_measurements: 0})
    |> then(&{:ok, &1})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.game_stats_modal
      :if={@stats_visible}
      id="my-modal"
      show
      on_cancel={JS.push("close_stats")}
      teams={@teams}
      total_cooperation_metrics={@total_cooperation_metrics}
    />

    <div class="flex flex-col h-[80vh] gap-8">
      <.before_game_view
        :if={@game_state == :lobby}
        teams={@teams}
        room_code={@room_code}
        wifi_ssid={@wifi_ssid}
        wifi_psk={@wifi_psk}
        ip={@ip}
        port={@port}
        wifi_qr_svg={@wifi_qr_svg}
        player_url_qr_svg={@player_url_qr_svg}
      />

      <.in_game_view
        :if={@game_state != :lobby}
        teams={@teams}
        game_state={@game_state}
        seconds_left={@seconds_left}
        room_code={@room_code}
        wifi_ssid={@wifi_ssid}
        wifi_psk={@wifi_psk}
        ip={@ip}
        port={@port}
        wifi_qr_svg={@wifi_qr_svg}
        player_url_qr_svg={@player_url_qr_svg}
      />
    </div>
    """
  end

  @impl true
  def handle_cast({:update_steering_state, steering_state}, socket) do
    socket
    |> assign(teams: update_teams(socket.assigns.teams, steering_state))
    |> assign(total_cooperation_metrics: steering_state.total_cooperation_metrics)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:update_room, room_code}, socket) do
    socket
    |> assign(room_code: room_code)
    |> assign(seconds_left: 10 * 60)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "start_game", nil)

    socket
    |> assign(game_state: :started)
    |> assign(timer: Process.send_after(self(), :tick, 1000))
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("stop_game", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)
    Process.cancel_timer(socket.assigns.timer)

    socket
    |> assign(game_state: :stopped)
    |> assign(timer: nil)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("goal", %{"team" => team}, socket) do
    teams = update_in(socket.assigns.teams, [team, :goals], &(&1 + 1))

    socket
    |> assign(teams: teams)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("reset_score", _params, socket) do
    teams =
      socket.assigns.teams
      |> Map.new(fn {team, team_data} -> {team, %{team_data | goals: 0}} end)

    socket
    |> assign(teams: teams)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("new_room", _params, socket) do
    Endpoint.broadcast_from(self(), @game_state, "new_room", nil)

    socket
    |> assign(game_state: :lobby)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("show_stats", _params, socket) do
    socket
    |> assign(stats_visible: true)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("close_stats", _params, socket) do
    {:noreply, assign(socket, stats_visible: false)}
  end

  @impl true
  def handle_event("reset_stats", _params, socket) do
    RoboSoccerPlatform.GameController.reset_stats()

    socket
    |> assign(total_cooperation_metrics: %{"green" => 1.0, "red" => 1.0, number_of_measurements: 0})
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("kick", %{"player_id" => player_id}, socket) do
    Endpoint.broadcast_from(self(), @game_state, "kick", %{player_id: player_id})

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) when socket.assigns.game_state != :started,
    do: {:noreply, socket}

  @impl true
  def handle_info(:tick, socket) do
    seconds_left = socket.assigns.seconds_left - 1

    if seconds_left > 0 do
      socket
      |> assign(seconds_left: seconds_left)
      |> assign(timer: Process.send_after(self(), :tick, 1000))
      |> then(&{:noreply, &1})
    else
      Endpoint.broadcast_from(self(), @game_state, "stop_game", nil)

      socket
      |> assign(game_state: :stopped)
      |> assign(seconds_left: 10 * 60)
      |> then(&{:noreply, &1})
    end
  end

  @impl true
  def handle_info(message, socket) do
    Logger.warning("[#{inspect(__MODULE__)}] Ignoring message: #{inspect(message)}")
    {:noreply, socket}
  end

  @spec render_wifi_qr_code(String.t(), String.t()) :: Phoenix.HTML.safe()
  defp render_wifi_qr_code(wifi_ssid, wifi_psk) do
    # Add padding so that the qr codes are the same size (between 33 and 53 character strings they are are 29x29)
    wifi_string = "WIFI:S:#{wifi_ssid};T:WPA;P:#{wifi_psk};;"

    if String.length(wifi_string) > 53 do
      Logger.warning("Please use wifi name + password shorter than 36 for nicer qr code rendering")
    end

    wifi_string |> String.pad_trailing(33) |> render_qr_code()
  end

  @spec render_player_url_qr_code(String.t(), String.t(), String.t()) :: Phoenix.HTML.safe()
  defp render_player_url_qr_code(ip, port, room_code) do
    "http://#{ip}:#{port}/player?room_code=#{room_code}" |> render_qr_code()
  end

  @spec render_qr_code(String.t()) :: Phoenix.HTML.safe()
  defp render_qr_code(string) do
    svg_settings = %QRCode.Render.SvgSettings{scale: 18}

    {:ok, qr} =
      string
      |> QRCode.create()
      |> QRCode.render(:svg, svg_settings)

    Phoenix.HTML.raw(qr)
  end

  @spec init_teams(steering_state()) :: teams()
  defp init_teams(steering_state) do
    update_teams(%{}, steering_state)
  end

  @spec update_teams(teams(), steering_state()) :: teams()
  defp update_teams(teams, steering_state) do
    steering_state.robot_instructions
    |> Map.new(fn {team, robot_instruction} ->
      team_player_inputs =
        steering_state.player_inputs
        |> Map.values()
        |> Enum.filter(&(&1.player.team == team))

      {
        team,
        %{
          player_inputs: team_player_inputs,
          robot_instruction: robot_instruction,
          goals: get_in(teams, [team, :goals]) || 0
        }
      }
    end)
  end
end
