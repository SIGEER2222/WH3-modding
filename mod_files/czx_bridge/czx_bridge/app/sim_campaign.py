"""sim_campaign.py — 战役世界模拟器：从开局跑到统一，产出 100+ 回合 / 1000+ 事件流。

每个事件经 TalkEngine.fire() 转成台本输出，写入 JSONL 日志。
用法：python sim_campaign.py [--out out/campaign_log.jsonl] [--seed 1]
"""
import json, os, sys, random, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engine import TalkEngine

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

REGIONS = ["altdorf", "karaz_a_karak", "eight_peaks", "naggarond", "lothern", "kislev",
           "wei_jin", "bastion", "sylvania", "skavenblight", "khemri", "sartosa",
           "athel_loren", "couronne", "nuln", "middenheim", "hexoatl", "itza"]

FACTIONS0 = [
    {"key": "empire",  "race": "empire",          "lord": "karl_franz"},
    {"key": "dwarfs",  "race": "dwarf",           "lord": "thorgrim"},
    {"key": "skaven",  "race": "skaven",          "lord": "queek"},
    {"key": "darkelf", "race": "dark_elf",        "lord": "malekith"},
    {"key": "kislev",  "race": "kislev",          "lord": "katarin"},
    {"key": "cathay",  "race": "cathay",          "lord": "miao_ying"},
    {"key": "khorne",  "race": "khorne_daemon",   "lord": "skarbrand"},
    {"key": "nurgle",  "race": "nurgle_daemon",   "lord": "ku_gath"},
    {"key": "vamp",    "race": "vampire_counts",  "lord": "mannfred"},
    {"key": "tombk",   "race": "tomb_kings",      "lord": "settra"},
    {"key": "highelf", "race": "high_elf",        "lord": "tyrion"},
    {"key": "greensk", "race": "greenskins",      "lord": "grimgor"},
    {"key": "ogre",    "race": "ogre_kingdoms",   "lord": "greasus"},
    {"key": "chaos",   "race": "warriors_of_chaos","lord": "archaon"},
    {"key": "bret",    "race": "bretonnia",       "lord": "louen"},
]

PLAYER = "dwarfs"  # 玩家视角派系


def weighted(rng, table):
    total = sum(w for _, w in table)
    r = rng.uniform(0, total)
    for item, w in table:
        r -= w
        if r <= 0:
            return item
    return table[-1][0]


class World:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.turn = 0
        self.factions = {f["key"]: dict(f, regions=6, alive=True,
                                       armies=2 + self.rng.randint(0, 2))
                         for f in FACTIONS0}
        for f, reg in zip(self.factions.values(), REGIONS):
            f["capital"] = reg
        self.wars = set()          # frozenset({a,b})
        self.allies = set()
        self.lord_alive = {f["key"]: f["lord"] for f in FACTIONS0}
        self.done = False
        self.winner = None

    def alive(self): return [k for k, v in self.factions.items() if v["alive"]]
    def at_war(self, a, b): return frozenset({a, b}) in self.wars
    def is_ally(self, a, b): return frozenset({a, b}) in self.allies

    def opponents_of(self, f):
        return [k for k in self.alive() if k != f and not self.is_ally(f, k)]

    def simulate_battle(self, atk, dfd, siege=False):
        """返回 battle 事件 ctx 序列 + 胜负方。"""
        R = self.rng
        la, ld = self.lord_alive.get(atk), self.lord_alive.get(dfd)
        evs = []
        rival = (la and ld) and {la, ld} in ({"thorgrim", "queek"}, {"malekith", "tyrion"})
        evs.append({"event": "battle_start",
                    "speaker": la or atk, "race": self.factions[atk]["race"],
                    "rival_pair": [la, ld] if rival else None,
                    "tags": [x for x in (la, ld) if x]})
        evs.append({"event": "first_blood"})
        if R.random() < 0.4:
            evs.append({"event": "monster_enters",
                        "side": "enemy" if dfd == PLAYER else "ally"})
        if rival and R.random() < 0.7:
            evs.append({"event": "lords_duel", "rival_pair": [la, ld]})
        if siege and R.random() < 0.6:
            evs.append({"event": "wall_breached"})
        if siege and R.random() < 0.5:
            evs.append({"event": "capture_point",
                        "side": "ally" if atk == PLAYER else "enemy",
                        "location": self.factions[dfd]["capital"]})
        for opt in ("cavalry_charge", "flank_engaged", "spell_cast", "ammo_depleted"):
            if R.random() < 0.35:
                evs.append({"event": opt,
                            "race": self.factions[R.choice([atk, dfd])]["race"]})
        if R.random() < 0.5:
            evs.append({"event": "army_half",
                        "side": "enemy" if dfd == PLAYER else "ally"})
        winner, loser = (atk, dfd) if R.random() < 0.55 else (dfd, atk)
        evs.append({"event": "mass_rout",
                    "side": "enemy" if loser == PLAYER else "ally",
                    "target_race": self.factions[loser]["race"]})
        if R.random() < 0.35:
            evs.append({"event": "lord_slain",
                        "side": "enemy" if loser == PLAYER else "ally",
                        "speaker": self.lord_alive.get(loser)})
            if R.random() < 0.4:
                self.lord_alive[loser] = None
        if R.random() < 0.6:
            evs.append({"event": "pursuit_phase"})
        evs.append({"event": "battle_result",
                    "speaker": self.lord_alive.get(winner) or winner,
                    "result": "victory" if winner == atk else "defeat"})
        return evs, winner, loser


def run(seed=1, out_path=None, verbose=False):
    rng = random.Random(seed + 777)
    eng = TalkEngine(seed=seed)
    w = World(seed)
    out_path = out_path or os.path.join(OUT_DIR, "campaign_log.jsonl")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    f = open(out_path, "w", encoding="utf-8")
    eid = [0]
    stats = {"turns": 0, "events": 0, "battles": 0, "wars": 0, "destroyed": 0}

    def emit(ctx, turn):
        eid[0] += 1
        ctx = {k: v for k, v in ctx.items() if v is not None}
        r = eng.fire(ctx)
        rec = {"id": eid[0], "turn": turn, "ctx": ctx,
               "line": r, "state": {"alive": len(w.alive())}}
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        stats["events"] += 1
        if verbose and r:
            print(f"T{turn:03d} [{r['channel']:>11}] {r['speaker']}: {r['text'][:50]}")
        return r

    # ---- 主循环 ----
    while not w.done and w.turn < 200:
        w.turn += 1
        stats["turns"] = w.turn
        player_lord = w.lord_alive.get(PLAYER)
        emit({"event": "turn_start", "speaker": player_lord}, w.turn)
        emit({"event": "world_tick",
              "lord": rng.choice([w.lord_alive[k] for k in w.alive() if w.lord_alive[k]] or ["某位领主"]),
              "region": rng.choice(REGIONS)}, w.turn)

        for fk in w.alive():
            fac = w.factions[fk]
            if not fac["alive"]:
                continue
            n = rng.choices([1, 2, 3], weights=[50, 35, 15])[0]
            for _ in range(n):
                act = weighted(rng, [
                    ("battle", 30 if any(w.at_war(fk, o) for o in w.alive()) else 0),
                    ("war_declared", 8), ("diplomacy", 10), ("siege", 12),
                    ("agent", 8), ("dev", 15), ("mechanic", 10), ("lord", 8), ("ambient", 9),
                ])
                if act == "battle":
                    foes = [o for o in w.alive() if w.at_war(fk, o)]
                    if not foes:
                        continue
                    dfd = rng.choice(foes)
                    stats["battles"] += 1
                    evs, winner, loser = w.simulate_battle(fk, dfd, siege=rng.random() < 0.3)
                    for e in evs:
                        emit(e, w.turn)
                    # 战局改变世界：后期升级加快收敛
                    loss_chance = 0.20 if w.turn < 80 else 0.45
                    if rng.random() < loss_chance:
                        lf = w.factions[loser]
                        lf["regions"] -= 1
                        if lf["armies"] > 0:
                            lf["armies"] -= 1
                            emit({"event": "army_destroyed", "faction": loser}, w.turn)
                        if lf["regions"] <= 0:
                            # 残国续命：前期半数概率苟住 1 块地，灭国放缓
                            if w.turn < 95 and rng.random() < 0.7:
                                lf["regions"] = 1
                            else:
                                lf["alive"] = False
                                stats["destroyed"] += 1
                                emit({"event": "faction_destroyed", "faction": loser,
                                      "race": lf["race"]}, w.turn)
                        elif winner == PLAYER and rng.random() < 0.5:
                            emit({"event": "city_lost", "location": lf["capital"],
                                  "side": "victor", "speaker": w.lord_alive.get(winner),
                                  "race": lf["race"]}, w.turn)
                elif act == "war_declared":
                    foes = [o for o in w.opponents_of(fk) if not w.at_war(fk, o)]
                    if foes:
                        tgt = rng.choice(foes)
                        w.wars.add(frozenset({fk, tgt}))
                        stats["wars"] += 1
                        emit({"event": "war_declared",
                              "speaker": w.lord_alive.get(fk) or "*",
                              "race": fac["race"],
                              "target_race": w.factions[tgt]["race"]}, w.turn)
                elif act == "diplomacy":
                    foes = [o for o in w.alive() if w.at_war(fk, o)]
                    others = [o for o in w.alive() if o != fk]
                    sub = weighted(rng, [("peace", 30 if foes else 0),
                                         ("ally", 20), ("break", 15), ("vassal", 8), ("confed", 6)])
                    if sub == "peace" and foes:
                        tgt = rng.choice(foes); w.wars.discard(frozenset({fk, tgt}))
                        emit({"event": "peace_treaty", "faction": fk, "target": tgt}, w.turn)
                    elif sub == "ally" and others:
                        tgt = rng.choice(others)
                        w.allies.add(frozenset({fk, tgt}))
                        emit({"event": "alliance_formed", "faction": fk, "target": tgt}, w.turn)
                    elif sub == "break":
                        emit({"event": "treaty_broken", "race": fac["race"], "faction": fk}, w.turn)
                    elif sub == "vassal":
                        emit({"event": "vassalized", "faction": fk}, w.turn)
                    elif sub == "confed" and others:
                        emit({"event": "confederation", "faction": fk,
                              "speaker": w.lord_alive.get(fk)}, w.turn)
                elif act == "siege":
                    emit({"event": "siege_started", "location": rng.choice(REGIONS)}, w.turn)
                    if rng.random() < 0.5:
                        emit({"event": "siege_lifted", "location": rng.choice(REGIONS)}, w.turn)
                elif act == "agent":
                    emit({"event": "agent_report",
                          "outcome": rng.choice(["success", "success", "fail"])}, w.turn)
                elif act == "dev":
                    emit({"event": weighted(rng, [("research_completed", 40),
                                                  ("building_completed", 40),
                                                  ("treasury_low", 20)]),
                          "tech": "新式军械", "building": "兵工厂",
                          "location": rng.choice(REGIONS)}, w.turn)
                elif act == "mechanic":
                    mech = {"dwarf": "grudge_cleared", "greenskins": "waaagh_called",
                            "nurgle_daemon": "plague_spread", "skaven": "ambush_sprung",
                            "chaos": "chaos_rift"}.get(fac["race"],
                            rng.choice(["corruption_spread", "rebellion", "idle_banter"]))
                    if mech == "waaagh_called":
                        emit({"event": mech, "speaker": w.lord_alive.get(fk)}, w.turn)
                    else:
                        emit({"event": mech, "race": fac["race"], "region": rng.choice(REGIONS)},
                             w.turn)
                elif act == "lord":
                    sub = weighted(rng, [("levelup", 35), ("lord_wounded", 15),
                                         ("lord_died", 8), ("lord_recruited", 20),
                                         ("quest", 22)])
                    if sub == "quest":
                        emit({"event": rng.choice(["quest_issued", "quest_completed"]),
                              "lord": w.lord_alive.get(fk) or fk, "quest": "传奇之证"}, w.turn)
                    elif sub == "lord_died" and w.lord_alive.get(fk):
                        emit({"event": "lord_died", "lord": w.lord_alive[fk],
                              "location": rng.choice(REGIONS),
                              "speaker": w.lord_alive.get(fk)}, w.turn)
                        w.lord_alive[fk] = None
                    else:
                        emit({"event": sub, "lord": w.lord_alive.get(fk) or fk,
                              "location": rng.choice(REGIONS)}, w.turn)
                else:
                    emit({"event": "idle_banter", "speaker": w.lord_alive.get(fk)}, w.turn)

        # 中后期大势倾轧：弱者自然衰落，保证战役有限时长内收敛
        if w.turn > 85 and w.turn % 15 == 0:
            weak = min((f for f in w.factions.values() if f["alive"]),
                       key=lambda f: f["regions"], default=None)
            if weak:
                weak["regions"] -= 1
                if weak["regions"] <= 0:
                    if w.turn < 95 and rng.random() < 0.6:
                        weak["regions"] = 1
                    else:
                        weak["alive"] = False
                        stats["destroyed"] += 1
                        emit({"event": "faction_destroyed", "faction": weak["key"],
                              "race": weak["race"]}, w.turn)

        # 胜利判定：只剩一家，或领头派系控制绝对多数且过了前期
        lead = max((f for f in w.factions.values() if f["alive"]),
                   key=lambda f: f["regions"], default=None)
        alive_regions = sum(f["regions"] for f in w.factions.values() if f["alive"])
        if len(w.alive()) <= 1 or \
           (lead and w.turn >= 110 and lead["regions"] >= 0.70 * max(1, alive_regions)):
            w.done = True
            w.winner = lead["key"] if lead else "the_ashes"  # 同归于尽：无人加冕
            emit({"event": "faction_destroyed", "faction": "其余诸邦",
                  "race": "chaos"}, w.turn)  # 终章播报
            emit({"event": "battle_result", "speaker": w.lord_alive.get(w.winner) or "narrator",
                  "result": "victory"}, w.turn)

    f.close()
    stats["winner"] = w.winner
    stats["out"] = out_path
    return stats


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    s = run(seed=a.seed, out_path=a.out, verbose=a.verbose)
    print(json.dumps(s, ensure_ascii=False, indent=2))
