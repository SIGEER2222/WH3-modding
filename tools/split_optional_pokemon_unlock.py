#!/usr/bin/env python3
"""Split Pokemon campaign access into an optional unlock patch."""
from __future__ import annotations

import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "mod_files" / "zzz_czx_vmp_unit_unlock"
OPTIONAL = ROOT / "mod_files" / "zzz_czx_vmp_pokemon_unlock"
BACKUP = ROOT / "scratch" / "custom_unit_pool_fix" / datetime.now().strftime("%Y%m%d_%H%M%S") / "split_optional_pokemon"
TABLES = {
    "building_units_allowed_tables": ("building", 1, "#building_units_allowed_tables;4;db/building_units_allowed_tables/!!czx_vmp_pokemon_unlock"),
    "units_to_groupings_military_permissions_tables": ("group", 0, "#units_to_groupings_military_permissions_tables;0;db/units_to_groupings_military_permissions_tables/!!czx_vmp_pokemon_unlock"),
    "units_to_exclusive_faction_permissions_tables": ("exclusive", 0, "#units_to_exclusive_faction_permissions_tables;0;db/units_to_exclusive_faction_permissions_tables/!!czx_vmp_pokemon_unlock"),
}

for table, (_kind, unit_index, optional_meta) in TABLES.items():
    main_path = next((MAIN / "db" / table).glob("!!czx_vmp_unit_unlock.tsv"))
    lines = main_path.read_text(encoding="utf-8-sig").splitlines()
    header = lines[0]
    rows = [line for line in lines[2:] if line.strip()]
    pokemon, remaining = [], []
    for row in rows:
        if row.split("\t")[unit_index].startswith("pkm_"):
            pokemon.append(row)
        else:
            remaining.append(row)
    backup = BACKUP / main_path.relative_to(ROOT / "mod_files")
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(main_path, backup)
    main_path.write_text("\n".join([header, lines[1], *remaining]) + "\n", encoding="utf-8-sig", newline="")
    optional_path = OPTIONAL / "db" / table / "!!czx_vmp_pokemon_unlock.tsv"
    optional_path.parent.mkdir(parents=True, exist_ok=True)
    optional_path.write_text("\n".join([header, optional_meta, *pokemon]) + "\n", encoding="utf-8-sig", newline="")
    print(f"{table}: main={len(remaining)} optional_pokemon={len(pokemon)}")
