#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""多角色接力编排：角色 = 本地 devin 会话，共享状态 = board.json，对话面 = Slack 频道。

- 角色数量任意（board.json 的 roles），与 Slack app 无关；
- Slack 只用现有 OpenAB 的 bot 身份发言，消息按角色打标签，每个任务一个线程；
- board.json 只由持锁的命令写入（run 循环，或 task/retry/close），角色只通过固定结尾 RELAY_RESULT 汇报交接；
- 每个任务里每个角色各自一个独立 devin 会话（cwd = WH3 根目录），权限模式按角色配置；任务之间互不共享会话。

用法（Windows Python313，在 WH3 根目录）：
    python tools/agent_relay.py task "标题" [--brief "说明"]
    python tools/agent_relay.py run [--max-turns 8] [--once]
    python tools/agent_relay.py status
    python tools/agent_relay.py stop | resume
    python tools/agent_relay.py retry T-0001 [--owner 审计]          阻塞任务恢复到指定角色
    python tools/agent_relay.py close T-0001 [--status done|blocked] [--note "..."]   人工关闭任务
Slack 频道里人类可发：STOP / 停止（编排器观察到的 STOP 不再派发新回合）、新任务：标题（建任务），其余顶层消息进当前任务的补充；在任务线程里回复 STOP / 停止同样生效。
"""
import argparse
import json
import msvcrt
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = Path(__file__).resolve().parent / "_agent_relay"
BOARD = STATE / "board.json"
HEARTBEAT = STATE / "heartbeat.json"
STOP_FILE = STATE / "STOP"
LOCK_FILE = STATE / "runner.lock"
TURNS = STATE / "turns"
ENV_FILE = Path(r"\\wsl.localhost\Ubuntu\home\sigeer\openab\openab.env")
DB = Path(os.environ["APPDATA"]) / "Devin" / "cli" / "sessions.db"
DEVIN_FALLBACK = (r"E:\Users\22448\AppData\Local\Programs\Devin\resources\app"
                  r"\extensions\windsurf\devin\bin\devin.exe")
CHANNEL = "C0CBH3WDXBR"
HUMAN_ID = "U0CBWG27THC"
STATUSES = {"handoff", "done", "blocked"}
DEFAULT_ROLES = {
    "生产": {"perm": "smart", "duties": "按任务说明完成工作，可读写 WH3 仓库（遵守 AGENTS.md）；只读任务不得写文件。完成后 status=handoff、to=审计。"},
    "审计": {"perm": "auto", "duties": "只读审查生产的结论：逐条核对其引用的文件、行号与事实是否属实，有无越界。不得修改文件。通过则 status=handoff、to=验证；不通过则 status=handoff、to=生产，并写清修改点。"},
    "验证": {"perm": "auto", "duties": "用读取/搜索工具复核关键证据（行号、字段名、路径是否存在、规则文字是否一致）。不得修改文件。证据一致则 status=done、to=none；不一致则 status=handoff、to=生产。"},
}
READ_RULE = "本轮只读：只用读取类工具（Read/Grep），文件路径以任务说明为准，直接用 Read 按路径打开；不使用 shell，不联网（不用 webfetch），不查询 memory 服务，不写文件。"
WRITE_RULE = "本轮可写文件，但只能写任务说明或「归属边界」列出的文件；只读任务不写文件；不联网，不查询 memory 服务，尽量不用 shell。"
RESULT_SPEC = ("{rule} 搜索工具可能看不到被 git 忽略的文件，以 Read 为准。若任何工具被拒绝，不要改用其他网络或命令工具，直接以 status=blocked 结束并说明原因。"
               "若本轮会改动或交付文件，回复开头先写「归属边界：」并列出文件清单，审计据此核对是否越界。"
               "回复的最后一段必须是固定结尾（不得省略，不得放进代码块）：\n"
               "RELAY_RESULT\nstatus: handoff|done|blocked\nto: {names}|none\nsummary: 一句话结论\n"
               "交给其他角色用 status=handoff；任务完成用 status=done 且 to=none；需要人类决策或无法完成用 status=blocked。")


def now():
    return datetime.now().isoformat(timespec="seconds")


def load_board():
    b = json.loads(BOARD.read_text(encoding="utf-8")) if BOARD.exists() else {"roles": {}, "tasks": [], "seq": 0, "cursor": ""}
    for k, v in DEFAULT_ROLES.items():
        b["roles"].setdefault(k, {}).update(perm=v["perm"], duties=v["duties"])
    for r in b["roles"].values():
        r.pop("sid", None)
        r.setdefault("perm", "auto")
        r.setdefault("duties", "按任务说明完成工作，只读，不修改文件。")
    return b


def save_board(b):
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = BOARD.with_suffix(".tmp")
    tmp.write_text(json.dumps(b, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, BOARD)


def heartbeat(**kw):
    STATE.mkdir(parents=True, exist_ok=True)
    HEARTBEAT.write_text(json.dumps({"ts": now(), "pid": os.getpid(), **kw}, ensure_ascii=False), encoding="utf-8")


def token():
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        if line.startswith("SLACK_BOT_TOKEN="):
            return line.split("=", 1)[1].strip().strip("\"'")
    raise SystemExit("openab.env 中没有 SLACK_BOT_TOKEN")


def slack(method, tok, **params):
    query = urllib.parse.urlencode(params)
    get = method in ("conversations.history", "conversations.replies")
    url = f"https://slack.com/api/{method}" + (f"?{query}" if get else "")
    req = urllib.request.Request(url, data=None if get else query.encode("utf-8"),
                                 headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req, timeout=20) as r:
        j = json.loads(r.read().decode("utf-8"))
    if not j.get("ok"):
        raise RuntimeError(f"{method} 失败：{j.get('error')}")
    return j


def post(tok, text, thread=None):
    params = {"channel": CHANNEL, "text": text[:12000]}
    if thread:
        params["thread_ts"] = thread
    return slack("chat.postMessage", tok, **params)["ts"]


def thread_msgs(tok, thread_ts, page=200):
    seen, cursor = {}, ""
    while True:
        j = slack("conversations.replies", tok, channel=CHANNEL, ts=thread_ts, limit=page,
                  **({"cursor": cursor} if cursor else {}))
        for m in j["messages"]:
            seen.setdefault(m["ts"], m)
        cursor = j.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            return sorted(seen.values(), key=lambda m: float(m["ts"]))


def thread_context(tok, thread_ts, budget=16000, per_msg=8000):
    msgs = thread_msgs(tok, thread_ts)
    picked, used = [], 0
    for m in reversed(msgs):
        body = m.get("text", "")
        if len(body) > per_msg:
            body = body[:per_msg] + "…（已截断，完整见 tools/_agent_relay/turns/）"
        text = ("[人类] " if m.get("user") == HUMAN_ID else "[机器人] ") + body
        if used + len(text) > budget:
            break
        picked.append(text)
        used += len(text)
    picked.reverse()
    head = (f"（线程更早的 {len(msgs) - len(picked)} 条未放入，完整输出见 tools/_agent_relay/turns/）\n"
            if len(picked) < len(msgs) else "")
    return head + "\n\n".join(picked)


def note(tok, t, text):
    if t.get("thread"):
        post(tok, f"[编排] {text}", thread=t["thread"])


def thread_stop(b, tok):
    t = active(b)
    if not t or not t.get("thread"):
        return
    for m in thread_msgs(tok, t["thread"]):
        if m.get("user") != HUMAN_ID or float(m["ts"]) <= float(t.get("seen", 0)):
            continue
        t["seen"] = m["ts"]
        if m.get("text", "").strip().lower() in ("stop", "停止"):
            STOP_FILE.parent.mkdir(parents=True, exist_ok=True)
            STOP_FILE.touch()
            post(tok, "已收到线程内停止指令，编排器在下一轮前停下。", thread=t["thread"])


def active(b):
    return next((t for t in b["tasks"] if t["status"] == "doing"), None)


def create_task(b, tok, title, brief="", owner="生产"):
    b["seq"] += 1
    tid = f"T-{b['seq']:04d}"
    thread = post(tok, f"[任务] {tid} {title}" + (f"\n{brief}" if brief else ""))
    b["tasks"].append({"id": tid, "title": title, "brief": brief, "status": "doing", "owner": owner,
                       "round": 1, "max_rounds": 3, "thread": thread, "history": [], "inbox": [], "created": now()})
    return tid


def poll_human(b, tok):
    cursor = float(b["cursor"] or 0)
    seen, cur = {}, ""
    while True:
        j = slack("conversations.history", tok, channel=CHANNEL, oldest=str(cursor), limit=200,
                  **({"cursor": cur} if cur else {}))
        for m in j["messages"]:
            seen.setdefault(m["ts"], m)
        cur = j.get("response_metadata", {}).get("next_cursor", "")
        if not cur:
            break
    for m in sorted(seen.values(), key=lambda m: float(m["ts"])):
        if float(m["ts"]) <= cursor or m.get("user") != HUMAN_ID:
            continue
        b["cursor"] = m["ts"]
        text = m.get("text", "").strip()
        if text.lower() in ("stop", "停止"):
            STOP_FILE.parent.mkdir(parents=True, exist_ok=True)
            STOP_FILE.touch()
            post(tok, "已收到停止指令，编排器在下一轮前停下。")
        elif text.startswith(("新任务：", "新任务:")):
            create_task(b, tok, text.split("：" if "：" in text else ":", 1)[1].strip())
        elif (t := active(b)):
            t["inbox"].append(text)


def build_prompt(b, t, role, ctx):
    parts = []
    if not t.get("sids", {}).get(role):
        parts.append(f"【角色设定】本会话只服务于任务 {t['id']} 的「{role}」角色。职责：{b['roles'][role]['duties']}"
                     "本轮只做本角色的事，不替其他角色决定。")
    parts.append(f"任务 {t['id']}：{t['title']}")
    if t["brief"]:
        parts.append(f"任务说明：{t['brief']}")
    parts.append("【任务线程】以下是本任务在 Slack 线程里的完整对话（按时间顺序）。发言前先读完；其他角色的结论以原文为准：\n" + ctx)
    if t["inbox"]:
        parts.append("人类补充：" + "；".join(t["inbox"]))
    parts.append(RESULT_SPEC.format(rule=READ_RULE if b["roles"][role]["perm"] == "auto" else WRITE_RULE,
                                    names="|".join(b["roles"])))
    return "\n\n".join(parts)


def parse(out):
    i = out.rfind("RELAY_RESULT")
    if i < 0:
        return None, out.strip()
    kv = {}
    for line in out[i:].splitlines()[1:]:
        m = re.match(r"^\W*(status|to|summary)\W*[:：]\s*(.*?)\W*$", line.strip(), re.I)
        if m:
            kv[m.group(1).lower()] = m.group(2).strip()
    kv["status"] = kv.get("status", "").lower()
    return (kv if kv["status"] in STATUSES else None), out[:i].strip()


def route(b, t, role, res):
    to = res.get("to", "none")
    t["history"].append({"ts": now(), "role": role, "status": res["status"], "to": to,
                         "summary": res.get("summary", "")})
    if res["status"] == "done" and to in ("none", ""):
        t["status"], t["owner"] = "done", ""
    elif res["status"] == "handoff" and to in b["roles"] and to != role:
        t["round"] += 1 if to == "生产" and role != "生产" else 0
        if t["round"] > t["max_rounds"]:
            t["history"].append({"ts": now(), "role": "编排器", "status": "blocked", "to": "none",
                                 "summary": f"超过 {t['max_rounds']} 轮，阻塞"})
            t["status"], t["owner"] = "blocked", ""
        else:
            t["owner"] = to
    else:
        t["status"], t["owner"] = "blocked", ""


def devin_exe():
    return shutil.which("devin") or DEVIN_FALLBACK


def newest_session():
    con = sqlite3.connect(DB.as_uri() + "?mode=ro", uri=True, timeout=5)
    try:
        for sid, wd in con.execute("select id, working_directory from sessions where coalesce(hidden,0)=0"
                                   " order by created_at desc limit 30"):
            if os.path.normcase(wd or "") == os.path.normcase(str(ROOT)):
                return sid
    finally:
        con.close()
    raise RuntimeError("未找到新建的角色会话")


def turn(devin, sid, perm, prompt):
    base = [devin, "-r", sid, "-p"] if sid else [devin, "-p"]
    r = subprocess.run(base + ["--permission-mode", perm, "--", prompt], cwd=ROOT,
                       capture_output=True, encoding="utf-8", errors="replace", timeout=1800)
    if r.returncode:
        raise RuntimeError(f"devin 退出码 {r.returncode}：{(r.stderr or '')[-300:]}")
    return r.stdout


def lock_or_fail():
    STATE.mkdir(parents=True, exist_ok=True)
    lock = open(LOCK_FILE, "a+")
    try:
        msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
    except OSError:
        lock.close()
        raise SystemExit("编排循环正在运行：先 stop 并等它退出，再执行本命令")
    return lock


def cmd_run(a):
    if STOP_FILE.exists():
        raise SystemExit("存在 STOP 文件，先执行 resume")
    lock = lock_or_fail()
    tok, devin, b = token(), devin_exe(), load_board()
    b["cursor"] = b["cursor"] or f"{time.time():.6f}"
    turns = 0
    try:
        while turns < a.max_turns and not STOP_FILE.exists():
            poll_human(b, tok)
            thread_stop(b, tok)
            t = active(b)
            if t is None or STOP_FILE.exists():
                print("没有进行中的任务" if t is None else "收到 STOP，本轮不再派发", flush=True)
                break
            role = t["owner"]
            if not t["thread"]:
                t["thread"] = post(tok, f"[任务] {t['id']} {t['title']}")
            heartbeat(task=t["id"], role=role, turns=turns)
            save_board(b)
            ok = False
            try:
                r = b["roles"][role]
                sid = t.setdefault("sids", {}).get(role, "")
                prompt = build_prompt(b, t, role, thread_context(tok, t["thread"]))
                inbox_seen = len(t["inbox"])
                TURNS.mkdir(parents=True, exist_ok=True)
                stem = TURNS / f"{t['id']}-{len(t['history']) + 1:02d}-{role}"
                stem.with_suffix(".prompt.txt").write_text(prompt, encoding="utf-8")
                poll_human(b, tok)
                thread_stop(b, tok)
                if STOP_FILE.exists():
                    break
                out = turn(devin, sid, r["perm"], prompt)
                ok = True
                stem.with_suffix(".out.txt").write_text(out, encoding="utf-8")
                if not sid:
                    t["sids"][role] = newest_session()
                res, body = parse(out)
            except Exception as e:  # 错误路径：阻塞当前任务，循环不崩
                res, body = {"status": "blocked", "to": "none", "summary": f"{role} 回合异常：{e}"}, ""
            res = res or {"status": "blocked", "to": "none", "summary": "回复缺少 RELAY_RESULT 结尾，需要人工判断"}
            route(b, t, role, res)
            if ok:
                del t["inbox"][:inbox_seen]
            post(tok, f"【{role}】{res.get('summary', '')}\n\n{body[:11000]}".rstrip(), t["thread"])
            if t["status"] == "blocked" and t["history"][-1]["role"] == "编排器":
                note(tok, t, t["history"][-1]["summary"])
            save_board(b)
            turns += 1
            print(f"{now()} {t['id']} {role} -> {t['status']} owner={t['owner'] or '-'}", flush=True)
            if a.once:
                break
    finally:
        save_board(b)
        lock.close()


def cmd_retry(a):
    lock = lock_or_fail()
    try:
        _retry(a)
    finally:
        lock.close()


def _retry(a):
    b = load_board()
    t = next((x for x in b["tasks"] if x["id"] == a.task), None)
    if t is None:
        raise SystemExit(f"没有任务 {a.task}")
    if active(b) not in (None, t):
        raise SystemExit(f"已有进行中的任务 {active(b)['id']}")
    owner = a.owner or next((h["role"] for h in reversed(t["history"]) if h["role"] in b["roles"]), "生产")
    if owner not in b["roles"]:
        raise SystemExit(f"未知角色：{owner}")
    t["history"].append({"ts": now(), "role": "人类", "status": "retry", "to": owner, "summary": "人工重试"})
    t["status"], t["owner"] = "doing", owner
    save_board(b)
    note(token(), t, f"人工重试，交给 {owner}")
    print(f"{t['id']} -> doing owner={owner}")


def cmd_close(a):
    lock = lock_or_fail()
    try:
        b = load_board()
        t = next((x for x in b["tasks"] if x["id"] == a.task), None)
        if t is None:
            raise SystemExit(f"没有任务 {a.task}")
        t["history"].append({"ts": now(), "role": "人类", "status": a.status, "to": "none",
                             "summary": a.note or "人工关闭"})
        t["status"], t["owner"] = a.status, ""
        save_board(b)
        note(token(), t, f"人工关闭为 {a.status}：{a.note or '无备注'}")
    finally:
        lock.close()
    print(f"{t['id']} -> {a.status}")


def cmd_task(a):
    lock = lock_or_fail()
    try:
        _task(a)
    finally:
        lock.close()


def _task(a):
    b = load_board()
    tid = create_task(b, token(), a.title, a.brief)
    save_board(b)
    print(tid)


def cmd_status(_):
    b = load_board()
    print("角色：" + "，".join(b["roles"]) + "（每个任务各自独立会话）")
    for t in b["tasks"]:
        print(f"{t['id']} [{t['status']}] owner={t['owner'] or '-'} round={t['round']}/{t['max_rounds']} "
              f"记录={len(t['history'])} 会话={len(t.get('sids', {}))} 标题={t['title']}")
    hb = json.loads(HEARTBEAT.read_text(encoding="utf-8")) if HEARTBEAT.exists() else None
    print("编排器心跳：" + (hb["ts"] if hb else "无") + ("；STOP 已设置" if STOP_FILE.exists() else ""))


def cmd_stop(_):
    STATE.mkdir(parents=True, exist_ok=True)
    STOP_FILE.touch()
    print("已写入 STOP")


def cmd_resume(_):
    STOP_FILE.unlink(missing_ok=True)
    print("已清除 STOP")


def main():
    ap = argparse.ArgumentParser(description="多角色接力编排（生产/审计/验证…）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("task")
    p.add_argument("title")
    p.add_argument("--brief", default="")
    p.set_defaults(fn=cmd_task)
    p = sub.add_parser("run")
    p.add_argument("--max-turns", type=int, default=8)
    p.add_argument("--once", action="store_true")
    p.set_defaults(fn=cmd_run)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    sub.add_parser("stop").set_defaults(fn=cmd_stop)
    sub.add_parser("resume").set_defaults(fn=cmd_resume)
    p = sub.add_parser("retry")
    p.add_argument("task")
    p.add_argument("--owner", default="")
    p.set_defaults(fn=cmd_retry)
    p = sub.add_parser("close")
    p.add_argument("task")
    p.add_argument("--status", choices=["done", "blocked"], default="blocked")
    p.add_argument("--note", default="")
    p.set_defaults(fn=cmd_close)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
