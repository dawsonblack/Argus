import requests
import json

# Change this if you use a different port or model name
RASA_API_URL = "http://localhost:5050/model/parse"
# RASA_API_URL = "http://localhost:5050/model/parse?model=my_brain.tar.gz"  # optional for specific model

def parse(text):
    payload = {"text": text}
    headers = {"Content-Type": "application/json"}

    response = requests.post(RASA_API_URL, data=json.dumps(payload), headers=headers)

    if response.status_code == 200:
        data = response.json()
        print(data)
        #intent = data["intent"]["name"]
        #confidence = data["intent"]["confidence"]
        #print(f"Intent: {intent}")# (confidence: {confidence:.2f})")
    else:
        print(f"Error {response.status_code}: {response.text}")

while True:
    prompt = input("Enter prompt:\n")
    parse(prompt)

# rasa train nlu --nlu data/appliances_nlu.yml --fixed-model-name appliance_categorization_seed
# rasa run --enable-api --model models/ --port 5050