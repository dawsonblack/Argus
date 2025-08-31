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
      message = %{sender: "Dawson", modality: "typed", text: text}
      case Chat.create_message(message) do #TODO: Dawson shouldn't be hardcoded, find a way to get the user
        {:ok, _message} ->
          Phoenix.PubSub.broadcast(Argus.PubSub, @topic, {:user_message, message})
          {:noreply, assign(socket, messages: Chat.list_messages())}

        {:error, changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  def handle_info({:user_message, _message}, socket) do
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
      /* Layout */
      .chat-wrap{
        max-width:900px;
        margin:0 auto;
        height:100vh;
        display:flex;
        flex-direction:column;
        gap:0.75rem;
        padding:1rem;
        box-sizing:border-box;
      }
      .chat-log{
        flex:1;
        overflow:auto;
        background:#121212;                 /* dark card */
        border:1px solid #333;
        border-radius:12px;
        padding:16px;
        display:flex;
        flex-direction:column;
        gap:8px;
        box-shadow:0 2px 8px rgba(0,0,0,.3);
      }

      /* Rows & alignment */
      .row{display:flex; justify-content:flex-end;}
      .row.assistant{justify-content:flex-start;}

      /* Bubbles */
      .bubble{
        max-width:75%;
        padding:10px 14px;
        border-radius:14px;
        line-height:1.45;
        white-space:pre-line;
        background:#00c853;                 /* user bubble: Argus green */
        color:#000;                         /* readable on green */
        box-shadow:0 1px 3px rgba(0,0,0,.35);
        border: none;
      }
      .bubble.assistant{
        background:#1c1c1c;                 /* assistant bubble: dark card */
        color:#eee;
        border:1px solid #333;
        box-shadow:0 1px 3px rgba(0,0,0,.35);
      }

      /* Typing bubble (animated dots) */
      .bubble.assistant.typing{
        display:inline-flex;
        align-items:center;
        gap:6px;
        opacity:.85;
      }
      .typing .dot{
        width:6px; height:6px; border-radius:50%;
        background:#aaa;
        opacity:.5;
        animation: blink 1.2s infinite ease-in-out;
      }
      .typing .dot:nth-child(2){ animation-delay: .15s; }
      .typing .dot:nth-child(3){ animation-delay: .3s; }
      @keyframes blink{
        0%, 80%, 100% { transform: translateY(0); opacity:.4; }
        40% { transform: translateY(-2px); opacity:1; }
      }

      /* Composer (matches item-form inputs/buttons) */
      .composer{
        display:flex; gap:.5rem; align-items:flex-end;
        border:1px solid #333; border-radius:12px;
        background:#121212; padding:10px;
      }
      .composer textarea{
        flex:1; resize:none; min-height:44px; max-height:140px;
        padding:.6rem; background:#1c1c1c; color:#fff;
        border:1px solid #333; border-radius:8px;
        font:inherit;
        transition:border .2s ease, box-shadow .2s ease;
      }
      .composer textarea:focus{
        outline:none; border-color:#00c853; box-shadow:0 0 4px #00c85366;
      }
      .composer button{
        padding:.6rem 1rem; border:none; border-radius:8px;
        background:#00c853; color:#000; font-weight:600; cursor:pointer;
        transition:background-color .2s ease, transform .06s ease;
      }
      .composer button:hover{ background:#00b84d; }
      .composer button:active{ transform:translateY(1px); }
    </style>

    <div class="chat-wrap">
      <div class="chat-log" id="messages" phx-hook="ScrollBottom">
        <%= for m <- @messages do %>
          <div class={"row #{m.sender}"}>
            <div class={"bubble #{m.sender}"}><%= m.text %></div>
          </div>
        <% end %>

        <%= if @typing do %>
          <div class="row assistant">
            <div class="bubble assistant typing">
              <span class="dot"></span><span class="dot"></span><span class="dot"></span>
            </div>
          </div>
        <% end %>
      </div>

      <form class="composer" phx-submit="send">
        <textarea
          id="chat-textbox"
          name="text"
          placeholder="Type a message…"
          phx-hook="EnterToSend"><%= @input %></textarea>
        <button type="submit">Send</button>
      </form>
    </div>
    """
  end
end
