defmodule Argus.Repo.Migrations.CreateApplianceCommands do
  use Ecto.Migration

  def change do
    create table(:appliance_commands) do
      add :name, :string, null: false
      add :command_type, :string, null: false
      add :protocol, :string, null: false
      add :command, :string, null: false
      add :uuid, :string
      add :appliance_id, references(:appliances, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:appliance_commands, [:appliance_id])
    create constraint(:appliance_commands, :command_type_valid, check: "command_type IN ('read', 'write', 'lifecycle')")
  end
end
