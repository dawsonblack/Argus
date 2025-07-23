defmodule ArgusWeb.HomeLive do
  use ArgusWeb, :live_view
  import ArgusWeb.UIComponents
  alias Argus.Homes
  def mount(%{"slug" => slug}, _session, socket) do
    home =
      Homes.get_home_by_slug(slug)
      |> Argus.Repo.preload(:spaces)

    {:ok, assign(socket, home: home)}
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
            <button>Enter</button>
          </.link>
        </section>
      <% end %>
      <.add_item />
    </main>
  </body>
  """
  end
end
