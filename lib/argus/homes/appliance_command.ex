defmodule Argus.Homes.ApplianceCommand do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appliance_commands" do
    field :name, :string
    field :protocol, :string
    field :command, :string
    field :channel, :string

    belongs_to :appliance, Argus.Homes.Appliance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(appliance_command, attrs) do
    appliance_command
    |> cast(attrs, [:name, :protocol, :command, :channel])
    |> validate_required([:name, :protocol, :command])
  end
end
