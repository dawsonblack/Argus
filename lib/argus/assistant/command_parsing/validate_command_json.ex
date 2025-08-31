defmodule Argus.Assistant.CommandParser.ValidateCommandJson do
  alias Argus.Assistant.Embeddings
  alias Argus.Homes
  import Argus.Homes

  def json_decode_or_nil(s) do
    case Jason.decode(s) do
      {:ok, json} -> json
      _ -> nil
    end
  end

  def maybe_put(nil, _k, _v), do: nil
  def maybe_put(map, k, v) do
    Map.put(map, k, v)
  end

  def ensure_valid_json_structure(nil), do: nil
  def ensure_valid_json_structure(command_json) do
    command_json =
      Map.new(command_json, fn {k, v} ->
        {
          k,
          if is_binary(v) do
            Slug.slugify(v)
          else
            v
          end

        } end)

    if Enum.all?(["room", "device", "command", "params"], &Map.has_key?(command_json, &1)) do
      command_json
    else
      nil #TODO: consider making this an error struct for better logging
    end
  end

  #TODO: if the space is nil then throwing that into a homes function will mess things up
  def ensure_valid_space(nil), do: nil
  def ensure_valid_space(%{"room" => nil} = command_json), do: command_json
  def ensure_valid_space(command_json) do
    home = command_json["home"]
    space_slug = command_json["room"]

    space =
      get_space_by_slug(home, space_slug) ||
        home
        |> list_spaces_in_home()
        |> Enum.map(fn %{slug: slug} -> slug end)
        |> closest_name_match(space_slug)
        |> case do
          [%{text: closest_slug}] -> get_space_by_slug(home, closest_slug)
          _ -> nil
        end

    Map.put(command_json, "room", space)
  end

  def ensure_valid_applince(nil), do: nil
  def ensure_valid_appliance(%{"room" => nil, "device" => nil}), do: nil
  def ensure_valid_appliance(%{"room" => nil} = command_json) do
    appliance_slug = command_json["device"]
    possible_appliances = list_appliances_in_home(command_json["home"])

    Enum.filter(possible_appliances, fn %Homes.Appliance{slug: slug} -> slug == appliance_slug end)
    |> case do
      [_first, _second | _even_more] ->
        nil
      [appliance] ->
        Map.put(command_json, "device", appliance)
      [] ->
        appliance =
          possible_appliances
          |> Enum.map(fn %{slug: slug} -> slug end)
          |> closest_name_match(appliance_slug)
          |> case do
            [] -> nil
            [%{text: closest_slug}] -> closest_slug
          end

        Map.put(command_json, "device", appliance)
        |> ensure_valid_appliance()
    end
  end

  def ensure_valid_appliance(%{"room" => space, "device" => nil} = command_json) do
    list_appliances_in_space(space)
    |> case do
      [_, _ | _] -> command_json
      [appliance] -> Map.put(command_json, "device", appliance)
      [] -> nil
    end
  end
  def ensure_valid_appliance(command_json) do
    space = command_json["room"]
    appliance_slug = command_json["device"]

    appliance =
      get_appliance_by_slug(space, appliance_slug) ||
          space
          |> list_appliances_in_space()
          |> Enum.map(fn %{slug: slug} -> slug end)
          |> closest_name_match(appliance_slug)
          |> case do
            [%{text: closest_slug}] -> get_appliance_by_slug(space, closest_slug)
            _ -> nil
          end
    Map.put(command_json, "device", appliance)
  end

  def ensure_valid_command(nil), do: nil
  def ensure_valid_command(%{"command" => nil} = command_json) do
    command_type = command_json["type"]

    case command_json["device"] do
      nil ->
        list_commands_of_type_in_space(command_json["room"], command_type)
      appliance ->
        list_commands_of_type_in_appliance(appliance, command_type)
    end
    |> case do
        [command] -> Map.put(command_json, "command", command)
        _ -> nil
       end
  end

  def ensure_valid_command(%{"device" => nil, "command" => command_name} = command_json) do
    command_type = command_json["type"]

    possible_commands = list_commands_of_type_in_space(command_json["room"], command_type)

    Enum.filter(possible_commands, fn %Homes.ApplianceCommand{name: name} -> name == command_name end)
    |> case do
      [_first, _second | _even_more] ->
        nil
      [command] ->
        Map.put(command_json, "command", command)
      [] ->
        command =
          possible_commands
          |> Enum.map(fn %{name: name} -> name end)
          |> closest_name_match(command_name)
          |> case do
            [] -> nil
            [%{text: closest_name}] -> closest_name
          end

        Map.put(command_json, "command", command)
        |> ensure_valid_appliance()
    end
  end

  def ensure_valid_command(%{"device" => appliance, "command" => command_name} = command_json) do
    command_type = command_json["type"]

    (get_appliance_command_by_name_and_type(appliance, command_name, command_type) ||
      appliance
      |> list_commands_of_type_in_appliance(command_type)
      |> Enum.map(fn %{name: name} -> name end)
      |> closest_name_match(command_name)
      |> case do
        [%{text: closest_name}] -> get_appliance_command_by_name_and_type(appliance, closest_name, command_type)
        _ -> nil
      end)

    |> case do
      nil -> nil
      command -> Map.put(command_json, "command", command)
    end
  end

  defp closest_name_match(candidates, name) do
    candidates
    |> Embeddings.embed()
    |> Embeddings.get_closest_embeddings(
        name
        |> Embeddings.embed()
        |> List.first()
        |> Map.get("embedding"),

        1, #max results
        0.80 #TODO: for this you may benefit from a higher relevance threshold than 0.6, experiment with it
      )
  end
end
