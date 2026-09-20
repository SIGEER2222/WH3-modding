# -*- coding: utf-8 -*-
"""Bisect which db file(s) inside a .pack crash WH3 battle init.

Builds test packs = (all non-db assets) + (subset of db files), launches
battle_basegame.xml (pure vanilla units -> no unresolved-key false positive),
and recursively halves the suspect set until single-file culprits are found.

Usage:
  python tools/bisect_pack.py <pack_name_in_data> [--xml battle_basegame.xml]
"""
import os, struct, subprocess, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from export_gamedata import iter_pack_entries

GAME = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III")
DATA = GAME / "data"
CRASH = Path.home() / "AppData/Roaming/The Creative Assembly/Warhammer3/crash_report"
ML = GAME / "zz_autotest_mods.txt"

env = os.environ.copy()
env["SteamAppId"] = env["SteamGameId"] = "1142710"
FLAGS = getattr(subprocess, "DETACHED_PROCESS", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
_testno = 0


def write_pack(path, nondb, db_payloads, extra_db):
    fm = dict(nondb)
    for n in extra_db:
        fm[n] = db_payloads[n]
    entries = sorted(fm.items())
    index = bytearray(); blob = bytearray()
    for p_, c in entries:
        index += struct.pack("<I", len(c)); index += b"\x00"
        index += p_.encode("utf-8"); index += b"\x00"; blob += c
    hdr = b"PFH5" + struct.pack("<IIIIII", 3, 0, 0, len(entries), len(index), int(time.time()))
    path.write_bytes(bytes(hdr + index + blob))


def crashed(nondb, db_payloads, db_subset, xml, wait=55):
    global _testno
    _testno += 1
    tp = DATA / f"zz_bisect_{_testno:02d}.pack"
    write_pack(tp, nondb, db_payloads, db_subset)
    ML.write_text(f'mod "{tp.name}";\n', encoding="utf-8")
    before = {p.name for p in CRASH.glob("*.mdmp")}
    p = subprocess.Popen([str(GAME / "Warhammer3.exe"), "game_startup_mode", "battle",
                          xml, ";", ML.name + ";"],
                         cwd=str(GAME), env=env, creationflags=FLAGS)
    t0 = time.time()
    while time.time() - t0 < wait:
        if p.poll() is not None:
            break
        time.sleep(4)
    alive = p.poll() is None
    new = [d.name for d in CRASH.glob("*.mdmp") if d.name not in before]
    print(f"  test#{_testno} dbfiles={len(db_subset)} -> "
          f"{'CRASH ' + str(new) if not alive or new else 'clean'} ({time.time()-t0:.0f}s)", flush=True)
    if alive:
        subprocess.run(["taskkill", "/F", "/PID", str(p.pid)], capture_output=True)
        time.sleep(2)
    try:
        tp.unlink()
    except OSError:
        pass
    return not alive or bool(new)


def main():
    src = DATA / (sys.argv[1] if len(sys.argv) > 1 else "zzz_czx_swarm_units3.pack")
    xml = "battle_basegame.xml"
    if "--xml" in sys.argv:
        xml = sys.argv[sys.argv.index("--xml") + 1]
    files = {e.name: e.payload for e in iter_pack_entries(src)}
    db_names = sorted(n for n in files if "/db/" in n or n.startswith("db/"))
    nondb = {k: v for k, v in files.items() if k not in db_names}
    db_payloads = {k: files[k] for k in db_names}
    print(f"{src.name}: {len(files)} entries, {len(db_names)} db files", flush=True)

    if crashed(nondb, db_payloads, [], xml):
        sys.exit("assets alone crash - bisection impossible")

    culprits = []

    def bisect(S, depth=0):
        if not S:
            return
        if len(S) == 1:
            culprits.append(S[0])
            print("  " * depth + f"CULPRIT: {S[0]}", flush=True)
            return
        half = len(S) // 2
        for part in (S[:half], S[half:]):
            if crashed(nondb, db_payloads, part, xml):
                bisect(part, depth + 1)

    bisect(db_names)
    print("\n=== culprits ===")
    for c in culprits:
        print(" ", c)
    rest = [n for n in db_names if n not in culprits]
    ok = not crashed(nondb, db_payloads, rest, xml, wait=60)
    print("full-minus-culprits:", "CLEAN" if ok else "STILL CRASHES (more poisons)")


if __name__ == "__main__":
    main()
