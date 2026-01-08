defmodule Argus.DeviceCommunication.CommandPipeline do

  def write_payload(appliance, command_name, command_type, user_input \\ nil) do
    cmd = Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, command_type)

    %{
      mac_address: appliance.mac_address,
      uuid: cmd.uuid,
      command:
        cmd.command
        |> Jason.decode!()
        |> rf_command(user_input)
    }
  end

  def read_payload(appliance, command_name) do
    cmd = Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, "read")

    %{
      mac_address: appliance.mac_address,
      uuid: cmd.uuid,
      command: "read"
    }
  end

  def interpret_read({:state_update, %{"data" => data}}, command) do
    command
    |> Jason.decode!()
    |> rf_command(data)
  end

  def interpret_read(response, _command), do: response

  def send_command_to_device(payload) do
    IO.puts("SEND COMMAND CALLED")
    IO.inspect(payload)
    topic = "appliance:#{payload.mac_address}"
    #:ok = Phoenix.PubSub.subscribe(Argus.PubSub, topic)

    :ok = Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      topic,
      {:send_command, payload}
    )
  end

  def send_command_to_device_synchronously(payload) do
    IO.puts("SEND COMMAND SYNCHRONOUSLY CALLED")
    IO.inspect(payload)
    topic = "appliance-sync:#{payload.mac_address}"
    :ok = Phoenix.PubSub.subscribe(Argus.PubSub, topic)

    :ok = Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      topic,
      {:send_command, payload
                      |> Map.put(:synchronous, true)}
    )

    response =
      receive do
        msg -> msg
      after
        5000 -> :timeout
      end

    Phoenix.PubSub.unsubscribe(Argus.PubSub, topic)
    response
  end

  def device_command_payload(appliance, command_name, command_type, user_input \\ nil) do #TODO: get rid of this and replace it in device worker
    cmd = Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, command_type)
    rf_command =
      cmd.command
      |> Jason.decode!()
      |> rf_command(user_input)
    %{
      mac_address: appliance.mac_address,
      uuid: cmd.uuid,
      command: rf_command
    }
  end

  #TODO: rename this to also describe when the command column is interpreting a read repsonse
  defp rf_command(pipeline_steps, initial_value) when is_list(pipeline_steps) do #TODO: only allow for commands with one user input currently
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
      "static"   => fn [_, b]    -> b end,

      "add"      => fn [a, b]    -> a + b end,
      "sub"      => fn [a, b]    -> a - b end,
      "mul"      => fn [a, b]    -> a * b end,
      "div"      => fn [a, b]    -> div(a, b) end,

      "gt"       => fn [a, b]    -> a > b end,
      "lt"       => fn [a, b]    -> a < b end,
      "eq"       => fn [a, b]    -> a == b end,

      "and"      => fn [a, b]    -> a and b end,
      "or"       => fn [a, b]    -> a or b end,
      "not"      => fn [a]       -> not a end,

      "hex"      => fn [a]       -> Integer.to_string(a, 16) end,
      "int"      => fn [a, b]    -> String.to_integer(a, b) end,
      "max"      => fn [a, b]    -> max(a, b) end,
      "min"      => fn [a, b]    -> min(a, b) end,

      "list"     => fn args      -> args end,
      "reverse"  => fn args      -> Enum.reverse(args) end,
      "append"   => fn [a, b]    -> a ++ [b] end,
      "prepend"  => fn [a, b]    -> b ++ [a] end,
      "slice"    => fn [a, b, c] -> Enum.slice(a, b..c) end,

      "substr"   => fn [a, b, c] -> String.slice(a, b, c) end,
      "charat"   => fn [a, b]    -> String.at(a, b) end,

      "bytearr"  => fn [a]       -> :erlang.list_to_binary(a) end,
      "ifelse"   => fn [a, b, c] -> if a, do: b, else: c end
    }
  end
end
