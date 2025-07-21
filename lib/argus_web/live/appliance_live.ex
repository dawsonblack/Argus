defmodule ArgusWeb.ApplianceLive do
  use Phoenix.LiveComponent

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:volume, fn -> 50 end)
      |> assign_new(:power, fn -> nil end)

    {:ok, socket}
  end

  def handle_event("toggle_power", _params, socket) do
    current = socket.assigns.power
    next = if current == "on", do: "off", else: "on"
    Argus.CommandPipeline.send_command(socket.assigns.appliance, next)
    {:noreply, assign(socket, :power, next)}
  end

  def handle_event("set_volume", %{"value" => value}, socket) do
    int_val = String.to_integer(value)
    Argus.CommandPipeline.send_command(socket.assigns.appliance, "volume", int_val)
    {:noreply, assign(socket, :volume, int_val)}
  end


  def render(assigns) do
    ~H"""
    <div id={"appliance-#{@appliance.slug}"} class={"appliance-card #{if @power == "on", do: "on", else: ""}"}>
      <div class="appliance-left">
        <h2 class="appliance-title"><%= @appliance.name %></h2>

        <div class="appliance-controls">
          <%= if has_command?(@appliance.appliance_commands, "on") and has_command?(@appliance.appliance_commands, "off") do %>
            <div class="switch-wrapper">
              <span class="switch-label">Power</span>
              <label class="switch">
                <input
                  type="checkbox"
                  phx-click="toggle_power"
                  phx-target={@myself}
                  checked={@power == "on"}
                />
                <span class="slider"></span>
              </label>
            </div>
          <% end %>
        </div>
      </div>

      <div id="#{@appliance.slug}-volume-stack" class="volume-stack" phx-hook="VolumeHover">
        <div class="volume-controls">
          <div
            class="volume-button plus"
            phx-click="set_volume"
            phx-value-value={min(@volume + 10, 100)}
            phx-target={@myself}
          >+</div>

          <div class="volume-line"></div>

          <div
            class="volume-button minus"
            phx-click="set_volume"
            phx-value-value={max(@volume - 10, 0)}
            phx-target={@myself}
          >−</div>
        </div>

        <div class="volume-bar-wrapper">
          <div class="volume-bar-fill" style={"height: #{@volume}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  defp has_command?(commands, name) do
    Enum.any?(commands, &(&1.name == name))
  end
end
