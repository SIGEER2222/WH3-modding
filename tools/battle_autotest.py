# -*- coding: utf-8 -*-
"""Launch a WH3 scripted battle directly (`game_startup_mode battle <xml>`),
bypassing the frontend so battle init can be tested without UI clicking.

The mod list is generated from the Mod Manager's real playset
(state.db playset_items), so load order matches a normal launch.

Usage:
  python tools/battle_autotest.py <battle.xml> [--mods full|none] [--wait 90]

- <battle.xml>: path to a <battle> XML; it is copied into game data\\ first
  (the VFS resolves loose files under data\\).
- --mods full : write <game>\\zz_autotest_mods.txt with every playset item
  in position order (add_working_directory for each installed workshop item,
  then mod "<pack>"; lines).
- --mods none : pass an empty mod list (';' only) - pure vanilla battle.
- --mods packs:a.pack,b.pack : load only the named packs from data\\,
  in the order given (no playset, no workshop dirs).
- --wait N    : after launch, poll up to N seconds; report whether the game
  is still alive and whether a new crash_report dump appeared.
"""
import argparse
import csv
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

GAME = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III")
DATA = GAME / "data"
WS = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710")
DB = Path.home() / "AppData/Roaming/WycccModManager/state.db"
CRASH = Path.home() / ("AppData/Roaming/The Creative Assembly/"
                       "Warhammer3/crash_report")
MODLIST = GAME / "zz_autotest_mods.txt"


def build_modlist(exclude: str = "") -> Path:
    db = sqlite3.connect(DB)
    playset = db.execute(
        "SELECT value FROM app_state "
        "WHERE key='current_playset_id:warhammer3'").fetchone()[0]
    rows = db.execute(
        "SELECT position, mod_id FROM playset_items WHERE playset_id=? "
        "ORDER BY position", (playset,)).fetchall()
    if exclude:
        rx = re.compile(exclude)
        kept = [(pos, mid) for pos, mid in rows if not rx.search(mid)]
        print(f"  exclude /{exclude}/ -> dropped {len(rows)-len(kept)}"
              f"/{len(rows)} items")
        rows = kept

    lines = []
    if WS.is_dir():
        for d in sorted(WS.iterdir(), key=lambda p: p.name):
            if d.is_dir():
                lines.append(f'add_working_directory "{d}";')
    missing = []
    for pos, mid in rows:
        if mid.startswith("steam:"):
            _, wsid, pack = mid.split(":", 2)
            d = WS / wsid
            hit = next((p for p in d.glob("*.pack")
                        if p.name.lower() == pack.lower()), None) \
                if d.is_dir() else None
            if hit is None:
                missing.append((pos, mid))
            else:
                lines.append(f'mod "{hit.name}";')
        elif mid.startswith("local:data:"):
            hit = next((p for p in DATA.glob("*.pack")
                        if _local_id(p.name) == mid), None)
            if hit is None:
                missing.append((pos, mid))
            else:
                lines.append(f'mod "{hit.name}";')
    for pos, mid in missing:
        print(f"  WARNING missing pack for pos {pos}: {mid}")
    MODLIST.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"modlist -> {MODLIST} ({len(lines)} lines, "
          f"{len(missing)} unresolved)")
    return MODLIST


def wh3_pids() -> set:
    """当前所有 Warhammer3.exe 的 pid。

    直接 Popen 拿到的 pid 不可靠：Steam 会接管并重拉起真正的游戏进程，
    那个中间进程几秒内就退出（rc=-1），只看它会误判成"立刻崩溃"。
    """
    out = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq Warhammer3.exe", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, errors="ignore")
    pids = set()
    for row in csv.reader(out.stdout.splitlines()):
        if len(row) >= 2 and row[0].strip().lower() == "warhammer3.exe":
            try:
                pids.add(int(row[1].strip()))
            except ValueError:
                pass
    return pids


def _local_id(name: str) -> str:
    import hashlib
    c = str((DATA / name).resolve()).replace("\\", "/").casefold()
    return "local:data:" + hashlib.sha256(c.encode("utf-8")).hexdigest()[:18]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("--mods", default="full")
    ap.add_argument("--wait", type=int, default=90)
    ap.add_argument("--exclude", default="",
                    help="regex on mod_id to drop from --mods full")
    args = ap.parse_args()

    exe = GAME / "Warhammer3.exe"
    if not exe.is_file():
        sys.exit(f"game exe not found: {exe}")

    xml_src = Path(args.xml)
    if not xml_src.is_file():
        sys.exit(f"xml not found: {xml_src}")
    xml_dst = DATA / xml_src.name
    if xml_src.resolve() != xml_dst.resolve():
        import shutil
        shutil.copy2(xml_src, xml_dst)
        print(f"xml -> {xml_dst}")

    if args.mods == "none":
        modlist_arg = ";"
    elif args.mods.startswith("file:"):
        src = Path(args.mods[5:])
        if not src.is_file():
            sys.exit(f"modlist file not found: {src}")
        MODLIST.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"modlist -> {MODLIST} (from {src})")
        modlist_arg = f"{MODLIST.name};"
    elif args.mods.startswith("packs:"):
        names = [n.strip() for n in args.mods[6:].split(",") if n.strip()]
        lines = []
        for n in names:
            if not (DATA / n).is_file():
                sys.exit(f"pack not found in data\\: {n}")
            lines.append(f'mod "{n}";')
        MODLIST.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"modlist -> {MODLIST} ({len(lines)} packs)")
        modlist_arg = f"{MODLIST.name};"
    else:
        modlist_arg = f"{build_modlist(args.exclude).name};"

    before = {p.name for p in CRASH.glob("*.mdmp")} if CRASH.is_dir() else set()
    prev_pids = wh3_pids()
    env = os.environ.copy()
    env["SteamAppId"] = env["SteamGameId"] = "1142710"
    flags = getattr(subprocess, "DETACHED_PROCESS", 0) | \
        getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    p = subprocess.Popen(
        [str(exe), "game_startup_mode", "battle", xml_dst.name, ";",
         modlist_arg],
        cwd=str(GAME), env=env, creationflags=flags, close_fds=True)
    print(f"launched pid={p.pid} xml={xml_dst.name} mods={args.mods}")

    deadline = time.time() + args.wait
    alive = True
    spawned = set()
    while time.time() < deadline:
        spawned = wh3_pids() - prev_pids
        if not spawned and time.time() - (deadline - args.wait) > 20:
            alive = False
            print("game gone (no Warhammer3.exe newer than launch)")
            break
        time.sleep(5)
    for pid in spawned:
        subprocess.run(["taskkill", "/F", "/PID", str(pid)], capture_output=True)
        time.sleep(2)
    new_dumps = sorted(
        (d for d in (CRASH.glob("*.mdmp") if CRASH.is_dir() else [])
         if d.name not in before),
        key=lambda d: d.stat().st_mtime)
    print(f"alive_after_{args.wait}s={alive} pids={sorted(spawned)} "
          f"new_dumps={len(new_dumps)}")
    for d in new_dumps:
        print("  dump:", d.name)
    return 0 if alive and not new_dumps else 1


if __name__ == "__main__":
    sys.exit(main())
