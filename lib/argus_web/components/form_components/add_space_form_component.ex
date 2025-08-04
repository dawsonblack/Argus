defmodule ArgusWeb.AddSpaceFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes
  alias Argus.Homes.Space

  def update(assigns, socket) do
  changeset = Homes.space_changeset(%Space{})
  {:ok, assign(socket, assigns)
    |> assign(:changeset, changeset)}
end


  def handle_event("save", %{"space" => space_params}, socket) do
    case Homes.create_space(socket.assigns.home, space_params) do
      {:ok, _space} ->
        send(self(), :space_created)
        {:noreply, assign(socket, changeset: Homes.space_changeset(%Space{}))}

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
        <h2 class="form-title">New Space</h2>
        <form phx-submit="save" phx-target={@myself}>
          <label for="name">Name</label>
          <input type="text" id="name" name="space[name]" />

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
