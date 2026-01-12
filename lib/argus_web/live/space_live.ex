defmodule ArgusWeb.SpaceLive do
  use ArgusWeb, :live_view
  import ArgusWeb.UIComponents
  alias Argus.Homes
  alias Argus.DeviceCommunication.CommandPipeline
  def mount(%{"home_slug" => home_slug, "space_slug" => space_slug}, _session, socket) do
    space =
      Homes.get_home_by_slug(home_slug)
      |> Homes.get_space_by_slug(space_slug)
      |> Argus.Repo.preload(appliances: :appliance_commands)

    if connected?(socket) do
      Enum.each(space.appliances, fn appliance ->
        IO.puts("Subscribing to appliance:#{appliance.mac_address}")
        Phoenix.PubSub.subscribe(Argus.PubSub, "appliance:#{appliance.mac_address}")

        Enum.each(Homes.list_commands_of_type_in_appliance(appliance, "read"), fn command ->
          CommandPipeline.read_payload(appliance, command.name) |> CommandPipeline.send_command_to_device()
        end) #TODO: fix all of this liveview logic
      end)
    end

    {:ok,
      socket
      |> assign(home_slug: home_slug)
      |> assign(space: space)
      |> assign(space_slug: space_slug)
      |> assign(:show_add_form, false)
      |> assign(:show_settings, false)}
  end

  def handle_event("show_add_form", _params, socket) do
    {:noreply, assign(socket, show_add_form: true)}
  end

  def handle_event("show_settings", _params, socket) do
    {:noreply, assign(socket, show_settings: true)}
  end

  def handle_info(:settings_closed, socket) do
    {:noreply, assign(socket, show_settings: false)}
  end


  def handle_info(:form_canceled, socket) do
    {:noreply, assign(socket, show_add_form: false)}
  end

  def handle_info({:state_update, %{"mac_address" => mac} = state}, socket) do
    slug = find_appliance_slug(socket.assigns.space.appliances, mac)
    send_update(ArgusWeb.ApplianceLive,
    id: slug,
    state_update: state)

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

      <.add_item phx-click="show_add_form" />
    </main>

    <.settings_button />

    <%= if @show_add_form do %>
      <.live_component
        module={ArgusWeb.ApplianceFormComponent}
        id="appliance-form"
        parent={@space}
      />
    <% end %>

    <%= if @show_settings do %>
      <.live_component
        module={ArgusWeb.ManageSpaceFormComponent}
        id="settings"
        home_slug={@home_slug}
        parent={@space}
      />
    <% end %>
  </body>
  """
  end
end
