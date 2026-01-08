defmodule Argus.Assistant do
  use GenServer

  alias Argus.Chat
  alias Argus.Assistant.CommandParsing
  alias Argus.DeviceCommunication.CommandPipeline

  @topic "chat:global"

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(state) do
    Phoenix.PubSub.subscribe(Argus.PubSub, @topic)
    {:ok, state}
  end

  def handle_info({:user_message, message}, state) do
    Phoenix.PubSub.broadcast_from(Argus.PubSub, self(), @topic, {:assistant_status, :typing})

    response = CommandParsing.parse_message(message[:text])

    reply =
    case response do
      {_, nil} ->
       "Something went wrong" #TODO: this has to do with json validation, have a better message for this

      {intent, command_json} when intent in [:action, :information] ->
        appliance = command_json["device"]
        command_name = command_json["command"].name
        command_type = if intent == :action, do: "write", else: "read"

        case intent do
          :action ->
            CommandPipeline.write_payload(appliance, command_name, command_type) |> CommandPipeline.send_command_to_device()
        end

        send_command = Task.async(fn ->
                                    CommandPipeline.read_payload(appliance, command_name)
                                    |> CommandPipeline.send_command_to_device_synchronously()
                                    |> CommandPipeline.interpret_read(
                                        Argus.Homes.get_appliance_command_by_name_and_type(appliance, command_name, "read").command
                                    )
                                  end)

        delay_message = Task.async(
          fn ->
            :timer.sleep(2000)
            case Chat.create_message(%{sender: "assistant", modality: message[:modality], text: "One sec..."}) do
              {:ok, _} ->
                Phoenix.PubSub.broadcast_from(Argus.PubSub, self(), @topic, {:assistant_status, :still_waiting})
            end
          end)

        send_command_result = Task.await(send_command, 11_000)

        case Task.yield(delay_message, 0) do
          nil -> Task.shutdown(delay_message, :brutal_kill)
          {:ok, _val} -> :ok
          {:exit, _} -> :ok
        end

        case send_command_result do
          {:state_update, _, _} ->
            "Request completed"
          :timeout ->
            "Request timed out"
          _ ->
            "An error occured. Please try again."
        end

      {_, reply} -> reply
    end

    case Chat.create_message(%{sender: "assistant", modality: message[:modality], text: reply}) do
      {:ok, reply} ->
        Phoenix.PubSub.broadcast_from(Argus.PubSub, self(), @topic, {:assistant_message, reply})
      _other ->
        Phoenix.PubSub.broadcast_from(Argus.PubSub, self(), @topic, {:assistant_status, :error})
    end

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}
end
