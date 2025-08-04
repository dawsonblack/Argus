defmodule ArgusWeb.ManageSpaceFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes
  alias Argus.Homes.Space

  def update(assigns, socket) do
    space = assigns.parent
    changeset = Homes.space_changeset(space)
    {:ok,
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"space" => space_params}, socket) do
    case Homes.update_space(socket.assigns.parent, space_params) do
      {:ok, space} ->
        send(self(), :space_updated)
        {:noreply,
          push_navigate(socket,
            to: ~p"/homes/#{socket.assigns.home_slug}/#{space.slug}"
          )}


      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :settings_closed)
    {:noreply, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, form: to_form(assigns.changeset))
    ~H"""
    <div class="item-form-backdrop">
      <div class="item-form">
        <h2 class="form-title">Settings</h2>
        <.form for={@form} phx-submit="save" phx-target={@myself}>
          <label for="name">Name</label>
          <.input field={@form[:name]} type="text" />

          <div class="bottom-container">
            <button class="delete-button" type="button">
              <svg xmlns="http://www.w3.org/2000/svg"
                  width="20" height="20"
                  fill="none" viewBox="0 0 24 24"
                  stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round"
                      d="M6 7h12M9 7V4h6v3M10 11v6m4-6v6M5 7h14l-1.5 12.5a2 2 0 01-2 1.5H8.5a2 2 0 01-2-1.5L5 7z" />
              </svg>
            </button>

            <div class="form-actions">
              <button type="button" phx-click="cancel" phx-target={@myself} class="cancel">Cancel</button>
              <button type="submit" class="save">Save</button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
