# -*- coding: utf-8 -*-
"""Regenerate recruitment wiring fragments for zzz_czx_digimon (all 104 units).

Replicates wargreymon's existing wiring sets across the whole roster:
  - units_custom_battle_permissions: unit x 25 factions (custom battle roster)
  - units_to_groupings_military_permissions: unit x 104 military groups
    (faction permission pools + rogue/rebel army pools)
  - building_units_allowed: ENABLED rows, vanilla-style cumulative unlock:
    unit tier t -> building level >= t+1 (t5 -> level 5 only).
    Building list = the curated 305-entry scaffold already in the fragment.

Idempotent: regenerates the three fragment files deterministically.
"""
import re
from pathlib import Path

MOD = Path(r"E:\Code\WH3-modding\mod_files\zzz_czx_digimon")
DB = MOD / "db"
ROSTER = MOD / "ROSTER.tsv"
T = "\t"

KEY_BASE = 2147200465  # first key used by the original wargreymon rows


def load_roster():
    lines = ROSTER.read_text(encoding="utf-8").splitlines()
    hdr = lines[0].split(T)
    out = []
    for l in lines[1:]:
        if not l or l.startswith("#"):
            continue
        f = l.split(T)
        out.append(dict(zip(hdr, f)))
    return out


def frag_lines(rel):
    p = DB / rel
    return p, p.read_text(encoding="utf-8").splitlines()


def bldg_level(name):
    """Parse trailing level: '..._4' / '..._4_tormentors' / '..._2b_throgg'."""
    m = re.search(r"_([1-5])[a-zA-Z]*(?:_\D.*)?$", name)
    return int(m.group(1)) if m else None


def main():
    roster = load_roster()
    units = [(r["key"], int(r["tier"])) for r in roster]
    print(f"units: {len(units)}")

    # --- extract the template lists from existing wargreymon rows ---
    p, lines = frag_lines("building_units_allowed_tables/!!czx_digimon_units.tsv")
    b_hdr, b_meta = lines[0], lines[1]
    buildings = list(dict.fromkeys(
        l.split(T)[0] for l in lines[2:] if l.strip()))
    print(f"buildings scaffold: {len(buildings)}")

    p, lines = frag_lines("units_custom_battle_permissions_tables/!!czx_digimon_units.tsv")
    c_hdr, c_meta = lines[0], lines[1]
    cbp_rows = [l.split(T) for l in lines[2:] if l.strip()]
    factions = list(dict.fromkeys(r[0] for r in cbp_rows))
    cbp_tail = cbp_rows[0][1:]  # row minus faction, minus unit
    print(f"cbp factions: {len(factions)}")

    p, lines = frag_lines("units_to_groupings_military_permissions_tables/!!czx_digimon_units.tsv")
    g_hdr, g_meta = lines[0], lines[1]
    groups = list(dict.fromkeys(
        l.split(T)[1] for l in lines[2:] if l.strip()))
    print(f"military groups: {len(groups)}")

    # --- building_units_allowed: enabled rows only, cumulative unlock ---
    # t1 -> lvl2+, t2 -> lvl3+, t3/t4/t5 -> lvl4+ (scaffold tops out at lvl4
    # for most factions; restricting t4/t5 to lvl5 would make ~50 units
    # unobtainable for races without lvl5 chains, e.g. vampire counts).
    out = [b_hdr, b_meta]
    key = KEY_BASE
    n = 0
    per_lvl = {}
    for ukey, tier in units:
        min_lvl = 2 if tier == 1 else 3 if tier == 2 else 4
        for b in buildings:
            lv = bldg_level(b)
            if lv is None or lv < min_lvl:
                continue
            out.append(T.join([b, ukey, "0", str(key), "0", "", "true"]))
            key += 1
            n += 1
            per_lvl[lv] = per_lvl.get(lv, 0) + 1
    (DB / "building_units_allowed_tables/!!czx_digimon_units.tsv").write_text(
        "\n".join(out) + "\n", encoding="utf-8")
    print(f"building_units_allowed: {n} enabled rows (per level {per_lvl})")

    # --- units_custom_battle_permissions: unit x factions ---
    out = [c_hdr, c_meta]
    n = 0
    for ukey, _ in units:
        for i, fac in enumerate(factions):
            row = [fac] + cbp_tail
            row[2] = ukey  # 'unit' column index
            out.append(T.join(row))
            n += 1
    (DB / "units_custom_battle_permissions_tables/!!czx_digimon_units.tsv").write_text(
        "\n".join(out) + "\n", encoding="utf-8")
    print(f"units_custom_battle_permissions: {n} rows")

    # --- units_to_groupings_military_permissions: unit x groups ---
    out = [g_hdr, g_meta]
    n = 0
    for ukey, _ in units:
        for g in groups:
            out.append(T.join([ukey, g]))
            n += 1
    (DB / "units_to_groupings_military_permissions_tables/!!czx_digimon_units.tsv").write_text(
        "\n".join(out) + "\n", encoding="utf-8")
    print(f"units_to_groupings: {n} rows")


if __name__ == "__main__":
    main()
