#!/usr/bin/env python3
"""Add low-fanout Vampire Counts campaign access to custom unit packs.

Units remain custom-battle enabled for the original factions, but campaign
access is restricted to Vampire Counts through one vanilla tier-1 building,
one military group, and exclusive-faction permissions.
"""
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ROOT = ROOT / "mod_files"
BACKUP_ROOT = ROOT / "scratch" / "custom_unit_pool_fix"
BUILDING = "wh_main_vmp_necromancers_1"
MILITARY_GROUP = "wh_main_group_vampire_counts"
FACTION = "wh_main_vmp_vampire_counts"

PACKS = (
    ("zzz_czx_digimon", "!!dgm_digimon", "!!dgm_digimon", 2_147_400_000),
    ("zzz_czx_swarm_units", "!!czx_swarm_units", "!!czx_all_factions", 2_147_401_000),
    ("zzz_czx_pokemon", "!!pkm_pokemon", "!!pkm_pokemon", 2_147_402_000),
    ("zz_dgm_mats", "!!czx_dgm_patch", "!!czx_dgm_patch", 2_147_403_000),
    ("zz_dgm_meta", "!!czx_dgm_patch", "!!czx_dgm_patch", 2_147_404_000),
)


def read_tsv(path: Path) -> tuple[list[str], list[str], list[str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    if len(lines) < 2:
        raise ValueError(f"TSV missing header/metadata: {path}")
    return lines[0].split("\t"), lines[1].split("\t"), lines[2:]


def data_rows(lines: list[str]) -> list[str]:
    return [line for line in lines if line.strip()]


def units_from_main_units(path: Path) -> list[str]:
    header, _, lines = read_tsv(path)
    unit_index = header.index("unit")
    units = []
    for line in data_rows(lines):
        fields = line.split("\t")
        if len(fields) > unit_index and fields[unit_index]:
            units.append(fields[unit_index])
    return units


def write_tsv(path: Path, header: list[str], metadata: list[str], lines: list[str]) -> None:
    path.write_text(
        "\n".join(["\t".join(header), "\t".join(metadata), *lines]) + "\n",
        encoding="utf-8-sig",
        newline="",
    )


def prepare_backup(paths: list[Path], stamp: str) -> Path:
    backup_root = BACKUP_ROOT / stamp / "vampire_access"
    for path in paths:
        relative = path.relative_to(MOD_ROOT)
        target = backup_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    return backup_root


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    operations: list[tuple[Path, list[str], list[str]]] = []
    all_paths: list[Path] = []
    for mod_name, main_shard, access_shard, key_base in PACKS:
        root = MOD_ROOT / mod_name
        main_path = root / "db" / "main_units_tables" / f"{main_shard}.tsv"
        building_path = root / "db" / "building_units_allowed_tables" / f"{access_shard}.tsv"
        group_path = root / "db" / "units_to_groupings_military_permissions_tables" / f"{access_shard}.tsv"
        exclusive_dir = root / "db" / "units_to_exclusive_faction_permissions_tables"
        exclusive_path = exclusive_dir / "!!czx_vmp_summon.tsv"
        units = units_from_main_units(main_path)
        building_header, building_meta, building_lines = read_tsv(building_path)
        group_header, group_meta, group_lines = read_tsv(group_path)
        if exclusive_path.is_file():
            exclusive_header, exclusive_meta, exclusive_lines = read_tsv(exclusive_path)
        else:
            exclusive_header = ["key", "faction", "allowed"]
            exclusive_meta = [
                "#units_to_exclusive_faction_permissions_tables;0;"
                "db/units_to_exclusive_faction_permissions_tables/!!czx_vmp_summon"
            ]
            exclusive_lines = []

        existing_building = {
            tuple(line.split("\t")[:2])
            for line in data_rows(building_lines)
        }
        existing_groups = {
            tuple(line.split("\t")[:2])
            for line in data_rows(group_lines)
        }
        existing_exclusive = {
            tuple(line.split("\t")[:2])
            for line in data_rows(exclusive_lines)
        }
        next_key = key_base
        new_buildings = []
        new_groups = []
        new_exclusive = []
        for unit in units:
            if (BUILDING, unit) not in existing_building:
                new_buildings.append(
                    f"{BUILDING}\t{unit}\t0\t{next_key}\t0\t\tfalse"
                )
                next_key += 1
            if (unit, MILITARY_GROUP) not in existing_groups:
                new_groups.append(f"{unit}\t{MILITARY_GROUP}")
            if (unit, FACTION) not in existing_exclusive:
                new_exclusive.append(f"{unit}\t{FACTION}\ttrue")
        print(
            f"{mod_name}: units={len(units)} add building={len(new_buildings)} "
            f"group={len(new_groups)} exclusive={len(new_exclusive)}"
        )
        operations.extend(
            [
                (building_path, building_header, building_meta + building_lines + new_buildings),
                (group_path, group_header, group_meta + group_lines + new_groups),
                (exclusive_path, exclusive_header, exclusive_meta + exclusive_lines + new_exclusive),
            ]
        )
        all_paths.extend([building_path, group_path])
        if exclusive_path.is_file():
            all_paths.append(exclusive_path)

    if not args.apply:
        print("dry-run; pass --apply to write Vampire Counts campaign access")
        return 0

    backup_root = prepare_backup(all_paths, stamp)
    for path, header, lines in operations:
        path.parent.mkdir(parents=True, exist_ok=True)
        metadata = lines[0:1]
        # operations carry header separately; split the stored metadata/data list.
        write_tsv(path, header, lines[0:1], lines[1:])
    print(f"applied; backups={backup_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
