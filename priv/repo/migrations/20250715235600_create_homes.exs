defmodule Argus.Repo.Migrations.CreateHomes do
  use Ecto.Migration

  def change do
    create table(:homes) do
      add :name, :string, null: false
      add :address, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:homes, [:slug])
  end
end
