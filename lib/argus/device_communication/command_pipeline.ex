defmodule Argus.DeviceCommunication.CommandPipeline do

  def read_from_device(mac_address) do
    Phoenix.PubSub.broadcast(
      Argus.PubSub,
      "appliance:#{mac_address}",
      {:send_command, %{command: "read", mac_address: mac_address}}
    )
  end

  def send_command(appliance, command_name, command_type, user_input \\ nil) do
    command = Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, command_type)

    payload = %{
      mac_address: appliance.mac_address,
      channel: command.channel,
      command:
        command.command
        |> Jason.decode!()
        |> rf_command(user_input)
    }

    Phoenix.PubSub.broadcast(
      Argus.PubSub,
      "appliance:#{appliance.mac_address}",
      {:send_command, payload}
    )
  end

  def command_call_payload(appliance, command_name, command_type, user_input \\ nil) do  #TODO: this is redundant code from send_command but it is used in device worker
    cmd = Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, command_type)
    rf_command =
      cmd.command
      |> Jason.decode!()
      |> rf_command(user_input)
    %{
      mac_address: appliance.mac_address,
      channel: cmd.channel,
      command: rf_command
    }
  end

  def rf_command(pipeline_steps, initial_value) when is_list(pipeline_steps) do #TODO: only allow for commands with one user input currently
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
