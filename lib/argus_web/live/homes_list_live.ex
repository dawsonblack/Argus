defmodule ArgusWeb.HomesListLive do
  use ArgusWeb, :live_view
  import ArgusWeb.UIComponents
  alias Argus.Homes
  def mount(_params, _session, socket) do
    homes = Homes.list_homes()
    {:ok,
      socket
      |> assign(homes: homes)
      |> assign(:show_home_form, false)}
  end

  def handle_event("show_home_form", _params, socket) do
    {:noreply, assign(socket, show_home_form: true)}
  end

  def handle_info(:home_created, socket) do
    # Refetch homes or append it
    {:noreply, assign(socket, homes: Homes.list_homes(), show_home_form: false)}
  end

  def handle_info(:form_canceled, socket) do
    {:noreply, assign(socket, show_home_form: false)}
  end

  def render(assigns) do
    ~H"""
    <body class={if @show_home_form, do: "blurred", else: ""}>
      <header>
        <h1>ARGUS</h1>
      </header>

      <main id="home-list" class="item-card-grid" phx-hook="HomesLoader">
        <%= for home <- @homes do %>
          <div class="item-card">
            <h2><%= home.name %></h2>
            <p>0 Lights On · No AC</p>
            <.link navigate={~p"/homes/#{home.slug}"}>
              <button class="view-button">Enter</button>
            </.link>
          </div>
        <% end %>

        <.add_item phx-click="show_home_form" />
      </main>

      <%= if @show_home_form do %>
        <.live_component
          module={ArgusWeb.HomeFormComponent}
          id="home-form"
        />
      <% end %>
    </body>
    """
  end
end
