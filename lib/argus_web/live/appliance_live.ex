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

        <div class="volume-wrapper">
          <label class="volume-label">Volume: <%= @volume %></label>
          <input
            id="#{@appliance.slug}-volume-slider"
            type="range"
            name="value"
            min="0"
            max="100"
            value={@volume}
            phx-hook="VolumeSlider"
            phx-target={@myself}
            class="volume-slider"
          />
        </div>
      </div>
    </div>
    """
  end

  defp has_command?(commands, name) do
    Enum.any?(commands, &(&1.name == name))
  end
end
