# lib/argus_web/live/chat_live.ex
defmodule ArgusWeb.ChatLive do
  use ArgusWeb, :live_view
  alias Argus.Chat
  alias Argus.Chat.Message
  alias Argus.Assistant.CommandParsing

  @topic "chat:global"

  def mount(_params, _session, socket) do
    messages = Chat.list_messages()
    Phoenix.PubSub.subscribe(Argus.PubSub, @topic)
    {:ok,
      socket
      |> assign(messages: messages)
      |> assign(input: "") #TODO: What is this input? Do you need it here?
      |> assign(typing: false)}
  end

  def handle_event("send", %{"text" => text}, socket) do
    if text == "" do
      {:noreply, socket}
    else
      case Chat.create_message(%{sender: "Dawson", modality: "typed", text: text}) do #TODO: Dawson shouldn't be hardcoded, find a way to get the user
        {:ok, _message} ->
          Phoenix.PubSub.broadcast(Argus.PubSub, @topic, {:user_message, text})
          {:noreply, assign(socket, messages: Chat.list_messages())}

        {:error, changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  def handle_info({:user_message, _text}, socket) do
    {:noreply, socket}
  end

  def handle_info({:assistant_status, :typing}, socket) do
    {:noreply, assign(socket, typing: true)}
  end

  def handle_info({:assistant_message, %Message{}}, socket) do
    {:noreply, assign(socket, messages: Chat.list_messages(), typing: false)}
  end

  def handle_info({:assistant_status, :error}, socket) do
    {:noreply, assign(socket, typing: false)}
  end

  def render(assigns) do
    ~H"""
    <style>
      .chat-wrap{max-width:880px;margin:0 auto;height:100vh;display:flex;flex-direction:column;gap:.75rem;padding:1rem;box-sizing:border-box}
      .chat-log{flex:1;overflow:auto;border:1px solid #e5e5e5;border-radius:.75rem;padding:1rem;display:flex;flex-direction:column;gap:.5rem;background:#fafafa}
      .row{display:flex}
      .row{justify-content:flex-end}
      .row.assistant{justify-content:flex-start}
      .bubble{max-width:75%;padding:.5rem .8rem;border-radius:1rem;line-height:1.3; white-space: pre-line;}
      .bubble{max-width:75%;padding:.5rem .8rem;border-radius:1rem;line-height:1.3}
      .bubble{background:#2563eb;color:#fff;border-top-right-radius:.25rem}
      .bubble.assistant{background:#e5e7eb;color:#111827;border-top-left-radius:.25rem}
      .composer{display:flex;gap:.5rem}
      .composer textarea{flex:1;resize:none;min-height:44px;max-height:140px;padding:.6rem;border:1px solid #e5e5e5;border-radius:.75rem}
      .composer button{padding:.6rem 1rem;border:1px solid #e5e5e5;border-radius:.75rem;background:white;cursor:default}
    </style>

    <div class="chat-wrap">
      <div class="chat-log" id="messages">
        <%= for m <- @messages do %>
          <div class={"row #{m.sender}"}>
            <div class={"bubble #{m.sender}"}><%= m.text %>
            </div>
          </div>
        <% end %>

        <%= if @typing do %>
          <div class="row assistant">
            <div class="bubble assistant" style="opacity:.75">typing…</div>
          </div>
        <% end %>
      </div>

      <form class="composer" phx-submit="send">
        <textarea name="text" placeholder="Type a message… (does nothing yet)"><%= @input %></textarea>
        <button type="submit">Send</button>
      </form>
    </div>
    """
  end
end
