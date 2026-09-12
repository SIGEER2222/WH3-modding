# -*- coding: utf-8 -*-
"""Add/replace multiple Lua scripts inside zzz_psw_merged.pack from mod_files source."""
from __future__ import annotations

import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from export_gamedata import iter_pack_entries

PACK = Path(r"E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710\3018964477\zzz_psw_merged.pack")
SOURCE_ROOT = Path(r"E:\Code\WH3-modding\mod_files\zzz_psw_merged")

# 要添加/替换的文件列表（相对于 SOURCE_ROOT 的路径）
PATCH_FILES = [
    "script/campaign/mod/psw_08_auto_manage.lua",
]


def main():
    files: dict[str, bytes] = {}
    for entry in iter_pack_entries(PACK):
        files[entry.name] = entry.payload

    # 添加/替换文件
    for rel_path in PATCH_FILES:
        src = SOURCE_ROOT / rel_path
        if not src.exists():
            print(f"WARNING: source file not found: {src}")
            continue
        pack_path = rel_path.replace("/", "\\")
        files[pack_path] = src.read_bytes()
        print(f"patched {rel_path} ({len(files[pack_path])} bytes)")

    bak = PACK.with_suffix(f".pack.bak_{int(time.time())}")
    if PACK.exists():
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
