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

  def list_spaces_in_home(%Home{id: home_id}) do
    Space
    |> where([s], s.home_id == ^home_id)
    |> Repo.all()
  end

  def list_appliances_in_space(%Space{id: space_id}) do
    Appliance
    |> where([a], a.space_id == ^space_id)
    |> Repo.all()
  end

  def list_commands_of_type_in_appliance(%Appliance{id: appliance_id}, command_type) do
    ApplianceCommand
    |> where([c], c.appliance_id == ^appliance_id and c.command_type == ^command_type)
    |> Repo.all()
  end

  def list_appliances_in_home(%Home{id: home_id}) do
    from(a in Appliance,
      join: s in Space, on: s.id == a.space_id,
      where: s.home_id == ^home_id,
      select: a
    )
    |> Repo.all()
  end

  def list_commands_of_type_in_space(%Space{id: space_id}, command_type) do
    from(c in ApplianceCommand,
      join: a in Appliance, on: a.id == c.appliance_id,
      where: a.space_id == ^space_id and c.command_type == ^command_type
    )
    |> Repo.all()
  end

  def get_home!(id), do: Repo.get!(Home, id)

  def get_home_by_slug(slug), do: Repo.get_by(Home, slug: slug)

  def get_space_by_slug(%Home{id: home_id}, slug), do: Repo.get_by(Space, home_id: home_id, slug: slug)

  def get_appliance_by_slug(%Home{id: home_id}, slug), do: Repo.get_by(Appliance, home_id: home_id, slug: slug)

  def get_appliance_by_slug(%Space{id: space_id}, slug), do: Repo.get_by(Appliance, space_id: space_id, slug: slug)

  def get_appliance_command_by_name_and_type(%Appliance{id: appliance_id}, name, command_type) do
    Repo.get_by(ApplianceCommand, appliance_id: appliance_id, name: name, command_type: command_type)
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
    case attrs[:command] do
      nil -> attrs
      command -> Map.put(attrs, :command, Jason.encode!(command))
    end

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

  def update_space(%Space{} = space, attrs) do
    space
    |> Space.changeset(attrs)
    |> Repo.update()
  end

  def delete_home(%Home{} = home) do
    Repo.delete(home)
  end

  def delete_space(%Space{} = space) do
    Repo.delete(space)
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

  def appliance_commands_struct(home_id, command_type) do
    from(s in Space,
      where: s.home_id == ^home_id,
      join: a in assoc(s, :appliances),
      join: c in assoc(a, :appliance_commands),
      where: c.command_type == ^command_type,
      select: {s.slug, a.slug, c.name}
    )
    |> Repo.all()
    |> Enum.group_by(fn {space, _, _} -> space end)
    |> Enum.map(fn {space, triples} ->
      devices =
        triples
        |> Enum.group_by(fn {_, appliance, _} -> appliance end,
                         fn {_, _, cmd} -> cmd end)
        |> Enum.map(fn {appliance, cmds} -> {appliance, Enum.uniq(cmds)} end)
        |> Map.new()

      {space, devices}
    end)
    |> Map.new()
  end
end
