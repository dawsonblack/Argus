defmodule Argus.DeviceCommunication.DeviceWorker do
  use GenServer
  alias Argus.DeviceCommunication.CommandPipeline

  def start_link(appliance) do
    GenServer.start_link(__MODULE__, appliance, name: via(appliance.id))
  end

  defp via(id), do: {:via, Registry, {Argus.DeviceRegistry, id}}

  def init(appliance) do
    port = Port.open({:spawn, "python3 assets/scripts/device_daemon.py"}, [
      :binary,
      :exit_status,
      {:line, 4096}
    ])

    init_payload =
      appliance
      |> CommandPipeline.device_command_payload("handshake", "lifecycle") #TODO: what if this doesn't exist
      |> Map.put("read", "80C37F00-CC16-11E4-8830-0800200C9A66") #TODO: this needs to be retrieved from database
      |> Jason.encode!()
      |> then(&(&1 <> "\n"))
    Port.command(port, init_payload)

    Phoenix.PubSub.subscribe(Argus.PubSub, "appliance:#{appliance.mac_address}")

    {:ok, %{appliance: appliance, port: port}}
  end

  def handle_cast({:send_command, command}, %{port: port} = state) do
    payload = Jason.encode!(command) <> "\n"
    Port.command(port, payload)
    {:noreply, state}
  end

  def handle_info({:send_command, command}, state) do
    handle_cast({:send_command, command}, state)
  end

  def handle_info({_, {:data, {:eol, line}}}, %{appliance: appliance} = state) do
    case Jason.decode(line) do
      # 1. State update from device
      {:ok, %{"state_update" => update_map, "mac_address" => mac_address}} when is_map(update_map) ->
        Phoenix.PubSub.broadcast(
          Argus.PubSub,
          "appliance:#{appliance.mac_address}",
          {:state_update, mac_address, update_map}
        )
        {:noreply, state}

      # 2. Connection status
      {:ok, %{"status" => _status, "mac_address" => _mac}} ->
        {:noreply, state}

      # 3. Error report from Python
      {:ok, %{"error" => _message, "mac_address" => _mac}} ->
        {:noreply, state}

      # Catch-all for anything else
      {:ok, _other} ->
        {:noreply, state}

      # Malformed JSON
      {:error, _err} ->
        {:noreply, state}
    end
  end

  def handle_info({:state_update, _mac, %{} = _state_data}, state) do
    # Swallow self-broadcasts or handle them if needed
    {:noreply, state}
  end
end
