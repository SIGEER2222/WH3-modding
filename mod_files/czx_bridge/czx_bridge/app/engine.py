"""engine.py — 外部台本引擎：加载 content/ → 事件选择 → 台本/LLM 双模输出。

独立运行：不依赖游戏。游戏事件从桥日志/输入文件喂入，也可手工触发。
"""
import json, glob, os, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, "content")


class TalkEngine:
    def __init__(self, content_dir=CONTENT, seed=None):
        self.personas = {}     # id -> {unit_keys, race, personality, voice_rules, examples, openers, forbidden, ticks}
        self.lore = []         # lorebook lore entries
        self.lines = []        # talk line entries
        self.used = {}         # "event|speaker" -> set(idx) 轮转池
        self.last_fired = {}   # event -> count（外部冷却交给调用方/daemon）
        self.rng = random.Random(seed)
        self._load(content_dir)

    # ---------- 加载 ----------
    def _load(self, content_dir):
        for p in sorted(glob.glob(os.path.join(content_dir, "personas", "*.json"))):
            card = json.load(open(p, encoding="utf-8"))
            d = card["data"]
            cid = os.path.splitext(os.path.basename(p))[0]
            ext = (d.get("extensions") or {}).get("czx") or {}
            keys = ext.get("unit_keys") or ([ext["unit_key"]] if ext.get("unit_key") else [])
            self.personas[cid] = {
                "name": d.get("name", cid),
                "unit_keys": keys,
                "faction": ext.get("faction_key", ""),
                "race": ext.get("race", ""),
                "desc": d.get("description", ""),
                "personality": d.get("personality", ""),
                "voice_rules": d.get("system_prompt", ""),
                "examples": [l.strip() for l in d.get("mes_example", "").split("<START>") if l.strip()],
                "openers": d.get("alternate_greetings", []),
                "first_line": d.get("first_mes", ""),
                "forbidden": ext.get("forbidden", []),
                "ticks": ext.get("voice_ticks", []),
                "tags": d.get("tags", []),
            }
        for p in sorted(glob.glob(os.path.join(content_dir, "*.json"))):
            book = json.load(open(p, encoding="utf-8"))
            for e in book.get("entries", []):
                if not e.get("enabled", True):
                    continue
                czx = (e.get("extensions") or {}).get("czx") or {}
                row = {
                    "keys": e.get("keys", []),
                    "keys2": e.get("secondary_keys", []),
                    "selective": bool(e.get("selective")),
                    "constant": bool(e.get("constant")),
                    "content": e["content"],
                    "order": e.get("insertion_order", 100),
                    "priority": e.get("priority", 50),
                    "kind": czx.get("kind", "lore"),
                    "speaker": czx.get("speaker", ""),
                    "channel": czx.get("channel", ""),
                    "cond": czx.get("cond", {}),
                    "template": bool(czx.get("template")),
                    "src": f"{os.path.basename(p)}:{book.get('entries',[]).index(e)}",
                }
                (self.lines if row["kind"] == "line" else self.lore).append(row)

    # ---------- 选择 ----------
    @staticmethod
    def build_tags(ctx):
        tags = {ctx.get("event", "")}
        for f in ("speaker", "race", "target_race", "side", "location", "result", "outcome"):
            if ctx.get(f):
                tags.add(ctx[f])
        tags.update(ctx.get("rival_pair", []) or [])
        tags.update(ctx.get("tags", []) or [])
        return tags

    @staticmethod
    def _cond_match(cond, ctx):
        if not cond:
            return True, 0
        for k, v in cond.items():
            cv = ctx.get(k)
            if isinstance(cv, list) and isinstance(v, list):
                if sorted(cv) != sorted(v):  # 数组 cond = 集合相等（如 rival_pair）
                    return False, 0
            elif cv not in (v if isinstance(v, list) else [v]):
                return False, 0
        return True, len(cond)

    def select(self, ctx):
        tags = self.build_tags(ctx)
        cands = []
        for i, ln in enumerate(self.lines):
            if not set(ln["keys"]) & tags:
                continue
            if ln["selective"] and not set(ln["keys2"]) <= tags:
                continue
            ok, cn = self._cond_match(ln["cond"], ctx)
            if not ok:
                continue
            spec = cn + len(set(ln["keys2"]) & tags)
            cands.append((spec, ln["priority"], -ln["order"], i, ln))
        if not cands:
            return None
        cands.sort(key=lambda c: (-c[0], -c[1], -c[2]))
        top = cands[0][0]
        pool = [c for c in cands if c[0] == top]
        pkey = f"{ctx.get('event','')}|{ctx.get('speaker','')}"
        used = self.used.setdefault(pkey, set())
        fresh = [c for c in pool if c[3] not in used]
        if not fresh:
            used.clear()
            fresh = pool
        pick = self.rng.choice(fresh)
        used.add(pick[3])
        return pick[4]

    def fill(self, text, ctx):
        for k, v in (ctx or {}).items():
            text = text.replace("{" + k + "}", str(v))
        return text

    def fire(self, ctx):
        ln = self.select(ctx)
        if not ln:
            return None
        return {"speaker": ln["speaker"], "channel": ln["channel"],
                "text": self.fill(ln["content"], ctx), "src": ln["src"]}

    # ---------- LLM prompt 组装（在线层用；无后端时返回 prompt 供预览） ----------
    def assemble_prompt(self, ctx, persona_id=None):
        tags = self.build_tags(ctx)
        parts = []
        for e in self.lore:
            if e["constant"] or (set(e["keys"]) & tags) or (set(e["keys2"]) & tags):
                parts.append(e["content"])
        sys_parts = [p for p in parts]  # 世界书条目
        if persona_id and persona_id in self.personas:
            p = self.personas[persona_id]
            sys_parts.append(f"角色：{p['name']}。{p['desc']}")
            sys_parts.append(f"口吻：{p['personality']} {p['voice_rules']}")
            if p["examples"]:
                sys_parts.append("示例台词：\n" + "\n".join(p["examples"]))
        sys_parts.append(f"当前事件：{ctx.get('event')}；上下文：{json.dumps(ctx, ensure_ascii=False)}")
        return {"system": "\n".join(sys_parts),
                "user": f"以该角色口吻产出一句台词（≤2句，中文，禁现代梗）。"}
