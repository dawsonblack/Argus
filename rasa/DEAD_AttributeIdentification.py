# ---------- ATTR PIPELINE (final-stage) ----------
# Inputs:
#  - text: user utterance
#  - op: "read" or "write"
#  - read_attr_candidates: e.g., ["power","volume"]            (when op == "read")
#  - write_cmd_candidates: e.g., ["on","off","volume"]         (when op == "write")
#  - schema: optional shape info, e.g. {"volume":{"type":"range","min":1,"max":100}}
#  - state: dict (keeps attr_learned_syns + kNN)

# Outputs:
#  - for READ:  {"status":"ok","attribute":"volume","op":"read", "confidence":...}
#  - for WRITE (static): {"status":"ok","attribute":"power","op":"write","command":"on","confidence":...}
#  - for WRITE (param):  {"status":"ok","attribute":"volume","op":"write","params":{"mode":"absolute","value":50,"units":None}, "confidence":...}
#  - or {"status":"ask", "message":...}

# ---------- small defaults ----------
from typing import Dict, Any, List, Tuple, Optional, Set
from rapidfuzz import process, fuzz
import numpy as np
import re
from rasa.DEAD_DeviceIdentification import Embedder

_ATTR_DEFAULT_SYNS = {
    "power":  {"power","state","switch","on/off"},
    "volume": {"volume","loudness","sound","level"},
}

_ON_PHRASES  = {"turn on","power on","enable","start"}
_OFF_PHRASES = {"turn off","power off","disable","stop","kill","shut off","switch off"}
_MUTE_WORDS  = {"mute","muted","silence","silent"}

_REL_UP  = {"loud","louder","turn up","volume up","raise","increase","more","up"}
_REL_DOWN= {"quiet","quieter","softer","turn down","volume down","lower","decrease","less","down"}

def _normalize_write_to_attrs(write_cmds: List[str]) -> Tuple[List[str], Dict[str, Set[str]]]:
    """
    Map write command names to attribute space.
    Returns (attr_candidates, attr->available_commands)
      e.g. ["on","off","volume"] -> (["power","volume"], {"power":{"on","off"}, "volume":{"volume"}})
    """
    attr2cmds: Dict[str, Set[str]] = {}
    cmds = {c.lower() for c in write_cmds}
    if ("on" in cmds) or ("off" in cmds):
        attr2cmds["power"] = {*(cmds & {"on","off"})}
    if "volume" in cmds:
        attr2cmds["volume"] = {"volume"}
    # extend here for more commands/attributes
    return (list(attr2cmds.keys()), attr2cmds)

def _syns_for_attr(name: str, state: Dict[str,Any]) -> Set[str]:
    learned = set(state.get("attr_learned_syns", {}).get(name, set()))
    base = set(_ATTR_DEFAULT_SYNS.get(name, {name}))
    return base | learned | {name}

def _best_attr_by_lex_fuzzy(text_l: str, attr_candidates: List[str], state: Dict[str,Any]) -> Tuple[Optional[str], int]:
    # exact first
    for a in attr_candidates:
        for term in _syns_for_attr(a, state):
            if term in text_l:
                return (a, 100)
    # fuzzy across all candidate synonyms
    idx: List[Tuple[str,str]] = []
    for a in attr_candidates:
        for term in _syns_for_attr(a, state):
            idx.append((term, a))
    if not idx:
        return (None, 0)
    match = process.extractOne(text_l, [t for (t,_) in idx], scorer=fuzz.WRatio)
    if not match:
        return (None, 0)
    term, score, _ = match
    for t,a in idx:
        if t == term:
            return (a, int(score))
    return (None, 0)

def _best_attr_by_knn(text: str, attr_candidates: List[str], state: Dict[str,Any]) -> Optional[str]:
    V = state.get("attr_knn_vecs", np.zeros((0,384)))
    if V.shape[0] == 0:
        return None
    v = Embedder.encode([text])[0]
    sims = (V @ v) / (np.linalg.norm(V, axis=1) * np.linalg.norm(v) + 1e-9)
    guess = state.get("attr_knn_labels", [None])[int(np.argmax(sims))]
    return guess if guess in set(attr_candidates) else None

def _contains_any_phrase(text_l: str, phrases: Set[str]) -> bool:
    return any(p in text_l for p in phrases)

def _extract_numbers_basic(text_l: str) -> List[Tuple[float,bool]]:
    out: List[Tuple[float,bool]] = []
    for m in re.finditer(r'(\d+)\s*(%)?', text_l):
        out.append((float(m.group(1)), bool(m.group(2))))
    # very light word-number support can be added if you want
    return out

# ---------- Stage A: choose attribute (shared) ----------
def choose_attribute(text: str,
                     op: str,  # "read" | "write"
                     read_attr_candidates: Optional[List[str]],
                     write_cmd_candidates: Optional[List[str]],
                     state: Dict[str,Any]) -> Tuple[Dict[str,Any], Dict[str,Any]]:
    s = dict(state)
    text_l = text.lower()

    if op == "read":
        attrs = read_attr_candidates or []
        if not attrs:
            return ({"status":"error","message":"No readable attributes."}, s)
    else:
        write_cmds = write_cmd_candidates or []
        if not write_cmds:
            return ({"status":"error","message":"No writable commands."}, s)
        attrs, _ = _normalize_write_to_attrs(write_cmds)
        if not attrs:
            return ({"status":"error","message":"No writable attributes mapped."}, s)

    # light heuristics for common patterns (helps avoid kNN misfires)
    if "power" in attrs and op == "write":
        if _contains_any_phrase(text_l, _ON_PHRASES | _OFF_PHRASES):
            return ({"status":"ok","attribute":"power","op":op,"confidence":0.95}, s)

    if "volume" in attrs and op == "write":
        if _contains_any_phrase(text_l, _MUTE_WORDS | {"min","minimum"}):
            return ({"status":"ok","attribute":"volume","op":op,"confidence":0.95}, s)
        if _contains_any_phrase(text_l, _REL_UP | _REL_DOWN):
            return ({"status":"ok","attribute":"volume","op":op,"confidence":0.9}, s)

    # lexical → fuzzy → kNN
    a, score = _best_attr_by_lex_fuzzy(text_l, attrs, s)
    if not a:
        knn = _best_attr_by_knn(text, attrs, s)
        if knn:
            a, score = knn, 60

    if not a:
        if len(attrs) == 1:
            return ({"status":"ok","attribute":attrs[0],"op":op,"confidence":0.5}, s)
        return ({"status":"ask","message":"Which attribute do you mean?"}, s)

    return ({"status":"ok","attribute":a,"op":op,"confidence":score/100.0}, s)

# ---------- Stage B: write parameters (only for parametric commands) ----------
def resolve_write(text: str,
                  attribute: str,
                  write_cmd_candidates: List[str],   # e.g. ["on","off","volume"]
                  schema: Optional[Dict[str,Any]],   # e.g. {"volume":{"type":"range","min":1,"max":100}}
                  state: Dict[str,Any]) -> Tuple[Dict[str,Any], Dict[str,Any]]:
    s = dict(state)
    text_l = text.lower()
    cmds = {c.lower() for c in write_cmd_candidates}

    # POWER (static)
    if attribute == "power":
        # prefer explicit command names if present
        if "on" in cmds and _contains_any_phrase(text_l, _ON_PHRASES):
            return ({"status":"ok","attribute":"power","op":"write","command":"on","confidence":1.0}, s)
        if "off" in cmds and _contains_any_phrase(text_l, _OFF_PHRASES):
            return ({"status":"ok","attribute":"power","op":"write","command":"off","confidence":1.0}, s)
        # if both on/off available but no phrase detected—ask
        if {"on","off"} & cmds:
            return ({"status":"ask","message":"Power: on or off?"}, s)
        return ({"status":"error","message":"Power not writable for this device."}, s)

    # PARAMETRIC (e.g., VOLUME)
    if attribute == "volume":
        if "volume" not in cmds:
            return ({"status":"error","message":"Volume command not available."}, s)

        spec = (schema or {}).get("volume", {"type":"range","min":0,"max":100})
        kind = spec.get("type","range")

        if kind != "range":
            # If your schema says otherwise, you can add enum handling here.
            return ({"status":"error","message":"Unsupported volume schema."}, s)

        lo = float(spec.get("min", 0))
        hi = float(spec.get("max", 100))

        # quick intents
        if _contains_any_phrase(text_l, {"max","maximum","full"}):
            return ({"status":"ok","attribute":"volume","op":"write",
                     "params":{"mode":"absolute","value":hi,"units":None}}, s)
        if _contains_any_phrase(text_l, _MUTE_WORDS | {"min","minimum"}):
            return ({"status":"ok","attribute":"volume","op":"write",
                     "params":{"mode":"absolute","value":lo,"units":None}}, s)

        # relative hints without number: nudge 5%
        if _contains_any_phrase(text_l, _REL_UP):
            return ({"status":"ok","attribute":"volume","op":"write",
                     "params":{"mode":"relative","value":+5,"units":"%"}}, s)
        if _contains_any_phrase(text_l, _REL_DOWN):
            return ({"status":"ok","attribute":"volume","op":"write",
                     "params":{"mode":"relative","value":-5,"units":"%"}}, s)

        # numeric
        nums = _extract_numbers_basic(text_l)
        if nums:
            n, is_pct = nums[0]
            if is_pct:
                # keep in %; executor can map 0–100 → device scale
                return ({"status":"ok","attribute":"volume","op":"write",
                         "params":{"mode":"absolute","value":max(0.0,min(100.0,n)),"units":"%"}}, s)
            # absolute in device units (executor clamps & converts as needed)
            return ({"status":"ok","attribute":"volume","op":"write",
                     "params":{"mode":"absolute","value":n,"units":None}}, s)

        return ({"status":"ask","message":"What volume value?"}, s)

    # add more attributes here if/when needed
    return ({"status":"error","message":f"{attribute!r} not handled."}, s)

# ---------- Optional: learning hook (device-agnostic) ----------
def learn_attr_feedback(state: Dict[str,Any], text: str, correct_attr: str, new_synonym: Optional[str]=None) -> Dict[str,Any]:
    s = dict(state)
    learned = {k:set(v) for k,v in s.get("attr_learned_syns",{}).items()}
    if new_synonym:
        syns = set(learned.get(correct_attr, set()))
        syns.add(new_synonym.lower())
        learned[correct_attr] = syns

    v = Embedder.encode([text])[0]
    V = s.get("attr_knn_vecs", np.zeros((0,384)))
    new_V = v.reshape(1,-1) if V.shape[0]==0 else np.vstack([V, v])

    new_labels = list(s.get("attr_knn_labels", [])) + [correct_attr]
    new_examples = list(s.get("attr_examples", [])) + [(text, correct_attr)]

    s.update({
        "attr_learned_syns": learned,
        "attr_knn_vecs": new_V,
        "attr_knn_labels": new_labels,
        "attr_examples": new_examples,
    })
    return s




if __name__ == "__main__":
    # --- WRITE case: the device exposes commands: on, off, volume
    noise_maker_writes = ["on","off","volume"]
    noise_maker_reads  = ["power","volume"]
    noise_maker_schema = {"volume":{"type":"range","min":1,"max":100}}

    light_writes = ["on", "off", "brightness"]
    light_reads = ["power","brightness"]
    light_schema = {"brightness":{"type":"range","min":1,"max":100}}

    fan_writes = ["on", "off", "speed"]
    fan_reads = ["power","speed"]
    fan_schema = {"speed":{"type":"range","min":1,"max":100}}

    noise_maker_tests = [
        ("turn on the noise maker",                "write"),
        ("make it louder",                         "write"),
        ("mute the noise maker",                   "write"),
        ("what's the volume of the noise maker",   "read")
    ]

    light_tests = [
        ("set the lamp brightness to 50",          "write"),
        ("set the lamp to 50",                     "write"),
        ("is the kitchen light on",                "read"),
        ("dim the kitchen lights",                 "write")
    ]

    fan_tests = [
        ("kill the office fan",                    "write"),
        ("what's the the bedroom fan speed",       "read"),
        ("is the fan on",                          "read")
    ]

    def runTests(tests, writes, reads, schema):
        state: Dict[str,Any] = {}
        for text, op in tests:
            # Stage A: choose attribute
            if op == "read":
                stage_a, state = choose_attribute(text, op, reads, None, state)
            else:
                stage_a, state = choose_attribute(text, op, None, writes, state)

            print(f"\n> {text!r} [{op}]")
            print("StageA:", stage_a)

            if stage_a.get("status") != "ok":
                continue

            if op == "read":
                print({"status":"ok","attribute":stage_a["attribute"],"op":"read","confidence":stage_a["confidence"]})
            else:
                # Stage B: only for write
                stage_b, state = resolve_write(text, stage_a["attribute"], writes, schema, state)
                print("StageB:", stage_b)
    
    runTests(noise_maker_tests, noise_maker_writes, noise_maker_reads, noise_maker_schema)
    runTests(light_tests, light_writes, light_reads, light_schema)
    runTests(fan_tests, fan_writes, fan_reads, fan_schema)