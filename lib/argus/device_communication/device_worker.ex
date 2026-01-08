defmodule Argus.DeviceCommunication.DeviceWorker do
  use GenServer
  alias Argus.DeviceCommunication.CommandPipeline

  def start_link(appliance) do
    GenServer.start_link(__MODULE__, appliance, name: via(appliance.id))
  end

  defp via(id), do: {:via, Registry, {Argus.DeviceRegistry, id}}

  def init(appliance) do
    port = Port.open({:spawn, "python assets/scripts/test_daemon.py"}, [ #CHANGEME: usually "python3" for mac and "python" for windows
      :binary,
      :exit_status,
      {:line, 4096}
    ])

    IO.puts("HEY HEY HEY OVER HERE")
    IO.inspect(appliance)

    init_payload =
      appliance
      |> CommandPipeline.device_command_payload("handshake", "lifecycle") #TODO: what if this doesn't exist
      |> Map.put("read", "80c37f00-cc16-11e4-8830-0800200c9a66") #TODO: this needs to be retrieved from database not hardcoded
      |> Jason.encode!()
      |> then(&(&1 <> "\n"))
    Port.command(port, init_payload)

    Phoenix.PubSub.subscribe(Argus.PubSub, "appliance:#{appliance.mac_address}")

    {:ok, %{appliance: appliance, port: port, connection: "connected"}}
  end

  def handle_info({:send_command, _command}, %{connection: "disconnected"} = state) do
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{state.appliance.mac_address}",
      {:error, "Device is not connected"}
    )
    {:noreply, state}
  end

  def handle_info({:send_command, command}, %{port: port} = state) do
    IO.puts("DEVICE WORKER SENDING TO APPLIANCE")
    payload = Jason.encode!(command) <> "\n"
    Port.command(port, payload)
    {:noreply, state}
  end

  def handle_info({_, {:data, {:eol, line}}}, state) do
    line
    |> Jason.decode!()
    |> handle_daemon_info(state)
  end

  def handle_info({_, {:exit_status, _}}, %{appliance: appliance} = state) do
    IO.puts("DAEMON HAS SHUT DOWN")
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{appliance.mac_address}",
      {:connection, "disconnected"}
    )
    {:noreply, %{state | connection: "disconnected"}}
  end

  def handle_info(message, state) do
    IO.puts("DEVICE WORKER RECEIVED UNEXPECTED MESSAGE")
    IO.inspect(message)
    {:noreply, state}
  end

  def handle_daemon_info(%{"state_update" => %{} = state_update}, %{appliance: appliance} = state) do
    IO.puts("DEVICE WORKER RECEIVED STATE UPDATE, SENDING TO TOPIC appliance:#{appliance.mac_address}")
    IO.inspect({node(), self()}, label: "NODE/PID")
    IO.inspect(:erlang.nodes(), label: "CONNECTED NODES")
    IO.inspect(Process.whereis(Argus.PubSub), label: "Argus.PubSub PID")
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{appliance.mac_address}",
      {:state_update, state_update}
    )
    {:noreply, state}
  end

  def handle_daemon_info(%{"connection" => connection}, %{appliance: appliance} = state) do
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{appliance.mac_address}",
      {:connection, connection}
    )
    {:noreply, %{state | connection: connection}}
  end

  def handle_daemon_info(%{"error" => error_msg}, %{appliance: appliance} = state) do
    Phoenix.PubSub.broadcast_from(
      Argus.PubSub,
      self(),
      "appliance:#{appliance.mac_address}",
      {:error, error_msg}
    )
    {:noreply, state}
  end

  def handle_daemon_info(message, state) do
    IO.puts("UNEXPECTED DAEMON MESSAGE")
    IO.inspect(message)
    {:noreply, state}
  end
end
