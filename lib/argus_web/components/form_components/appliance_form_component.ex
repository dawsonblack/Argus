defmodule ArgusWeb.ApplianceFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes
  alias Argus.Homes.Appliance

  def update(assigns, socket) do
  changeset = Homes.appliance_changeset(%Appliance{})
  {:ok, assign(socket, assigns)
    |> assign(:changeset, changeset)}
end


  def handle_event("save", %{"appliance" => appliance_params}, socket) do
    case Homes.create_appliance(socket.assigns.parent, appliance_params) do
      {:ok, _appliance} ->
        send(self(), :appliance_created)
        {:noreply, assign(socket, changeset: Homes.appliance_changeset(%Appliance{}))}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :form_canceled)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="item-form-backdrop">
      <div class="item-form">
        <h2 class="form-title">New Appliance</h2>
        <form phx-submit="save" phx-target={@myself}>
          <label for="name">Name</label>
          <input type="text" id="name" name="appliance[name]" />

          <label for="mac-address">Mac Address</label>
          <input type="text" id="mac-address" name="appliance[mac_address]" />

          <div class="form-actions">
            <button type="button" phx-click="cancel" phx-target={@myself} class="cancel">Cancel</button>
            <button type="submit" class="save">Save</button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
