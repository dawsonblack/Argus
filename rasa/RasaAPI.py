from rasa.core.agent import Agent
from fastapi import FastAPI, Request, HTTPException
import uvicorn

# Load your trained model directly (can be a .tar.gz or folder)
intent_model = Agent.load("intent/models/intent_parser.tar.gz")
#write_command_model = Agent.load("write_commands/models/write_commands.tar.gz")

app = FastAPI()

@app.post("/predict")
async def predict(request: Request):
    body = await request.json()
    model = body.get('model')
    prompt = body.get('prompt')
    if model == 'intent':
        prediction = await intent_model.parse_message(prompt)
    elif model == 'write_command':
        raise HTTPException(status_code=501, detail="I can't determine write command intents yet")
        #prediction = await write_command_model.parse_message(prompt)
    elif model == 'read_command':
        raise HTTPException(status_code=501, detail="I can't determine read command intents yet")
    else:
        raise HTTPException(status_code=400, detail="model does not exist")
    return prediction

uvicorn.run(app, host="0.0.0.0", port=5050)


# source venv/bin/activate

# rasa run --enable-api --model models/intent_parser.tar.gz --port 5050
#rasa train nlu --config config.yml --nlu data/nlu.yml --out models --fixed-model-name intent_model2