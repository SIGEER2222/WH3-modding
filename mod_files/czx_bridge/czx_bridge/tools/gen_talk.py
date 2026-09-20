#!/usr/bin/env python3
"""gen_talk.py — 人设卡(chara_card_v2 JSON) + lorebook JSON → czx_talk_data.lua

用法:  python tools/gen_talk.py
输入:  content/personas/*.json   角色卡 V2（extensions.czx 放游戏键）
       content/*.json           lorebook（entries[].extensions.czx.kind = lore|line）
输出:  script/czx_talk_data.lua  CZX_PERSONA / CZX_LORE / CZX_TALK
lint:  字段缺失、禁写项、超长、重复触发键、selective 缺副键
"""
import json, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "script", "czx_talk_data.lua")
VALID_CHANNELS = {"dilemma", "event_feed", "battle_bark", "advisor"}
VALID_KINDS = {"lore", "line"}
MAX_LINE_LEN = 120  # bark 上限（字符）

errors, warnings = [], []

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'

def lua_table(d, indent=1):
    pad, pad2 = "  " * indent, "  " * (indent + 1)
    items = []
    for k, v in d.items():
        if isinstance(v, dict):
            items.append(f"{pad2}{k} = {lua_table(v, indent+1)}")
        elif isinstance(v, list):
            items.append(f"{pad2}{k} = {{ {', '.join(lua_str(x) if isinstance(x,str) else json.dumps(x) for x in v)} }}")
        elif isinstance(v, str):
            items.append(f"{pad2}{k} = {lua_str(v)}")
        elif isinstance(v, bool):
            items.append(f"{pad2}{k} = {'true' if v else 'false'}")
        else:
            items.append(f"{pad2}{k} = {v}")
    return "{\n" + ",\n".join(items) + "\n" + pad + "}"

def lint_persona(card_id, d):
    for f in ("name", "description", "personality", "system_prompt"):
        if not d.get(f):
            errors.append(f"persona {card_id}: 缺字段 {f}")
    ext = (d.get("extensions") or {}).get("czx") or {}
    for f in ("faction_key", "race"):
        if not ext.get(f):
            errors.append(f"persona {card_id}: extensions.czx 缺 {f}")
    if not ext.get("unit_key") and not ext.get("unit_keys"):
        errors.append(f"persona {card_id}: extensions.czx 缺 unit_key/unit_keys")
    if not d.get("mes_example"):
        warnings.append(f"persona {card_id}: mes_example 为空（无 few-shot 示例）")
    return ext

def lint_entry(src, idx, e):
    czx = (e.get("extensions") or {}).get("czx") or {}
    kind = czx.get("kind", "lore")
    tag = f"{src}#{idx}"
    if kind not in VALID_KINDS:
        errors.append(f"{tag}: 未知 kind={kind}")
    if not e.get("keys"):
        errors.append(f"{tag}: 无触发 keys")
    if e.get("selective") and not e.get("secondary_keys"):
        errors.append(f"{tag}: selective=true 但无 secondary_keys")
    content = e.get("content", "")
    if not content.strip():
        errors.append(f"{tag}: content 为空")
    if kind == "line":
        if len(e.get("keys", [])) > 1:
            warnings.append(f"{tag}: line 的 keys 应为单一事件名（当前 {e['keys']}）；上下文条件放 secondary_keys/cond")
        if czx.get("channel") not in VALID_CHANNELS:
            errors.append(f"{tag}: line 缺合法 channel（{sorted(VALID_CHANNELS)}）")
        if "speaker" not in czx:
            errors.append(f"{tag}: line 缺 speaker")
        if len(content) > MAX_LINE_LEN and "duo" not in str(czx.get("speaker")):
            warnings.append(f"{tag}: 台本超 {MAX_LINE_LEN} 字符（{len(content)}），确认是否拆条")

def main():
    personas = {}
    for p in sorted(glob.glob(os.path.join(ROOT, "content", "personas", "*.json"))):
        card = json.load(open(p, encoding="utf-8"))
        if card.get("spec") != "chara_card_v2":
            warnings.append(f"{os.path.basename(p)}: spec 不是 chara_card_v2，仍按 data 读取")
        d = card["data"]
        card_id = os.path.splitext(os.path.basename(p))[0]
        ext = lint_persona(card_id, d)
        personas[card_id] = {
            "unit_keys": ext.get("unit_keys") or ([ext["unit_key"]] if ext.get("unit_key") else []),
            "faction": ext.get("faction_key", ""),
            "race": ext.get("race", ""),
            "desc": d["description"],
            "personality": d["personality"],
            "voice_rules": d["system_prompt"],
            "examples": [l.strip() for l in d.get("mes_example", "").split("<START>") if l.strip()],
            "openers": d.get("alternate_greetings", []),
            "first_line": d.get("first_mes", ""),
            "forbidden": ext.get("forbidden", []),
            "ticks": ext.get("voice_ticks", []),
            "tags": d.get("tags", []),
        }

    lore_entries, talk_entries = [], []
    seen_triggers = {}
    for p in sorted(glob.glob(os.path.join(ROOT, "content", "*.json"))):
        book = json.load(open(p, encoding="utf-8"))
        for idx, e in enumerate(book.get("entries", [])):
            if not e.get("enabled", True):
                continue
            lint_entry(os.path.basename(p), idx, e)
            czx = (e.get("extensions") or {}).get("czx") or {}
            tkey = (tuple(sorted(e.get("keys", []))), tuple(sorted(e.get("secondary_keys", []))))
            is_line = czx.get("kind") == "line"
            # line 允许同触发键共存（变体轮转池）；lore 重复才告警
            if tkey in seen_triggers and not is_line:
                warnings.append(f"{os.path.basename(p)}#{idx}: 触发键与 {seen_triggers[tkey]} 重复")
            seen_triggers[tkey] = f"{os.path.basename(p)}#{idx}"
            row = {
                "keys": e.get("keys", []),
                "keys2": e.get("secondary_keys", []),
                "selective": bool(e.get("selective")),
                "constant": bool(e.get("constant")),
                "content": e["content"],
                "order": e.get("insertion_order", 100),
                "priority": e.get("priority", 50),
            }
            if czx.get("kind") == "line":
                row["speaker"] = czx.get("speaker", "")
                row["channel"] = czx.get("channel", "")
                if czx.get("cond"):
                    row["cond"] = czx["cond"]
                if czx.get("template"):
                    row["template"] = True
                talk_entries.append(row)
            else:
                lore_entries.append(row)

    def emit(name, rows):
        body = ",\n".join("  " + lua_table(r) for r in rows)
        return f"{name} = {{\n{body}\n}}\n"

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("-- AUTO-GENERATED by gen_talk.py — 勿手改，改 content/*.json 后重跑\n")
        f.write("CZX_PERSONA = {\n")
        for cid, p in personas.items():
            f.write(f"  {cid} = {lua_table(p)},\n")
        f.write("}\n\n")
        f.write(emit("CZX_LORE", lore_entries))
        f.write("\n")
        f.write(emit("CZX_TALK", talk_entries))

    print(f"OK: {len(personas)} personas, {len(lore_entries)} lore, {len(talk_entries)} lines -> {OUT}")
    for w in warnings: print("WARN:", w)
    for e in errors: print("ERR :", e)
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
