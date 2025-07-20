defmodule Argus.Homes.Appliance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "appliances" do
    field :name, :string
    field :mac_address, :string
    field :slug, :string

    belongs_to :home, Argus.Homes.Home
    belongs_to :space, Argus.Homes.Space

    has_many :appliance_commands, Argus.Homes.ApplianceCommand

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(appliance, attrs) do
    appliance
    |> cast(attrs, [:name, :mac_address])
    |> validate_required([:name, :mac_address])
    |> Argus.Slugger.maybe_generate_slug()
    |> unique_constraint(:slug, name: :unique_appliance_home_slug)
    |> unique_constraint(:slug, name: :unique_appliance_space_slug)
  end
end
