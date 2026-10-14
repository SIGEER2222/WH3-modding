# -*- coding: utf-8 -*-
"""Build a Chinese LLM-facing campaign brief from a parsed summary.

build_digest(summary, events=None) -> structured dict (all fields localized)
digest_to_markdown(digest) -> human/LLM-readable Chinese markdown

The digest is designed for "given the current state, what should the player do
next" reasoning: economy, army composition + estimated power, territory,
diplomacy incl. the global AI-vs-AI war graph, missions, recent events.
"""

import locdb

_UNVERIFIED = "估计值，未经游戏内核对"


def _cn(fn, key):
    if not key:
        return "?"
    return fn(key) or key


def nearest_region(x, y, region_xy, max_dist=60.0):
    if x is None or y is None or not region_xy:
        return None
    best = None
    best_d = max_dist * max_dist
    for k, (rx, ry) in region_xy.items():
        d = (rx - x) * (rx - x) + (ry - y) * (ry - y)
        if d < best_d:
            best_d = d
            best = k
    return best


def _commander_name(cmd):
    if not cmd:
        return None
    parts = []
    for elem in ("forename", "family_name", "clan_name", "other"):
        k = cmd.get(elem)
        if k:
            t = locdb.char_name(k)
            if t:
                parts.append(t)
    return "·".join(parts) if parts else None


def _unit_line(u):
    key = u.get("key")
    name = _cn(locdb.unit_name, key)
    st = u.get("strength")
    stats = locdb.unit_stats(key) or {}
    num_men = stats.get("num_men")
    out = {"key": key, "name": name}
    if st and len(st) == 2:
        out["strength"] = st
        if num_men == 1:
            out["strength_kind"] = "hp"
        else:
            out["strength_kind"] = "men"
    if u.get("rank"):
        out["rank"] = u["rank"]
    if u.get("commander"):
        cn = _commander_name(u["commander"])
        if cn:
            out["commander_name"] = cn
    out["power"] = stats.get("mp_cost")
    out["upkeep"] = stats.get("upkeep")
    out["tier"] = stats.get("tier")
    out["caste"] = stats.get("caste") or stats.get("category") or None
    return out


def _member_name(m):
    return locdb.member_name(m.get("name"))


def _army_block(army, region_xy):
    units = [_unit_line(u) for u in army.get("units") or []]
    power = sum(u["power"] or 0 for u in units)
    upkeep = sum(u["upkeep"] or 0 for u in units)
    near = None
    if army.get("province"):
        loc = locdb.province_name(army["province"]) or army["province"]
        near = loc
    else:
        rk = nearest_region(army.get("x"), army.get("y"), region_xy)
        if rk:
            near = _cn(locdb.region_name, rk) + " 附近"
    cmdr = None
    for u in units:
        if u.get("commander_name"):
            cmdr = u["commander_name"]
            break
    if cmdr is None and army.get("commander_member"):
        cmdr = _member_name(army["commander_member"])
    garrison_cn = None
    if army.get("garrison_of"):
        garrison_cn = _cn(locdb.region_name, army["garrison_of"])
    # unit count summary by name
    counts = {}
    for u in units:
        counts.setdefault(u["name"], {"n": 0, "strength": [], "rank": []})
        counts[u["name"]]["n"] += 1
        if u.get("strength"):
            counts[u["name"]]["strength"].append(u["strength"])
        if u.get("rank"):
            counts[u["name"]]["rank"].append(u["rank"])
    compact = []
    for name, c in counts.items():
        seg = name + ("×%d" % c["n"] if c["n"] > 1 else "")
        if c["strength"]:
            seg += "（兵力 %s）" % "/".join(
                "%d-%d" % (s[0], s[1]) for s in c["strength"])
        if c["rank"]:
            seg += "（经验 %s）" % "/".join(str(r) for r in c["rank"])
        compact.append(seg)
    return {
        "name": army.get("name"),
        "location": near,
        "province_key": army.get("province"),
        "garrison_of": army.get("garrison_of"),
        "garrison_cn": garrison_cn,
        "commander": cmdr,
        "unit_count": len(units),
        "power_estimate": power or None,
        "upkeep_estimate": upkeep or None,
        "units": units,
        "compact": compact,
    }


def build_digest(summary, events=None):
    save = summary.get("save") or {}
    player = summary.get("player") or {}
    world = summary.get("world") or {}
    factions = summary.get("factions") or []
    region_xy = world.get("region_xy") or {}

    fkey_to_row = {f.get("key"): f for f in factions if f.get("key")}

    # ---- overview / economy ----
    econ_note = []
    for arr in (player.get("econ_data") or []):
        if arr and any(v for v in arr if v):
            econ_note.append(arr)
    income_est = None
    if len(econ_note) >= 2:
        inc = sum(v for v in econ_note[-2] if v and v > 0)
        exp = sum(-v for v in econ_note[-1] if v and v < 0) +             sum(v for v in econ_note[-1] if v and v > 0)
        income_est = {"income_breakdown": econ_note[-2],
                      "expense_breakdown": econ_note[-1],
                      "note": _UNVERIFIED}

    alive = [f for f in factions
             if (f.get("units") or 0) + (f.get("forces") or 0) + (f.get("characters") or 0) > 0]
    overview = {
        "save_name": save.get("name"),
        "turn": save.get("turn"),
        "season": save.get("season"),
        "campaign": _cn(locdb.campaign_name, save.get("campaign")),
        "campaign_key": save.get("campaign"),
        "version": save.get("version"),
        "player_faction": player.get("name") or _cn(locdb.faction_name, player.get("key")),
        "player_faction_key": player.get("key"),
        "treasury": player.get("treasury"),
        "income_estimate": income_est,
        "forces": player.get("forces"),
        "units": player.get("units"),
        "characters": len(player.get("characters") or []),
        "regions_owned": len(player.get("regions") or []),
        "factions_alive": len(alive),
        "factions_total": len(factions),
        "mods": [m.get("pack") for m in (save.get("mods") or [])],
        "faction_bundles": [locdb.bundle_name(b.get("key")) or b.get("key")
                            for b in (player.get("faction_bundles") or [])],
    }

    # ---- player regions ----
    pregions = []
    for r in sorted(player.get("regions") or [],
                    key=lambda r: -(r.get("level") or 0)):
        bnames = []
        for b in (r.get("buildings") or [])[:8]:
            bnames.append(_cn(locdb.building_name, b))
        pregions.append({
            "name": _cn(locdb.region_name, r["key"]),
            "key": r["key"],
            "level": r.get("level"),
            "buildings": bnames,
        })

    # ---- armies ----
    armies = [_army_block(a, region_xy) for a in (player.get("armies") or [])]
    armies.sort(key=lambda a: -(a["power_estimate"] or 0))

    # ---- characters (FAMILY_MEMBER details preferred: rank/xp/skill
    # points/role verified against WH3SaveEditor field map) ----
    chars = []
    members = player.get("members") or []
    if members:
        members = sorted(members, key=lambda m: (
            0 if m.get("army") else 1, -(m.get("rank") or 0)))
        for m in members:
            rk = nearest_region(m.get("x"), m.get("y"), region_xy)
            subtype = locdb.subtype_name(m.get("subtype")) or m.get("subtype")
            chars.append({
                "name": _member_name(m),
                "type": locdb.agent_type_cn(m.get("type")),
                "type_key": m.get("type"),
                "subtype": subtype,
                "rank": m.get("rank"),
                "xp": m.get("xp"),
                "skill_points": m.get("skill_points"),
                "army": m.get("army"),
                "traits_n": len(m.get("traits") or []),
                "near": _cn(locdb.region_name, rk) if rk else None,
            })
    else:
        for c in (player.get("characters") or []):
            rk = nearest_region(c.get("x"), c.get("y"), region_xy)
            chars.append({
                "type": locdb.agent_type_cn(c.get("type")),
                "type_key": c.get("type"),
                "rank": c.get("rank"),
                "near": _cn(locdb.region_name, rk) if rk else None,
                "x": c.get("x"), "y": c.get("y"),
            })

    # ---- diplomacy ----
    diplo = []
    for d in (player.get("diplomacy") or []):
        if not d.get("key"):
            continue
        diplo.append({
            "faction": _cn(locdb.faction_name, d["key"]),
            "key": d["key"],
            "stance": d.get("stance"),
            "stance_cn": locdb.stance_cn(d.get("stance")),
            "attitude": d.get("attitude"),
        })
    wars = [d for d in diplo if d["stance"] == "war"]
    allies = [d for d in diplo if d["stance"] in
              ("military_alliance", "defensive_alliance", "allied")]
    treaties = [d for d in diplo if d["stance"] in
                ("trade", "trade_agreement", "non_aggression_pact", "military_access")]
    vassals = [d for d in diplo if d["stance"] in ("vassal", "master", "client_state")]
    diplomacy = {
        "wars": sorted(wars, key=lambda d: d["attitude"] or 0),
        "allies": allies,
        "treaties": treaties,
        "vassals": vassals,
        "neutral_count": sum(1 for d in diplo if d["stance"] == "neutral"),
        "all": diplo,
    }

    # ---- world powers ----
    top = sorted(alive, key=lambda f: -(f.get("units") or 0))[:10]
    powers = [{
        "faction": _cn(locdb.faction_name, f.get("key")),
        "key": f.get("key"),
        "units": f.get("units"),
        "forces": f.get("forces"),
        "regions": f.get("regions"),
        "treasury": f.get("treasury"),
        "is_player": f.get("key") == player.get("key"),
    } for f in top]

    world_wars = []
    for a, b in (world.get("wars") or []):
        fa, fb = fkey_to_row.get(a), fkey_to_row.get(b)
        world_wars.append({
            "a": _cn(locdb.faction_name, a), "a_key": a,
            "b": _cn(locdb.faction_name, b), "b_key": b,
            "a_units": (fa or {}).get("units"), "b_units": (fb or {}).get("units"),
        })

    # ---- missions / ancillaries / resources ----
    missions = []
    for m in (player.get("missions") or []):
        missions.append({
            "id": m.get("id"),
            "status": locdb.mission_status_cn(m.get("status")),
            "status_key": m.get("status"),
            "title": locdb.mission_title(m.get("title_loc")) or m.get("id"),
            "desc": (locdb.mission_desc(m.get("desc_loc")) or "")[:400] or None,
        })
    order = {"进行中": 0, "已发布": 0, "已完成": 1, "失败": 2, "已取消": 3}
    missions.sort(key=lambda m: order.get(m["status"], 9))

    ancillaries = [{"name": _cn(locdb.ancillary_name, a), "key": a}
                   for a in (player.get("ancillaries") or [])]
    resources = [{"name": _cn(locdb.pooled_name, k), "key": k, "value": v}
                 for k, v in (player.get("resources") or {}).items()]

    return {
        "overview": overview,
        "territory": pregions,
        "armies": armies,
        "characters": chars,
        "diplomacy": diplomacy,
        "world_powers": powers,
        "world_wars": world_wars,
        "storms": world.get("storms") or [],
        "crisis_triggered": world.get("crisis_triggered"),
        "missions": missions,
        "ancillaries": ancillaries,
        "resources": resources,
        "recent_events": events or [],
    }


# ---------------- markdown rendering ----------------

def _fmt(n):
    return "{:,}".format(n) if isinstance(n, (int, float)) else "?"


def digest_to_markdown(d):
    o = d["overview"]
    L = []
    L.append("# 战锤3 战役简报 · %s" % (o.get("save_name") or "?"))
    L.append("")
    L.append("## 概要")
    L.append("- 回合 **%s** · %s · 战役：%s（%s）" %
             (o.get("turn"), o.get("season") or "?", o.get("campaign"), o.get("campaign_key")))
    L.append("- 版本：%s" % (o.get("version") or "?"))
    L.append("- 玩家派系：**%s**（%s）" % (o.get("player_faction"), o.get("player_faction_key")))
    inc = o.get("income_estimate")
    inc_txt = ""
    if inc:
        inc_txt = " · 上轮账面收支明细：收入 %s / 支出 %s（%s）" % (
            _fmt(sum(v for v in inc["income_breakdown"] if v > 0)),
            _fmt(sum(v for v in inc["expense_breakdown"] if v > 0)),
            inc["note"])
    L.append("- 金库 **%s**%s" % (_fmt(o.get("treasury")), inc_txt))
    L.append("- 军团 %s · 单位 %s · 角色 %s · 城市 %s · 存活派系 %s/%s" % (
        o.get("forces"), o.get("units"), o.get("characters"),
        o.get("regions_owned"), o.get("factions_alive"), o.get("factions_total")))
    fb = o.get("faction_bundles") or []
    if fb:
        L.append("- 派系生效中效果：%s" % "、".join(fb[:12]))
    L.append("")

    if d["territory"]:
        L.append("## 玩家领土（%d 城）" % len(d["territory"]))
        for r in d["territory"]:
            lv = " T%d" % r["level"] if r.get("level") else ""
            L.append("- **%s**%s：%s" % (r["name"], lv, "、".join(r["buildings"][:6]) or "—"))
        L.append("")

    if d["armies"]:
        L.append("## 玩家军团（%d 支，按估算战力排序）" % len(d["armies"]))
        for i, a in enumerate(d["armies"], 1):
            head = "%d. " % i
            bits = []
            if a.get("name"):
                bits.append("「%s」" % a["name"])
            if a.get("commander"):
                bits.append("将领 %s" % a["commander"])
            if a.get("garrison_cn"):
                bits.append("驻军于 %s" % a["garrison_cn"])
            elif a.get("location"):
                bits.append("位于 %s" % a["location"])
            bits.append("%d 单位" % a["unit_count"])
            if a.get("power_estimate"):
                bits.append("估算战力 %s" % _fmt(a["power_estimate"]))
            if a.get("upkeep_estimate"):
                bits.append("维持费 %s/回合" % _fmt(a["upkeep_estimate"]))
            L.append("- %s%s" % (head, " · ".join(bits)))
            L.append("  - %s" % "；".join(a["compact"]))
        L.append("")

    if d["characters"]:
        L.append("## 玩家角色（%d 名）" % len(d["characters"]))
        for c in d["characters"][:18]:
            bits = []
            if c.get("name"):
                bits.append("**%s**" % c["name"])
            bits.append(c.get("subtype") or c["type"])
            if c.get("rank") is not None:
                bits.append("Lv.%s" % c["rank"])
            if c.get("xp"):
                bits.append("XP %s" % _fmt(c["xp"]))
            if c.get("skill_points"):
                bits.append("⚠未分配技能点 %d" % c["skill_points"])
            if c.get("army"):
                bits.append("率领「%s」" % c["army"])
            elif c.get("near"):
                bits.append("近 %s" % c["near"])
            L.append("- %s" % " · ".join(bits))
        if len(d["characters"]) > 18:
            L.append("- …另有 %d 名候选/未激活角色" % (len(d["characters"]) - 18))
        L.append("")

    dp = d["diplomacy"]
    L.append("## 外交态势")
    if dp["wars"]:
        L.append("- **交战 %d 家**：%s" % (len(dp["wars"]), "、".join(
            "%s（态度 %s）" % (w["faction"], w.get("attitude")) for w in dp["wars"])))
    else:
        L.append("- 当前无交战对象")
    if dp["allies"]:
        L.append("- 同盟：%s" % "、".join(
            "%s（%s）" % (a["faction"], a["stance_cn"]) for a in dp["allies"]))
    if dp["vassals"]:
        L.append("- 附庸关系：%s" % "、".join(
            "%s（%s）" % (v["faction"], v["stance_cn"]) for v in dp["vassals"]))
    if dp["treaties"]:
        L.append("- 条约：%s" % "、".join(
            "%s（%s）" % (t["faction"], t["stance_cn"]) for t in dp["treaties"]))
    L.append("- 其余中立派系 %d 家" % dp["neutral_count"])
    L.append("")

    if d["world_powers"]:
        L.append("## 世界格局 · 兵力 Top %d" % len(d["world_powers"]))
        for p in d["world_powers"]:
            mark = "（玩家）" if p["is_player"] else ""
            L.append("- %s%s：%s 单位 / %s 军团 / %s 城 / 金库 %s" % (
                p["faction"], mark, _fmt(p.get("units")), _fmt(p.get("forces")),
                _fmt(p.get("regions")), _fmt(p.get("treasury"))))
        L.append("")
    if d["world_wars"]:
        L.append("### 全球战争（含 AI 之间）· %d 对" % len(d["world_wars"]))
        for w in d["world_wars"][:30]:
            L.append("- %s（%s 单位）× %s（%s 单位）" % (
                w["a"], _fmt(w.get("a_units")), w["b"], _fmt(w.get("b_units"))))
        L.append("")

    if d["missions"]:
        L.append("## 任务与胜利目标")
        for m in d["missions"][:12]:
            line = "- [%s] **%s**" % (m["status"], m["title"])
            if m.get("desc"):
                line += "：%s" % m["desc"].replace("\n", " ")
            L.append(line)
        L.append("")

    if d["ancillaries"]:
        L.append("## 装备库（%d 件）" % len(d["ancillaries"]))
        L.append("- " + "、".join(a["name"] for a in d["ancillaries"][:40]))
        L.append("")
    if d["resources"]:
        L.append("## 派生资源")
        L.append("- " + "、".join("%s：%s" % (r["name"], _fmt(r["value"])) for r in d["resources"]))
        L.append("")

    if d.get("storms") or d.get("crisis_triggered"):
        L.append("## 世界状态")
        if d.get("storms"):
            L.append("- 魔法风暴：%s" % "、".join(
                locdb.STORM_CN.get(s, s) for s in d["storms"]))
        L.append("- 终局危机：%s" % ("已触发" if d.get("crisis_triggered") else "未触发"))
        L.append("")

    if d.get("recent_events"):
        L.append("## 最近事件（跨存档差分）")
        for e in d["recent_events"]:
            L.append("- %s" % e)
        L.append("")

    L.append("## 已加载 MOD（%d）" % len(o["mods"]))
    L.append("- " + "、".join(o["mods"]))
    L.append("")
    L.append("> 数值带「估计」标注者为存档字段直读/换算，语义未随版本核验；兵力 cur/max 中单体单位为 HP、多体单位为人数。")
    return "\n".join(L)
