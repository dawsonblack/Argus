defmodule Argus.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :sender, :string, null: false
      add :modality, :string, null: false
      add :text, :text, null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:messages, [:inserted_at])
  end
end
