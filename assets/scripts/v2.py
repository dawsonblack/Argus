import sys
import json
import asyncio
from bleak import BleakClient

async def run_once(mac, channel, handshake, command):
    try:
        print(f"Connecting to {mac}", flush=True)
        async with BleakClient(mac) as client:
            if not client.is_connected:
                raise Exception("Failed to connect")

            print(f"Connected. Writing handshake to {channel}", flush=True)
            await client.write_gatt_char(channel, handshake, response=True)

            await asyncio.sleep(0.1)

            print(f"Writing command to {channel}", flush=True)
            await client.write_gatt_char(channel, command, response=True)

            print(json.dumps({"status": "ok"}), flush=True)

    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)

def main():
    for line in sys.stdin:
        try:
            data = json.loads(line.strip())
            mac = data["mac_address"]
            channel = data["channel"]
            handshake = bytearray(data["handshake"])
            command = bytearray(data["command"])

            asyncio.run(run_once(mac, channel, handshake, command))
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)

main()