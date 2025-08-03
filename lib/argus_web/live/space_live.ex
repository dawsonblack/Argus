defmodule ArgusWeb.SpaceLive do
  use ArgusWeb, :live_view
  import ArgusWeb.UIComponents
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

    {:ok,
      socket
      |> assign(home_slug: home_slug)
      |> assign(space: space)
      |> assign(space_slug: space_slug)
      |> assign(:show_appliance_form, false)}
  end

  def handle_event("show_appliance_form", _params, socket) do
    {:noreply, assign(socket, show_appliance_form: true)}
  end

  def handle_info(:appliance_created, socket) do
    home =
      Homes.get_space_by_slug(socket.assigns.home, socket.assigns.space_slug)
      |> Argus.Repo.preload(:appliances)

    {:noreply, assign(socket, home: home, show_space_form: false)}
  end


  def handle_info(:form_canceled, socket) do
    {:noreply, assign(socket, show_space_form: false)}
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

  def handle_info(msg, socket) do
    IO.inspect(msg, label: "Unhandled pubsub msg in SpaceLive")
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

    <main class="item-card-grid">
      <%= for appliance <- @space.appliances do %>
        <.live_component
          module={ArgusWeb.ApplianceLive}
          id={appliance.slug}
          appliance={appliance}
        />
      <% end %>

      <.add_item phx-click="show_appliance_form" />
    </main>

    <%= if @show_appliance_form do %>
      <.live_component
        module={ArgusWeb.ApplianceFormComponent}
        id="appliance-form"
        parent={@space}
      />
    <% end %>
  </body>
  """
  end
end
