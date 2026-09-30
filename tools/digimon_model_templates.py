"""Data-driven Digimon model archetypes used by the batch pipeline.

The template file deliberately describes more than a donor skeleton: it is the
contract for semantic bones, protected source weights, motion slots and the
environment probes that must pass before a unit is promoted.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_PATH = ROOT / "tools" / "digimon_model_templates.json"

with TEMPLATE_PATH.open(encoding="utf-8") as _f:
    CATALOG = json.load(_f)

TEMPLATES = CATALOG["templates"]
FAMILY_TO_TEMPLATE = {
    "biped": "biped_tail",
    "quad": "quadruped_longtail",
    "bird": "winged_biped",
    "snake": "serpentine",
    "spider": "arthropod",
}

def template_id_for_family(family):
    return FAMILY_TO_TEMPLATE.get(family, "biped_tail")

def template_for_family(family):
    return TEMPLATES[template_id_for_family(family)]

def template_id_for_record(record):
    return template_id_for_family(record.get("family", "biped"))

def template_for_record(record):
    return TEMPLATES[template_id_for_record(record)]

def merged_motion_slots(template):
    slots = list(CATALOG["defaults"].get("motion_slots", []))
    extra = template.get("motion_slots", [])
    return slots + [slot for slot in extra if slot not in slots]
