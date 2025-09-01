##CHANGEME Have not used this since before August 31, 2025

import requests
import json
from transformers import pipeline

def getConversationHistory(filename="conversation_history.json"):
    with open(filename, "r", encoding="utf-8") as f:
        return json.load(f)

def addToConversationHistory(message, role, filename="conversation_history.json"):
    data = getConversationHistory(filename)
    data.append({'role': role, 'content': str(message)})
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)


def callRasaAPI(model, prompt):
    payload = {"model": model, "prompt": prompt}
    headers = {"Content-Type": "application/json"}

    response = requests.post("http://localhost:5050/predict", data=json.dumps(payload), headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(response.status_code)
        return {"error": response.status_code, "message": response.text}


def determineAppliance(prompt):
    response = requests.post("http://localhost:8080/parse", json={"prompt": prompt})
    if response.status_code == 200:
        return response.json()
    else:
        return {"error": response.status_code, "message": response.text}


def promptLLM(prompt, system_context=None, message_history=None, model="llama3.2:3b-instruct-q4_K_M"):
    url = "http://localhost:11434/api/chat"

    messages = []
    if message_history:
        messages = message_history
    if system_context:
        messages.insert(0, {"role": "system", "content": system_context})

    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": model,
        "messages": messages,
        "stream": False
    }
    headers = {"Content-Type": "application/json"}

    response = requests.post(url, headers=headers, data=json.dumps(payload))
    if response.status_code == 200:
        return response.json()["message"]["content"]
    else:
        return {"error": response.status_code, "message": response.text}


RELATIVE_CLASSIFICATION_MODEL = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")

while True:
    prompt = input("> ")
    addToConversationHistory(prompt, "user")
    intent = callRasaAPI("intent", prompt.lower())['intent']['name']
    print(intent)

    if intent == "action" or intent == "information":
        device_data = determineAppliance(prompt)
        if response['status'] == "ok":
            payload = {'space': device_data['room'], 'appliance': device_data['device']}

            #if intent is action, get the write commands, call it commands, and add write as the command_type into the payload
            #else get the read commands, call it commands, and add read as the command_type into the payload
            command_data = callRasaAPI("write_command", prompt.lower())
            
            #if "static" not in commands[command_data['intent']['name']]['command']:
                #entities = command_data['entities']
                #payload['params'] = [entity['value'] for entity in entities if entity['entity'] == 'value']

            reply = f"You are asking about the {response['device']} in the {response['room']}. I don't have the ability to interact with appliances yet, but I know what you're asking about"
        else:
            reply = "There was an issue figuring out which appliance you are talking about"

    elif intent == "arithmetic":
        system_context = "You are part of a calculator. Take a math question and format it into an arithmetic expression that can be evaluated.\n"
        system_context += 'For example: "what is nine plus ten" -> "9+10"\n'
        system_context += 'Return ONLY the expression, do not evaluate it and do not say anything else'

        response = promptLLM(prompt, system_context)
        reply = eval(response)

    elif intent == "conversation":
        system_context = "You are a smart home system named Argus. Be friendly, helpful, and concise"
        message_history = getConversationHistory()[-20:]
        reply = promptLLM(prompt, system_context, message_history)

    else:
        reply = "Sorry, I couldn't make sense of what you said"

    print(reply)
    addToConversationHistory(reply, "assistant")