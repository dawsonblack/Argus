defmodule Argus.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :sender, :string
    field :modality, :string
    field :text, :string
    timestamps(updated_at: false, type: :utc_datetime_usec)
    #TODO: add an intent label
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:sender, :modality, :text])
    |> validate_required([:sender, :modality, :text])
    |> Argus.Slugger.maybe_generate_slug()
    |> unique_constraint(:slug)
    |> validate_inclusion(:modality, ["typed", "spoken"])
  end
end
