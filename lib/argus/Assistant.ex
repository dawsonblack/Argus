defmodule Argus.Assistant do
  use GenServer

  alias Argus.Chat
  alias Argus.Chat.Message
  alias Argus.Assistant.CommandParsing

  @topic "chat:global"

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    Phoenix.PubSub.subscribe(Argus.PubSub, @topic)
    {:ok, state}
  end

  def handle_info({:user_message, message}, state) do
    Phoenix.PubSub.broadcast(Argus.PubSub, @topic, {:assistant_status, :typing})

    response = CommandParsing.parse_message(message)
    case Chat.create_message(%{sender: "assistant", modality: "typed", text: response}) do
      {:ok, reply} ->
        Phoenix.PubSub.broadcast(Argus.PubSub, @topic, {:assistant_message, reply})
      _ ->
        Phoenix.PubSub.broadcast(Argus.PubSub, @topic, {:assistant_status, :error})
    end

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}
end
