#!/usr/bin/env python3
"""Move Vampire Counts campaign access rows into a standalone patch mod."""
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ROOT = ROOT / "mod_files"
PATCH = MOD_ROOT / "zzz_czx_vmp_unit_unlock"
BACKUP_ROOT = ROOT / "scratch" / "custom_unit_pool_fix"

PACKS = (
    ("zzz_czx_digimon", "!!dgm_digimon"),
    ("zzz_czx_swarm_units", "!!czx_all_factions"),
    ("zzz_czx_pokemon", "!!pkm_pokemon"),
    ("zz_dgm_meta", "!!czx_dgm_patch"),
    ("zz_dgm_mats", "!!czx_dgm_patch"),
)
TABLES = {
    "building_units_allowed_tables": "building_units_allowed",
    "units_to_groupings_military_permissions_tables": "units_to_groupings_military_permissions",
    "units_to_exclusive_faction_permissions_tables": "units_to_exclusive_faction_permissions",
}


def read_tsv(path: Path) -> tuple[list[str], list[str], list[str]]:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    if len(lines) < 2:
        raise ValueError(f"TSV missing header/metadata: {path}")
    return lines[0].split("\t"), lines[1].split("\t"), [x for x in lines[2:] if x.strip()]


def write_tsv(path: Path, header: list[str], metadata: list[str], rows: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(["\t".join(header), "\t".join(metadata), *rows]) + "\n",
        encoding="utf-8-sig",
        newline="",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_root = BACKUP_ROOT / stamp / "split_vampire_unlock"

    collected: dict[str, list[str]] = {table: [] for table in TABLES}
    templates: dict[str, tuple[list[str], list[str]]] = {}
    source_paths: list[Path] = []
    seen: dict[str, set[str]] = {table: set() for table in TABLES}

    for mod_name, shard in PACKS:
        for table, suffix in TABLES.items():
            if table == "units_to_exclusive_faction_permissions_tables":
                source = MOD_ROOT / mod_name / "db" / table / "!!czx_vmp_summon.tsv"
            else:
                source = MOD_ROOT / mod_name / "db" / table / f"{shard}.tsv"
            if not source.is_file():
                continue
            header, metadata, rows = read_tsv(source)
            templates.setdefault(table, (header, metadata))
            source_paths.append(source)
            for row in rows:
                key = "\t".join(row.split("\t")[:2]) if table == "building_units_allowed_tables" else row
                if key not in seen[table]:
                    seen[table].add(key)
                    collected[table].append(row)

    patch_names = {
        "building_units_allowed_tables": "!!czx_vmp_unit_unlock.tsv",
        "units_to_groupings_military_permissions_tables": "!!czx_vmp_unit_unlock.tsv",
        "units_to_exclusive_faction_permissions_tables": "!!czx_vmp_unit_unlock.tsv",
    }
    patch_metadata = {
        "building_units_allowed_tables": "#building_units_allowed_tables;4;db/building_units_allowed_tables/!!czx_vmp_unit_unlock",
        "units_to_groupings_military_permissions_tables": "#units_to_groupings_military_permissions_tables;0;db/units_to_groupings_military_permissions_tables/!!czx_vmp_unit_unlock",
        "units_to_exclusive_faction_permissions_tables": "#units_to_exclusive_faction_permissions_tables;0;db/units_to_exclusive_faction_permissions_tables/!!czx_vmp_unit_unlock",
    }
    patch_paths = [
        PATCH / "db" / table / filename
        for table, filename in patch_names.items()
    ]
    all_backup_paths = [p for p in dict.fromkeys(source_paths + patch_paths) if p.is_file()]

    for table, rows in collected.items():
        print(f"{table}: {len(rows)} rows -> patch")
    if not args.apply:
        print("dry-run; pass --apply to write the standalone patch")
        return 0

    for path in all_backup_paths:
        target = backup_root / path.relative_to(MOD_ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)

    for table, rows in collected.items():
        header, _ = templates[table]
        write_tsv(
            PATCH / "db" / table / patch_names[table],
            header,
            patch_metadata[table].split("\t"),
            rows,
        )

    for mod_name, shard in PACKS:
        for table in (
            "building_units_allowed_tables",
            "units_to_groupings_military_permissions_tables",
        ):
            source = MOD_ROOT / mod_name / "db" / table / f"{shard}.tsv"
            if source.is_file():
                header, metadata, _ = read_tsv(source)
                write_tsv(source, header, metadata, [])
        source = MOD_ROOT / mod_name / "db" / "units_to_exclusive_faction_permissions_tables" / "!!czx_vmp_summon.tsv"
        if source.is_file():
            header, metadata, _ = read_tsv(source)
            write_tsv(source, header, metadata, [])

    print(f"applied; backups={backup_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
