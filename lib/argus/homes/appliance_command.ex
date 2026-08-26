defmodule Argus.Homes.ApplianceCommand do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appliance_commands" do
    field :name, :string
    field :command_type, :string
    field :command, :string
    field :uuid, :string
    field :cluster, :integer
    field :endpoint, :integer

    belongs_to :appliance, Argus.Homes.Appliance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(appliance_command, attrs) do
    appliance_command
    |> cast(attrs, [:name, :command_type, :command, :uuid, :cluster, :endpoint])
    |> validate_required([:name, :command_type, :command])
  end
end
