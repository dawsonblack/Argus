defmodule ArgusWeb.ApplianceLive do
  use Phoenix.LiveComponent

  alias Argus.Homes
  alias Argus.DeviceCommunication.CommandPipeline

  def update(%{appliance: appliance} = assigns, socket) do
    read_cmds = Homes.list_commands_of_type_in_appliance(appliance, "read")

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:_read_index, fn ->
        # index by name and also keep by-uuid for quick filtering
        %{
          by_name: Map.new(read_cmds, &{&1.name, &1}),
          by_uuid: Enum.group_by(read_cmds, & &1.uuid)
        }
      end)
      |> then(fn socket ->
        Enum.reduce(read_cmds, socket, fn cmd, s2 ->
          assign_new(s2, String.to_atom(cmd.name), fn -> nil end)
        end)
      end)

    {:ok, socket}
  end

  def update(%{state_update: %{"uuid" => uuid, "data" => data}}, socket) do
    read_cmds =
    case socket.assigns[:_read_index] do
      %{by_uuid: by_uuid} -> Map.get(by_uuid, uuid, [])
      _ -> Homes.list_reads_for_uuid(socket.assigns.appliance, uuid)
    end

    socket =
      Enum.reduce(read_cmds, socket, fn cmd, s ->
        val = CommandPipeline.interpret_read(data, cmd.command)
        assign(s, String.to_atom(cmd.name), val)
      end)

    {:ok, socket}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  def handle_event("toggle_power", _params, socket) do
    current = socket.assigns.power
    next = if current == "on", do: "off", else: "on"
    CommandPipeline.write_to_device(socket.assigns.appliance, next, "write")
    {:noreply, assign(socket, :power, next)}
  end

  def handle_event("set_volume", %{"value" => value}, socket) do
    int_val = String.to_integer(value)
    CommandPipeline.write_to_device(socket.assigns.appliance, "volume", "write", int_val)
    {:noreply, assign(socket, :volume, int_val)}
  end


  def render(assigns) do
    ~H"""
    <div id={"appliance-#{@appliance.slug}"} class={"item-card appliance #{if @power == "on", do: "on", else: ""}"}>
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
            phx-value-value={if @volume, do: min(@volume + 5, 100), else: nil}
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
            phx-value-value={if @volume, do: min(@volume - 5, 0), else: nil}
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
