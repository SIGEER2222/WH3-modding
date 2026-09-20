# -*- coding: utf-8 -*-
"""Extract a vanilla battle animsuite for use as a custom-skeleton template.

For each (bin_name, skeleton) pair:
  scratch/salzaar_digimon/vanilla_<tag>/
      <bin>.bin                animsuite bin (patched per unit later)
      clip_list.txt            every animations/battle/<skel>/... path in bin
      clips/<name>.anim        the referenced clip files
      <skel>.anim/.anm.meta    skeleton template (also copied to tools/_skel)

Usage: python tools/extract_vanilla_animset.py [tag=bin:skel ...]
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from export_gamedata import iter_pack_entries, GAME_DATA

ROOT = Path(r"E:\Code\WH3-modding")
OUT_BASE = ROOT / "scratch" / "salzaar_digimon"
SKEL_DIR = ROOT / "tools" / "_skel"

SETS = {
    "hu1_sws":  ("hu1_empire_sword_and_shield.bin", "humanoid01"),
    "wf1_wolf": ("wf1_giant_wolf.bin", "wolf01"),
    "bi1_eagle": ("bi1_eagle.bin", "bird01"),
    "sn1_serpent": ("sn1_serpent.bin", "snake01"),
    "sp1_spider": ("sp1_giant_spider.bin", "spider01"),
    "in1_rotfly": ("in1_wh3_rot_fly.bin", "insect01"),
    "dr1b_dragon": ("dr1b_chaos_dragon.bin", "dragon01b"),
    "co1_cockatrice": ("co1_dlc22_cockatrice.bin", "cockatrice01"),
    "st1_stag": ("st1_stag.bin", "stag01"),
}


def find_entry(name):
    for pack in sorted(GAME_DATA.glob("anim*.pack")):
        for e in iter_pack_entries(pack, prefixes=(name,)):
            if e.name == name:
                return e.payload
    return None


def extract_set(tag, bin_name, skel):
    out = OUT_BASE / f"vanilla_{tag}"
    out.mkdir(parents=True, exist_ok=True)
    clip_dir = out / "clips"
    clip_dir.mkdir(exist_ok=True)

    # 1) bin
    payload = find_entry(f"animations/database/battle/bin/{bin_name}")
    if payload is None:
        print(tag, "BIN NOT FOUND:", bin_name)
        return
    (out / bin_name).write_bytes(payload)

    paths = sorted(set(
        m.group(0).decode()
        for m in re.finditer(rb"animations/battle/[\w/\.]+?\.anim", payload)))
    mine = [p for p in paths if p.startswith(f"animations/battle/{skel}/")]
    (out / "clip_list.txt").write_text("\n".join(mine) + "\n",
                                     encoding="utf-8")
    print(f"{tag}: bin ok, {len(mine)} clips for {skel}")

    # 2) clips (flat, basename only)
    want = {p.split("/")[-1] for p in mine}
    got = set()
    for pack in sorted(GAME_DATA.glob("anim*.pack")):
        if got == want:
            break
        for e in iter_pack_entries(pack,
                                   prefixes=(f"animations/battle/{skel}/",)):
            fn = e.name.split("/")[-1]
            if fn in want:
                (clip_dir / fn).write_bytes(e.payload)
                got.add(fn)
    print(f"   clips: {len(got)}/{len(want)}")

    # 3) skeleton anim + meta -> set dir and tools/_skel
    for ext in (".anim", ".anm.meta", ".bone_inv_trans_mats"):
        d = find_entry(f"animations/skeletons/{skel}{ext}")
        if d:
            (out / f"{skel}{ext}").write_bytes(d)
            if ext == ".anim":
                (SKEL_DIR / f"{skel}.anim").write_bytes(d)
        else:
            print("   missing skeleton res:", skel + ext)


def main():
    tags = sys.argv[1:] or list(SETS)
    for t in tags:
        bin_name, skel = SETS[t]
        extract_set(t, bin_name, skel)


if __name__ == "__main__":
    main()
