# -*- coding: utf-8 -*-
"""Convert public Digimon downloads (Spriters/Models Resource zips) into
pipeline-ready GLBs under scratch/dgm_pub_src/glb + index.json.

Per unit:
  1. pick a source model file inside the extracted zip dir
     (prefer <chr>.dae; fallback binary .fbx; never ASCII .fbx)
  2. blender tools/fbx_to_glb.py  (bakes object transforms into data so
     accessor verts and IBMs share one frame)
  3. auto-detect bind up-axis from IBM joint positions and run
     tools/glb_reorient.py until joints+verts are Y-up standing
     (the convention the digimon_batch pipeline expects)

Usage:
  python tools/dgm_pub_convert.py                 # all mapped units
  python tools/dgm_pub_convert.py --units a,b     # subset
  python tools/dgm_pub_convert.py --report        # just print mapping
"""
import argparse
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(r"E:\Code\WH3-modding")
TOOLS = ROOT / "tools"
SRC = ROOT / "scratch" / "dgm_pub_src"
EX = SRC / "ex"
OUT = SRC / "glb"
BLENDER = r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
PY = sys.executable

REP = json.loads(
    (ROOT / "scratch" / "digimon_batch" / "report.json")
    .read_text(encoding="utf-8"))
FORMATS = json.loads((SRC / "formats.json").read_text(encoding="utf-8"))
INVENTORY = json.loads((SRC / "inventory.json").read_text(encoding="utf-8"))
ROSTER = {}
for l in (ROOT / "mod_files" / "zzz_czx_digimon_v2" / "ROSTER.tsv"
          ).read_text(encoding="utf-8").splitlines():
    c = l.split("\t")
    if len(c) > 1 and c[0].startswith("czx_dgm_"):
        ROSTER[c[0]] = c[1]

# unit -> (asset_id, preferred filename regex or None)
# overrides for units whose old GLB name had no chr### or wrong model
MANUAL = {
    "czx_dgm_vritramon": ("331595", r"chr679\.dae"),
    "czx_dgm_wargrowlmon": ("304077", None),
    "czx_dgm_fujinmon": ("336099", None),
    "czx_dgm_shinegreymonbm": ("304032", r"Burst Mode/chr776\.dae"),
    "czx_dgm_omegamonx": ("305434", None),
    "czx_dgm_omegamonab": ("304226", None),
    "czx_dgm_omegamonas": ("308181", None),
    "czx_dgm_magnamon": ("304228", None),
    "czx_dgm_susanoomon": ("304225", None),
    # dae fails Collada schema validation (missing texcoord attr)
    "czx_dgm_tentomon": ("324499", r"chr303\.fbx"),
    "czx_dgm_kabuterimon": ("324504", r"chr304\.fbx"),
    "czx_dgm_tinkermon": ("327563", None),
    "czx_dgm_fairymon": ("327562", None),          # Kazemon
    "czx_dgm_lilimon": ("324570", r"chr359 2\.89x Fix\.dae"),
    "czx_dgm_jetsilphymon": ("327560", None),
    "czx_dgm_cresgarurumon": ("308180", None),
    "czx_dgm_omegamond": ("304227", None),          # Zwart D
    # 341947 (NC s129_p) is a legless Bip001 rig; old unit used the Links
    # chr230 Millenniummon model (asset 304071) which is biped-compatible
    "czx_dgm_zeedmillennium": ("304071", None),
    "czx_dgm_dorugoramon": ("324393", None),
    # old unit reused the chr397 veedramon model; proper public models exist
    "czx_dgm_ulforcev": ("304156", None),
    "czx_dgm_ulforcevx": ("305922", None),
    # 304054: root chr126 = base Gallantmon, "Crimson Mode/" chr013 = CM
    "czx_dgm_gallantmon": ("304054", r"Gallantmon Crimson Mode ChaosGallantmon/chr126\.dae"),
    "czx_dgm_gallantmoncm": ("304054", r"Crimson Mode/chr013\.dae"),
    # imperialdm (dragon mode) has NO public download -> unmapped
}


def unit_chr(key):
    m = re.search(r"chr(\d+)", REP[key].get("glb", ""), re.I)
    return "chr" + m.group(1) if m else None


def resolve(key):
    """-> (asset_id, regex) or None"""
    if key in MANUAL:
        return MANUAL[key]
    chr_id = unit_chr(key)
    if not chr_id:
        return None
    hits = [a for a, fs in FORMATS.items()
            if any(chr_id in p.lower() for p, _f, _x in fs)]
    if not hits:
        return None
    return hits[0], re.escape(chr_id) + r"[^/]*\.dae$"


def pick_file(aid, prefer_re):
    files = FORMATS[aid]
    pools = [[p for p, f, _ in files if f == "dae"],
             [p for p, f, _ in files if f == "fbx-bin"]]
    if prefer_re:
        for pool in pools:
            m = [p for p in pool if re.search(prefer_re, p, re.I)]
            if m:
                return m[0]
    for pool in pools:
        root = [p for p in pool if p.count("/") == 1]
        if root:
            return root[0]
        if pool:
            return pool[0]
    return None


OLD_GLB = ROOT / "scratch" / "salzaar_digimon" / "glb"


def ibm_joints(path):
    """{node_name: bind position} from a GLB's first skin."""
    import glb_bindspace as gb  # noqa -- tools on sys.path
    js, buf = gb.read_glb(str(path))
    sk = js.get("skins", [])
    if not sk or sk[0].get("inverseBindMatrices") is None:
        return {}
    ibm = gb.read_accessor(js, buf, sk[0]["inverseBindMatrices"]) \
        .reshape(-1, 4, 4).transpose(0, 2, 1)
    out = {}
    for j, m in zip(sk[0]["joints"], ibm):
        name = js["nodes"][j].get("name", "")
        out[name] = np.linalg.inv(m)[:3, 3]
    return out


CANDIDATES = {
    "ok":     np.eye(3),
    "rx+90":  np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0.]]),
    "rx-90":  np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0.]]),
    "rx180":  np.array([[1, 0, 0], [0, -1, 0], [0, 0, -1.]]),
    "rz+90":  np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1.]]),
    "rz-90":  np.array([[0, 1, 0], [-1, 0, 0], [0, 0, 1.]]),
}


def best_rot_vs_old(new_joints, key):
    """Pick the rotation that best aligns new bind joints onto the unit's
    OLD (salzaar, already-verified) source skeleton. Scale-free Procrustes
    on shared bone names; returns candidate key or None."""
    old_p = OLD_GLB / REP[key].get("glb", "")
    if not old_p.exists():
        return None
    old = ibm_joints(old_p)
    shared = [n for n in new_joints if n in old]
    if len(shared) < 5:
        return None
    a = np.array([old[n] for n in shared])
    best = (1e18, None)
    for ck, R in CANDIDATES.items():
        b = np.array([new_joints[n] @ R.T for n in shared])
        # normalize: center + rms scale
        an = a - a.mean(0)
        bn = b - b.mean(0)
        bn *= np.sqrt((an ** 2).sum() / max((bn ** 2).sum(), 1e-12))
        err = np.linalg.norm(an - bn, axis=1).mean()
        if err < best[0]:
            best = (err, ck)
    return best


def reorient_to_yup(path, key):
    """Rotate bind space to match the unit's old source orientation."""
    new = ibm_joints(path)
    if not new:
        return "no-skin"
    r = best_rot_vs_old(new, key)
    if r is None:
        return "no-match"
    err, ck = r
    if ck != "ok":
        subprocess.run([PY, str(TOOLS / "glb_reorient.py"),
                        str(path), str(path), ck],
                       check=True, capture_output=True)
    return f"{ck} err={err:.3f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--units", default="")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()

    want = set(args.units.split(",")) if args.units else None
    keys = [k for k in REP if not want or k in want]

    plan, unresolved = {}, []
    for k in keys:
        r = resolve(k)
        if r is None:
            unresolved.append(k)
            continue
        aid, pref = r
        f = pick_file(aid, pref)
        if f is None:
            unresolved.append(k + " (no usable file)")
            continue
        plan[k] = (aid, f)
    print(f"planned {len(plan)}, unresolved {len(unresolved)}")
    for k in unresolved:
        print("  UNRESOLVED", k, ROSTER.get(k), REP[k].get("glb"))
    if args.report:
        for k, (a, f) in sorted(plan.items()):
            print(f"{k:34s} {a} {f}")
        return

    OUT.mkdir(exist_ok=True)
    index = []
    fails = []
    for k, (aid, rel) in sorted(plan.items()):
        src = EX / aid / rel
        if not src.exists():
            print(f"{k:34s} MISSING {rel}")
            fails.append(k); continue
        cn = ROSTER.get(k, k)
        stem = re.sub(r"[^\w一-鿿]+", "_", Path(rel).stem).strip("_")
        dst = OUT / f"{cn}_{stem}.glb"
        if not dst.exists():
            cmd = [BLENDER, "-b", "--factory-startup", "-P",
                   str(TOOLS / "fbx_to_glb.py"), "--",
                   str(src), str(dst), "--no-anim"]
            r = subprocess.run(cmd, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            if not dst.exists():
                tail = "\n".join((r.stdout or "").splitlines()[-6:])
                print(f"{k:34s} CONVERT FAIL\n{tail}")
                fails.append(k); continue
        res = reorient_to_yup(dst, k)
        index.append({"file": dst.name, "digimon": cn,
                      "asset": stem, "unit": k})
        # digimon_batch scan resolves roster names through CN_ALIAS, which
        # maps them to the OLD salzaar spellings — emit a duplicate entry
        # under the alias too so the lookup finds this file either way.
        for alias, orig in {"祭祀兽": "祭师兽",
                            "喷射风灵兽": "喷射西尔芙兽"}.items():
            if cn == orig:
                index.append({"file": dst.name, "digimon": alias,
                              "asset": stem, "unit": k})
        print(f"{k:34s} {dst.name}  rot={res}")
    # merge into any existing index rather than clobbering it on partial runs
    idx_path = OUT / "index.json"
    if idx_path.exists():
        keep = [e for e in json.loads(idx_path.read_text(encoding="utf-8"))
                if e.get("unit") not in plan]
        index = keep + index
    idx_path.write_text(
        json.dumps(index, ensure_ascii=False, indent=1),
        encoding="utf-8")
    print(f"done: {len(index)} glb, {len(fails)} failed")


if __name__ == "__main__":
    sys.path.insert(0, str(TOOLS))
    main()
