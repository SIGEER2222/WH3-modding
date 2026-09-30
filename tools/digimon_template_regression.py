import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from digimon_model_templates import CATALOG, TEMPLATES, template_id_for_record

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORK = ROOT / "scratch" / "dgm_pub_batch"

REPRESENTATIVES = {
    "biped_tail": {"unit": "czx_dgm_greymon", "special": "greymon_chr050_trial"},
    "quadruped_longtail": {"unit": "czx_dgm_garurumon"},
    "winged_biped": {"unit": "czx_dgm_birdramon"},
    "serpentine": {"unit": "czx_dgm_seadramon"},
    "arthropod": {"unit": "czx_dgm_kabuterimon"},
}

ENVIRONMENT_EVIDENCE = {
    "biped_tail": ["biped_tail/run_flat"],
    "quadruped_longtail": ["quadruped_longtail/slope_up_12deg"],
    "winged_biped": ["winged_biped/obstacle_025h"],
    "serpentine": ["serpentine/slope_up_12deg"],
    "arthropod": ["arthropod/obstacle_025h"],
}


def _pose_files(unit_dir):
    return {path.stem.lower(): path for path in unit_dir.glob("pose_*.json")}


def _probe(name, status, evidence=None, note=None):
    row = {"name": name, "status": status}
    if evidence:
        row["evidence"] = [str(path) for path in evidence]
    if note:
        row["note"] = note
    return row


def _unit_entry(work, template_id, spec):
    template = TEMPLATES[template_id]
    unit = spec["unit"]
    unit_dir = work / unit
    poses = _pose_files(unit_dir)
    bound = unit_dir / f"{unit}_bound.glb"
    skeletons = sorted(unit_dir.glob("skel_*.json"))
    probes = []
    probes.append(_probe("bind_pose", "pass" if bound.exists() else "fail", [bound] if bound.exists() else None))
    idle = [path for key, path in poses.items() if "combat_idle" in key or "idle" in key]
    walk = [path for key, path in poses.items() if "walk" in key]
    attack = [path for key, path in poses.items() if "attack" in key]
    run = [path for key, path in poses.items() if "run" in key]
    probes.append(_probe("idle_breath", "pass" if idle else "not_generated", idle))
    probes.append(_probe("walk_cycle", "pass" if walk else "not_generated", walk))
    probes.append(_probe("run_cycle", "pass" if run else "not_generated", run))
    probes.append(_probe("charge_cycle", "not_generated", note="requires a reviewed locomotion clip, never inferred from attack"))
    probes.append(_probe("attack_cycle", "pass" if attack else "not_generated", attack))
    probes.append(_probe("turn_90", "not_generated", note="turn clip not present in representative scratch set"))
    probes.append(_probe("slope_up_12deg", "not_generated", note="terrain scene pending for this representative"))
    probes.append(_probe("slope_down_12deg", "not_generated", note="terrain scene pending for this representative"))
    probes.append(_probe("obstacle_025h", "not_generated", note="terrain scene pending for this representative"))
    if spec.get("special"):
        special_dir = ROOT / "scratch" / spec["special"]
        native = sorted((special_dir / "render").glob("*.png"))
        probes.append(_probe("native_motion_visual_review", "review_required" if native else "not_generated", native,
                             "chr050 native motion rendered; middle frames still show airborne posture"))
    environment_evidence = []
    for relative in ENVIRONMENT_EVIDENCE.get(template_id, []):
        probe_dir = ROOT / "scratch" / "dgm_template_env" / relative
        probe_json = probe_dir / "probe.json"
        render = probe_dir / "frame000.png"
        environment_evidence.append({
            "name": relative.rsplit("/", 1)[-1],
            "status": "pass" if probe_json.exists() and render.exists() and render.stat().st_size > 0 else "not_generated",
            "probe": str(probe_json),
            "render": str(render),
        })
    return {
        "template": template_id,
        "unit": unit,
        "family": template.get("resource_family"),
        "bound_glb": str(bound),
        "skeleton_json": [str(path) for path in skeletons],
        "motion_slots": list(CATALOG["defaults"].get("motion_slots", [])),
        "environment": template.get("environment", {}),
        "motion_policy": template.get("motion_policy", {}),
        "probes": probes,
        "environment_evidence": environment_evidence,
    }


def build(work):
    report = json.loads((work / "report.json").read_text(encoding="utf-8"))
    entries = []
    for template_id, spec in REPRESENTATIVES.items():
        record = report.get(spec["unit"], {})
        if template_id_for_record(record) != template_id:
            raise RuntimeError(f"representative family mismatch: {spec['unit']}")
        entries.append(_unit_entry(work, template_id, spec))
    return {"schema_version": 1, "source_work": str(work), "templates": entries}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=str(DEFAULT_WORK))
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    work = Path(args.work)
    result = build(work)
    out = Path(args.out) if args.out else work / "template_regression.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print("TEMPLATE_REGRESSION", out)
    for entry in result["templates"]:
        summary = {}
        for probe in entry["probes"]:
            summary[probe["status"]] = summary.get(probe["status"], 0) + 1
        env_pass = sum(item["status"] == "pass" for item in entry["environment_evidence"])
        print(entry["template"], entry["unit"], summary, "environment_pass", env_pass)


if __name__ == "__main__":
    main()
