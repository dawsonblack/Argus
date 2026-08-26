defmodule Argus.DeviceCommunication.ZigbeeWorker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    port = Port.open({:spawn, "python assets/scripts/zigbee_daemon.py"}, [ #CHANGEME: usually "python3" for mac and "python" for windows
      :binary,
      :exit_status,
      {:line, 4096}
    ])

    Argus.Homes.list_appliances()
    |> Enum.filter(&(&1.protocol == "zigbee"))
    |> Enum.each(fn appliance ->
          Phoenix.PubSub.subscribe(Argus.PubSub, "appliance:#{appliance.mac_address}")
          Phoenix.PubSub.subscribe(Argus.PubSub, "appliance-sync:#{appliance.mac_address}")
    end)

    {:ok, %{port: port, connection: "connecting"}}
  end



  def handle_info({:send_command, command}, %{connection: "connected", port: port} = state) do
    IO.puts("ZIGBEE WORKER SENDING COMMAND TO APPLIANCE")

    payload = Jason.encode!(command) <> "\n"
    Port.command(port, payload)
    {:noreply, state}
  end

  def handle_info({:send_command, command}, %{connection: _connection} = state) do
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{command.mac_address}",
      {:error, "Zigbee coordinator is not connected"}
    )

    {:noreply, state}
  end

  def handle_info({_, {:data, {:eol, line}}}, state) do
    line
    |> Jason.decode!()
    |> handle_daemon_info(state)
  end

  def handle_info({_, {:exit_status, status}}, state) do
    IO.puts("ZIGBEE DAEMON HAS SHUT DOWN WITH STATUS #{status}")

    Argus.Homes.list_appliances()
    |> Enum.filter(&(&1.protocol == "zigbee"))
    |> Enum.each(fn appliance ->
          Phoenix.PubSub.broadcast_from(
            Argus.PubSub,
            self(),
            "appliance:#{appliance.mac_address}",
            {:connection, "disconnected"}
          )
    end)

    {:noreply, %{state | connection: "disconnected"}}
  end

  def handle_info(message, state) do
    IO.puts("ZIGBEE WORKER RECEIVED UNEXPECTED MESSAGE")
    IO.inspect(message)
    {:noreply, state}
  end

  def handle_daemon_info(%{"synchronous_state_update" => %{"mac_address" => mac_address} = state_update}, state) do
    IO.puts("ZIGBEE WORKER RECEIVED SYNCHRONOUS STATE UPDATE, SENDING TO TOPIC appliance-sync:#{mac_address}")
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance-sync:#{mac_address}",
      {:state_update, state_update}
    )
    {:noreply, state}
  end

  def handle_daemon_info(%{"state_update" => %{"mac_address" => mac_address} = state_update}, state) do
    IO.puts("ZIGBEE WORKER RECEIVED STATE UPDATE, SENDING TO TOPIC appliance:#{mac_address}")
    IO.inspect(state_update)
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{mac_address}",
      {:state_update, state_update}
    )
    {:noreply, state}
  end

  def handle_daemon_info(%{"connection" => connection}, state) do
    Argus.Homes.list_appliances()
    |> Enum.filter(&(&1.protocol == "zigbee"))
    |> Enum.each(fn appliance ->
          Phoenix.PubSub.broadcast_from(
            Argus.PubSub,
            self(),
            "appliance:#{appliance.mac_address}",
            {:connection, connection}
          )
    end)

    {:noreply, %{state | connection: connection}}
  end

  def handle_daemon_info(%{"error" => error_msg, "mac_address" => mac_address} = msg, state) do
    IO.puts("ZIGBEE DAEMON DEVICE SPECIFIC ERROR for #{mac_address}: #{error_msg}")
    IO.inspect(msg)
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{mac_address}",
      {:error, error_msg}
    )

    {:noreply, state}
  end

  def handle_daemon_info(%{"error" => error_msg}, state) do
    IO.puts("ZIGBEE DAEMON ERROR: #{error_msg}")

    Argus.Homes.list_appliances()
    |> Enum.filter(&(&1.protocol == "zigbee"))
    |> Enum.each(fn appliance ->
      Phoenix.PubSub.broadcast_from(
        Argus.PubSub,
        self(),
        "appliance:#{appliance.mac_address}",
        {:error, error_msg}
      )
    end)

    {:noreply, state}
  end

  def handle_daemon_info(message, state) do
    IO.puts("UNEXPECTED ZIGBEE DAEMON MESSAGE")
    IO.inspect(message)
    {:noreply, state}
  end
end
