import requests
import json

def promptPhi(prompt):
    url = "http://localhost:11434/api/generate"

    payload = {
        "model": "phi",
        "prompt": prompt,
        "options": {
            "temperature": 0.2,
            "stream": False
        }
    }

    response = requests.post(url, json=payload)

    lines = response.text.strip().split("\n")
    full_text = ""
    for line in lines:
        try:
            data = json.loads(line)
            full_text += data.get("response", "")
        except json.JSONDecodeError:
            continue

    return full_text.strip()


def determineIntent(user_input):
    prompt = f"""Classify the following user input into one of three categories:
1. action_command: requests to do something (e.g. turn on a light, set temperature)
2. info_request: asks for status (e.g. what’s the temperature?)
3. neither: includes chit-chat or comments (e.g. you’re cool, how are you?)

Respond ONLY with one of the three words above. Do not explain or elaborate.
Input: "{user_input}\""""
    return promptPhi(prompt)


def determineTargetAppliance(user_input):
    prompt = f"""You are a smart home assistant. Your job is to identify which device the user is referring to based on a list of devices. Pick the one that best matches the user's request.
    If none of the listed devices clearly match, respond with 5 for "None of the above".
Devices:
1. "noise maker" in the room "bedroom"
2. "overhead light" in the room "bedroom"
3. "fan" in the room "kitchen"
4. "lamp" in the room "office"
5. None of the above

Respond ONLY with the number of the matching device. For example, if the input is "Turn on the fan", you would respond with "3".
Input: {user_input}"""
    return promptPhi(prompt)

user_input = input("Enter user input: ")
intent = determineTargetAppliance(user_input)
print(f"Intent: {intent}")