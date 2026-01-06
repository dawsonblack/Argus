#CHANGEME you can probably delete this, I think this is old code from when you explicitly connected to only one device.
#Last time using this code was likely before August 1, 2025

# defmodule Argus.DevicePort do
#   use GenServer

#   def start_link(_) do
#     GenServer.start_link(__MODULE__, nil, name: __MODULE__)
#   end

#   def send_command(command_map) do
#     GenServer.cast(__MODULE__, {:send, command_map})
#   end

#   @impl true
#   def init(_) do
#     port = Port.open({:spawn, "python3 assets/scripts/device_daemon.py"}, [:binary, :exit_status, {:line, 4096}])

#     {:ok, %{port: port}}
#   end

#   @impl true
#   def handle_cast({:send, command}, %{port: port} = state) do
#     payload = Jason.encode!(command) <> "\n"
#     Port.command(port, payload)
#     {:noreply, state}
#   end

#   @impl true
#   def handle_info({port, {:data, {:eol, line}}}, state) do
#     case Jason.decode(line) do
#       {:ok, %{"mac_address" => id, "event" => "state_update", "state" => state_data}} ->
#         Phoenix.PubSub.broadcast(Argus.PubSub, "appliance:#{id}", {:appliance_updated, state_data})

#       {:ok, other} ->
#         IO.inspect(other, label: "Other JSON message from device")

#       {:error, error} ->
#         IO.warn("JSON decode error: #{inspect(error)}")
#     end

#     {:noreply, state}
#   end

# end
