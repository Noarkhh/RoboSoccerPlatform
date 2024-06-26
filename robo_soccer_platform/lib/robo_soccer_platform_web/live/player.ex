defmodule RoboSoccerPlatformWeb.Player do
  use RoboSoccerPlatformWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(id: UUID.uuid4())
      |> assign(form: %{"errors" => []})

    {:ok, socket}
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
        <div class="flex max-w-[70%] w-max ">
          <.input
            phx-debounce="blur"
            name="username"
            value=""
            label="NAZWA GRACZA"
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

  def handle_event("change", %{"username" => username}, socket) do
    form = Map.put(socket.assigns.form, "username", username)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"team" => team}, socket) do
    form = assign_form_errors(socket.assigns.form)

    if form["errors"] == [] do
      socket = assign(socket, form: form)

      path =
        "/player/steering?" <>
          URI.encode_query(
            team: team,
            username: socket.assigns.form["username"],
            id: socket.assigns.id
          )

      {:noreply, push_navigate(socket, to: path)}
    else
      {:noreply, assign(socket, form: form)}
    end
  end

  defp assign_form_errors(form) do
    errors =
      if Map.get(form, "username", "") == "" do
        ["Przed dołączeniem do drużyny podaj swoją nazwę"]
      else
        []
      end

    Map.put(form, "errors", errors)
  end
end
