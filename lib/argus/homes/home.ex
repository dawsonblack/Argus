defmodule Argus.Homes.Home do
  use Ecto.Schema
  import Ecto.Changeset

  schema "homes" do
    field :name, :string
    field :address, :string
    field :slug, :string

    has_many :spaces, Argus.Homes.Space
    has_many :appliances, Argus.Homes.Appliance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(home, attrs) do
    home
    |> cast(attrs, [:name, :address])
    |> validate_required([:name, :address])
    |> Argus.Slugger.maybe_generate_slug()
    |> unique_constraint(:slug)
  end
end
