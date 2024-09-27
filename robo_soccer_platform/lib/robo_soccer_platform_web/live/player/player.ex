defmodule RoboSoccerPlatformWeb.Player do
  use RoboSoccerPlatformWeb, :live_view

  @join_game "join_game"

  alias RoboSoccerPlatformWeb.Player.Utils
  alias RoboSoccerPlatformWeb.Endpoint

  def mount(_params, _session, socket) do
    Endpoint.subscribe(@join_game)

    socket
    |> assign(id: UUID.uuid4())
    |> assign(form: %{"errors" => []})
    |> then(&{:ok, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="h-[75vh]">
      <.form
        for={@form}
        phx-change="change"
        phx-submit="submit"
        class="flex flex-col gap-20 items-center h-full"
      >
        <div class="flex flex-col max-w-[70%] w-max">
          <.input
            phx-debounce="blur"
            name="username"
            value=""
            label="NAZWA GRACZA"
            errors={@form["errors"]}
            label_class="text-center"
          />
          <.input
            phx-debounce="500"
            name="room_code"
            value=""
            label="NUMER POKOJU"
            errors={@form["errors"]}
            label_class="text-center"
          />
        </div>
        <div class="flex flex-col w-full h-full gap-8">
          <.join_team_button team={:green} class="bg-light-green active:bg-dark-green">
            Dołącz do drużyny zielonej!
          </.join_team_button>
          <.join_team_button team={:red} class="bg-light-red active:bg-dark-red">
            Dołącz do drużyny czerwonej!
          </.join_team_button>
        </div>
      </.form>
    </div>
    """
  end

  def handle_event("change", %{"username" => username, "room_code" => room_code}, socket) do
    form =
      socket.assigns.form
      |> Map.put("username", username)
      |> Map.put("room_code", room_code)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"team" => team}, socket) do
    form = Utils.put_form_errors(socket.assigns.form)

    if form["errors"] == [] do
      Endpoint.broadcast_from(
        self(),
        @join_game,
        "request",
        %{id: socket.assigns.id, team: team, code: socket.assigns.form["room_code"]}
      )
    end

    {:noreply, assign(socket, form: form)}
  end

  # ignore other players requests
  def handle_info(%{topic: @join_game, event: "request"}, socket), do: {:noreply, socket}

  def handle_info(
    %{topic: @join_game, event: "response", payload: %{code: :error, id: id}},
    socket
  ) when id == socket.assigns.id do

    {:noreply, put_flash(socket, :error, "ZŁY NUMER POKOJU, SPRÓBUJ PONOWNIE")}
  end

  def handle_info(
    %{topic: @join_game, event: "response", payload: %{id: id, team: team}},
    socket
  ) when id == socket.assigns.id do

    path =
      "/player/steering?" <>
        URI.encode_query(
          team: team,
          username: socket.assigns.form["username"],
          room_code: socket.assigns.form["room_code"],
          id: socket.assigns.id
        )

    {:noreply, push_navigate(socket, to: path)}
  end

  # ignore responses to other player
  def handle_info(%{topic: @join_game, event: "response"}, socket), do: {:noreply, socket}

  attr :team, :any, required: true
  attr :class, :any, default: ""

  slot :inner_block

  defp join_team_button(assigns) do
    ~H"""
    <.button
      type="button"
      phx-click="submit"
      phx-value-team={@team}
      class={["flex-1 w-full !text-black !text-4xl transition" | List.wrap(@class)]}
    >
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end
end
