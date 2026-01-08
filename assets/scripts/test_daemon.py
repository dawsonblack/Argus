import sys
import json
import asyncio
from bleak import BleakClient

def ParseAndSendStateUpdate(mac, sender, data: bytearray, synchronous=False):
    if not isinstance(sender, str):
        sender = sender.uuid

    state_update = {
        "mac_address": mac,
        "uuid": sender,
        "data": data.hex()
    }

    if synchronous:
        json_state = {
            "synchronous_state_update": state_update
        }
    else:
        json_state = {
            "state_update": state_update
        }

    print(json.dumps(json_state), flush=True)

def notificationHandler(mac):
    def handleNotification(sender, data):
        ParseAndSendStateUpdate(mac, sender, data)
    return handleNotification


async def connectAndListen(mac_address, uuid, handshake, read):
    try:
        async with BleakClient(mac_address) as client:
            if not client.is_connected:
                return
            
            print(json.dumps({"connection": "connected", "mac_address": mac_address}), flush=True)

            if handshake and uuid:
                await client.write_gatt_char(uuid, bytearray(handshake), response=True)

            await client.start_notify(read, notificationHandler(mac_address))

            while True:
                line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
                try:
                    data = json.loads(line.strip())

                    if data["mac_address"] != mac_address:
                        continue

                    command = data.get("command")
                    uuid = data.get("uuid")
                    handshake = data.get("handshake")
                    synchronous = data.get("synchronous", False)

                    if handshake:
                        await client.write_gatt_char(uuid, bytearray(handshake), response=True)
                        await asyncio.sleep(0.1)  # brief delay if needed

                    if command == "read":
                        state = await client.read_gatt_char(uuid)
                        ParseAndSendStateUpdate(mac_address, uuid, state, synchronous)
                        continue

                    # Write command
                    await client.write_gatt_char(uuid, bytearray(command), response=True)

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
    uuid = initial_payload.get("uuid")
    handshake = initial_payload.get("command")
    read = initial_payload.get("read")
    asyncio.run(connectAndListen(mac_address, uuid, handshake, read))

main()

#{"command":[6,224,226,230,109,168,200,255,255],"mac_address":"BA38DF23-BA87-3204-BF7C-F63DCFDBBB1F","uuid":"90759319-1668-44da-9ef3-492d593bd1e5","read":"80C37F00-CC16-11E4-8830-0800200C9A66"}