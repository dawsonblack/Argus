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
    <div id={"appliance-#{@appliance.slug}"} class={"card appliance #{if @power == "on", do: "on", else: ""}"}>
      <div class="appliance-left">
        <h2 class="appliance-title"><%= @appliance.name %></h2>
      </div>

      <div class="appliance-controls">
          <%= if has_command?(@appliance.appliance_commands, "on") and has_command?(@appliance.appliance_commands, "off") do %>
            <div class="switch-wrapper">
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

      <div id="#{@appliance.slug}-volume-stack" class="volume-stack" phx-hook="VolumeHover">
        <div class="volume-bar-wrapper">
          <div class="volume-bar-fill" style={"height: #{@volume}%"}></div>
        </div>

        <div class="volume-controls">
          <div
            id="#{@appliance.slug}-volume-up"
            class="volume-button plus"
            phx-click="set_volume"
            phx-value-value={min(@volume + 5, 100)}
            phx-target={@myself}
            phx-hook="RepeatClick"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </div>

          <div
            id="#{@appliance.slug}-volume-down"
            class="volume-button minus"
            phx-click="set_volume"
            phx-value-value={max(@volume - 5, 0)}
            phx-target={@myself}
            phx-hook="RepeatClick"
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp has_command?(commands, name) do
    Enum.any?(commands, &(&1.name == name))
  end
end
