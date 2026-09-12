# -*- coding: utf-8 -*-
"""Patch military_force_type_horde_details_tables + psw_04 script inside zzz_psw_merged.pack."""
from __future__ import annotations

import os
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
os.environ["RPFM_SCHEMA_WH3"] = str(Path(__file__).parent / "schema" / "schema_wh3.ron")

from export_gamedata import iter_pack_entries
from build_pack import Schema, SCHEMA_PATH, read_db_tsv, encode_db

PACK = Path(r"E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710\3018964477\zzz_psw_merged.pack")
SOURCE_ROOT = Path(r"E:\Code\WH3-modding\mod_files\zzz_psw_merged")

# 要注入的文件列表: (源文件相对路径, pack内目标路径, 是否DB表)
PATCH_FILES = [
    ("script/campaign/mod/psw_04_dynamic_ex_limit.lua",
     "script/campaign/mod/psw_04_dynamic_ex_limit.lua", False),
    ("db/military_force_type_horde_details_tables/zzz_psw_mixu_compat.tsv",
     "db/military_force_type_horde_details_tables/zzz_psw_mixu_compat", True),
]


def main():
    schema = Schema(SCHEMA_PATH)
    files: dict[str, bytes] = {}
    for entry in iter_pack_entries(PACK):
        files[entry.name] = entry.payload

    for src_rel, pack_path, is_db in PATCH_FILES:
        src = SOURCE_ROOT / src_rel
        if not src.exists():
            print(f"WARNING: source not found: {src}")
            continue
        if is_db:
            table, version, internal_path, rows = read_db_tsv(src)
            # pack 中用正斜杠，统一路径格式
            internal_path = internal_path.replace("\\", "/")
            encoded = encode_db(table, version, rows, schema)
            files[internal_path] = encoded
            print(f"patched DB {internal_path} ({len(encoded)} bytes, {len(rows)} rows)")
        else:
            pack_path = pack_path.replace("\\", "/")
            files[pack_path] = src.read_bytes()
            print(f"patched {pack_path} ({len(files[pack_path])} bytes)")

    bak = PACK.with_suffix(f".pack.bak_{int(time.time())}")
    PACK.rename(bak)
    print(f"backed up to {bak}")

    entries = sorted(files.items(), key=lambda x: x[0])
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
    print(f"wrote {PACK} ({len(header+index+data)} bytes, {len(entries)} files)")


if __name__ == "__main__":
    main()
