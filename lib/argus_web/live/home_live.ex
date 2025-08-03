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
      |> assign(:show_space_form, false)}
  end

  def handle_event("show_space_form", _params, socket) do
    {:noreply, assign(socket, show_space_form: true)}
  end

  def handle_info(:space_created, socket) do
    home =
      Homes.get_home_by_slug(socket.assigns.slug)
      |> Argus.Repo.preload(:spaces)

    {:noreply, assign(socket, home: home, show_space_form: false)}
  end


  def handle_info(:form_canceled, socket) do
    {:noreply, assign(socket, show_space_form: false)}
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

      <.add_item phx-click="show_space_form" />
    </main>

    <%= if @show_space_form do %>
      <.live_component
        module={ArgusWeb.SpaceFormComponent}
        id="space-form"
        home={@home}
      />
    <% end %>
  </body>
  """
  end
end
