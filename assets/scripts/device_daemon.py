import sys
import json
import asyncio
from bleak import BleakClient

def ParseAndSendStateUpdate(mac, data: bytearray):
    data = data.hex()
    volume = int(data[0:2], 16)
    is_on = data[3] == "1"
    json_state = {
        "state_update": {
            "volume": volume,
            "power": "on" if is_on else "off"
        },
        "mac_address": mac
    }
    print(json.dumps(json_state), flush=True)

def notificationHandler(mac):
    def handleNotification(_, data):
        ParseAndSendStateUpdate(mac, data)
    return handleNotification


async def connectAndListen(mac_address, channel, handshake, read):
    try:
        async with BleakClient(mac_address) as client:
            if not client.is_connected:
                print(json.dumps({"error": "Connection failed", "mac_address": mac_address}), flush=True)
                return

            if handshake and channel:
                await client.write_gatt_char(channel, bytearray(handshake), response=True)

            await client.start_notify(read, notificationHandler(mac_address))

            while True:
                line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
                try:
                    data = json.loads(line.strip())

                    if data["mac_address"] != mac_address:
                        continue

                    command = data.get("command")
                    if command == "read":
                        state = await client.read_gatt_char(read)
                        ParseAndSendStateUpdate(mac_address, state)
                        continue

                    channel = data.get("channel")
                    handshake = data.get("handshake")

                    if handshake:
                        await client.write_gatt_char(channel, bytearray(handshake), response=True)
                        await asyncio.sleep(0.1)  # brief delay if needed

                    # Write command
                    await client.write_gatt_char(channel, bytearray(command), response=True)

                    # Optionally send back confirmation
                    #print(json.dumps({"status": "command_sent", "mac_address": mac_address}), flush=True)

                except Exception as e:
                    print(json.dumps({"error": str(e), "mac_address": mac_address}), flush=True)

    except Exception as e:
        print(json.dumps({"error": str(e), "mac_address": mac_address}), flush=True)


def decodeInitialPayload():
    line = sys.stdin.readline()
    data = json.loads(line.strip())
    return data

def main():
    initial_payload = decodeInitialPayload()
    mac_address = initial_payload.get("mac_address")
    channel = initial_payload.get("channel")
    handshake = initial_payload.get("command")
    read = initial_payload.get("read")
    asyncio.run(connectAndListen(mac_address, channel, handshake, read))

main()