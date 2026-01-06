import requests
import json
import requests, numpy as np


home = {
    "bedroom": {"lamp": ['on'],
                 "light": ['on', 'off', 'brightness'],
                 "fan": ['on', 'off', 'speed'],
                 "noise maker": ['on', 'off', 'volume']},

    "kitchen": {"light": ['on', 'off', 'brightness']},

    "office": {"light": ['on', 'off', 'brightness'],
               "fan": ['on', 'off', 'speed']}
}

def join_with_and(items: list[str]) -> str:
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]} and {items[1]}"
    return ", ".join(items[:-1]) + f", and {items[-1]}"

def generate_sentences(home_data: dict) -> list[str]:
    sentences = []
    for room, devices in home_data.items():
        for device, commands in devices.items():
            cmd_list = join_with_and(commands)
            sentence = f"The {device} in the {room} supports the commands: {cmd_list}."
            sentences.append(sentence)
    return sentences




URL = "http://localhost:11434/api/embed"
MODEL = "mxbai-embed-large"

def embed(texts):
    if isinstance(texts, str):
        texts = [texts]
    r = requests.post(URL, json={"model": MODEL, "input": texts})
    r.raise_for_status()
    return r.json()["embeddings"]  # list of vectors


def cosine(u, v) -> float:
    u = np.asarray(u, dtype=np.float32).ravel()
    v = np.asarray(v, dtype=np.float32).ravel()
    nu = np.linalg.norm(u)
    nv = np.linalg.norm(v)
    if nu == 0.0 or nv == 0.0:
        return 0.0
    return float(np.dot(u, v) / (nu * nv))

def getClosestEmbeddings(ref_data, target_emb, max_results=3, min_relevance=0.60):
    results = []
    for item in ref_data:
        relevance = cosine(item['embedding'], target_emb)
        if relevance < min_relevance:
            continue

        candidate = {"text": item['text'], "score": relevance}

        if len(results) < max_results:
            results.append(candidate)
        else:
            # find the current weakest match in results
            weakest_idx = min(range(len(results)), key=lambda i: results[i]["score"])
            if relevance > results[weakest_idx]["score"]:
                results[weakest_idx] = candidate
    return results

# embedded_device_data = []
# sentences = generate_sentences(home)
# print(sentences)
# for s in sentences:
#     embeddings = embed(s)
#     embedded_device_data.append({'embedding': embeddings, 'text': s})

# prompt = "Turn the flucker in the bedroom to 30"
# results = getClosestEmbeddings(embedded_device_data, embed(prompt))
# print(results)


system_message = """You are Argus's smart-home command parser.
Return ONLY valid JSON in this exact schema (no extra text, no code fences):
{
  "room": string|null,          // e.g., "bedroom"
  "device": string|null,        // e.g., "light"
  "command": string|null,       // e.g., "on"
  "params": array|null          // [] if none; numbers are numeric; relative change as strings "+N" or "-N"
}
Rules:
- Use ONLY devices/rooms/commands mentioned in the facts.
- If any field is missing or ambiguous, set it to null instead of guessing.
- If user requests a relative change, encode as "+N" or "-N" (strings). Absolute values are numbers.
- Do not add fields. Do not include comments. Do not wrap in code fences.
- Output must be a single JSON object and must parse with a strict JSON parser."""




"""<USER_TEXT>
---- END USER TEXT ----

CONTEXT (authoritative facts; use only these):
<FACT_1>
<FACT_2>
...
---- END FACTS ----

Examples of correct output:
{"room":"bedroom","device":"fan","command":"speed","params":[31]}
{"room":"office","device":"lamp","command":"brightness","params":["-10"]}
{"room":"bedroom","device":"light","command":"on","params":[]}
{"room":null,"device":"noise maker","command":"volume","params":[50]}

Never do this (invalid): 
- {"room":"bedroom"} Here's the JSON you asked for...
- ```json {...} ```
- {"room":"bedroom","device":"noise maker","command":"volume","params":[,]}"""





user_message = f"{prompt}\n---- END USER TEXT ----\n\n"

if len(results) > 0:
    user_message += "CONTEXT (authoritative facts; use only these):\n"
    for result in results:
        user_message += f"{result['text']}\n"
    user_message += "---- END FACTS ----\n\n"

user_message +="""Examples of correct output:
{"room":"bedroom","device":"fan","command":"speed","params":[31]}
{"room":"office","device":"lamp","command":"brightness","params":["-10"]}
{"room":"bedroom","device":"light","command":"on","params":[]}
{"room":null,"device":"noise maker","command":"volume","params":[50]}

Never do this (invalid): 
- {"room":"bedroom"} Here's the JSON you asked for...
- ```json {...} ```
- {"room":"bedroom","device":"noise maker","command":"volume","params":[,]}"""

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

# response = promptLLM(user_message, system_message)
# print(response)

# print("LKDJGVLKWJDBVLKWDS")
# r = requests.post(URL, json={"model": MODEL, "input": "hello there"})
# r.raise_for_status()
# print(r.json()["embeddings"])  # list of vectors




# # generate sentences for all devices and their possible commands
# # embed the sentences
# # embed the user prompt
# # find the most similar sentences
# # inject the user prompt and the sentences into the llm prompt template
# # call ollama with that prompt and the system context
# # make sure the json is legit
# # make an api call with it