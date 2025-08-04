
defmodule ArgusWeb.ManageHomeFormComponent do
  use ArgusWeb, :live_component

  alias Argus.Homes

  def update(assigns, socket) do
    home = assigns.home
    changeset = Homes.home_changeset(home)
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"home" => home_params}, socket) do
    case Homes.update_home(socket.assigns.home, home_params) do
      {:ok, home} ->
        send(self(), :home_updated)

        {:noreply,
          push_navigate(socket,
            to: ~p"/homes/#{home.slug}"
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

          <label for="address">Address</label>
          <.input field={@form[:address]} type="text" />

          <div class="form-actions">
            <button type="button" phx-click="cancel" phx-target={@myself} class="cancel">Cancel</button>
            <button type="submit" class="save">Save</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
