# -*- coding: utf-8 -*-
"""Patch czx_swarm_expansion.pack in-place:
- czx_zhanglang weight -> medium
- gou num_men / max_men_per_ship -> 48
"""
from __future__ import annotations

import struct
import sys
import time
from pathlib import Path

ROOT = Path(r"E:\Code\WH3-modding")
PACK = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data\czx_swarm_expansion.pack")

sys.path.insert(0, str(ROOT / "tools"))
import build_pack as bp
from export_gamedata import iter_pack_entries, load_schema, PackEntry, decode_db_table


def main():
    schemas = load_schema(bp.SCHEMA_PATH)
    schema_obj = bp.Schema(bp.SCHEMA_PATH)

    # read all pack entries
    files: dict[str, bytes] = {}
    for entry in iter_pack_entries(PACK):
        files[entry.name] = entry.payload

    target = "db/main_units_tables/!!czx_swarm_expansion"
    old = files[target]

    version, fields, rows = decode_db_table("main_units_tables", old, schemas["main_units_tables"])
    print(f"main_units_tables v{version}: {len(rows)} rows, {len(fields)} fields")

    # find and modify rows
    unit_idx = fields.index("unit")
    num_men_idx = fields.index("num_men")
    max_men_idx = fields.index("max_men_per_ship")
    weight_idx = fields.index("weight")
    changed = 0
    for row in rows:
        unit = row[unit_idx]
        if unit == "czx_zhanglang":
            row[weight_idx] = "medium"
            changed += 1
            print(f"  {unit}: weight -> medium")
        elif unit == "gou":
            row[num_men_idx] = "48"
            row[max_men_idx] = "48"
            changed += 1
            print(f"  {unit}: num_men -> 48, max_men_per_ship -> 48")

    # re-encode
    row_dicts = [dict(zip(fields, r)) for r in rows]
    new_payload = bp.encode_db("main_units_tables", version, row_dicts, schema_obj)
    files[target] = new_payload
    print(f"re-encoded {target}: {len(old)} -> {len(new_payload)} bytes")

    # write new PFH5 pack
    bak = PACK.with_suffix(f".pack.bak_{int(time.time())}")
    PACK.rename(bak)
    print(f"backed up original to {bak}")

    # build index + data
    entries = sorted(files.items(), key=lambda item: item[0])
    index = bytearray()
    data = bytearray()
    for path, content in entries:
        index += struct.pack("<I", len(content))
        index += b"\x00"  # uncompressed
        index += path.encode("utf-8")
        index += b"\x00"
        data += content

    header = bytearray()
    header += b"PFH5"
    header += struct.pack("<I", 3)
    header += struct.pack("<I", 0)  # dep size
    header += struct.pack("<I", 0)
    header += struct.pack("<I", len(entries))
    header += struct.pack("<I", len(index))
    header += struct.pack("<I", int(time.time()))

    PACK.write_bytes(bytes(header + index + data))
    print(f"wrote {PACK} ({len(header + index + data)} bytes, {len(entries)} files)")


def load_schema_and_decode(schemas, table, payload):
    """Decode a DB table using schemas dict from export_gamedata.load_schema."""
    return load_schema_and_decode_imp(schemas, table, payload)


def load_schema_and_decode_imp(schemas, table, payload):
    from export_gamedata import decode_db_table
    return decode_db_table(table, payload, schemas)


if __name__ == "__main__":
    main()
