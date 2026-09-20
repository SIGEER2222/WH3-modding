#!/usr/bin/env python3
"""test_talk.py — 台本选择器的参考实现 + 场景测试。

模拟运行时逻辑：
  context tags = {event, speaker, race, target_race, side, location, result, outcome, rival_pair...}
  命中规则：keys ∩ tags ≠ ∅；selective 时要求 secondary_keys ⊆ tags（AND_ALL）；
            extensions.czx.cond 全字段须与 context 相等。
  排序：命中 cond 字段数 + 命中副键数 → priority 降序 → order 升序；同分轮转。
"""
import json, glob, os, sys, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
random.seed(42)

def load_lines():
    out = []
    for p in glob.glob(os.path.join(ROOT, "content", "*.json")):
        book = json.load(open(p, encoding="utf-8"))
        for i, e in enumerate(book.get("entries", [])):
            if not e.get("enabled", True):
                continue
            czx = (e.get("extensions") or {}).get("czx") or {}
            if czx.get("kind") != "line":
                continue
            out.append({
                "src": f"{os.path.basename(p)}#{i}",
                "keys": set(e.get("keys", [])),
                "keys2": set(e.get("secondary_keys", [])),
                "selective": bool(e.get("selective")),
                "content": e["content"],
                "order": e.get("insertion_order", 100),
                "priority": e.get("priority", 50),
                "speaker": czx.get("speaker", ""),
                "channel": czx.get("channel", ""),
                "cond": czx.get("cond", {}),
            })
    return out

def build_tags(ctx):
    tags = {ctx["event"]}
    for f in ("speaker", "race", "target_race", "side", "location", "result", "outcome"):
        if ctx.get(f):
            tags.add(ctx[f])
    for x in ctx.get("rival_pair", []):
        tags.add(x)
    if ctx.get("tags"):
        tags |= set(ctx["tags"])
    return tags

def select(lines, ctx, verbose=False):
    tags = build_tags(ctx)
    cands = []
    for ln in lines:
        if not (ln["keys"] & tags):
            continue
        if ln["selective"] and not (ln["keys2"] <= tags):
            continue
        cond = ln["cond"]
        if cond and not all(ctx.get(k) == v for k, v in cond.items()):
            continue
        spec = len(cond) + len(ln["keys2"] & tags)
        cands.append((spec, -ln["priority"], ln["order"], ln))
    if not cands:
        return None, []
    cands.sort(key=lambda c: (-c[0], c[1], c[2]))
    top = cands[0][0]
    pool = [c for c in cands if c[0] == top]  # 同特异度池内轮转
    pick = random.choice(pool)
    if verbose:
        for spec, negp, order, ln in cands[:5]:
            mark = "*" if ln is pick[3] else " "
            print(f"   {mark} spec={spec} pri={-negp} ord={order} [{ln['src']}] {ln['content'][:40]}")
    return pick[3], cands

def run_case(name, ctx, expect_sub=None, expect_speaker=None):
    print(f"\n[{name}] {ctx}")
    ln, _ = select(LINES, ctx, verbose=True)
    if ln is None:
        print("   [X] no match"); FAILURES.append(name); return
    ok = True
    if expect_sub and expect_sub not in ln["content"]:
        ok = False
    if expect_speaker and ln["speaker"] != expect_speaker:
        ok = False
    print(f"   {'[OK]' if ok else '[X]'} {ln['speaker']}@{ln['channel']}: {ln['content'][:60]}")
    if not ok:
        FAILURES.append(name)

LINES = load_lines()
FAILURES = []

print(f"loaded {len(LINES)} talk lines")

# --- T01 宣战檄文 ---
run_case("T01 巫王对高精(恩怨)", {"event": "war_declared", "speaker": "malekith",
         "race": "dark_elf", "target_race": "high_elf"}, expect_speaker="malekith",
         expect_sub="圣火")
run_case("T01 斯卡布兰德对基斯里夫", {"event": "war_declared", "speaker": "skarbrand",
         "race": "khorne_daemon", "target_race": "kislev"}, expect_sub="血")
run_case("T01 索林对鼠人", {"event": "war_declared", "speaker": "thorgrim",
         "race": "dwarf", "target_race": "skaven"}, expect_sub="八峰山")
run_case("T01 混沌无名领主", {"event": "war_declared", "speaker": "*",
         "race": "chaos", "target_race": "empire"}, expect_speaker="*")

# --- T02 阵前喊话 ---
run_case("T02 索林vs奎克(恩怨对白)", {"event": "battle_start",
         "rival_pair": ["thorgrim", "queek"], "tags": {"thorgrim", "queek"}},
         expect_sub="八峰山")
run_case("T02 巫王vs泰里昂", {"event": "battle_start",
         "rival_pair": ["malekith", "tyrion"], "tags": {"malekith", "tyrion"}},
         expect_sub="守护者")
run_case("T02 单体领主(震旦)", {"event": "battle_start", "speaker": "miao_ying",
         "race": "cathay"}, expect_speaker="miao_ying")

# --- T03 名城陷落 ---
run_case("T03 贝勒加攻八峰山", {"event": "city_lost", "location": "eight_peaks",
         "speaker": "belegar", "side": "victor"}, expect_sub="回家了")
run_case("T03 巫王失纳迦隆德", {"event": "city_lost", "location": "naggarond",
         "speaker": "malekith", "side": "loser"}, expect_sub="圣火")

# --- T04 领主阵亡 ---
run_case("T04 敌将死", {"event": "lord_slain", "side": "enemy"}, expect_sub="压上去")
run_case("T04 我方曼弗雷德倒", {"event": "lord_slain", "speaker": "mannfred",
         "side": "ally"}, expect_speaker="mannfred")

# --- T05 世界彼端（模板轮转） ---
run_case("T05 回合末播报", {"event": "world_tick"}, expect_speaker="narrator")

# --- T06-T10 ---
run_case("T06 敌方巨兽", {"event": "monster_enters", "side": "enemy"}, expect_sub="炮兵")
run_case("T07 事务官成功", {"event": "agent_report", "outcome": "success"}, expect_sub="事成")
run_case("T08 矮人清账", {"event": "grudge_cleared", "race": "dwarf"}, expect_sub="账")
run_case("T09 鼠人溃逃", {"event": "mass_rout", "side": "enemy",
         "target_race": "skaven"}, expect_sub="鼠人")
run_case("T10 索林大胜", {"event": "battle_result", "speaker": "thorgrim",
         "result": "victory"}, expect_speaker="thorgrim")

# --- 战役层扩展事件 ---
run_case("议和", {"event": "peace_treaty", "faction": "empire", "target": "kislev"},
         expect_speaker="narrator")
run_case("矮人被毁约", {"event": "treaty_broken", "race": "dwarf"}, expect_sub="仇恨之书")
run_case("灭族讣告", {"event": "faction_destroyed", "faction": "empire"},
         expect_sub="抹除")
run_case("围城中", {"event": "siege_started", "location": "naggarond"},
         expect_sub="围城")
run_case("裂缝开启", {"event": "chaos_rift", "region": "kislev"},
         expect_sub="裂缝")
run_case("Waaagh 召唤", {"event": "waaagh_called", "speaker": "grimgor"},
         expect_speaker="grimgor")
run_case("回合开始·赛特拉", {"event": "turn_start", "speaker": "settra"},
         expect_speaker="settra")

# --- 战斗层扩展事件 ---
run_case("首血", {"event": "first_blood"}, expect_sub="接战")
run_case("我方增援", {"event": "reinforcements", "side": "ally"}, expect_sub="增援")
run_case("领主单挑·巫王对泰里昂", {"event": "lords_duel",
         "rival_pair": ["malekith", "tyrion"]}, expect_sub="千年的账")
run_case("城墙破口", {"event": "wall_breached"}, expect_sub="城墙")
run_case("弹药见底", {"event": "ammo_depleted"}, expect_sub="弹药")
run_case("平局", {"event": "battle_result", "result": "draw"}, expect_sub="两败俱伤")

print(f"\n{'='*50}")
if FAILURES:
    print(f"FAILED {len(FAILURES)}: {FAILURES}"); sys.exit(1)
print("ALL PASS")
