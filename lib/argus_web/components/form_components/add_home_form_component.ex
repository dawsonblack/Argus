defmodule ArgusWeb.AddHomeFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes
  alias Argus.Homes.Home

  def update(_assigns, socket) do
    changeset = Homes.home_changeset(%Home{})
    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"home" => home_params}, socket) do
    case Homes.create_home(home_params) do
      {:ok, _home} ->
        send(self(), :home_created)
        {:noreply, assign(socket, changeset: Homes.home_changeset(%Home{}))}

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
        <h2 class="form-title">New Home</h2>
        <form phx-submit="save" phx-target={@myself}>
          <label for="name">Name</label>
          <input type="text" id="name" name="home[name]" />

          <label for="address">Address</label>
          <input type="text" id="address" name="home[address]" />

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
