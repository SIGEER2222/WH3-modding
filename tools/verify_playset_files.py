# -*- coding: utf-8 -*-
"""Verify every pack required by the active WH3 playset is on disk.

Run AFTER Steam (re)installs the game and workshop items:
  python tools/verify_playset_files.py

- steam:<wsid>:<pack>  -> pack must exist under workshop\\content\\1142710\\<wsid>\\
- local:data:<hash>    -> some *.pack in game data\\ must hash to that id
- Also scans workshop item dirs for locally-missing packs that were once
  hand-copied into data\\ (same filename -> same mod_id), and copies hits back.

Exit code 0 when the whole playset resolves, 1 otherwise.
"""
import hashlib
import sqlite3
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data")
WS = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710")
DB = Path.home() / "AppData/Roaming/WycccModManager/state.db"


def local_id(name: str) -> str:
    c = str((DATA / name).resolve()).replace("\\", "/").casefold()
    return "local:data:" + hashlib.sha256(c.encode("utf-8")).hexdigest()[:18]


def main() -> int:
    db = sqlite3.connect(DB)
    playset = db.execute(
        "SELECT value FROM app_state WHERE key='current_playset_id:warhammer3'"
    ).fetchone()[0]
    rows = db.execute(
        "SELECT position, mod_id FROM playset_items "
        "WHERE playset_id=? ORDER BY position", (playset,)).fetchall()

    steam_needed, local_ids = {}, []
    for pos, mid in rows:
        if mid.startswith("steam:"):
            _, wsid, pack = mid.split(":", 2)
            steam_needed[wsid] = pack.lower()
        elif mid.startswith("local:data:"):
            local_ids.append((pos, mid))
    print(f"playset items: {len(rows)}  steam: {len(steam_needed)}  "
          f"local: {len(local_ids)}")

    missing_ws = []
    for wsid, pack in sorted(steam_needed.items()):
        d = WS / wsid
        if not d.is_dir():
            missing_ws.append((wsid, pack, "item dir absent"))
        elif not any(p.name.lower() == pack for p in d.glob("*.pack")):
            have = ",".join(p.name for p in d.glob("*.pack")) or "<none>"
            missing_ws.append((wsid, pack, f"pack absent (has: {have})"))
    print(f"steam items missing: {len(missing_ws)}")
    for m in missing_ws:
        print("  ", m)

    # A pack that was hand-copied into data\ keeps a local:data id; if the same
    # filename ships inside a workshop item dir, copying it back restores it.
    unresolved = {mid for _, mid in local_ids}
    present = {p.name: local_id(p.name) for p in DATA.glob("*.pack")}
    resolved = {i for i in unresolved if i in present.values()}
    unresolved -= resolved

    if unresolved and WS.is_dir():
        for d in WS.iterdir():
            if not d.is_dir():
                continue
            for p in d.glob("*.pack"):
                lid = local_id(p.name)
                if lid in unresolved and p.name not in present:
                    shutil.copy2(p, DATA / p.name)
                    present[p.name] = lid
                    unresolved.discard(lid)
                    print(f"recovered {p.name} <- {p}")

    local_ok = len(local_ids) - len(unresolved)
    print(f"local packs resolved: {local_ok}/{len(local_ids)}")
    for pos, mid in local_ids:
        if mid in unresolved:
            print("  MISSING local:", pos, mid)
    return 1 if (missing_ws or unresolved) else 0


if __name__ == "__main__":
    sys.exit(main())
