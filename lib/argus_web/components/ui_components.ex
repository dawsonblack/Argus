defmodule ArgusWeb.UIComponents do
  use Phoenix.Component
  attr :rest, :global

  def add_item(assigns) do
    ~H"""
    <div class="add-item item-card" {@rest}>
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <line x1="12" y1="5" x2="12" y2="19" />
        <line x1="5" y1="12" x2="19" y2="12" />
      </svg>
    </div>


    <style>
      .add-item {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .add-item svg {
        width: 100px;
        stroke: currentColor;
        stroke-width: 2;
      }
    </style>
    """
  end

  def settings_button(assigns) do
    ~H"""
    <button
      phx-click="show_settings"
      class="settings-button"
      aria-label="settings">
      <svg xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="settings-icon">
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h.09a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h.09a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v.09a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
      </svg>
    </button>


    <style>
      .settings-button {
        position: fixed;
        bottom: 24px;
        right: 24px;
        background: none;
        border: none;
        cursor: pointer;
        z-index: 100;
        color: #888;
        padding: 8px;
      }

      .settings-button:hover {
        color: #00c853;
      }

      .settings-icon {
        width: 28px;
        height: 28px;
        stroke-width: 2;
      }
    </style>
    """
  end
end
