defmodule Argus.Repo.Migrations.CreateSpaces do
  use Ecto.Migration

  def change do
    create table(:spaces) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :home_id, references(:homes, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:spaces, [:home_id])

    create unique_index(:spaces, [:slug, :home_id])
  end
end
