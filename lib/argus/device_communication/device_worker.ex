defmodule Argus.DeviceWorker do
  use GenServer

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
      |> Argus.CommandPipeline.create_command_payload("handshake")
      |> Map.put("read", "80C37F00-CC16-11E4-8830-0800200C9A66") #this needs to be retrieved from database
      |> Jason.encode!()
      |> then(&(&1 <> "\n"))
    Port.command(port, init_payload)

    # Subscribe to PubSub so this worker can receive commands
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
      {:ok, %{"status" => status, "mac_address" => mac}} ->
        #Logger.info("Device #{mac} is #{status}")
        {:noreply, state}

      # 3. Error report from Python
      {:ok, %{"error" => message, "mac_address" => mac}} ->
        #Logger.error("Device #{mac} error: #{message}")
        {:noreply, state}

      # Catch-all for anything else
      {:ok, other} ->
        #Logger.debug("Other message: #{inspect(other)}")
        {:noreply, state}

      # Malformed JSON
      {:error, err} ->
        #Logger.warning("Failed to decode BLE response: #{inspect(err)}")
        {:noreply, state}
    end
  end

  def handle_info({:state_update, _mac, %{} = _state_data}, state) do
    # Swallow self-broadcasts or handle them if needed
    {:noreply, state}
  end

  # def handle_call(:get_state, _from, state) do
  #   {:reply, state.appliance.state || %{}, state}
  # end
end
