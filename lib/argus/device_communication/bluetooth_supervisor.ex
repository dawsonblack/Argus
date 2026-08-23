defmodule Argus.DeviceCommunication.BluetoothSupervisor do
  use Supervisor

  def start_link(_arg) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    children =
      Argus.Homes.list_appliances()
      |> Enum.filter(&(&1.protocol == "bluetooth"))
      |> Enum.map(fn appliance ->
        %{
          id: {:bluetooth_device, appliance.id},
          start: {
            Argus.DeviceCommunication.BluetoothWorker,
            :start_link,
            [appliance]
          }
        }
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
