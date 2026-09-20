#!/usr/bin/env python3
"""talk_app.py — czx talk 外部应用 CLI。

用法：
  python talk_app.py list                     列出人设/事件类型
  python talk_app.py fire --event war_declared --speaker malekith --target-race high_elf
  python talk_app.py chat <persona_id>        与领主对话（LLM 在线才生效，否则提示）
  python talk_app.py demo scenarios/xxx.json  跑剧本（事件序列 → 逐条输出）
  python talk_app.py prompt --event battle_start --speaker malekith   预览拼好的 LLM prompt
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from engine import TalkEngine
import llm


def cmd_list(eng, _):
    print(f"personas ({len(eng.personas)}):")
    for pid, p in eng.personas.items():
        print(f"  {pid:14s} {p['name']:30s} race={p['race']} unit_keys={len(p['unit_keys'])}")
    evs = sorted({k for ln in eng.lines for k in ln["keys"]})
    print(f"events ({len(evs)}): {', '.join(evs)}")
    print(f"lore entries: {len(eng.lore)} | talk lines: {len(eng.lines)}")


def ctx_from_args(a):
    ctx = {"event": a.event}
    for f in ("speaker", "race", "target_race", "side", "location", "result", "outcome"):
        v = getattr(a, f.replace("-", "_"), None)
        if v:
            ctx[f] = v
    if getattr(a, "rival", None):
        ctx["rival_pair"] = a.rival.split(",")
    if getattr(a, "tag", None):
        ctx["tags"] = a.tag.split(",")
    return ctx


def cmd_fire(eng, a):
    ctx = ctx_from_args(a)
    r = eng.fire(ctx)
    if not r:
        print("(no line matched)"); return 1
    print(f"[{r['channel']}] {r['speaker']}: {r['text']}")
    if a.llm:
        prompt = eng.assemble_prompt(ctx, ctx.get("speaker"))
        out = llm.chat(prompt["system"], prompt["user"])
        print(f"[llm] {out or '(llm unavailable, script fallback above)'}")
    return 0


def cmd_prompt(eng, a):
    ctx = ctx_from_args(a)
    p = eng.assemble_prompt(ctx, ctx.get("speaker"))
    print("=== system ==="); print(p["system"])
    print("=== user ==="); print(p["user"])
    return 0


def cmd_chat(eng, a):
    pid = a.persona
    if pid not in eng.personas:
        print(f"unknown persona: {pid}"); return 1
    p = eng.personas[pid]
    print(f"== {p['name']} ==  (exit 退出)")
    print(p.get("first_line") or "")
    history = []
    while True:
        try:
            q = input("你: ").strip()
        except EOFError:
            break
        if q in ("exit", "quit", ""):
            break
        prompt = eng.assemble_prompt({"event": "chat", "speaker": pid}, pid)
        hist = "".join(history[-6:])
        out = llm.chat(prompt["system"] + f"\n对话历史：{hist}",
                       f"玩家说：{q}\n以 {p['name']} 口吻回应（≤3句）。")
        if out is None:
            print(f"{p['name']}: [无 LLM 后端 —— 配置 CZX_LLM_BASE/CZX_LLM_KEY 后启用]")
            continue
        history.append(f"玩家:{q}\n{p['name']}:{out}\n")
        print(f"{p['name']}: {out}")
    return 0


def cmd_demo(eng, a):
    path = a.scenario
    if not os.path.isabs(path):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), path)
    sc = json.load(open(path, encoding="utf-8"))
    print(f"===== {sc.get('title', path)} =====")
    for i, step in enumerate(sc.get("steps", [])):
        ctx = dict(step.get("ctx", {}))
        ctx.setdefault("event", step.get("event"))
        r = eng.fire(ctx)
        if r:
            print(f"{i+1:02d} [{r['channel']:>11}] {r['speaker']}: {r['text']}")
        else:
            print(f"{i+1:02d} [  (无台本命中)] {ctx.get('event')}")
    return 0


def main():
    ap = argparse.ArgumentParser(description="czx talk external app")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list")

    def add_ctx(sp):
        sp.add_argument("--event", required=True)
        sp.add_argument("--speaker"); sp.add_argument("--race")
        sp.add_argument("--target-race"); sp.add_argument("--side")
        sp.add_argument("--location"); sp.add_argument("--result")
        sp.add_argument("--outcome"); sp.add_argument("--rival")
        sp.add_argument("--tag")

    sp = sub.add_parser("fire"); add_ctx(sp); sp.add_argument("--llm", action="store_true")
    sp = sub.add_parser("prompt"); add_ctx(sp)
    sp = sub.add_parser("chat"); sp.add_argument("persona")
    sp = sub.add_parser("demo"); sp.add_argument("scenario")

    a = ap.parse_args()
    eng = TalkEngine()
    return {"list": cmd_list, "fire": cmd_fire, "prompt": cmd_prompt,
            "chat": cmd_chat, "demo": cmd_demo}[a.cmd](eng, a) or 0


if __name__ == "__main__":
    sys.exit(main())
