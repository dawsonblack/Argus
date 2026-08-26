import sys
import json
import asyncio
from types import SimpleNamespace
from bellows.zigbee.application import ControllerApplication


def send(payload):
    print(json.dumps(payload, default=str), flush=True)


def stateUpdate(cluster, data, synchronous=False):
    update = {
        "mac_address": str(cluster.endpoint.device.ieee),
        "endpoint": cluster.endpoint.endpoint_id,
        "cluster": cluster.cluster_id,
        "data": data
    }

    send({
        "synchronous_state_update" if synchronous else "state_update": update
    })


def attributeUpdated(cluster, attribute, value):
    stateUpdate(cluster, {
        "attribute": attribute,
        "value": value
    })


def clusterCommand(cluster, tsn, command, args):
    stateUpdate(cluster, {
        "command": command,
        "args": args
    })


cluster_listener = SimpleNamespace(
    attribute_updated=attributeUpdated,
    cluster_command=clusterCommand
)


def listenToDevice(device):
    for endpoint_id, endpoint in device.endpoints.items():
        if endpoint_id == 0:
            continue

        for cluster in list(endpoint.in_clusters.values()) + list(endpoint.out_clusters.values()):
            cluster.add_context_listener(cluster_listener)

async def sendCommand(app, data):
    device = next(
        device for device in app.devices.values()
        if str(device.ieee).lower() == data["mac_address"].lower()
    )

    endpoint = device.endpoints[data["endpoint"]]
    cluster = endpoint.in_clusters[data["cluster"]]

    response = await cluster.command(data["command"])

    stateUpdate(
        cluster,
        response,
        data.get("synchronous", False)
    )


async def connectAndListen():
    app = None

    try:
        app = await ControllerApplication.new(
            {
                "device": {
                    "path": "COM3",
                    "baudrate": 115200,
                },
                "database_path": "zigbee.db"
            },
            auto_form=False
        )

        for device in app.devices.values():
            listenToDevice(device)

        send({"connection": "connected"})

        while True:
            line = await asyncio.get_running_loop().run_in_executor(
                None,
                sys.stdin.readline
            )

            if not line:
                break

            try:
                data = json.loads(line)
                await sendCommand(app, data)

            except Exception as e:
                error = {"error": str(e)}

                if data.get("mac_address"):
                    error["mac_address"] = data["mac_address"]
                send(error)

    except Exception as e:
        send({"error": str(e)})

    finally:
        if app:
            await app.shutdown()


asyncio.run(connectAndListen())