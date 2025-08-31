defmodule Argus.Chat do
  import Ecto.Query, warn: false
  alias Argus.Chat.Message
  alias Argus.Repo

  alias Argus.Chat.Message

  def list_messages, do: Repo.all(Message)

  def get_message!(id), do: Repo.get!(Message, id)

  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  def message_changeset(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end
end
