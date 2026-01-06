#last time I used this was before August 23 2025, this might be deletable

from transformers import pipeline

ALL_UNKNOWN = "idk anything fam"
UNKNOWN_DEVICE = "idk the device"
UNKNOWN_ROOM = "idk the room"

def uncertain(guess):
    return guess["scores"][0] < 0.7

def is_unique_device(device, home_data):
    count = sum(device in apps for apps in home_data.values())
    return count == 1

def room_with_one_device(room, home_data):
    return len(home_data[room]) == 1

def guessAttribute(prompt, attribute_list, clf):
    guess = clf(prompt, candidate_labels=attribute_list, multi_label=False)
    print(guess)
    return guess

def room_for(device, home_data):
    for room, apps in home_data.items():
        if device in apps:
            return room


def parseCommand(prompt, home_data, clf):
    device_guess = guessAttribute(prompt, list(set().union(*home_data.values())), clf)
    room_guess = guessAttribute(prompt, list(set(home_data.keys())), clf)

    device_uncertain = uncertain(device_guess)
    room_uncertain = uncertain(room_guess)

    device = device_guess['labels'][0]
    room = room_guess['labels'][0]

    if device_uncertain and room_uncertain:
        return ALL_UNKNOWN

    elif room_uncertain:
        if is_unique_device(device, home_data):
            room = room_for(device, home_data)
        else:
            return UNKNOWN_ROOM
    
    elif device_uncertain:
        if room_with_one_device(room, home_data):
            device = next(iter(home_data[room]))
        else:
            return UNKNOWN_DEVICE

    if device not in home_data[room]:
        if is_unique_device(device, home_data):
            room = room_for(device, home_data)
        else:
            return f"There is no {device} in the {room}"

    return f"{device} in the {room}"


clf = pipeline("zero-shot-classification",
               model="MoritzLaurer/deberta-v3-large-zeroshot-v2.0")

home_data = {
    'bedroom': {'lamp', 'light', 'fan', 'noise maker', 'thermostat', 'hygrometer'},
    'kitchen': {'light', 'thermostat', 'hygrometer'},
    'office': {'light', 'fan', 'thermostat', 'hygrometer'}
}

while True:
    prompt = input("Enter command: ")
    response = parseCommand(prompt, home_data, clf)
    print(response)