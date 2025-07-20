import asyncio
from bleak import BleakClient
import sys
import json

#DEVICE_ID = "E0:E2:E6:6D:A8:CA" #windows
DEVICE_ID = "BA38DF23-BA87-3204-BF7C-F63DCFDBBB1F" #mac
CHAR_WRITE = "90759319-1668-44da-9ef3-492d593bd1e5"
CHAR_READ = "80C37F00-CC16-11E4-8830-0800200C9A66"

handshake_1 = bytearray([0x06, 0xE0, 0xE2, 0xE6, 0x6D, 0xA8, 0xC8, 0xFF, 0xFF])
handshake_2 = bytearray([0x07])
turn_on = bytearray([0x02, 0x01])
turn_off = bytearray([0x02, 0x00])

def parse_notification(data: bytearray):
    data = data.hex()
    volume = int(data[0:2], 16)
    is_on = data[3] == "1"
    json_state = {
        "type": "state_update",
        "volume": volume,
        "state": "on" if is_on else "off"
    }
    print(json.dumps(json_state), flush=True)


async def main():
    async with BleakClient(DEVICE_ID) as client:
        await client.write_gatt_char(CHAR_WRITE, handshake_1, response=True)

        def handle_notification(sender, data):
            parse_notification(data)
        await client.start_notify(CHAR_READ, handle_notification)
        print("Bluetooth connection established with noise maker")


        # Command loop
        while True:
            line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
            line = line.strip()

            if line == "on":
                await client.write_gatt_char(CHAR_WRITE, turn_on, response=True)
            elif line == "off":
                await client.write_gatt_char(CHAR_WRITE, turn_off, response=True)
            elif line.isdigit():
                value = int(line)
                hexval = max(0, min(99, value - 1)) + 1  # clamp between 1 and 100
                await client.write_gatt_char(CHAR_WRITE, bytearray([0x01, hexval]), response=True)
            elif line == "read":
                value = await client.read_gatt_char(CHAR_READ)
                parse_notification(value)
            elif line == "quit":
                print("Exiting...")
                break

asyncio.run(main())






# from bleak import BleakScanner

# async def scan():
#     devices = await BleakScanner.discover()
#     for d in devices:
#         print(d)

# asyncio.run(scan())