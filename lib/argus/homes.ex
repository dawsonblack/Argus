defmodule Argus.Homes do
  @moduledoc """
  The Homes context.
  """

  import Ecto.Query, warn: false
  alias Argus.Repo

  alias Argus.Homes.Home
  alias Argus.Homes.Space
  alias Argus.Homes.Appliance
  alias Argus.Homes.ApplianceCommand


  def list_homes, do: Repo.all(Home)
  def list_appliances, do: Repo.all(Appliance)

  def get_home!(id), do: Repo.get!(Home, id)

  def get_home_by_slug(slug), do: Repo.get_by(Home, slug: slug)

  def get_space_by_slug(%Home{id: home_id}, slug), do: Repo.get_by(Space, home_id: home_id, slug: slug)

  def get_appliance_by_slug(%Home{id: home_id}, slug), do: Repo.get_by(Appliance, home_id: home_id, slug: slug)

  def get_appliance_by_slug(%Space{id: space_id}, slug), do: Repo.get_by(Appliance, space_id: space_id, slug: slug)

  def get_appliance_command_by_name(%Appliance{id: appliance_id}, name) do
    Repo.get_by(ApplianceCommand, appliance_id: appliance_id, name: name)
  end


  def create_home(attrs \\ %{}) do
    %Home{}
    |> Home.changeset(attrs)
    |> Repo.insert()
  end

  def create_space(home, attrs) do
    %Space{}
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:home, home)
    |> Space.changeset(attrs)
    |> Repo.insert()
  end

  def create_appliance(parent, attrs) do
    %Appliance{}
    |> Ecto.Changeset.change()
    |> maybe_put_assoc(parent)
    |> Appliance.changeset(attrs)
    |> Repo.insert()
  end

  def create_appliance_command(appliance, attrs) do
    attrs =
      attrs
      |> Map.update(:command, nil, fn val -> Jason.encode!(val) end)

    %ApplianceCommand{}
    |> ApplianceCommand.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:appliance, appliance)
    |> Repo.insert()
  end

  defp maybe_put_assoc(changeset, %Home{} = home) do
    Ecto.Changeset.put_assoc(changeset, :home, home)
  end
  defp maybe_put_assoc(changeset, %Space{} = space) do
    Ecto.Changeset.put_assoc(changeset, :space, space)
  end


  def update_home(%Home{} = home, attrs) do
    home
    |> Home.changeset(attrs)
    |> Repo.update()
  end


  def delete_home(%Home{} = home) do
    Repo.delete(home)
  end


  def home_changeset(%Home{} = home, attrs \\ %{}) do
    Home.changeset(home, attrs)
  end

  def space_changeset(%Space{} = space, attrs \\ %{}) do
    Space.changeset(space, attrs)
  end

  def appliance_changeset(%Appliance{} = appliance, attrs \\ %{}) do
    Appliance.changeset(appliance, attrs)
  end
end
