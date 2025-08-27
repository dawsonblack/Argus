defmodule Argus.DeviceSupervisor do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children =
      Argus.Homes.list_appliances()
      |> Enum.map(fn appliance ->
        %{
          id: {:device, appliance.id},
          start: {Argus.DeviceWorker, :start_link, [appliance]}
        }
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_device_state(mac_address) do
    case Registry.lookup(Argus.DeviceRegistry, mac_address) do
      [{pid, _}] ->
        GenServer.call(pid, :get_state)

      [] ->
        %{}
    end
  end

end
