defmodule ArgusWeb.HomeLive do
  use ArgusWeb, :live_view
  import ArgusWeb.UIComponents
  alias Argus.Homes
  def mount(%{"slug" => slug}, _session, socket) do
    home =
      Homes.get_home_by_slug(slug)
      |> Argus.Repo.preload(:spaces)

    {:ok,
      socket
      |> assign(home: home)
      |> assign(slug: slug)
      |> assign(:show_add_form, false)
      |> assign(:show_settings, false)}
  end

  def handle_event("show_add_form", _params, socket) do
    {:noreply, assign(socket, show_add_form: true, show_settings: false)}
  end

  def handle_event("show_settings", _params, socket) do
    {:noreply, assign(socket, show_settings: true, show_add_form: false)}
  end

  def handle_info(:space_created, socket) do
    home =
      Homes.get_home_by_slug(socket.assigns.slug)
      |> Argus.Repo.preload(:spaces)

    {:noreply, assign(socket, home: home, show_add_form: false)}
  end

  def handle_info(:settings_closed, socket) do
    {:noreply, assign(socket, show_settings: false)}
  end

  def handle_info(:form_canceled, socket) do
    {:noreply, assign(socket, show_add_form: false)}
  end

  def render(assigns) do
  ~H"""
  <body>
    <header>
      <h1><%= @home.name %></h1>
    </header>

    <main class="item-card-grid">
      <%= for space <- @home.spaces do %>
        <section class="item-card">
          <h2><%= space.name %></h2>
          <p>🌡️ Temp: 70°F · 💧 Humidity: 43%</p>
          <.link navigate={~p"/homes/#{@home.slug}/#{space.slug}"}>
            <button class="view-button">Enter</button>
          </.link>
        </section>
      <% end %>

      <.add_item phx-click="show_add_form" />
    </main>

    <%= if @show_add_form do %>
      <.live_component
        module={ArgusWeb.AddSpaceFormComponent}
        id="space-form"
        home={@home}
      />
    <% end %>

    <%= if @show_settings do %>
      <.live_component
        module={ArgusWeb.ManageHomeFormComponent}
        id="settings"
        home={@home}
      />
    <% end %>

    <.settings_button />

  </body>
  """
  end
end
