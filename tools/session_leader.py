# -*- coding: utf-8 -*-
"""session_leader.py — Devin CLI 会话 leader 轮巡器

每轮 tick：
  1. 读 %APPDATA%\\Devin\\cli\\sessions.db 枚举 root 下的会话；
  2. 用 session_locks/<id>.lock 是否被排他持有判断会话是否在跑；
  3. 取每个会话的最新消息做摘要，唤醒持久 leader 会话（devin -r <id> -p）；
  4. leader 返回 JSON 计划 {"summary": ..., "dispatches": [...]}，
     脚本校验后对各停下的会话执行 devin -r <sid> -p -- <prompt> 并行派发。

数据源（全部实测确认，3000.10.35）：
  - sessions.db（WAL）：sessions 表列 id/working_directory/last_activity_at/title/
    hidden；message_nodes 表按 row_id 最大者为最新消息（created_at 不可靠，
    resume 会重写）；chat_message 为 JSON，含 role/content/tool_calls/metadata。
  - session_locks/<id>.lock：会话进程存活期间被排他打开——文件打不开=在跑，
    能打开=残留死锁=已停止；文件不存在=已停止。
  - 派发必须在会话原 working_directory 里跑 -r，否则会弹交互目录选择挂住。

运行：Windows Python313。例：
  python tools/session_leader.py --root E:\\Code\\WH3-modding
  python tools/session_leader.py --root E:\\Code\\WH3-modding --once --dry-run

状态与日志：tools/_session_leader/{state.json,leader.log,dispatches/}
可选任务板 tools/_session_leader/board.json：{"<sid>": {"goal": "...", "paused": true}}
——存在时只有板上会话参与派发决策，并把 goal 一并喂给 leader。
"""

import argparse
import ctypes
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

STATE_DIR = Path(__file__).resolve().parent / "_session_leader"
STATE_FILE = STATE_DIR / "state.json"
LOG_FILE = STATE_DIR / "leader.log"
BOARD_FILE = STATE_DIR / "board.json"
MISSION_FILE = STATE_DIR / "mission.md"
STOP_FILE = STATE_DIR / "STOP"
SELF_LOCK = STATE_DIR / "leader.lock"
DISPATCH_DIR = STATE_DIR / "dispatches"
GPT6_CONFIG = STATE_DIR / "gpt6_config.json"

DEVIN_FALLBACK = (r"E:\Users\22448\AppData\Local\Programs\Devin\resources\app"
                  r"\extensions\windsurf\devin\bin\devin.exe")
CLI_DIR = Path(os.environ["APPDATA"]) / "Devin" / "cli"
DB_PATH = CLI_DIR / "sessions.db"
LOCK_DIR = CLI_DIR / "session_locks"

MAX_EXCERPT = 700          # 每会话喂给 leader 的尾部摘要长度
MAX_PROMPT = 4000          # 单条派发 prompt 上限
DIGEST_CAP = 20000         # 整份 digest 上限（Windows argv 限制 ~32k）


def log(msg):
    line = f"[{datetime.now():%Y-%m-%d %H:%M:%S}] {msg}"
    print(line, flush=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def devin_exe():
    exe = shutil.which("devin") or DEVIN_FALLBACK
    if not Path(exe).exists() and shutil.which("devin") is None:
        raise SystemExit(f"找不到 devin 可执行文件：{exe}")
    return exe


def norm_dir(p):
    return os.path.normcase(os.path.normpath(p))


def query_db(sql, args=()):
    con = sqlite3.connect(f"file:{DB_PATH.as_posix()}?mode=ro", uri=True)
    try:
        return con.execute(sql, args).fetchall()
    finally:
        con.close()


def is_running(session_id):
    """devin 用 LockFile 字节锁持有 <id>.lock：抢不到锁=在跑；抢到=残留死锁=已停。"""
    import msvcrt
    lock = LOCK_DIR / f"{session_id}.lock"
    if not lock.exists():
        return False
    try:
        fd = os.open(str(lock), os.O_RDWR)
    except OSError:
        return True
    try:
        msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
        msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
        return False
    except OSError:
        return True
    finally:
        os.close(fd)


def load_sessions(root):
    root_n = norm_dir(root)
    rows = query_db(
        "select id, working_directory, title, last_activity_at from sessions"
        " where coalesce(hidden,0)=0")
    out = []
    for sid, wd, title, act in rows:
        if not wd:
            continue
        wd_n = norm_dir(wd)
        if wd_n == root_n or wd_n.startswith(root_n + os.sep):
            out.append({"id": sid, "cwd": wd, "title": title or "",
                        "last_activity_at": act or 0})
    return out


def session_tail(session_id, max_nodes=60):
    """返回 (state, last_text)。state ∈ idle / mid_turn / awaiting_reply / empty"""
    rows = query_db(
        "select chat_message from message_nodes where session_id=?"
        " order by row_id desc limit ?", (session_id, max_nodes))
    msgs = []
    for (raw,) in rows:
        try:
            j = json.loads(raw)
        except Exception:
            continue
        meta = j.get("metadata") or {}
        tele = meta.get("telemetry") or {}
        if tele.get("source") == "cache_keepalive":
            continue
        role = j.get("role")
        if role == "system":
            continue
        msgs.append(j)
    if not msgs:
        return "empty", ""
    head = msgs[0]
    role = head.get("role")
    if role == "user":
        state = "awaiting_reply"
    elif head.get("tool_calls"):
        state = "mid_turn"
    else:
        state = "idle"
    text = ""
    for m in msgs:  # 找最近一条非空文本（assistant/user 皆可）
        c = (m.get("content") or "").strip()
        if c:
            text = c
            break
    return state, text


def first_prompt(session_id):
    rows = query_db(
        "select content from prompt_history where session_id=? and"
        " coalesce(is_shell,0)=0 order by timestamp asc limit 1", (session_id,))
    return (rows[0][0] or "")[:300] if rows else ""


def build_digest(sessions, states, board, leader_id=None, owned=None):
    lines = []
    for s in sessions:
        st = states[s["id"]]
        tag = {"running": f"运行中(静默{st['quiet_min']}分钟)",
               "open_idle": f"窗口开着但回合已结束-锁占用不可派(静默{st['quiet_min']}分钟)",
               "idle": "已停-上一轮完成",
               "awaiting_reply": "已停-等待回复中断",
               "mid_turn": "已停-工具执行中断",
               "empty": "空会话"}.get(st["state"], st["state"])
        if s["id"] == leader_id:
            tag += "（leader 自身，勿派发）"
        ago = datetime.fromtimestamp(s["last_activity_at"]).strftime("%m-%d %H:%M") \
            if s["last_activity_at"] else "?"
        entry = board.get(s["id"], {}) if board else {}
        if s["id"] in (owned or ()):
            tag += "（我方派遣 worker）"
        goal = entry.get("goal", "")
        excerpt = st["text"][-MAX_EXCERPT:].replace("\n", " ")
        lines.append(
            f"### {s['id']}「{s['title']}」\n"
            f"- 目录: {s['cwd']}  最后活动: {ago}  状态: {tag}"
            + (f"  暂停" if entry.get("paused") else "")
            + (f"\n- 登记目标: {goal}" if goal else "")
            + (f"\n- 原始任务: {st['task'][:300]}" if st["task"] else "")
            + (f"\n- 累计派发 {st['dispatches']} 次，上次派发 {st['last_dispatch'] or '无'}")
            + (f"\n- 最近输出: {excerpt}" if excerpt else ""))
    digest = "\n\n".join(lines)
    return digest[:DIGEST_CAP]


LEADER_RULES = """\
你是 Devin 会话 leader，负责监督本工作区内其他 Devin 会话的进度。

规则：
1. 先读会话清单，用不超过 5 行中文总结整体进度（谁在跑、谁卡住、谁已完成）。
2. 只对"已停"且确实还有未完工作的会话派发后续指令；已完成、暂停中（标注"暂停"）、
   运行中、以及"窗口开着但回合已结束"（锁占用，派不进去，需要用户先关窗口）的
   会话一律不派。没有可派的就让 dispatches 为空。
3. 每条 prompt 用中文写，具体、可独立执行（该会话只收到这一条消息，看不到本摘要）。
4. 会话只能看到自己的会话历史；prompt 里必要时复述必要的上下文。
5. 最后一行起只输出一个 JSON 代码块，禁止其他尾随文字：
```json
{"summary": "<整体进度总结>",
 "dispatches": [{"session_id": "<已停会话id>", "prompt": "<指令>"}],
 "spawns": [{"cwd": "<工作目录>", "prompt": "<自包含任务指令>"}]}
```
"spawns" 是在指定目录起全新会话执行 prompt（新会话没有旧会话的历史记忆，
prompt 必须写全背景：它能看到工作区文件但看不到任何会话记录）。spawns/dispatches
都可为空。spawn 只用于派新任务，不要让新会话重复其他会话正在做的事。
6. 清单中标注"我方派遣"的会话是你之前 spawn 的 worker——对已停的我方 worker
   可用 dispatches 续派下一步指令，形成持续推进；其他会话只读状态。
7. 你可以用自己的工具读取工作区文件核实 worker 的产出（报告/台账）再决策。
8. 若附带"长期任务主线"，那是用户定的常设目标——你的核心职责是持续推进它们。
"""


def ensure_leader(root, devin, st):
    lid = st.get("leader_id")
    if lid and query_db("select 1 from sessions where id=?", (lid,)):
        return lid
    token = f"LEADER-BOOT-{int(time.time())}"
    prompt = (f"[{token}] 你是本会话调度体系的 leader。{LEADER_RULES}\n"
              "本轮是初始化：只需回复 OK 表示就绪，JSON 块里 dispatches 为空。")
    r = subprocess.run([devin, "-p", "--", prompt], cwd=root,
                       capture_output=True, encoding="utf-8", errors="replace",
                       timeout=900)
    log(f"leader 初始化 rc={r.returncode} out={r.stdout[-200:]!r}")
    rows = query_db("select session_id from prompt_history where content like ?"
                    " order by timestamp desc limit 1", (f"%{token}%",))
    if not rows:
        raise RuntimeError("leader 会话创建后未能定位 session id")
    st["leader_id"] = rows[0][0]
    save_state(st)
    log(f"leader session = {st['leader_id']}")
    return st["leader_id"]


def sys_stats(root):
    """机器资源快照，每轮随 digest 喂给 leader（用户授权 leader 处置资源问题）。"""
    try:
        drive = (Path(root).drive or "E:") + "\\"
        free_gb = shutil.disk_usage(drive).free / 1e9

        class _MEM(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong),
                        ("dwMemoryLoad", ctypes.c_ulong),
                        ("ullTotalPhys", ctypes.c_ulonglong),
                        ("ullAvailPhys", ctypes.c_ulonglong),
                        ("ullTotalPageFile", ctypes.c_ulonglong),
                        ("ullAvailPageFile", ctypes.c_ulonglong),
                        ("ullTotalVirtual", ctypes.c_ulonglong),
                        ("ullAvailVirtual", ctypes.c_ulonglong),
                        ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
        m = _MEM(); m.dwLength = ctypes.sizeof(_MEM)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
        mem = f"物理内存负载 {m.dwMemoryLoad}% (可用 {m.ullAvailPhys/1e9:.1f}/{m.ullTotalPhys/1e9:.1f}GB)"
        try:
            tl = subprocess.run(["tasklist", "/fo", "csv", "/nh"],
                                capture_output=True, encoding="utf-8",
                                errors="replace", timeout=30).stdout.lower()
            procs = (f"进程数 devin={tl.count('devin.exe')}"
                     f" node={tl.count('node.exe')}"
                     f" python={tl.count('python.exe')}"
                     f" tabbit={tl.count('tabbit')}")
        except Exception:
            procs = "进程数 获取失败"
        return (f"磁盘 {drive} 可用 {free_gb:.1f}GB | {mem} | {procs}")
    except Exception as e:
        return f"机器状态获取失败:{e!r}"


def wake_leader(devin, root, leader_id, digest, perm):
    mission = ""
    if MISSION_FILE.exists():
        mission = ("\n\n## 长期任务主线（mission.md，用户定义，每轮必须推进）\n\n"
                   + MISSION_FILE.read_text(encoding="utf-8")[:8000])
    prompt = (LEADER_RULES + mission
              + f"\n本轮时间 {datetime.now():%Y-%m-%d %H:%M}。\n"
              + f"## 机器状态\n{sys_stats(root)}\n\n"
                "会话清单：\n" + digest)
    r = subprocess.run([devin, "-r", leader_id, "-p",
                        "--permission-mode", perm, "--", prompt], cwd=root,
                       capture_output=True, encoding="utf-8", errors="replace",
                       timeout=1800)
    if r.returncode != 0:
        log(f"leader 调用失败 rc={r.returncode} err={r.stderr[-400:]!r}")
        return None
    return r.stdout


def parse_plan(text):
    m = re.search(r"```json\s*(\{.*?\})\s*```", text, re.S)
    cand = m.group(1) if m else text[text.find("{"):]
    try:
        plan = json.loads(cand)
    except Exception as e:
        log(f"leader 输出无法解析为 JSON：{e}\n{text[-500:]}")
        return None
    if not isinstance(plan.get("dispatches", []), list):
        plan["dispatches"] = []
    return plan


def resolve_owned(st):
    """把 spawn_list 里的 prompt 反查成 session_id 集合（我方派遣的 worker）。"""
    prefixes = {sp.get("prompt", "")[:60] for sp in st.get("spawn_list", [])}
    prefixes.discard("")
    if not prefixes:
        return set()
    rows = query_db("select session_id, content from prompt_history"
                    " order by timestamp desc limit 800")
    owned = set()
    for sid, content in rows:
        if content and any(content.startswith(p) for p in prefixes):
            owned.add(sid)
    st["owned"] = sorted(owned)
    return owned


def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def save_state(st):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(st, ensure_ascii=False, indent=2),
                          encoding="utf-8")


def load_board():
    if BOARD_FILE.exists():
        try:
            return json.loads(BOARD_FILE.read_text(encoding="utf-8"))
        except Exception as e:
            log(f"board.json 解析失败（忽略任务板）：{e}")
    return None


def acquire_self_lock():
    """进程内持有 leader.lock 一个字节；已被锁则已有实例在跑。"""
    import msvcrt
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    fd = os.open(SELF_LOCK, os.O_RDWR | os.O_CREAT)
    try:
        msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
    except OSError:
        os.close(fd)
        return None
    os.write(fd, str(os.getpid()).encode())
    os.lseek(fd, 0, os.SEEK_SET)
    return fd  # 调用方持有至退出


class Dispatcher:
    def __init__(self, max_concurrent):
        self.max_concurrent = max_concurrent
        self.inflight = {}  # sid -> {"p": Popen, "f": file}

    def reap(self, st):
        for sid, it in list(self.inflight.items()):
            rc = it["p"].poll()
            if rc is None:
                continue
            it["f"].close()
            log(f"派发完成 {sid} rc={rc}")
            if not sid.startswith("spawn_"):
                st.setdefault("sessions", {}).setdefault(sid, {})[
                    "dispatching"] = False
            del self.inflight[sid]

    def dispatch(self, devin, sid, cwd, prompt, st, perm="accept-edits"):
        DISPATCH_DIR.mkdir(parents=True, exist_ok=True)
        f = open(DISPATCH_DIR / f"{sid}.log", "a", encoding="utf-8")
        f.write(f"\n===== dispatch {datetime.now():%Y-%m-%d %H:%M:%S} =====\n")
        f.write(prompt + "\n-----\n")
        f.flush()
        p = subprocess.Popen([devin, "-r", sid, "-p",
                              "--permission-mode", perm, "--", prompt],
                             cwd=cwd, stdout=f, stderr=subprocess.STDOUT,
                             encoding="utf-8", errors="replace")
        self.inflight[sid] = {"p": p, "f": f}
        info = st.setdefault("sessions", {}).setdefault(sid, {})
        info["dispatching"] = True
        info["dispatches"] = info.get("dispatches", 0) + 1
        info["last_dispatch_at"] = int(time.time())
        log(f"已派发 {sid}（pid={p.pid}）：{prompt[:120]!r}")


def tick(devin, root, st, args, disp):
    disp.reap(st)
    sessions = load_sessions(root)
    board = load_board()
    cutoff = int(time.time()) - args.max_age_days * 86400
    sessions = [s for s in sessions
                if s["last_activity_at"] >= cutoff
                or (board and s["id"] in board)]
    states = {}
    now_ts = int(time.time())
    owned = resolve_owned(st)
    for s in sessions:
        sid = s["id"]
        locked = is_running(sid) or sid in disp.inflight
        tail_state, text = session_tail(sid)
        quiet_min = (now_ts - s["last_activity_at"]) // 60
        if locked:
            # 锁被持有=devin.exe 进程开着；但回合可能早已完成（终端闲置中）
            state = "running" if tail_state != "idle" and quiet_min < 3 \
                else "open_idle"
        else:
            state = tail_state  # idle / mid_turn / awaiting_reply / empty
        info = st.get("sessions", {}).get(sid, {})
        states[sid] = {
            "state": state, "text": text, "quiet_min": quiet_min,
            "task": first_prompt(sid),
            "dispatches": info.get("dispatches", 0),
            "last_dispatch": (datetime.fromtimestamp(info["last_dispatch_at"])
                              .strftime("%m-%d %H:%M")
                              if info.get("last_dispatch_at") else ""),
            "dispatching": info.get("dispatching", False),
        }
    rank = {"running": 0, "open_idle": 1}
    sessions.sort(key=lambda s: (
        rank.get(states[s["id"]]["state"], 2), -s["last_activity_at"]))
    digest = build_digest(sessions, states, board, st.get("leader_id"), owned)
    if args.dry_run:
        print(digest)
        return

    # 变化检测用"稳定签名"而非 digest 原文：last_activity/静默分钟会被
    # cache_keepalive 周期性推高，只有状态类别+尾部文本才算真实变化。
    # mission.md 内容也进签名：改任务书立即唤醒 leader 重新决策。
    import hashlib
    mission_sig = hashlib.md5(MISSION_FILE.read_bytes()).hexdigest() \
        if MISSION_FILE.exists() else "-"
    sig = hashlib.md5(json.dumps(
        [mission_sig] +
        [[s["id"], states[s["id"]]["state"],
          hashlib.md5(states[s["id"]]["text"][-MAX_EXCERPT:]
                      .encode()).hexdigest(),
          states[s["id"]]["dispatches"]]
         for s in sessions], ensure_ascii=False).encode()).hexdigest()

    leader_id = st.get("leader_id")
    if leader_id and is_running(leader_id):
        log("leader 会话正被占用（可能在交互终端开着），本轮跳过")
        return
    if sig == st.get("last_sig"):
        log("会话状态无变化，跳过本轮 leader 唤醒")
        return
    leader_id = ensure_leader(root, devin, st)
    out = wake_leader(devin, root, leader_id, digest,
                      args.dispatch_permission)
    if out is None:
        return
    st["last_sig"] = sig
    plan = parse_plan(out)
    if plan is None:
        return
    log("leader 总结：" + str(plan.get("summary", "")).strip())

    now = int(time.time())
    for sp in (plan.get("spawns") or [])[:args.max_spawn_per_tick]:
        cwd = (sp.get("cwd") or "").strip()
        prompt = (sp.get("prompt") or "")[:MAX_PROMPT]
        if not prompt or not cwd or not os.path.isdir(cwd) \
                or not norm_dir(cwd).startswith(norm_dir(root)):
            log(f"跳过非法 spawn（cwd 必须在 root 内且存在）：{cwd!r}")
            continue
        import hashlib
        h = hashlib.md5((norm_dir(cwd) + "|" + prompt[:200]).encode()).hexdigest()
        seen = st.setdefault("spawned", {})
        if h in seen and now - seen[h] < args.cooldown * 60:
            log(f"相同 spawn 在冷却期内已派过，跳过：{prompt[:80]!r}")
            continue
        seen[h] = now
        st.setdefault("spawn_list", []).append(
            {"prompt": prompt, "cwd": cwd, "at": now})
        DISPATCH_DIR.mkdir(parents=True, exist_ok=True)
        tag = f"spawn_{int(time.time())}"
        f = open(DISPATCH_DIR / f"{tag}.log", "a", encoding="utf-8")
        f.write(f"===== spawn {datetime.now():%Y-%m-%d %H:%M:%S} cwd={cwd} =====\n")
        f.write(prompt + "\n-----\n")
        f.flush()
        p = subprocess.Popen([devin, "-p", "--permission-mode",
                              args.dispatch_permission, "--", prompt],
                             cwd=cwd, stdout=f, stderr=subprocess.STDOUT,
                             encoding="utf-8", errors="replace")
        disp.inflight[tag] = {"p": p, "f": f}
        log(f"已开新会话（pid={p.pid} cwd={cwd}）：{prompt[:120]!r}")

    sent = 0
    for d in plan["dispatches"]:
        sid = d.get("session_id", "")
        prompt = (d.get("prompt") or "")[:MAX_PROMPT]
        sess = next((s for s in sessions if s["id"] == sid), None)
        entry = board.get(sid, {}) if board else {}
        if sent >= args.max_dispatch_per_tick:
            break
        if len(disp.inflight) >= args.max_concurrent:
            log(f"并发上限 {args.max_concurrent}，其余派发留到下轮")
            break
        if not sess or sid == leader_id or not prompt:
            log(f"跳过非法派发目标 {sid!r}")
            continue
        if board is not None and sid not in board and sid not in owned:
            log(f"{sid} 不在任务板且非我方 worker，跳过")
            continue
        if entry.get("paused") or is_running(sid) or sid in disp.inflight:
            log(f"{sid} 暂停/在跑，跳过")
            continue
        last_at = st.get("sessions", {}).get(sid, {}).get("last_dispatch_at", 0)
        if now - last_at < args.cooldown * 60:
            log(f"{sid} 冷却中（上次派发距今 {(now-last_at)//60} 分钟），跳过")
            continue
        disp.dispatch(devin, sid, sess["cwd"], prompt, st,
                      args.dispatch_permission)
        sent += 1
    if sent == 0:
        log("本轮无派发")


def gpt6_advise(root):
    """外部顾问层：每 N tick 把三线状态喂给 OpenAI 兼容端点（gpt-6），
    产出进度总结+规划建议写 scratch/pipeline/GPT6_ADVISORY.md，供负责人
    翻阅+leader 下轮参考（参考不盲从）。配置缺失或调用失败静默跳过。"""
    if not GPT6_CONFIG.exists():
        return
    try:
        cfg = json.loads(GPT6_CONFIG.read_text(encoding="utf-8"))
        pipe = Path(root) / "scratch" / "pipeline"
        parts = []
        summ = pipe / "LEADER_SUMMARY.md"
        if summ.exists():
            parts.append("# LEADER_SUMMARY\n" +
                         summ.read_text(encoding="utf-8")[:6000])
        if LOG_FILE.exists():
            tail = LOG_FILE.read_text(encoding="utf-8",
                                      errors="replace").splitlines()[-40:]
            parts.append("# 近期调度日志\n" + "\n".join(tail))
        for line in ("research", "dgm_audit", "game_compare"):
            f = pipe / line / "LATEST.md"
            if f.exists():
                parts.append(f"# {line}/LATEST.md（头部）\n"
                             + f.read_text(encoding="utf-8",
                                           errors="replace")[:4000])
        ctx = "\n\n".join(parts)[:28000]
        prompt = ("你是外部顾问，为 Devin 多会话集群（一个持久 leader + 若干 worker "
                  "在 WH3 mod 工程里推进三条线：model-studio 能力实现/数码兽模型审计修复/"
                  "游戏导出对比追赶，总纲是 DQS/correctives 重新评估计划）做阶段评估。"
                  "以下是当前状态。请输出：①一段话进度评估 ②当前最大风险/瓶颈 "
                  "③下一周期派工建议（到线/工单级）④对计划本身的修正建议。"
                  "中文，≤800 字，只输出这四段。\n\n" + ctx)
        models = cfg.get("models") or [cfg.get("model", "gpt-6")]
        text = used = None
        for m in models:
            body = json.dumps({
                "model": m,
                "max_tokens": cfg.get("max_tokens", 2000),
                "messages": [{"role": "user", "content": prompt}],
            }).encode("utf-8")
            req = urllib.request.Request(
                cfg["url"], data=body, method="POST",
                headers={"Content-Type": "application/json",
                         "Authorization": "Bearer " + cfg["key"]})
            try:
                with urllib.request.urlopen(req, timeout=240) as r:
                    out = json.loads(r.read().decode("utf-8", "replace"))
                text = out["choices"][0]["message"]["content"]
                used = out.get("model") or m
                break
            except Exception as e:
                log(f"gpt-6 顾问调用失败 model={m}:{e!r}")
        if text is None:
            return
        (pipe / "GPT6_ADVISORY.md").write_text(
            f"# GPT-6 顾问意见（{datetime.now():%Y-%m-%d %H:%M} 刷新，model={used}）\n\n"
            + text + "\n", encoding="utf-8")
        log(f"gpt-6 顾问意见已刷新 GPT6_ADVISORY.md (model={used})")
    except Exception as e:
        log(f"gpt-6 顾问调用失败：{e!r}")


def maybe_gpt6_advise(root, st):
    cfg = {}
    if GPT6_CONFIG.exists():
        try:
            cfg = json.loads(GPT6_CONFIG.read_text(encoding="utf-8"))
        except Exception:
            return
    interval = int(cfg.get("interval_ticks", 6))
    if interval <= 0:
        return
    st["tick_n"] = st.get("tick_n", 0) + 1
    if st["tick_n"] % interval == 0:
        gpt6_advise(root)


def main():
    ap = argparse.ArgumentParser(description="Devin 会话 leader 轮巡器")
    ap.add_argument("--root", required=True, help="管理的会话工作区根目录")
    ap.add_argument("--interval", type=int, default=600, help="轮巡间隔秒")
    ap.add_argument("--once", action="store_true", help="只跑一轮")
    ap.add_argument("--dry-run", action="store_true",
                    help="只打印会话状态摘要，不唤醒 leader、不派发")
    ap.add_argument("--cooldown", type=int, default=60, help="同会话两次派发最小间隔分钟")
    ap.add_argument("--max-dispatch-per-tick", type=int, default=3)
    ap.add_argument("--max-spawn-per-tick", type=int, default=2,
                    help="每轮最多新开会话数")
    ap.add_argument("--max-concurrent", type=int, default=3)
    ap.add_argument("--max-age-days", type=float, default=7,
                    help="只管理最近 N 天有活动的会话（任务板上的除外）")
    ap.add_argument("--dispatch-permission", default="accept-edits",
                    choices=["normal", "accept-edits", "smart", "bypass"],
                    help="派发会话的权限模式：accept-edits 允许写文件但仍拦命令执行")
    ap.add_argument("--duration-min", type=float, default=0,
                    help="总运行分钟数，0=不限")
    args = ap.parse_args()

    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    fd = acquire_self_lock()
    if fd is None:
        print("已有 session_leader 实例在跑，退出"); sys.exit(1)
    devin = devin_exe()
    st = load_state()
    for info in st.get("sessions", {}).values():  # 上次退出时在途派发的残留标记
        info["dispatching"] = False
    disp = Dispatcher(args.max_concurrent)
    deadline = time.time() + args.duration_min * 60 if args.duration_min else None
    log(f"启动 root={args.root} interval={args.interval}s"
        + (f" duration={args.duration_min}min" if deadline else ""))
    while True:
        try:
            tick(devin, args.root, st, args, disp)
            maybe_gpt6_advise(args.root, st)
        except Exception as e:
            log(f"tick 异常：{e!r}")
        save_state(st)
        if STOP_FILE.exists():
            log("检测到 STOP 文件，退出")
            break
        if args.once or (deadline and time.time() >= deadline):
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
