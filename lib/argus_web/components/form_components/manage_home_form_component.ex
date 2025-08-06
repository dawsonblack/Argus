
defmodule ArgusWeb.ManageHomeFormComponent do
  use ArgusWeb, :live_component
  import ArgusWeb.UIComponents

  alias Argus.Homes

  def update(assigns, socket) do
    home = assigns.home
    changeset = Homes.home_changeset(home)
    {:ok,
     socket
     |> assign(assigns)
     |> assign(confirm_delete: false)
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"home" => home_params}, socket) do
    case Homes.update_home(socket.assigns.home, home_params) do
      {:ok, home} ->
        {:noreply,
          push_navigate(socket,
            to: ~p"/homes/#{home.slug}"
          )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", _params, socket) do
    case Homes.delete_home(socket.assigns.home) do
      {:ok, _home} ->
        {:noreply,
          push_navigate(socket,
            to: "/homes/"
          )}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("cancel", _params, socket) do
    send(self(), :settings_closed)
    {:noreply, socket}
  end

  def handle_event("confirm_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: true)}
  end

  def handle_event("delete_canceled", _params, socket) do
    {:noreply, assign(socket, confirm_delete: false)}
  end

  def render(assigns) do
    assigns = assign(assigns, form: to_form(assigns.changeset))
    ~H"""
    <div class="item-form-backdrop">
      <%= unless @confirm_delete do %>
        <div class="item-form">
          <h2 class="form-title">Settings</h2>
          <.form for={@form} phx-submit="save" phx-target={@myself}>
            <label for="name">Name</label>
            <.input field={@form[:name]} type="text" />

            <label for="address">Address</label>
            <.input field={@form[:address]} type="text" />

            <div class="bottom-container">
              <button class="delete-button" type="button" phx-click="confirm_delete" phx-target={@myself}>
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
      <% else %>
        <.delete_confirmation myself={@myself} name={@home.name}/>
      <% end %>
    </div>
    """
  end
end
