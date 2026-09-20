# -*- coding: utf-8 -*-
"""czx_bridge daemon v0.1 — tails the telemetry file written by the in-game
Lua agent (script/battle/mod/czx_bridge.lua) and maintains live battle state.

The agent writes one JSON object per line to <game_dir>/czx_bridge_telemetry.jsonl:
  hello  session header (agent version, caps, battle type)
  snap   per-tick snapshot: {"t":ms,"ph":phase,"n":N,"ctrl":{...},"units":[...]}
  evt    diff-derived events: phase / engaged / routing / shattered / unit_gone /
         snap_error / tick_error / slow_tick / bye
  bye    final line before the agent closes the file

Usage:
  python bridge_daemon.py                      # tail live, print feed
  python bridge_daemon.py --replay             # read existing file from start, then tail
  python bridge_daemon.py --status 10          # army summary every 10s (default 15)
  python bridge_daemon.py --state-out s.json   # also dump latest state for other tools
  python bridge_daemon.py --quiet              # events off, status only
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from collections import deque
from pathlib import Path

DEFAULT_GAME_DIR = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III"
)
DEFAULT_FILE = "czx_bridge_telemetry.jsonl"


class BattleState:
    """Aggregated view of the current telemetry session."""

    def __init__(self) -> None:
        self.hello: dict | None = None
        self.phase = "?"
        self.units: dict[int, dict] = {}   # uid -> last unit record
        self.gone: set[int] = set()
        self.events: deque[dict] = deque(maxlen=500)
        self.snaps = 0
        self.last_t = 0
        self.last_line_at = 0.0

    def feed(self, msg: dict) -> None:
        kind = msg.get("kind")
        self.last_line_at = time.time()
        if kind == "hello":
            self.hello = msg
        elif kind == "snap":
            self.snaps += 1
            self.last_t = msg.get("t") or 0
            self.phase = msg.get("ph") or self.phase
            seen = set()
            for u in msg.get("units") or []:
                uid = u.get("u")
                if uid is None:
                    continue
                seen.add(uid)
                self.units[uid] = u
                self.gone.discard(uid)
        elif kind == "evt":
            self.events.append(msg)
            e = msg.get("e")
            if e == "phase":
                self.phase = msg.get("to") or self.phase
            elif e == "unit_gone":
                self.gone.add(msg.get("u"))
            elif e == "bye":
                pass

    def side_counts(self) -> dict[str, dict]:
        out: dict[str, dict] = {}
        for uid, u in self.units.items():
            if uid in self.gone:
                continue
            side = f"al{u.get('al')}/ar{u.get('ar')}"
            s = out.setdefault(side, {"n": 0, "hp": 0.0, "rout": 0})
            s["n"] += 1
            hp = u.get("hp")
            if isinstance(hp, (int, float)):
                s["hp"] += hp
            fl = u.get("fl") or ""
            if "r" in fl or "s" in fl:
                s["rout"] += 1
        return out


def fmt_status(st: BattleState) -> str:
    sides = st.side_counts()
    parts = []
    for side, s in sorted(sides.items()):
        mean_hp = (s["hp"] / s["n"]) if s["n"] else 0.0
        parts.append(f"{side}: n={s['n']} hp={mean_hp:.0%} rout={s['rout']}")
    t_s = st.last_t / 1000.0
    return (
        f"[{t_s:7.1f}s] ph={st.phase:<16} units={len(st.units) - len(st.gone)}"
        f" gone={len(st.gone)} | " + " | ".join(parts)
    )


def fmt_evt(msg: dict) -> str:
    t = (msg.get("t") or 0) / 1000.0
    e = msg.get("e") or "?"
    extra = {k: v for k, v in msg.items() if k not in ("v", "kind", "t", "ph", "e")}
    return f"  {t:7.1f}s  {e:<14} {json.dumps(extra, ensure_ascii=False)}"


def tail(path: Path, args) -> None:
    st = BattleState()
    fh = None
    offset = 0
    warned_stale = False
    next_status = 0.0

    print(f"[daemon] tailing {path} (poll {args.poll}s)", flush=True)
    while True:
        try:
            size = path.stat().st_size
        except OSError:
            if fh:
                fh.close()
                fh = None
            size = -1

        if fh is None:
            if size < 0:
                time.sleep(args.poll)
                continue
            fh = path.open("r", encoding="utf-8", errors="replace")
            offset = 0 if args.replay else max(0, size - 1_000_000)
            fh.seek(offset)
            if offset and not args.replay:
                fh.readline()  # discard partial line
            print(f"[daemon] file opened @offset={offset}", flush=True)

        if 0 <= size < offset:  # truncated -> new battle session
            print("[daemon] file truncated -> new session", flush=True)
            fh.close()
            fh = path.open("r", encoding="utf-8", errors="replace")
            offset = 0
            st = BattleState()

        fh.seek(offset)
        got = False
        while True:
            line = fh.readline()
            if not line:
                break
            offset = fh.tell()
            line = line.strip()
            if not line:
                continue
            got = True
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                print(f"[daemon] bad line: {line[:120]!r}", flush=True)
                continue
            st.feed(msg)
            if msg.get("kind") == "hello":
                caps = msg.get("caps") or {}
                b = msg.get("battle") or {}
                print(
                    f"[daemon] session: agent={msg.get('agent')} type={b.get('type')}"
                    f" siege={b.get('siege')} io={caps.get('io')}"
                    f" os_time={caps.get('os_time')} os_clock={caps.get('os_clock')}",
                    flush=True,
                )
            elif msg.get("kind") == "evt" and not args.quiet:
                print(fmt_evt(msg), flush=True)
                if msg.get("e") == "bye":
                    print("[daemon] battle end (bye)", flush=True)

        now = time.time()
        if st.hello and now >= next_status:
            print(fmt_status(st), flush=True)
            next_status = now + args.status
            if args.state_out:
                tmp = Path(str(args.state_out) + ".tmp")
                tmp.write_text(
                    json.dumps(
                        {
                            "hello": st.hello,
                            "phase": st.phase,
                            "last_t": st.last_t,
                            "sides": st.side_counts(),
                            "events": list(st.events)[-50:],
                        },
                        ensure_ascii=False,
                    ),
                    encoding="utf-8",
                )
                tmp.replace(args.state_out)

        if st.hello and not got and (now - st.last_line_at) > args.stale:
            if not warned_stale:
                print(
                    f"[daemon] no data for {args.stale}s - agent idle or battle over",
                    flush=True,
                )
                warned_stale = True
        elif got:
            warned_stale = False

        time.sleep(args.poll)


def main() -> int:
    ap = argparse.ArgumentParser(description="czx_bridge telemetry daemon v0.1")
    ap.add_argument("--game-dir", type=Path, default=DEFAULT_GAME_DIR)
    ap.add_argument("--file", default=DEFAULT_FILE, help="telemetry filename in game dir")
    ap.add_argument("--path", type=Path, help="explicit file path (overrides game-dir/file)")
    ap.add_argument("--replay", action="store_true", help="read file from the start first")
    ap.add_argument("--poll", type=float, default=0.5, help="tail poll interval (s)")
    ap.add_argument("--status", type=float, default=15.0, help="status line interval (s)")
    ap.add_argument("--stale", type=float, default=15.0, help="staleness warning (s)")
    ap.add_argument("--state-out", type=Path, help="write latest state JSON here")
    ap.add_argument("--quiet", action="store_true", help="suppress per-event lines")
    args = ap.parse_args()

    path = args.path or (args.game_dir / args.file)
    try:
        tail(path, args)
    except KeyboardInterrupt:
        print("\n[daemon] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
