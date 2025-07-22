defmodule ArgusWeb.HomesListLive do
  use ArgusWeb, :live_view
  alias Argus.Homes
  def mount(_params, _session, socket) do
    homes = Homes.list_homes()
    {:ok, assign(socket, homes: homes)}
  end

  def render(assigns) do
    ~H"""
    <body>
      <header>
        <h1>ARGUS</h1>
      </header>

      <main id="home-list" class="grid" phx-hook="HomesLoader">
        <%= for home <- @homes do %>
          <div class="card">
            <h2><%= home.name %></h2>
            <p>0 Lights On · No AC</p>
            <.link navigate={~p"/homes/#{home.slug}"}>
              <button>Enter</button>
            </.link>
          </div>
        <% end %>
      </main>
    </body>
    """
  end
end
