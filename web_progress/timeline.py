# -*- coding: utf-8 -*-
"""Cross-save campaign timeline: diff consecutive save summaries into events.

存档只存状态不存历史，事件由相邻存档差分推导：
  - 宣战/停战（玩家外交表 stance）
  - 派系灭亡/激活（活跃度判定：单位+军团+角色 任一>0 视为活跃）
  - 军力剧变（单位数/军团数骤变=战损与扩军信号）
  - 角色折损（派系角色数骤降）/ 玩家角色增减
  - 建筑完成/损毁（区域建筑 key 集合差分）
  - 装备获得/失去（玩家 ancillary key 差分）
  - 任务发布/状态变化（玩家 mission status 串）
  - 魔法风暴生成/消散、终局危机触发
"""

SCHEMA = 2

# 军力剧变阈值（相对上一次快照）
UNIT_DROP = -25      # 疑似战损
UNIT_SURGE = 40      # 大规模扩军
FORCE_DROP = -3
FORCE_SURGE = 4
CHARACTER_DROP = -3  # 派系角色折损

EVENT_SCHEMA_FIELDS = ("war_declared", "war_ended", "faction_destroyed", "faction_emerged",
                       "units_dropped", "units_surge", "forces_dropped", "forces_surge",
                       "characters_dropped", "player_characters_changed",
                       "building_completed", "building_lost",
                       "ancillary_gained", "ancillary_lost",
                       "mission_issued", "mission_status",
                       "storm_spawned", "storm_ended", "crisis_triggered")


def _activity(fc):
    return (fc.get("units") or 0) + (fc.get("forces") or 0) + (fc.get("characters") or 0) > 0


def _war_keys(summary):
    player = summary.get("player") or {}
    wars = set()
    for row in player.get("diplomacy") or []:
        if row.get("stance") == "war" and row.get("key"):
            wars.add(row["key"])
    return wars


def snapshot_of(summary):
    save = summary["save"]
    factions = {}
    active = set()
    for f in summary["factions"]:
        if f.get("key"):
            factions[f["key"]] = {
                "treasury": f.get("treasury"),
                "units": f.get("units") or 0,
                "forces": f.get("forces") or 0,
                "characters": f.get("characters") or 0,
            }
            if _activity(f):
                active.add(f["key"])
    player = summary.get("player") or {}
    world = summary.get("world") or {}
    missions = {}
    for m in player.get("missions") or []:
        if m.get("id"):
            missions[m["id"]] = m.get("status")
    return {
        "turn": save.get("turn"),
        "mtime": (summary.get("save_file") or {}).get("mtime"),
        "name": (summary.get("save_file") or {}).get("name") or save.get("name"),
        "campaign": save.get("campaign"),
        "player_key": save.get("player_faction_key"),
        "player": {
            "treasury": player.get("treasury"),
            "units": player.get("units") or 0,
            "forces": player.get("forces") or 0,
            "characters": len(player.get("characters") or []),
        },
        "faction_count": len(factions),
        "factions": factions,
        "active": active,
        "wars": sorted(_war_keys(summary)),
        "masters": sorted(
            (row.get("key") for row in (player.get("diplomacy") or [])
             if row.get("stance") == "master" and row.get("key")),
        ),
        "buildings": {k: sorted(v) for k, v in (world.get("region_buildings") or {}).items()},
        "ancillaries": sorted(player.get("ancillaries") or []),
        "missions": missions,
        "storms": sorted(world.get("storms") or []),
        "crisis": bool(world.get("crisis_triggered")),
    }


def diff(prev, curr):
    """Diff two snapshots -> list of events (curr is newer). Each event has a
    scope: 'player' (involves the player directly) or 'world'."""
    events = []
    turn = curr.get("turn")

    def add(etype, scope, key=None, detail=None):
        ev = {"turn": turn, "type": etype, "scope": scope}
        if key is not None:
            ev["key"] = key
        if detail:
            ev["detail"] = detail
        events.append(ev)

    prev_active = prev["active"] if prev else set()
    curr_active = curr["active"]
    for key in sorted(curr_active - prev_active):
        add("faction_emerged", "world", key)
    if prev:
        for key in sorted(prev_active - curr_active):
            add("faction_destroyed", "world", key)

    prev_wars = set(prev["wars"]) if prev else set()
    curr_wars = set(curr["wars"])
    for key in sorted(curr_wars - prev_wars):
        add("war_declared", "player", key)
    for key in sorted(prev_wars - curr_wars):
        add("war_ended", "player", key)

    if prev:
        for key, st in curr["factions"].items():
            old = prev["factions"].get(key)
            if not old:
                continue
            du = st["units"] - old["units"]
            df = st["forces"] - old["forces"]
            dc = st["characters"] - old["characters"]
            if du <= UNIT_DROP:
                add("units_dropped", "world", key, {"delta": du, "units": st["units"]})
            elif du >= UNIT_SURGE:
                add("units_surge", "world", key, {"delta": du, "units": st["units"]})
            if df <= FORCE_DROP:
                add("forces_dropped", "world", key, {"delta": df})
            elif df >= FORCE_SURGE:
                add("forces_surge", "world", key, {"delta": df})
            if dc <= CHARACTER_DROP:
                add("characters_dropped", "world", key, {"delta": dc})

        pc = curr["player"]["characters"] - prev["player"]["characters"]
        if pc != 0:
            add("player_characters_changed", "player", None, {"delta": pc})

        # buildings per region
        for region, blist in curr["buildings"].items():
            old = set(prev["buildings"].get(region) or ())
            for b in sorted(set(blist) - old):
                add("building_completed", "world", region, {"building": b})
            for b in sorted(old - set(blist)):
                add("building_lost", "world", region, {"building": b})

        # player ancillaries
        for a in sorted(set(curr["ancillaries"]) - set(prev["ancillaries"])):
            add("ancillary_gained", "player", None, {"item": a})
        for a in sorted(set(prev["ancillaries"]) - set(curr["ancillaries"])):
            add("ancillary_lost", "player", None, {"item": a})

        # player missions
        for mid, st in curr["missions"].items():
            if mid not in prev["missions"]:
                add("mission_issued", "player", None, {"mission": mid, "status": st})
            elif prev["missions"][mid] != st:
                add("mission_status", "player", None,
                    {"mission": mid, "from": prev["missions"][mid], "to": st})

        # storms
        for s in sorted(set(curr["storms"]) - set(prev["storms"])):
            add("storm_spawned", "world", None, {"storm": s})
        for s in sorted(set(prev["storms"]) - set(curr["storms"])):
            add("storm_ended", "world", None, {"storm": s})

        # NOTE: crisis.triggered 字段语义未定（实测为 [0, True]），不产生事件

    return events


def build_timeline(summaries):
    """summaries: list of summary dicts (any order) -> timeline dict."""
    snaps = [snapshot_of(s) for s in summaries]
    snaps = [s for s in snaps if s["turn"] is not None]
    # dedupe by turn: keep the latest mtime per turn
    by_turn = {}
    for s in snaps:
        t = s["turn"]
        if t not in by_turn or (s["mtime"] or 0) > (by_turn[t]["mtime"] or 0):
            by_turn[t] = s
    ordered = [by_turn[t] for t in sorted(by_turn)]

    events = []
    for a, b in zip(ordered, ordered[1:]):
        events.extend(diff(a, b))
    events.reverse()  # newest first

    player_key = ordered[-1]["player_key"] if ordered else None

    # series: player + top rivals (by final units)
    final = ordered[-1]["factions"] if ordered else {}
    rivals = sorted(
        (k for k in final if k != player_key),
        key=lambda k: -final[k]["units"],
    )[:5]
    series = {}
    for key in ([player_key] if player_key else []) + rivals:
        series[key] = {
            "turns": [s["turn"] for s in ordered],
            "units": [s["factions"].get(key, {}).get("units") for s in ordered],
            "treasury": [s["factions"].get(key, {}).get("treasury") for s in ordered],
        }

    campaign = ordered[-1]["campaign"] if ordered else None
    return {
        "schema": SCHEMA,
        "campaign": campaign,
        "player_key": player_key,
        "points": [
            {
                "turn": s["turn"],
                "mtime": s["mtime"],
                "name": s["name"],
                "faction_count": s["faction_count"],
                "active_count": len(s["active"]),
                "player": s["player"],
                "war_count": len(s["wars"]),
            }
            for s in ordered
        ],
        "series": series,
        "events": events,
        "save_count": len(ordered),
    }
