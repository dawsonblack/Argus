defmodule ArgusWeb.HomeFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes
  alias Argus.Homes.Home

  def update(assigns, socket) do
    changeset = Homes.change_home(%Home{})
    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"home" => home_params}, socket) do
    case Homes.create_home(home_params) do
      {:ok, _home} ->
        send(self(), :home_created)
        {:noreply, assign(socket, changeset: Homes.change_home(%Home{}))}

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
        <h2>New Home</h2>
        <form phx-submit="save" phx-target={@myself}>
          <label for="home_name">Name</label>
          <input type="text" id="home_name" name="home[name]" />
          <label for="home_name">Address</label>
          <input type="text" id="home_name" name="home[address]" />
          <button type="button" phx-click="cancel" phx-target={@myself}>Cancel</button>
          <button type="submit">Save</button>
        </form>
      </div>
    </div>
    """
  end
end
