defmodule Argus.Repo.Migrations.CreateApplianceCommands do
  use Ecto.Migration

  def change do
    create table(:appliance_commands) do
      add :name, :string, null: false
      add :protocol, :string, null: false
      add :command, :string, null: false
      add :channel, :string
      add :appliance_id, references(:appliances, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:appliance_commands, [:appliance_id])
  end
end
