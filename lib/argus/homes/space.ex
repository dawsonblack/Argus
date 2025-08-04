defmodule Argus.Homes.Space do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spaces" do
    field :name, :string
    field :slug, :string

    belongs_to :home, Argus.Homes.Home
    has_many :appliances, Argus.Homes.Appliance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(space, attrs) do
    space
    |> cast(attrs, [:name])
    |> validate_required([:name], message: "This field is required")
    |> Argus.Slugger.maybe_generate_slug()
    |> unique_constraint([:slug, :home_id])
  end
end
