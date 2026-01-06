# lib/argus_web/live/chat_live.ex
defmodule ArgusWeb.ChatLive do
  use ArgusWeb, :live_view
  alias Argus.Homes

  @impl true
  def mount(_params, _session, socket) do
    homes = Homes.list_homes()

    messages =
      Enum.map(homes, fn h ->
        %{
          id: "home-#{h.id}",
          role: if(rem(h.id, 2) == 1, do: :argus, else: :user),
          text: "#{h.name} — #{h.address}"
        }
      end)

    {:ok, assign(socket, messages: messages, input: "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Minimal inline styles so this is drop-in. Move to app.css later. -->
    <style>
      .chat-wrap{max-width:880px;margin:0 auto;height:100vh;display:flex;flex-direction:column;gap:.75rem;padding:1rem;box-sizing:border-box}
      .chat-log{flex:1;overflow:auto;border:1px solid #e5e5e5;border-radius:.75rem;padding:1rem;display:flex;flex-direction:column;gap:.5rem;background:#fafafa}
      .row{display:flex}
      .row.user{justify-content:flex-end}
      .row.argus{justify-content:flex-start}
      .bubble{max-width:75%;padding:.5rem .8rem;border-radius:1rem;line-height:1.3}
      .bubble.user{background:#2563eb;color:#fff;border-top-right-radius:.25rem}
      .bubble.argus{background:#e5e7eb;color:#111827;border-top-left-radius:.25rem}
      .composer{display:flex;gap:.5rem}
      .composer textarea{flex:1;resize:none;min-height:44px;max-height:140px;padding:.6rem;border:1px solid #e5e5e5;border-radius:.75rem}
      .composer button{padding:.6rem 1rem;border:1px solid #e5e5e5;border-radius:.75rem;background:white;cursor:default}
    </style>

    <div class="chat-wrap">
      <div class="chat-log" id="messages">
        <%= for m <- @messages do %>
          <div class={"row #{m.role}"}>
            <div class={"bubble #{m.role}"}>
              <%= m.text %>
            </div>
          </div>
        <% end %>
      </div>

      <form class="composer">
        <textarea name="text" placeholder="Type a message… (does nothing yet)"><%= @input %></textarea>
        <button type="button" disabled>Send</button>
      </form>
    </div>
    """
  end
end
