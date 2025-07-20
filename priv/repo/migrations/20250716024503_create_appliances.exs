defmodule Argus.Repo.Migrations.CreateAppliances do
  use Ecto.Migration

  def change do
    create table(:appliances) do
      add :name, :string, null: false
      add :mac_address, :string, null: false
      add :slug, :string, null: false

      add :space_id, references(:spaces, on_delete: :nothing)
      add :home_id, references(:homes, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:appliances, [:space_id])
    create index(:appliances, [:home_id])

    create unique_index(:appliances, [:slug, :home_id],
      where: "space_id IS NULL",
      name: :unique_appliance_home_slug
    )
    create unique_index(:appliances, [:slug, :space_id],
      where: "home_id IS NULL",
      name: :unique_appliance_space_slug
    )
  end
end
