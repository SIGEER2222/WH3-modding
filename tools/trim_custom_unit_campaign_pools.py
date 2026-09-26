#!/usr/bin/env python3
"""Make custom-unit source packs campaign-safe.

The unit and custom-battle DB rows remain intact, while campaign recruitment
and AI random-army fan-out tables are reduced to header/metadata-only shards.
Use --apply to write changes; the original TSV files are copied into scratch.
"""
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ROOT = ROOT / "mod_files"
BACKUP_ROOT = ROOT / "scratch" / "custom_unit_pool_fix"

TARGETS: dict[str, tuple[str, ...]] = {
    "zzz_czx_digimon": (
        "db/building_units_allowed_tables/!!dgm_digimon.tsv",
        "db/units_to_groupings_military_permissions_tables/!!dgm_digimon.tsv",
        "db/cdir_military_generator_unit_qualities_tables/!!dgm_digimon.tsv",
    ),
    "zzz_czx_swarm_units": (
        "db/building_units_allowed_tables/!!czx_all_factions.tsv",
        "db/units_to_groupings_military_permissions_tables/!!czx_all_factions.tsv",
    ),
    "zzz_czx_pokemon": (
        "db/building_units_allowed_tables/!!pkm_pokemon.tsv",
        "db/units_to_groupings_military_permissions_tables/!!pkm_pokemon.tsv",
        "db/cdir_military_generator_unit_qualities_tables/!!pkm_pokemon.tsv",
    ),
    "zz_dgm_mats": (
        "db/building_units_allowed_tables/!!czx_dgm_patch.tsv",
        "db/units_to_groupings_military_permissions_tables/!!czx_dgm_patch.tsv",
    ),
    "zz_dgm_meta": (
        "db/building_units_allowed_tables/!!czx_dgm_patch.tsv",
        "db/units_to_groupings_military_permissions_tables/!!czx_dgm_patch.tsv",
    ),
    "zzz_czx_dgm_patch": (
        "db/building_units_allowed_tables/!!czx_dgm_patch.tsv",
        "db/units_to_groupings_military_permissions_tables/!!czx_dgm_patch.tsv",
    ),
}


def campaign_rows(path: Path) -> tuple[list[str], int]:
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    if len(lines) < 2:
        raise ValueError(f"TSV missing header/metadata: {path}")
    data_rows = [line for line in lines[2:] if line.strip()]
    return lines[:2], len(data_rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_root = BACKUP_ROOT / stamp
    changed = 0
    for mod_name, rel_paths in TARGETS.items():
        mod_root = MOD_ROOT / mod_name
        for rel in rel_paths:
            path = mod_root / rel
            if not path.is_file():
                print(f"MISSING {path}")
                continue
            header, old_count = campaign_rows(path)
            print(f"{mod_name}/{rel}: {old_count} data rows -> 0")
            if not args.apply:
                continue
            backup = backup_root / mod_name / rel
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup)
            path.write_text("\n".join(header) + "\n", encoding="utf-8-sig", newline="")
            changed += 1

    if args.apply:
        print(f"changed={changed}; backups={backup_root}")
    else:
        print("dry-run; pass --apply to write source TSVs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
