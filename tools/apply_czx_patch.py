# -*- coding: utf-8 -*-
"""Rebuild czx_swarm_expansion.pack from mod_files source, keeping any binary
payloads that fail to re-encode (e.g. tables with older schema versions)."""
from __future__ import annotations

import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import build_pack as bp
from export_gamedata import iter_pack_entries

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "czx_swarm_expansion"
PACK = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data\czx_swarm_expansion.pack")


def main():
    schema = bp.Schema(bp.SCHEMA_PATH)
    files: dict[str, bytes] = {}

    # keep existing pack contents as fallback
    for entry in iter_pack_entries(PACK):
        files[entry.name] = entry.payload

    # DB TSVs
    for tsv in sorted((MOD / "db").rglob("*.tsv")):
        rel = tsv.relative_to(MOD).as_posix()
        try:
            table, version, internal, rows = bp.read_db_tsv(tsv)
            encoded = bp.encode_db(table, version, rows, schema)
            key = internal.replace("\\", "/")
            files[key] = encoded
            print(f"  encoded db {rel} -> {key} ({len(encoded)} bytes)")
        except Exception as e:
            print(f"  [KEEP] db {rel}: {e}")

    # Loc TSVs
    for tsv in sorted((MOD / "text").rglob("*.tsv")):
        rel = tsv.relative_to(MOD).as_posix()
        try:
            internal, rows = bp.read_loc_tsv(tsv)
            encoded = bp.encode_loc(rows)
            key = internal.replace("\\", "/")
            files[key] = encoded
            print(f"  encoded loc {rel} -> {key} ({len(encoded)} bytes)")
        except Exception as e:
            print(f"  [KEEP] loc {rel}: {e}")

    # Other files
    for top in ("script", "ui", "variantmeshes", "animations", "audio", "vfx"):
        base = MOD / top
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if path.is_file():
                rel = path.relative_to(MOD).as_posix()
                files[rel] = path.read_bytes()
                print(f"  copied {rel}")

    # reserved
    files.update(bp.pack_reserved_files())

    # write pack
    bak = PACK.with_suffix(f".pack.bak_{int(time.time())}")
    PACK.rename(bak)
    print(f"backed up to {bak}")

    entries = sorted(files.items(), key=lambda item: item[0])
    index = bytearray()
    data = bytearray()
    for p, c in entries:
        index += struct.pack("<I", len(c))
        index += b"\x00"
        index += p.encode("utf-8")
        index += b"\x00"
        data += c

    header = bytearray()
    header += b"PFH5"
    header += struct.pack("<I", 3)
    header += struct.pack("<I", 0)
    header += struct.pack("<I", 0)
    header += struct.pack("<I", len(entries))
    header += struct.pack("<I", len(index))
    header += struct.pack("<I", int(time.time()))

    PACK.write_bytes(bytes(header + index + data))
    print(f"wrote {PACK} ({len(header + index + data)} bytes, {len(entries)} files)")


if __name__ == "__main__":
    main()
