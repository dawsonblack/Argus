import sys
import json
import asyncio
from enum import Enum

import zhaquirks

from zigpy.zcl import AttributeReportedEvent

from zha.application.gateway import Gateway
from zha.application.helpers import (
    CoordinatorConfiguration,
    QuirksConfiguration,
    ZHAConfiguration,
    ZHAData,
)

last_states = {}


def jsonValue(value):
    if value is None:
        return None

    if isinstance(value, (str, int, float, bool)):
        return value

    if isinstance(value, Enum):
        return jsonValue(value.value)

    if isinstance(value, bytes):
        return value.hex()

    if isinstance(value, (list, tuple)):
        return [jsonValue(item) for item in value]

    if isinstance(value, dict):
        return {
            str(key): jsonValue(item)
            for key, item in value.items()
        }

    return str(value)


def send(payload):
    print(
        json.dumps(payload),
        flush=True
    )


def attributeReported(event):
    value = jsonValue(event.value)

    key = (
        str(event.device_ieee),
        event.endpoint_id,
        event.cluster_id,
        event.attribute_id
    )

    if last_states.get(key) == value:
        return

    last_states[key] = value

    send({
        "state_update": {
            "mac_address": str(event.device_ieee),
            "endpoint": event.endpoint_id,
            "cluster": event.cluster_id,
            "data": {
                "attribute": event.attribute_id,
                "value": value
            }
        }
    })


def listenToCluster(cluster):
    cluster.on_event(
        AttributeReportedEvent.event_type,
        attributeReported
    )


def listenToDevice(device):
    for endpoint_id, endpoint in device.endpoints.items():
        if endpoint_id == 0:
            continue

        for cluster in endpoint.in_clusters.values():
            listenToCluster(cluster)

        for cluster in endpoint.out_clusters.values():
            listenToCluster(cluster)


def listenToDevices(app):
    for device in app.devices.values():
        listenToDevice(device)


def findDevice(app, mac_address):
    return next(
        device
        for device in app.devices.values()
        if str(device.ieee).lower() == mac_address.lower()
    )


def findCluster(device, endpoint_id, cluster_id):
    endpoint = device.endpoints[endpoint_id]

    if cluster_id in endpoint.in_clusters:
        return endpoint.in_clusters[cluster_id]

    if cluster_id in endpoint.out_clusters:
        return endpoint.out_clusters[cluster_id]

    raise ValueError(
        f"Cluster {cluster_id} not found on endpoint {endpoint_id}"
    )


async def sendCommand(app, data):
    device = findDevice(
        app,
        data["mac_address"]
    )

    cluster = findCluster(
        device,
        data["endpoint"],
        data["cluster"]
    )

    command_type = data.get("command_type", "write")

    if command_type == "read":
        attributes = data["command"]

        if not isinstance(attributes, list):
            attributes = [attributes]

        response = await cluster.read_attributes(
            attributes
        )

        send({
            "synchronous_state_update"
            if data.get("synchronous", False)
            else "state_update": {
                "mac_address": str(device.ieee),
                "endpoint": data["endpoint"],
                "cluster": data["cluster"],
                "data": jsonValue(response)
            }
        })

        return

    response = await cluster.command(
        data["command"]
    )

    if data.get("synchronous", False):
        send({
            "synchronous_state_update": {
                "mac_address": str(device.ieee),
                "endpoint": data["endpoint"],
                "cluster": data["cluster"],
                "data": jsonValue(response)
            }
        })


async def stdinLoop(app):
    while True:
        line = await asyncio.get_running_loop().run_in_executor(
            None,
            sys.stdin.readline
        )

        if not line:
            return

        data = None

        try:
            data = json.loads(line)

            await sendCommand(
                app,
                data
            )

        except Exception as e:
            error = {
                "error": str(e)
            }

            if data and data.get("mac_address"):
                error["mac_address"] = data["mac_address"]

            send(error)


async def connectAndListen():
    gateway = None

    try:
        config = ZHAData(
            config=ZHAConfiguration(
                coordinator_configuration=CoordinatorConfiguration(
                    path="COM3",
                    baudrate=115200,
                    radio_type="ezsp",
                    flow_control=None,
                ),
                quirks_configuration=QuirksConfiguration(
                    enabled=True,
                    setup_function=zhaquirks.setup,
                ),
            ),
            zigpy_config={
                "database_path": "zigbee.db",
            },
        )

        gateway = await Gateway.async_from_config(
            config
        )

        await gateway.async_initialize()
        await gateway.async_initialize_devices_and_entities()

        app = gateway.application_controller

        listenToDevices(app)

        send({
            "connection": "connected"
        })

        await stdinLoop(app)

    except Exception as e:
        send({
            "error": str(e)
        })

    finally:
        if gateway:
            await gateway.shutdown()


asyncio.run(connectAndListen())