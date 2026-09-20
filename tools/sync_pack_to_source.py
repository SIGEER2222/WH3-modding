# -*- coding: utf-8 -*-
"""Sync a built .pack back into mod_files/<mod>/ source layout.

Use when the deployed pack is the source of truth (source tree drifted or
is incomplete) and you want `build_pack.py` to reproduce it.

  db/<table>/<file>            -> decoded TSV (real pack version stamps)
  text/**/*.loc                -> decoded .loc.tsv
  everything else              -> raw file copy (variantmeshes, ui, script...)
  reserved pack metadata       -> skipped (build_pack regenerates)

Usage:
  python tools/sync_pack_to_source.py <pack_path> <mod_name> [--wipe]

--wipe deletes existing db/ and text/ dirs first (exact mirror).
Existing source-only files outside db/text are left alone.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_pack as bp
from export_gamedata import (
    SCHEMA_RON, decode_db_table, iter_pack_entries, load_schema,
    parse_loc, write_db_tsv,
)

ROOT = Path(__file__).resolve().parents[1]

RESERVED = (
    "notes.rpfm_reserved",
    "dependencies_manager_v2.rpfm_reserved",
    "settings.rpfm_reserved",
)


def write_loc_tsv(out: Path, internal: str, rows) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8-sig", newline="") as f:
        f.write("key\ttext\ttooltip\n")
        f.write(f"#loc;;{internal}\n")
        for k, t, tip in rows:
            f.write("\t".join((k, t, "true" if tip else "false")) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pack")
    ap.add_argument("mod_name")
    ap.add_argument("--wipe", action="store_true")
    args = ap.parse_args()

    pack = Path(args.pack)
    mod_root = ROOT / "mod_files" / args.mod_name
    if not pack.is_file():
        sys.exit(f"pack not found: {pack}")
    if not mod_root.is_dir():
        sys.exit(f"mod source not found: {mod_root}")

    schemas = load_schema(SCHEMA_RON)
    entries = list(iter_pack_entries(pack))
    print(f"{pack.name}: {len(entries)} entries")

    if args.wipe:
        import shutil
        for d in ("db", "text"):
            p = mod_root / d
            if p.is_dir():
                shutil.rmtree(p)
                print(f"wiped {d}/")

    n_db = n_loc = n_file = n_skip = n_fail = 0
    for e in entries:
        name = e.name.replace("/", "\\")
        leaf = name.rsplit("\\", 1)[-1]
        if leaf in RESERVED:
            n_skip += 1
            continue
        if name.startswith("db\\"):
            table = name.split("\\")[1]
            try:
                ver, fields, rows = decode_db_table(
                    table, e.payload, schemas.get(table, {}))
            except Exception as ex:
                print(f"  FAIL decode {name}: {ex}")
                n_fail += 1
                continue
            internal = name.replace("\\", "/")
            tsv_rel = internal[len("db/"):]
            out = mod_root / "db" / (tsv_rel + ".tsv")
            write_db_tsv(out, table, leaf, ver, fields, rows)
            n_db += 1
        elif name.lower().endswith(".loc"):
            try:
                rows = list(parse_loc(e.payload))
            except Exception as ex:
                print(f"  FAIL loc {name}: {ex}")
                n_fail += 1
                continue
            out = mod_root / (name.replace("\\", "/") + ".tsv")
            write_loc_tsv(out, name.replace("\\", "/"), rows)
            n_loc += 1
        else:
            out = mod_root / name.replace("\\", "/")
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(e.payload)
            n_file += 1

    print(f"synced: {n_db} db tsv, {n_loc} loc tsv, {n_file} files, "
          f"{n_skip} reserved skipped, {n_fail} failures")
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
