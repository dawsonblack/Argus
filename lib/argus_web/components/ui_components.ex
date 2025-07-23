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
end
