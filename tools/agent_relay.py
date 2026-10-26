#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""多角色接力编排：角色 = 本地 devin 会话，共享状态 = board.json，对话面 = Slack 或 Mattermost 频道。

- 角色数量任意（board.json 的 roles）；
- 每个角色可配独立 bot 身份（env 里 CHAT_TOKEN_<角色名> / SLACK_TOKEN_<角色名>），以各自 bot 身份发言、可被 @；
  未配角色 token 时回退为编排器 token 发言 + 【角色】前缀；
- board.json 只由持锁的命令写入（run 循环，或 task/retry/close），角色只通过固定结尾 RELAY_RESULT 汇报交接
  （status/to/summary 必填；blocking 回退时必填；files 生产每轮与 done 必填——done 时系统登记到任务 deliverables）；
- 每个任务里每个角色各自一个独立 devin 会话（cwd = WH3 根目录），权限模式按角色配置；任务之间互不共享会话；
- 人类 @某角色 bot：有进行中任务则把任务派给该角色并把消息进 inbox，没有则以消息内容建新任务交给它。

凭据（relay.env 不入库）：依次取 $AGENT_RELAY_ENV、tools/_agent_relay/relay.env、tools/relay.env、旧 openab.env 路径：
    CHAT_PLATFORM=mattermost|mm|slack         默认 slack
    CHAT_BOT_TOKEN / SLACK_BOT_TOKEN          编排器 token（必需）
    CHAT_TOKEN_<角色> / SLACK_TOKEN_<角色>    角色 token（可选；缺省回退编排器身份 + 【角色】前缀）
    # Mattermost（tools/mattermost/provision.py 一键生成下面全部）：
    MM_URL=http://127.0.0.1:8065  MM_CHANNEL=<channel_id>  MM_HUMAN_ID=<admin_uid>
    MM_USER_<角色>=<bot_username>
    # Slack：SLACK_CHANNEL=C0...  SLACK_HUMAN_ID=U0...（可选覆盖默认值）
    RELAY_TRANSPORT=cli|acp                     默认 cli；acp 走 `devin acp` 长驻进程（实验）

用法（Windows Python，在 WH3 根目录）：
    python tools/agent_relay.py task "标题" [--brief "说明"]
    python tools/agent_relay.py run [--max-turns 8] [--once]
    python tools/agent_relay.py status
    python tools/agent_relay.py stop | resume
    python tools/agent_relay.py retry T-0001 [--owner 审计]          阻塞任务恢复到指定角色
    python tools/agent_relay.py close T-0001 [--status done|blocked] [--note "..."]   人工关闭任务
频道里人类可发：STOP / 停止（编排器观察到的 STOP 不再派发新回合）、新任务：标题（建任务）、@角色bot 文本（派任务给该角色），其余顶层消息进当前任务的补充；在任务线程里回复 STOP / 停止同样生效。
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
ENV_CANDIDATES = [STATE / "relay.env",
                  Path(__file__).resolve().parent / "relay.env",
                  Path(r"\\wsl.localhost\Ubuntu\home\sigeer\openab\openab.env")]
DB = Path(os.environ["APPDATA"]) / "Devin" / "cli" / "sessions.db"
DEVIN_FALLBACKS = ([Path(os.environ["LOCALAPPDATA"]) / "devin/cli/bin/devin.exe"]
                   if os.environ.get("LOCALAPPDATA") else []) + [
                  Path(r"E:\Users\22448\AppData\Local\Programs\Devin\resources\app"
                       r"\extensions\windsurf\devin\bin\devin.exe")]
CHANNEL = "C0CBH3WDXBR"
HUMAN_ID = "U0CBWG27THC"
STATUSES = {"handoff", "done", "blocked"}
DEFAULT_MODEL = "swe-2-max"
DEFAULT_ROLES = {
    "生产": {"perm": "smart", "model": DEFAULT_MODEL, "duties": "按任务说明完成工作，可读写 WH3 仓库（遵守 AGENTS.md）；只读任务不得写文件。完成后 status=handoff、to=审计。"},
    "审计": {"perm": "auto", "model": DEFAULT_MODEL, "duties": "只读审查生产的结论：逐条核对其引用的文件、行号与事实是否属实，有无越界。不得修改文件。通过则 status=handoff、to=验证；不通过则 status=handoff、to=生产，并写清修改点。"},
    "验证": {"perm": "auto", "model": DEFAULT_MODEL, "duties": "用读取/搜索工具复核关键证据（行号、字段名、路径是否存在、规则文字是否一致）。不得修改文件。证据一致则 status=done、to=none；不一致则 status=handoff、to=生产。"},
}
READ_RULE = "本轮只读：只用读取类工具（Read/Grep），文件路径以任务说明为准，直接用 Read 按路径打开；不使用 shell，不联网（不用 webfetch），不查询 memory 服务，不写文件。"
WRITE_RULE = "本轮可写文件，但只能写任务说明或「归属边界」列出的文件；只读任务不写文件；不联网，不查询 memory 服务，尽量不用 shell。"
RESULT_SPEC = ("{rule} 搜索工具可能看不到被 git 忽略的文件，以 Read 为准。若任何工具被拒绝，不要改用其他网络或命令工具，直接以 status=blocked 结束并说明原因。"
               "若本轮会改动或交付文件，回复开头先写「归属边界：」并列出文件清单，审计据此核对是否越界。"
               "回复的最后一段必须是固定结尾（不得省略，不得放进代码块）：\n"
               "RELAY_RESULT\nstatus: handoff|done|blocked\nto: {names}|none\nsummary: 一句话结论\n"
               "blocking: 阻断项，分号分隔（可选；回退/不通过时必填；done 不得有）\n"
               "files: 本次结论涉及的交付/改动文件，逗号分隔（生产每轮必填；done 必填最终清单；纯核对无交付写 none）\n"
               "交给其他角色用 status=handoff；任务完成用 status=done 且 to=none；需要人类决策或无法完成用 status=blocked。")


def now():
    return datetime.now().isoformat(timespec="seconds")


def load_board():
    b = json.loads(BOARD.read_text(encoding="utf-8")) if BOARD.exists() else {"roles": {}, "tasks": [], "seq": 0, "cursor": ""}
    for k, v in DEFAULT_ROLES.items():
        b["roles"].setdefault(k, {}).update(perm=v["perm"], model=v["model"], duties=v["duties"])
    for r in b["roles"].values():
        r.pop("sid", None)
        r.setdefault("perm", "auto")
        r.setdefault("model", DEFAULT_MODEL)
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


_ENV = None


def env():
    global _ENV, CHANNEL, HUMAN_ID
    if _ENV is not None:
        return _ENV
    cands = ([Path(os.environ["AGENT_RELAY_ENV"])] if os.environ.get("AGENT_RELAY_ENV") else []) + ENV_CANDIDATES
    for p in cands:
        if not p.exists():
            continue
        e = {}
        for line in p.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                e[k.strip()] = v.strip().strip("\"'")
        CHANNEL = e.get("MM_CHANNEL") or e.get("SLACK_CHANNEL", CHANNEL)
        HUMAN_ID = e.get("MM_HUMAN_ID") or e.get("SLACK_HUMAN_ID", HUMAN_ID)
        _ENV = e
        return e
    raise SystemExit("找不到 Slack env：设 AGENT_RELAY_ENV，或建 tools/_agent_relay/relay.env")


def token():
    e = env()
    for k in ("CHAT_BOT_TOKEN", "SLACK_BOT_TOKEN"):
        if e.get(k):
            return e[k]
    raise SystemExit("env 中没有 CHAT_BOT_TOKEN / SLACK_BOT_TOKEN（编排器 token）")


def role_tok(role):
    """角色独立 bot token；未配时回退编排器 token。返回 (token, 是否独立身份)。"""
    e = env()
    own = e.get(f"CHAT_TOKEN_{role}") or e.get(f"SLACK_TOKEN_{role}")
    return (own or token(), bool(own))


def is_mm():
    return env().get("CHAT_PLATFORM", "slack").lower() in ("mattermost", "mm")


def mm(path, tok, method="GET", body=None, params=None):
    url = env()["MM_URL"].rstrip("/") + "/api/v4" + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {tok}",
                                          "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode() or "{}")


def mm_msgs(j):
    """MM posts 响应 → slack 风格 [{user,text,ts,id,root_id}]，按时间升序。"""
    msgs = [{"user": p["user_id"], "text": p.get("message", ""),
             "ts": str(p.get("create_at", 0) / 1000), "id": p["id"],
             "root_id": p.get("root_id", "")} for p in j.get("posts", {}).values()]
    return sorted(msgs, key=lambda m: float(m["ts"]))


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
    if is_mm():
        body = {"channel_id": CHANNEL, "message": text[:16000]}
        if thread:
            body["root_id"] = thread
        return mm("/posts", tok, "POST", body)["id"]
    params = {"channel": CHANNEL, "text": text[:12000]}
    if thread:
        params["thread_ts"] = thread
    return slack("chat.postMessage", tok, **params)["ts"]


def whoami(tok):
    if is_mm():
        return mm("/users/me", tok).get("id")
    return slack("auth.test", tok).get("user_id")


def join_channel(tok):
    if is_mm():
        try:
            mm(f"/channels/{CHANNEL}/members", tok, "POST", {"user_id": whoami(tok)})
        except Exception as e:
            if "already" not in str(e).lower():
                raise
        return
    try:
        slack("conversations.join", tok, channel=CHANNEL)
    except RuntimeError as e:
        if "already_in_channel" not in str(e):
            raise


def identities(b):
    """返回 (uid->发言标签, role->身份键)。Slack 身份键=bot uid；MM=用户名。"""
    labels, role_uid, seen = {}, {}, {}
    for role in b["roles"]:
        tok, own = role_tok(role)
        if tok not in seen:
            try:
                seen[tok] = whoami(tok) or ""
            except Exception:
                seen[tok] = ""
        uid = seen[tok]
        if own and uid:
            labels[uid] = role
            role_uid[role] = env().get(f"MM_USER_{role}", uid) if is_mm() else uid
        elif uid:
            labels.setdefault(uid, "编排")
    try:
        labels.setdefault(whoami(token()) or "", "编排")
    except Exception:
        pass
    labels[HUMAN_ID] = "人类"
    return labels, role_uid


MENTION = re.compile(r"<@(U[A-Z0-9]+)>")
MM_MENTION = re.compile(r"@([A-Za-z0-9._-]+)")


def mentions(text):
    if is_mm():
        return MM_MENTION.findall(text or "")
    return MENTION.findall(text or "")


def strip_mentions(text):
    return (MM_MENTION if is_mm() else MENTION).sub("", text or "").strip()


def at(role, role_uid):
    """mention 展示形式：Slack <@uid>；MM @username。"""
    key = (role_uid or {}).get(role)
    if not key:
        return f"@{role}"
    return f"@{key}" if is_mm() else f"<@{key}>"


def assign_mention(b, t, uids, uid_role, role_uid, tok, src):
    """uids 里命中角色 bot → 任务派给该角色。返回命中角色名或 None。"""
    hit = next((uid_role[u] for u in uids if u in uid_role), None)
    if hit and t and hit != t["owner"]:
        t["history"].append({"ts": now(), "role": "人类", "status": "assign", "to": hit,
                             "summary": f"@{hit} 指派（{src}）"})
        t["owner"] = hit
        post(tok, f"[编排] 收到 {at(hit, role_uid)} 指派，下一回合由「{hit}」处理。", thread=t.get("thread"))
    return hit


def linkify(text, uid_role):
    """把 @角色名 转成平台 mention：Slack <@uid>；MM @username。"""
    for key, role in uid_role.items():
        rep = f"@{key}" if is_mm() else f"<@{key}>"
        text = re.sub(rf"@{re.escape(role)}(?![A-Za-z0-9_一-鿿])", rep, text)
    return text


def thread_msgs(tok, thread_ts, page=200):
    if is_mm():
        return mm_msgs(mm(f"/posts/{thread_ts}/thread", tok, params={"perPage": page}))
    seen, cursor = {}, ""
    while True:
        j = slack("conversations.replies", tok, channel=CHANNEL, ts=thread_ts, limit=page,
                  **({"cursor": cursor} if cursor else {}))
        for m in j["messages"]:
            seen.setdefault(m["ts"], m)
        cursor = j.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            return sorted(seen.values(), key=lambda m: float(m["ts"]))


def thread_context(tok, thread_ts, labels=None, budget=16000, per_msg=8000):
    labels = labels or {}
    msgs = thread_msgs(tok, thread_ts)
    picked, used = [], 0
    for m in reversed(msgs):
        body = m.get("text", "")
        if len(body) > per_msg:
            body = body[:per_msg] + "…（已截断，完整见 tools/_agent_relay/turns/）"
        text = f"[{labels.get(m.get('user'), '机器人')}] " + body
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


def thread_human(b, tok, uid_role, role_uid=None):
    t = active(b)
    if not t or not t.get("thread"):
        return
    for m in thread_msgs(tok, t["thread"]):
        if m.get("user") != HUMAN_ID or float(m["ts"]) <= float(t.get("seen", 0)):
            continue
        t["seen"] = m["ts"]
        text = m.get("text", "").strip()
        if text.lower() in ("stop", "停止"):
            STOP_FILE.parent.mkdir(parents=True, exist_ok=True)
            STOP_FILE.touch()
            post(tok, "已收到线程内停止指令，编排器在下一轮前停下。", thread=t["thread"])
        elif mentions(text):
            if assign_mention(b, t, mentions(text), uid_role, role_uid, tok, "线程"):
                t["inbox"].append(text)


def active(b):
    return next((t for t in b["tasks"] if t["status"] == "doing"), None)


def create_task(b, tok, title, brief="", owner="生产", role_uid=None):
    b["seq"] += 1
    tid = f"T-{b['seq']:04d}"
    head = f"[任务] {tid} {title}" + (f" → {at(owner, role_uid)}" if role_uid and owner in role_uid else "")
    thread = post(tok, head + (f"\n{brief}" if brief else ""))
    b["tasks"].append({"id": tid, "title": title, "brief": brief, "status": "doing", "owner": owner,
                       "round": 1, "max_rounds": 3, "thread": thread, "history": [], "inbox": [], "created": now()})
    return tid


def channel_msgs(tok, oldest, page=200):
    """频道顶层消息（不含线程回复），按时间升序。"""
    if is_mm():
        out, pg = [], 0
        while True:
            j = mm(f"/channels/{CHANNEL}/posts", tok,
                   params={"since": int(float(oldest) * 1000), "perPage": page, "page": pg})
            msgs = mm_msgs(j)
            out += [m for m in msgs if not m["root_id"]]
            if len(msgs) < page:
                return out
            pg += 1
    seen, cur = {}, ""
    while True:
        j = slack("conversations.history", tok, channel=CHANNEL, oldest=str(oldest), limit=page,
                  **({"cursor": cur} if cur else {}))
        for m in j["messages"]:
            seen.setdefault(m["ts"], m)
        cur = j.get("response_metadata", {}).get("next_cursor", "")
        if not cur:
            return sorted(seen.values(), key=lambda m: float(m["ts"]))


def poll_human(b, tok, uid_role=None, role_uid=None):
    uid_role = uid_role or {}
    cursor = float(b["cursor"] or 0)
    for m in channel_msgs(tok, cursor):
        if float(m["ts"]) <= cursor or m.get("user") != HUMAN_ID:
            continue
        b["cursor"] = m["ts"]
        text = m.get("text", "").strip()
        if text.lower() in ("stop", "停止"):
            STOP_FILE.parent.mkdir(parents=True, exist_ok=True)
            STOP_FILE.touch()
            post(tok, "已收到停止指令，编排器在下一轮前停下。")
        elif text.startswith(("新任务：", "新任务:")):
            create_task(b, tok, text.split("：" if "：" in text else ":", 1)[1].strip(), role_uid=role_uid)
        elif (t := active(b)):
            assign_mention(b, t, mentions(text), uid_role, role_uid, tok, "频道")
            t["inbox"].append(text)
        else:
            role = next((uid_role[u] for u in mentions(text) if u in uid_role), None)
            if role:
                title = strip_mentions(text)[:80] or f"{role} 的任务"
                create_task(b, tok, title, owner=role, role_uid=role_uid)


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
        m = re.match(r"^\W*(status|to|summary|blocking|files)\W*[:：]\s*(.*?)\W*$", line.strip(), re.I)
        if m:
            kv[m.group(1).lower()] = m.group(2).strip()
    kv["status"] = kv.get("status", "").lower()
    return (kv if kv["status"] in STATUSES else None), out[:i].strip()


def route(b, t, role, res):
    to = res.get("to", "none")
    entry = {"ts": now(), "role": role, "status": res["status"], "to": to,
             "summary": res.get("summary", "")}
    for k in ("blocking", "files"):
        if res.get(k):
            entry[k] = res[k]
    t["history"].append(entry)
    if res["status"] == "done" and to in ("none", ""):
        files = [f.strip() for f in res.get("files", "").split(",")
                 if f.strip() and f.strip().lower() != "none"]
        t["deliverables"] = {"files": files, "by": role, "ts": now()}
        if not res.get("files"):
            t["history"].append({"ts": now(), "role": "编排器", "status": "warn", "to": "none",
                                 "summary": "done 未附 files 交付清单（按契约应补报）"})
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
    exe = shutil.which("devin")
    if exe:
        return exe
    for p in DEVIN_FALLBACKS:
        if p.exists():
            return str(p)
    raise SystemExit("找不到 devin CLI（PATH、LOCALAPPDATA\\devin\\cli\\bin、旧 Devin Desktop 路径均无）")


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


def turn(devin, sid, perm, model, prompt):
    base = [devin, "-r", sid, "-p"] if sid else [devin, "-p"]
    r = subprocess.run(base + ["--permission-mode", perm, "--model", model, "--", prompt],
                       cwd=ROOT, capture_output=True, encoding="utf-8", errors="replace", timeout=1800)
    if r.returncode:
        raise RuntimeError(f"devin 退出码 {r.returncode}：{(r.stderr or '')[-300:]}")
    return r.stdout


class AcpHost:
    """长驻 `devin acp` 子进程（JSON-RPC over stdio）。首个 session 等用户配置的 MCP
    全连上才返回，冷启动可能数分钟；同进程后续 session/new 复用 MCP 池。
    RELAY_TRANSPORT=acp 启用；sids 存 acp sessionId，重启用 session/load 恢复。"""

    def __init__(self, devin, model):
        import queue, threading
        self._q, self._id = queue.Queue(), 0
        self.proc = subprocess.Popen([devin, "acp", "--model", model],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, cwd=ROOT, bufsize=0)
        threading.Thread(target=self._reader, daemon=True).start()
        self.call("initialize", {"protocolVersion": 1, "clientCapabilities": {
            "fs": {"readTextFile": True, "writeTextFile": False}, "terminal": False}})

    def _reader(self):
        for line in iter(self.proc.stdout.readline, b""):
            try:
                self._q.put(json.loads(line))
            except Exception:
                pass

    def call(self, method, params=None, timeout=480):
        self._id += 1
        rid = self._id
        self.proc.stdin.write((json.dumps({"jsonrpc": "2.0", "id": rid, "method": method,
                                           "params": params or {}}) + "\n").encode())
        self.proc.stdin.flush()
        notes, t0 = [], time.time()
        while time.time() - t0 < timeout:
            try:
                msg = self._q.get(timeout=2)
            except Exception:
                if self.proc.poll() is not None:
                    raise RuntimeError(f"devin acp 进程退出 {self.proc.returncode}")
                continue
            m = msg.get("method")
            if m == "session/request_permission":      # 闸门：写角色放行、只读角色拒绝
                self._answer_perm(msg)
                continue
            if msg.get("id") == rid:
                if "error" in msg:
                    raise RuntimeError(f"{method} 错误：{msg['error']}")
                return msg.get("result", {}), notes
            notes.append(msg)
        raise RuntimeError(f"{method} 超时 {timeout}s")

    def _answer_perm(self, msg):
        # 简化闸门：统一放行（角色边界已由系统提示约束；细粒度策略留待接入）
        self.proc.stdin.write((json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": {
            "outcome": {"outcome": "selected", "optionId": "allow_once"}}}) + "\n").encode())
        self.proc.stdin.flush()

    def ensure_session(self, sid):
        if sid:
            try:
                self.call("session/load", {"sessionId": sid, "cwd": str(ROOT), "mcpServers": []})
                return sid
            except Exception:
                pass
        res, _ = self.call("session/new", {"cwd": str(ROOT), "mcpServers": []})
        return res["sessionId"]

    def prompt(self, sid, text, timeout=1800):
        _, notes = self.call("session/prompt",
                             {"sessionId": sid, "prompt": [{"type": "text", "text": text}]},
                             timeout=timeout)
        chunks = [((n.get("params") or {}).get("update") or {}).get("content", {}).get("text", "")
                  for n in notes
                  if ((n.get("params") or {}).get("update") or {}).get("sessionUpdate") == "agent_message_chunk"]
        return "".join(chunks)

    def close(self):
        try:
            self.proc.terminate()
        except Exception:
            pass


def turn_acp(host, sid, prompt):
    return host.prompt(sid, prompt)


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
    labels, role_uid = identities(b)
    uid_role = {u: r for r, u in role_uid.items()}
    for role in b["roles"]:  # 各角色 bot 自助进公共频道；私有频道需人工 /invite
        rtok, own = role_tok(role)
        if own:
            try:
                join_channel(rtok)
            except Exception as e:
                print(f"{role} bot 进频道失败（发言时可能报错）：{e}", flush=True)
    own_list = "、".join(role_uid) or "无"
    print(f"身份：编排={whoami(tok) or '?'}；角色独立身份 {own_list}", flush=True)
    b["cursor"] = b["cursor"] or f"{time.time():.6f}"
    turns = 0
    acp = None
    if env().get("RELAY_TRANSPORT", "cli").lower() == "acp":
        acp = AcpHost(devin, DEFAULT_MODEL)
        print("transport=acp（长驻 devin acp 进程，首个 session 需等 MCP 连接）", flush=True)
    try:
        while turns < a.max_turns and not STOP_FILE.exists():
            poll_human(b, tok, uid_role, role_uid)
            thread_human(b, tok, uid_role, role_uid)
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
                prompt = build_prompt(b, t, role, thread_context(tok, t["thread"], labels))
                inbox_seen = len(t["inbox"])
                TURNS.mkdir(parents=True, exist_ok=True)
                stem = TURNS / f"{t['id']}-{len(t['history']) + 1:02d}-{role}"
                stem.with_suffix(".prompt.txt").write_text(prompt, encoding="utf-8")
                poll_human(b, tok, uid_role, role_uid)
                thread_human(b, tok, uid_role, role_uid)
                if STOP_FILE.exists():
                    break
                if acp:
                    sid = t["sids"][role] = acp.ensure_session(sid)
                    out = acp.prompt(sid, prompt)
                else:
                    out = turn(devin, sid, r["perm"], r.get("model", DEFAULT_MODEL), prompt)
                ok = True
                stem.with_suffix(".out.txt").write_text(out, encoding="utf-8")
                if not sid and not acp:
                    t["sids"][role] = newest_session()
                res, body = parse(out)
            except Exception as e:  # 错误路径：阻塞当前任务，循环不崩
                res, body = {"status": "blocked", "to": "none", "summary": f"{role} 回合异常：{e}"}, ""
            res = res or {"status": "blocked", "to": "none", "summary": "回复缺少 RELAY_RESULT 结尾，需要人工判断"}
            route(b, t, role, res)
            if ok:
                del t["inbox"][:inbox_seen]
            rtok, own = role_tok(role)
            text = linkify(f"{res.get('summary', '')}\n\n{body[:11000]}".rstrip(), uid_role)
            post(rtok, (text if own else f"【{role}】" + text), t["thread"])
            if t["status"] == "blocked" and t["history"][-1]["role"] == "编排器":
                note(tok, t, t["history"][-1]["summary"])
            save_board(b)
            turns += 1
            print(f"{now()} {t['id']} {role} -> {t['status']} owner={t['owner'] or '-'}", flush=True)
            if a.once:
                break
    finally:
        if acp:
            acp.close()
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
    _, role_uid = identities(b)
    tid = create_task(b, token(), a.title, a.brief, role_uid=role_uid)
    save_board(b)
    print(tid)


def cmd_status(_):
    b = load_board()
    print("角色：" + "，".join(b["roles"]) + "（每个任务各自独立会话）")
    for t in b["tasks"]:
        d = t.get("deliverables")
        extra = f" 交付={len(d['files'])}项({d['by']})" if d else ""
        print(f"{t['id']} [{t['status']}] owner={t['owner'] or '-'} round={t['round']}/{t['max_rounds']} "
              f"记录={len(t['history'])} 会话={len(t.get('sids', {}))}{extra} 标题={t['title']}")
        if d and d["files"]:
            print("    files: " + ", ".join(d["files"]))
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
