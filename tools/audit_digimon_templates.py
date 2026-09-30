"""Audit existing Digimon units against reusable model templates.

This is read-only. It distinguishes a real topology failure from missing
instance mapping evidence, so the batch pipeline cannot silently promote an
unverified unit.
"""
import argparse
import fnmatch
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from digimon_model_templates import CATALOG, TEMPLATES, template_id_for_record

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORK = ROOT / "scratch" / "dgm_pub_batch"


def _source_match(pattern, name):
    if "*" in pattern or "?" in pattern:
        return fnmatch.fnmatchcase(name, pattern)
    return name == pattern or name.startswith(pattern)


def _role_source_names(template, role, source_names):
    patterns = template.get("source_role_patterns", {}).get(role, [])
    return sorted({name for name in source_names
                   if any(_source_match(pattern, name) for pattern in patterns)})


def _target_coverage(template, bone_names, jmap, source_names):
    targets = set(bone_names)
    mapped_targets = set(jmap.values()) if jmap is not None else set()
    roles = {}
    for role, candidates in template.get("target_roles", {}).items():
        present = [bone for bone in candidates if bone in targets]
        source = _role_source_names(template, role, source_names)
        mapped = [bone for bone in present if bone in mapped_targets]
        mapped_source = [name for name in source
                         if jmap is not None and jmap.get(name) in present]
        source_present = bool(source)
        if jmap is None:
            state = "evidence_missing" if source_present else "not_present"
        elif source_present and not mapped:
            state = "override_required"
        else:
            state = "ready" if present and (mapped or not source_present) else "override_required"
        roles[role] = {
            "present": present,
            "source": source,
            "mapped": mapped,
            "mapped_source": mapped_source,
            "state": state,
            "ok": state in ("ready", "not_present"),
        }
    return roles


def _parent_map(skeleton):
    bones = skeleton.get("bones", [])
    return {bone["name"]: (bones[bone.get("parent", -1)]["name"]
                              if bone.get("parent", -1) >= 0
                              and bone.get("parent", -1) < len(bones) else None)
            for bone in bones}


def _chain_checks(template, skeleton, jmap, source_names):
    targets = {bone["name"] for bone in skeleton.get("bones", [])}
    parent = _parent_map(skeleton)
    reverse = {}
    if jmap is not None:
        for source, target in jmap.items():
            reverse.setdefault(target, []).append(source)
    out = {}
    for name, chain in template.get("attachment_chains", {}).items():
        branches = chain.get("branches") or [chain.get("target", [])]
        branch_rows = []
        for branch in branches:
            present = [bone for bone in branch if bone in targets]
            mapped = [bone for bone in present if bone in reverse]
            source = [source_name for bone in mapped
                      for source_name in reverse.get(bone, [])]
            topology_ok = True
            if chain.get("must_be_serial") and len(present) > 1:
                topology_ok = all(parent.get(child) == ancestor
                                  for ancestor, child in zip(present, present[1:]))
            if jmap is None:
                state = "evidence_missing" if source_names else "not_present"
            elif not present:
                state = "not_present"
            elif not mapped:
                state = "override_required"
            elif chain.get("must_be_serial") and not topology_ok:
                state = "override_required"
            elif chain.get("must_be_serial") and len(set(mapped)) < min(2, len(present)):
                state = "override_required"
            else:
                state = "ready"
            branch_rows.append({
                "present": present,
                "mapped": mapped,
                "source": source,
                "topology_ok": topology_ok,
                "state": state,
            })
        states = {row["state"] for row in branch_rows}
        if "override_required" in states:
            state = "override_required"
        elif "evidence_missing" in states:
            state = "evidence_missing"
        elif "ready" in states:
            state = "ready"
        else:
            state = "not_present"
        out[name] = {"state": state, "branches": branch_rows,
                     "ok": state in ("ready", "not_present")}
    return out


def _row_status(template, roles, chains, jmap):
    required = template.get("required_roles", CATALOG["defaults"]["required_roles"])
    optional = set(template.get("optional_roles", []))
    required_failures = [role for role in required
                         if roles.get(role, {}).get("state") == "override_required"]
    optional_failures = [role for role in optional
                         if roles.get(role, {}).get("state") == "override_required"]
    chain_failures = [name for name, row in chains.items()
                      if row["state"] == "override_required"]
    evidence_missing = (jmap is None or
                        any(roles.get(role, {}).get("state") == "evidence_missing"
                            for role in required + list(optional)) or
                        any(row["state"] == "evidence_missing"
                            for row in chains.values()))
    if required_failures or optional_failures or chain_failures:
        status = "override_required"
    elif evidence_missing:
        status = "evidence_missing"
    else:
        status = "ready"
    return status, required_failures, optional_failures, chain_failures


def audit(work):
    report = json.loads((work / "report.json").read_text(encoding="utf-8"))
    rows = []
    for key, rec in sorted(report.items()):
        if not rec.get("skel"):
            continue
        unit_dir = work / key
        skel_path = unit_dir / f"skel_{rec['skel']}.json"
        if not skel_path.exists():
            rows.append({"unit": key, "template": template_id_for_record(rec),
                         "status": "missing_skeleton"})
            continue
        skeleton = json.loads(skel_path.read_text(encoding="utf-8"))
        jmap_path = unit_dir / "jmap.json"
        jmap = json.loads(jmap_path.read_text(encoding="utf-8")) if jmap_path.exists() else None
        source_names = sorted(set(rec.get("joints", {}).keys()) |
                              (set(jmap.keys()) if jmap is not None else set()))
        template_id = template_id_for_record(rec)
        template = TEMPLATES[template_id]
        roles = _target_coverage(template, [bone["name"] for bone in skeleton["bones"]], jmap, source_names)
        chains = _chain_checks(template, skeleton, jmap, source_names)
        status, required_failures, optional_failures, chain_failures = _row_status(template, roles, chains, jmap)
        rows.append({"unit": key, "family": rec.get("family"),
                     "template": template_id, "skeleton": rec["skel"],
                     "status": status,
                     "required_failures": required_failures,
                     "optional_failures": optional_failures,
                     "chain_failures": chain_failures,
                     "mapping_evidence": bool(jmap_path.exists()),
                     "roles": roles, "chains": chains,
                     "environment": template.get("environment", {}),
                     "motion_donor": template.get("motion_donor", {})})
    summary = {}
    for row in rows:
        bucket = summary.setdefault(row["template"], {"total": 0})
        bucket["total"] += 1
        bucket[row["status"]] = bucket.get(row["status"], 0) + 1
    return {"schema_version": CATALOG["schema_version"],
            "summary": summary, "units": rows}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=str(DEFAULT_WORK))
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    work = Path(args.work)
    result = audit(work)
    out = Path(args.out) if args.out else work / "template_audit.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print("TEMPLATE_AUDIT", out)
    for template, stats in sorted(result["summary"].items()):
        print(template, stats)
    for row in result["units"]:
        if row["status"] != "ready":
            print(row["unit"], row["template"], row["status"],
                  "required=" + ",".join(row.get("required_failures", [])),
                  "optional=" + ",".join(row.get("optional_failures", [])),
                  "chains=" + ",".join(row.get("chain_failures", [])))


if __name__ == "__main__":
    main()
