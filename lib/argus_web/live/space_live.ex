defmodule ArgusWeb.SpaceLive do
  use ArgusWeb, :live_view
  alias Argus.Homes
  def mount(%{"home_slug" => home_slug, "space_slug" => space_slug}, _session, socket) do
    space =
      Homes.get_home_by_slug(home_slug)
      |> Homes.get_space_by_slug(space_slug)
      |> Argus.Repo.preload(appliances: :appliance_commands)

    if connected?(socket) do
      Enum.each(space.appliances, fn appliance ->
        Phoenix.PubSub.subscribe(Argus.PubSub, "appliance:#{appliance.mac_address}")
        Argus.CommandPipeline.read_from_device(appliance.mac_address)
      end)
    end

    {:ok, assign(socket, home_slug: home_slug, space: space)}
  end


  def handle_info({:state_update, mac, update}, socket) do
    id = find_appliance_slug(socket.assigns.space.appliances, mac)
    send_update(ArgusWeb.ApplianceLive,
      id: id,
      volume: update["volume"],
      power: update["power"]
    )

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    IO.inspect(_msg, label: "Unhandled pubsub msg in SpaceLive")
    {:noreply, socket}
  end

  defp find_appliance_slug(appliances, mac) do
    Enum.find_value(appliances, fn a ->
      if a.mac_address == mac, do: a.slug, else: nil
    end)
  end

  def render(assigns) do
  ~H"""
  <body>
    <header>
      <h1><%= @space.name %></h1>
    </header>

    <main class="room-grid">
      <%= for appliance <- @space.appliances do %>
        <.live_component
          module={ArgusWeb.ApplianceLive}
          id={appliance.slug}
          appliance={appliance}
        />
      <% end %>
    </main>
  </body>
  """
  end
end
