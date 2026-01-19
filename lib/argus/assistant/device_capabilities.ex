defmodule Argus.Assistant.DeviceCapabilities do
  alias Argus.Homes

  def load_capability_embeddings(home_slug, command_type) do
    "priv/device_capabilities/#{home_slug}_#{command_type}.json"
    |> File.read!()
    |> Jason.decode!()
  end

  #TODO: have this function run on startup/whenever there is a change to the homes data tables
  def refresh_device_capabilities_export() do
    homes = Homes.list_homes()
    Enum.each(homes, fn %{id: id, slug: slug} ->
      Enum.each(["read", "write", "lifecycle"], fn command_type ->
        home_data = Homes.appliance_commands_map(id, command_type)
        generate_device_capabilities_export(home_data, slug, command_type)
        {slug, command_type}
      end)
    end)
  end

  defp generate_device_capabilities_export(home_data, home_slug, command_type) do
    File.write!(
      "priv/device_capabilities/#{home_slug}_#{command_type}.json",
      home_data
      |> device_capability_sentences()
      |> Argus.Assistant.Embeddings.embed()
      |> Jason.encode!(pretty: true)
    )
  end

  defp device_capability_sentences(home_data) do
    home_data
    |> Enum.flat_map(fn {room, devices} ->
      Enum.map(devices, fn {device, commands} ->
        cmd_list = join_with_and(commands)
        "The #{to_string(device)} in the #{to_string(room)} supports the commands: #{cmd_list}."
      end)
    end)
  end

  defp join_with_and([]), do: "This device does not support any commands"

  defp join_with_and([one]), do: to_string(one)

  defp join_with_and([one, two]), do: "#{to_string(one)} and #{to_string(two)}"

  defp join_with_and(items) when is_list(items) do
    parts = Enum.map(items, &to_string/1)
    init = Enum.drop(parts, -1)
    last = List.last(parts)
    Enum.join(init, ", ") <> ", and " <> last
  end
end
