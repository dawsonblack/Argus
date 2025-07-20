defmodule Argus.CommandPipeline do

  def read_from_device(mac_address) do
    Phoenix.PubSub.broadcast(
      Argus.PubSub,
      "appliance:#{mac_address}",
      {:send_command, %{command: "read", mac_address: mac_address}}
    )
  end

  def send_command(appliance, command_name, user_input \\ nil) do
    Phoenix.PubSub.broadcast(
      Argus.PubSub,
      "appliance:#{appliance.mac_address}",
      {:send_command, create_command_payload(appliance, command_name, user_input)}
    )
  end

  def create_command_payload(appliance, command_name, user_input \\ nil) do
    cmd = Argus.Homes.get_appliance_command_by_name(appliance, command_name)

    command =
      cmd.command
      |> Jason.decode!()
      |> generate_command(user_input)

    %{
      mac_address: appliance.mac_address,
      channel: cmd.channel,
      command: command
    }
  end

  defp generate_command(pipeline_steps, initial_value) when is_list(pipeline_steps) do
    Enum.reduce(pipeline_steps, initial_value, fn
      [step | args], acc ->
        apply_pipeline_step(step, [acc] ++ args)
    end)
  end


  defp apply_pipeline_step(op, args) when is_list(args) do
    case Map.fetch(ops(), to_string(op)) do
      {:ok, function} -> function.(args)
      :error -> raise ArgumentError, "Unknown operation: #{inspect(op)}"
    end
  end

  defp ops do
    %{
      "static"   => fn [_, b] -> b end,
      "add"      => fn [a, b] -> a + b end,
      "sub"      => fn [a, b] -> a - b end,
      "mul"      => fn [a, b] -> a * b end,
      "div"      => fn [a, b] -> div(a, b) end,
      "hex"      => fn [a]    -> Integer.to_string(a, 16) end,
      "max"      => fn [a, b] -> max(a, b) end,
      "min"      => fn [a, b] -> min(a, b) end,
      "list"     => fn args   -> args end,
      "reverse"  => fn args   -> Enum.reverse(args) end,
      "append"   => fn [a, b] -> a ++ [b] end,
      "prepend"  => fn [a, b] -> b ++ [a] end,
      "bytearr"  => fn [a]    -> :erlang.list_to_binary(a) end
    }
  end

@moduledoc """


{
  "parameters": ["value"],
  "value_pipeline": {
    "min": 1,
    "max": 100,
    "+": 1,
    "hex": nil,
    [0x01].append: nil,
    bytearray: nil
  }
}

"""
end
