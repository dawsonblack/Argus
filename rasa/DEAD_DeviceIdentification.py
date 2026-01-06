# pip install sentence-transformers rapidfuzz
from typing import Dict, Set, Tuple, Any, List, Optional
from sentence_transformers import SentenceTransformer
from rapidfuzz import process, fuzz
import numpy as np
import random
import re
from collections import defaultdict

Embedder = SentenceTransformer("all-MiniLM-L6-v2")  # swap later if desired

# ---------- Types ----------
# home_data: Dict[str, Set[str]]  # room -> {devices}
# NLU state is an immutable dict you pass around & replace with returned copies.

def empty_state() -> Dict[str, Any]:
    return {
        "learned_syns": defaultdict(set),  # canonical_device -> {synonyms}
        "device_syns": defaultdict(set),   # canonical_device -> {synonyms} (built per inventory)
        "rooms": set(),                    # current room set
        "devices": set(),                  # current device set
        "knn_vecs": np.zeros((0, 384)),    # embeddings matrix
        "knn_labels": [],                  # [(device, room)]
        "examples": []                     # [(utterance, device, room)]
    }

# ---------- Pure helpers ----------
def is_unique_device(device: str, home_data: Dict[str, Set[str]]) -> bool:
    return sum(device in apps for apps in home_data.values()) == 1

def room_for(device: str, home_data: Dict[str, Set[str]]) -> Optional[str]:
    for room, apps in home_data.items():
        if device in apps:
            return room
    return None

def room_with_one_device(room: str, home_data: Dict[str, Set[str]]) -> bool:
    return len(home_data.get(room, set())) == 1

def _flatten_syns(device_syns: Dict[str, Set[str]]) -> Dict[str, str]:
    # term -> canonical
    return {term: canon for canon, syns in device_syns.items() for term in syns | {canon}}

# ---------- Inventory reload (pure) ----------
def reload_inventory(home_data: Dict[str, Set[str]], state: Dict[str, Any]) -> Dict[str, Any]:
    rooms = set(home_data.keys())
    devices = set().union(*home_data.values()) if home_data else set()
    # Build device_syns from learned_syns + canonical names
    device_syns = defaultdict(set)
    for d in devices:
        syns = set([d])
        syns |= state["learned_syns"].get(d, set())
        device_syns[d] = syns

    # Synthetic utterances aligned to current inventory (commands + info)
    templates = [
        "turn on the {device} in the {room}",
        "turn off the {device} in the {room}",
        "switch the {device} on in the {room}",
        "switch the {device} off in the {room}",
        "what's the status of the {device} in the {room}",
        "is the {device} on in the {room}",
        "which room has the {device}",
        "where is the {device}",
        "{room} {device}",                  # terse
        "the {device} in the {room}",       # noun phrase
        "in the {room}, the {device}"       # prepositional
    ]
    examples: List[Tuple[str, str, str]] = []
    for room, apps in home_data.items():
        for d in apps:
            # include up to 2 learned synonyms if present
            syns = sorted(device_syns.get(d, {d}))
            picks = {d} | set(random.sample(syns, k=min(2, max(0, len(syns)-1))))
            for t in templates:
                for dv in picks:
                    txt = t.format(device=dv, room=room)
                    examples.append((txt, d, room))

    # Build k-NN memory
    vecs = Embedder.encode([e[0] for e in examples]) if examples else np.zeros((0, 384))
    new_state = {
        **state,
        "rooms": rooms,
        "devices": devices,
        "device_syns": device_syns,
        "examples": examples,
        "knn_vecs": np.array(vecs),
        "knn_labels": [(d, r) for (_, d, r) in examples],
    }
    return new_state

# ---------- Parsing (pure) ----------
def parse_slots(text: str, home_data: Dict[str, Set[str]], state: Dict[str, Any]) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """
    Returns (result, state) where result is:
      {"status":"ok","device":d,"room":r,"confidence":float}  OR
      {"status":"ask","message":...}                         OR
      {"status":"error","message":...}
    State is unchanged (pure) – learning happens via learn_feedback.
    """
    text_l = text.lower()

    # 1) Lexical hit: devices
    flat = _flatten_syns(state["device_syns"])
    dev_guess, dev_score = (None, 0)
    if flat:
        # exact substring first
        for term, canon in flat.items():
            if term in text_l:
                dev_guess, dev_score = canon, 100
                break
        # fuzzy if no exact
        if not dev_guess:
            match = process.extractOne(text_l, list(flat.keys()), scorer=fuzz.WRatio)
            if match:
                term, score, _ = match
                dev_guess, dev_score = flat[term], score

    # 2) Lexical hit: rooms
    room_guess, room_score = (None, 0)
    if state["rooms"]:
        # “in the bedroom” heuristic
        for r in state["rooms"]:
            if f"in the {r}" in text_l or f"{r} " in text_l:
                room_guess, room_score = r, 95
                break
        if not room_guess:
            match = process.extractOne(text_l, list(state["rooms"]), scorer=fuzz.WRatio)
            if match:
                rterm, rscore, _ = match
                room_guess, room_score = rterm, rscore

    # 3) Semantic k-NN backstop (only if weak lexical evidence)
    kd, kr, ks = (None, None, 0.0)
    if (dev_score < 80 or room_score < 80) and state["knn_vecs"].shape[0] > 0:
        v = Embedder.encode([text])[0]
        A = state["knn_vecs"]
        sims = (A @ v) / (np.linalg.norm(A, axis=1) * np.linalg.norm(v) + 1e-9)
        i = int(np.argmax(sims))
        kd, kr = state["knn_labels"][i]
        ks = float(sims[i])
        if dev_score < 80:
            dev_guess, dev_score = kd, int(100 * ks)
        if room_score < 80:
            room_guess, room_score = kr, int(100 * ks)

    # 4) Constraint resolution (pure)
    device = dev_guess
    room = room_guess

    if device is None and room is None:
        return ({"status": "ask", "message": "Which device and room?"}, state)

    if device and (room is None):
        if is_unique_device(device, home_data):
            room = room_for(device, home_data)
        else:
            return ({"status": "ask", "message": f"Which room is the {device}?"}, state)

    if room and (device is None):
        if room_with_one_device(room, home_data):
            device = next(iter(home_data[room]))
        else:
            return ({"status": "ask", "message": f"Which device in the {room}?"}, state)

    if device not in home_data.get(room, set()):
        if is_unique_device(device, home_data):
            room = room_for(device, home_data)
        else:
            return ({"status": "error", "message": f"There is no {device} in the {room}."}, state)

    confidence = max(dev_score, room_score) / 100.0
    return ({"status": "ok", "device": device, "room": room, "confidence": float(confidence)}, state)

# ---------- Learning (pure) ----------
def learn_feedback(state: Dict[str, Any],
                   text: str,
                   correct_device: str,
                   correct_room: str,
                   new_synonym_for_device: Optional[str] = None) -> Dict[str, Any]:
    """
    User confirmed/corrected parse. Returns a NEW state with:
      - optional new device synonym persisted
      - new kNN example appended
    """
    # persist new synonym (inventory-agnostic memory)
    learned_syns = defaultdict(set, {k: set(v) for k, v in state["learned_syns"].items()})
    if new_synonym_for_device:
        learned_syns[correct_device].add(new_synonym_for_device.lower())

    # append semantic example
    v = Embedder.encode([text])[0]
    knn_vecs = state["knn_vecs"]
    if knn_vecs.shape[0] == 0:
        new_vecs = v.reshape(1, -1)
    else:
        new_vecs = np.vstack([knn_vecs, v])

    new_labels = list(state["knn_labels"]) + [(correct_device, correct_room)]
    new_examples = list(state["examples"]) + [(text, correct_device, correct_room)]

    # device_syns stays as-is until next reload_inventory(), which will incorporate learned_syns
    return {
        **state,
        "learned_syns": learned_syns,
        "knn_vecs": new_vecs,
        "knn_labels": new_labels,
        "examples": new_examples,
    }





from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any
import uvicorn

# import your existing functions here
# (empty_state, reload_inventory, parse_slots, etc.)

app = FastAPI()

# ---------- Setup ----------
home = {
    "bedroom": {"lamp", "light", "fan", "noise maker", "thermostat", "hygrometer"},
    "kitchen": {"light", "thermostat", "hygrometer"},
    "office": {"light", "fan", "thermostat", "hygrometer"},
}

state = empty_state()
state = reload_inventory(home, state)

# ---------- Request schema ----------
class ParseRequest(BaseModel):
    prompt: str

# ---------- Endpoint ----------
@app.post("/parse")
def parse(request: ParseRequest) -> Dict[str, Any]:
    result, _ = parse_slots(request.prompt, home, state)
    return result

# ---------- Run ----------
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)