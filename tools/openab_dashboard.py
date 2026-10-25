#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OpenAB 多会话桥（Slack <-> devin acp）只读状态页。

只读：不改 config、不写 sessions.db、不发 Slack 消息、不重启进程。
数据源：WSL 内 ~/openab/config.toml 与 openab.log（经 WSL 的 UNC 路径直接读取，wsl.exe 管道对大输出会静默截断）；
Windows 侧 %APPDATA%\\devin\\cli\\sessions.db（sqlite 只读打开）。

用法（Windows Python313；WSL 下用 tools/winpy 转发）：
    tools/winpy tools/openab_dashboard.py [--port 8770]
浏览器打开 http://127.0.0.1:8770/
"""
import argparse
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
import sys
import tomllib
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
LINE_TS = re.compile(r"^(\d{4}-\d\d-\d\dT[\d:.]+Z)\s+(.*)$")
ERR = re.compile(r"\bERROR\b|panicked|failed to|spawn failed", re.I)
SESSIONS_DB = os.path.expandvars(r"%APPDATA%\devin\cli\sessions.db")
RELAY_DIR = Path(__file__).resolve().parent / "_agent_relay"


def parse_iso(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone()


def fmt(t):
    return t.strftime("%m-%d %H:%M:%S") if t else None


def local_fmt(v):
    try:
        return fmt(dt.datetime.fromtimestamp(float(v)))
    except (TypeError, ValueError):
        return None


def wsl(args, timeout=30):
    p = subprocess.run(["wsl.exe", "-e", *args], capture_output=True, timeout=timeout)
    return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")


def openab_running():
    rc, out, _ = wsl(["pgrep", "-x", "openab"])
    pids = [p for p in out.split() if p.isdigit()]
    return rc == 0 and bool(pids), pids


def parse_log(text):
    log = {"started": None, "sock": None, "devin_cwd": None, "allow": None,
           "dispatches": 0, "sessions": set(), "events": []}
    ev = log["events"].append
    for raw in text.splitlines():
        m = LINE_TS.match(ANSI.sub("", raw))
        if not m:
            continue
        t, body = parse_iso(m.group(1)), m.group(2)
        if "config loaded" in body:
            log.update(started=t, sock=None, allow=None)
            ev((t, "启动", "config loaded（新进程）"))
        elif "starting slack adapter" in body:
            a = re.search(r"allow_all_channels=(\w+) allow_all_users=(\w+) channels=(\d+) users=(\d+)", body)
            if a:
                log["allow"] = {"allow_all_channels": a[1] == "true", "allow_all_users": a[2] == "true",
                                "channels": int(a[3]), "users": int(a[4])}
            ev((t, "Slack", "starting slack adapter"))
        elif "Slack Socket Mode connected" in body:
            log["sock"] = t
            ev((t, "Slack", "Socket Mode 已连接"))
        elif "session created session_id=" in body:
            sid = body.split("session_id=", 1)[1].split()[0]
            log["sessions"].add(sid)
            ev((t, "会话", f"创建会话 {sid}"))
        elif "batch dispatched" in body:
            log["dispatches"] += 1
            ms = re.search(r"agent_dispatch_ms=(\d+)", body)
            ev((t, "派发", f"Slack 消息已派发给 agent（agent 耗时 {ms[1] if ms else '?'} ms）"))
        elif "spawning agent" in body:
            c = re.search(r'cwd="([^"]*)"', body)
            ev((t, "spawn", f"拉起 agent，cwd={c[1] if c else '?'}"))
        elif "skills discovery:" in body:
            c = re.search(r"cwd=(\S+)", body)
            if c:
                log["devin_cwd"] = c[1]
        elif "control socket listening" in body:
            ev((t, "控制", "control socket 已监听"))
        elif ERR.search(body) and "acp::connection" not in body:
            ev((t, "错误", body[:200]))
    return log


def text_of(m):
    c = m.get("content")
    return c.strip() if isinstance(c, str) else ""


def tail_state(con, sid):
    rows = con.execute(
        "SELECT chat_message FROM message_nodes WHERE session_id=? ORDER BY row_id DESC LIMIT 60", (sid,)).fetchall()
    seen, msgs = set(), []
    for (raw,) in rows:
        try:
            j = json.loads(raw)
        except (TypeError, ValueError):
            continue
        if not isinstance(j, dict) or j.get("message_id") in seen:
            continue
        seen.add(j.get("message_id"))
        if ((j.get("metadata") or {}).get("telemetry") or {}).get("source") == "cache_keepalive" \
                or j.get("role") == "system":
            continue
        msgs.append(j)
    if not msgs:
        return "空会话", ""
    head = msgs[0]
    state = "等待回复" if head.get("role") == "user" else "执行中" if head.get("tool_calls") else "空闲"
    return state, next((t for t in map(text_of, msgs) if t), "")[:160]


def read_sessions(db, limit, openab_sids):
    p = Path(db)
    if not p.exists():
        raise FileNotFoundError(f"sessions.db 不存在：{p}")
    con = sqlite3.connect(p.as_uri() + "?mode=ro", uri=True, timeout=5)
    try:
        rows = con.execute(
            "SELECT id, title, working_directory, created_at, last_activity_at FROM sessions "
            "WHERE coalesce(hidden,0)=0 ORDER BY last_activity_at DESC LIMIT ?", (limit,)).fetchall()
        out = []
        for sid, title, wd, created, last in rows:
            try:
                state = tail_state(con, sid)[0]
            except sqlite3.Error:
                state = "未知"
            out.append({"id": sid, "title": (title or "(untitled)")[:60], "cwd": wd or "",
                        "cwd_bug": "\\mnt\\" in (wd or "").lower(),
                        "source": "OpenAB" if sid in openab_sids else "本地",
                        "state": state,
                        "created": local_fmt(created), "last": local_fmt(last)})
        return out
    finally:
        con.close()


def runner_active():
    lock = RELAY_DIR / "runner.lock"
    if not lock.exists():
        return False
    import msvcrt
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


def read_relay():
    board = RELAY_DIR / "board.json"
    if not board.exists():
        return None
    b = json.loads(board.read_text(encoding="utf-8"))
    hb = RELAY_DIR / "heartbeat.json"
    tasks = [{"id": t["id"], "title": t["title"], "status": t["status"], "owner": t.get("owner", ""),
              "round": t.get("round"), "max_rounds": t.get("max_rounds"), "sessions": len(t.get("sids", {})),
              "hops": [f"{h['ts'][5:16].replace('T', ' ')} {h['role']} → {h['to']}（{h['status']}）"
                       for h in t.get("history", [])[-4:]]}
             for t in b.get("tasks", [])]
    return {"runner_active": runner_active(),
            "heartbeat": json.loads(hb.read_text(encoding="utf-8")) if hb.exists() else None,
            "roles": [{"name": k} for k in b.get("roles", {})],
            "tasks": tasks}


def read_config(openab_dir):
    cfg = tomllib.loads((Path(openab_dir) / "config.toml").read_text(encoding="utf-8"))
    slack, agent, pool = cfg.get("slack", {}), cfg.get("agent", {}), cfg.get("pool", {})
    opts = pool.get("default_config_options") or {}
    return {"agent": Path(str(agent.get("command", ""))).name,
            "agent_args": " ".join(agent.get("args", [])),
            "working_dir": str(agent.get("working_dir", "")),
            "aliases": (cfg.get("workspace") or {}).get("aliases", {}),
            "max_sessions": pool.get("max_sessions"), "session_ttl_hours": pool.get("session_ttl_hours"),
            "mode": opts.get("mode"), "model": opts.get("model"),
            "allow_all_channels": slack.get("allow_all_channels", True),
            "allowed_channels": slack.get("allowed_channels", []),
            "allow_all_users": slack.get("allow_all_users", True),
            "allowed_users": slack.get("allowed_users", []),
            "allow_bot_messages": slack.get("allow_bot_messages", "off")}


def warnings_for(st):
    w, cfg, o = [], st["config"] or {}, st["openab"]
    if not o.get("running"):
        w.append(("bad", "OpenAB 进程未运行。终端关闭即停，没有自启，需在 WSL 中重新启动"))
    elif not o.get("socket_connected"):
        w.append(("warn", "进程在运行，但 Slack Socket Mode 未连接"))
    if cfg.get("allow_all_users"):
        w.append(("bad", "allow_all_users=true：频道内任何成员都能驱动本机 devin（bypass 模式，无审批）"))
    if cfg.get("allow_all_channels"):
        w.append(("warn", "allow_all_channels=true：bot 所在的任何频道都会响应"))
    wd = cfg.get("working_dir", "")
    if wd.startswith("/mnt/"):
        w.append(("bad", f"agent.working_dir 是 WSL 路径 {wd}，devin 会解析成 E:\\mnt\\… 错误目录"))
    elif wd[:2].endswith(":") and not os.path.isdir(wd):
        w.append(("bad", f"agent.working_dir 指向不存在的目录：{wd}"))
    if cfg.get("mode") == "bypass":
        w.append(("info", "pool.mode=bypass：无人值守，权限请求自动通过"))
    if "\\mnt\\" in (o.get("devin_cwd") or "").lower():
        w.append(("bad", f"devin 日志里的工作区是 {o['devin_cwd']}（错误目录）"))
    for s in st["sessions"]:
        if s["cwd_bug"]:
            w.append(("bad", f"会话 {s['id']}（{s['title']}）工作目录错误：{s['cwd']}"))
    return w


def collect(opts):
    st = {"generated_at": fmt(dt.datetime.now()), "openab": {}, "config": None,
          "sessions": [], "events": [], "warnings": [], "errors": {}}
    err = st["errors"]
    running, pids = False, []
    try:
        running, pids = openab_running()
    except (OSError, subprocess.SubprocessError) as e:
        err["process"] = f"进程检查失败：{e}"
    log = parse_log("")
    try:
        lines = (Path(opts.openab_dir) / "openab.log").read_bytes().decode("utf-8", "replace").splitlines()
        log = parse_log("\n".join(lines[-opts.log_lines:]))
    except OSError as e:
        err["log"] = f"日志读取失败：{e}"
    started = log["started"] if running else None
    now = dt.datetime.now().astimezone()
    secs = int((now - started).total_seconds()) if started else None
    st["openab"] = {
        "running": running, "pids": pids,
        "started_at": fmt(started),
        "uptime": f"{secs // 3600}h {secs % 3600 // 60}m" if secs is not None else None,
        "socket_connected": bool(running and log["sock"] and started and log["sock"] >= started),
        "socket_connected_at": fmt(log["sock"]),
        "devin_cwd": log["devin_cwd"],
        "dispatches": log["dispatches"],
        "sessions_in_log": len(log["sessions"]),
        "allow": log["allow"],
    }
    try:
        st["config"] = read_config(opts.openab_dir)
    except (OSError, subprocess.SubprocessError, RuntimeError, tomllib.TOMLDecodeError) as e:
        err["config"] = f"config 读取失败：{e}"
    try:
        st["sessions"] = read_sessions(opts.sessions_db, opts.sessions_limit, log["sessions"])
    except (OSError, sqlite3.Error) as e:
        err["sessions"] = f"会话池读取失败：{e}"
    st["events"] = [{"time": fmt(t), "kind": k, "text": x}
                    for t, k, x in sorted(log["events"], key=lambda ev: ev[0], reverse=True)[:80]]
    try:
        st["relay"] = read_relay()
    except (OSError, ValueError) as e:
        err["relay"] = f"接力板读取失败：{e}"
    st["warnings"] = [{"level": lv, "text": tx} for lv, tx in warnings_for(st)]
    return st


PAGE = r"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OpenAB 多会话桥</title>
<style>
*{box-sizing:border-box}
body{margin:0;font:13px/1.5 system-ui,"Microsoft YaHei",sans-serif;background:#0e1319;color:#d7dee7}
header{display:flex;align-items:center;gap:12px;padding:12px 18px;background:#141c25;border-bottom:1px solid #223041;position:sticky;top:0;z-index:1;flex-wrap:wrap}
header h1{margin:0;font-size:16px}
.muted{color:#7d8c9b}
.badge{display:inline-block;padding:1px 9px;border-radius:999px;font-size:12px;font-weight:600;white-space:nowrap}
.ok{background:#1d6b41;color:#dcfde9}.bad{background:#7d2433;color:#ffdbe0}.warn{background:#7a5b1c;color:#fff1cf}.info{background:#25466a;color:#d9ecff}.gray{background:#2c3742;color:#c8d2dc}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:14px;padding:14px 18px}
.card{background:#141c25;border:1px solid #223041;border-radius:10px;padding:12px 14px;min-width:0}
.card.wide{grid-column:1/-1}
.card h2{margin:0 0 8px;font-size:13px;color:#9fb3c8;font-weight:600}
.kv{display:grid;grid-template-columns:110px 1fr;gap:4px 10px}
.kv>div:nth-child(odd){color:#7d8c9b}
.mono{font-family:Consolas,"Cascadia Mono",monospace;font-size:12px;word-break:break-all}
table{width:100%;border-collapse:collapse;font-size:12.5px}
th,td{text-align:left;padding:5px 6px;border-bottom:1px solid #1d2935;vertical-align:top}
th{color:#7d8c9b;font-weight:600}
.bad-cell{color:#ff8a98;font-weight:600}
.list>div{padding:5px 0;border-bottom:1px solid #1d2935}
.list .t{color:#7d8c9b;font-family:Consolas,monospace;font-size:12px;margin-right:8px}
.snip{color:#9fb3c8;font-size:12px;margin-top:2px}
</style></head>
<body>
<header>
  <h1>OpenAB 多会话桥 · 只读状态</h1>
  <span id="run" class="badge gray">加载中…</span>
  <span id="ts" class="muted"></span>
  <span class="muted" style="margin-left:auto">每 10 秒自动刷新 · 只读，不做任何写操作</span>
</header>
<main>
  <section class="card" id="proc"><h2>运行与连接</h2><div class="muted">加载中…</div></section>
  <section class="card" id="cfg"><h2>配置（~/openab/config.toml）</h2><div class="muted">加载中…</div></section>
  <section class="card wide" id="warn"><h2>告警</h2><div class="muted">加载中…</div></section>
  <section class="card wide" id="sess"><h2>会话池（sessions.db）</h2><div class="muted">加载中…</div></section>
  <section class="card wide" id="relay"><h2>多角色接力</h2><div class="muted">加载中…</div></section>
  <section class="card wide" id="ev"><h2>事件（openab.log，最新在前）</h2><div class="muted">加载中…</div></section>
</main>
<script>
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const badge = (cls, text) => `<span class="badge ${cls}">${esc(text)}</span>`;
const LV = {bad:["bad","高"], warn:["warn","中"], info:["info","提示"]};
function render(d) {
  const o = d.openab || {}, c = d.config, e = d.errors || {};
  const run = document.getElementById("run");
  run.className = "badge " + (o.running ? "ok" : "bad");
  run.textContent = o.running ? "OpenAB 运行中" : "OpenAB 已停止";
  document.getElementById("ts").textContent = "数据时间 " + d.generated_at;
  const devinBad = (o.devin_cwd || "").toLowerCase().includes("\\mnt\\");
  document.getElementById("proc").innerHTML = `<h2>运行与连接</h2><div class="kv">
    <div>进程 PID</div><div class="mono">${esc((o.pids || []).join(", ") || "—")}</div>
    <div>本次启动</div><div>${esc(o.started_at || "—")}${o.uptime ? "（已运行 " + esc(o.uptime) + "）" : ""}</div>
    <div>Slack 连接</div><div>${o.socket_connected ? badge("ok", "Socket Mode 已连接") : badge("bad", "未连接")} <span class="muted">${esc(o.socket_connected_at || "")}</span></div>
    <div>派发次数</div><div>${esc(o.dispatches ?? 0)}（日志窗口内）· 会话创建 ${esc(o.sessions_in_log ?? 0)} 个</div>
    <div>devin 工作区</div><div class="mono ${devinBad ? "bad-cell" : ""}">${esc(o.devin_cwd || "—")}</div>
    </div>${e.process || e.log ? `<div class="bad-cell" style="margin-top:8px">${esc(e.process || "")} ${esc(e.log || "")}</div>` : ""}`;
  if (c) {
    const allowCh = c.allow_all_channels ? badge("warn", "全部频道") : esc((c.allowed_channels || []).join(", ") || "（空）");
    const allowUs = c.allow_all_users ? badge("bad", "全部成员") : esc((c.allowed_users || []).join(", ") || "（空）");
    const aliases = Object.entries(c.aliases || {}).map(([k, v]) => k + " → " + v).join("；") || "—";
    document.getElementById("cfg").innerHTML = `<h2>配置（~/openab/config.toml）</h2><div class="kv">
      <div>agent</div><div class="mono">${esc(c.agent)} ${esc(c.agent_args)}</div>
      <div>working_dir</div><div class="mono ${String(c.working_dir).startsWith("/mnt/") ? "bad-cell" : ""}">${esc(c.working_dir)}</div>
      <div>workspace 别名</div><div class="mono">${esc(aliases)}</div>
      <div>Slack 频道</div><div>${allowCh}</div>
      <div>Slack 成员</div><div>${allowUs}</div>
      <div>bot 消息</div><div class="mono">${esc(c.allow_bot_messages)}</div>
      <div>会话池</div><div>最多 ${esc(c.max_sessions)} 个，TTL ${esc(c.session_ttl_hours)} h，mode=${esc(c.mode)}，model=${esc(c.model)}</div>
      </div>`;
  } else {
    document.getElementById("cfg").innerHTML = `<h2>配置（~/openab/config.toml）</h2><div class="bad-cell">${esc(e.config || "读取失败")}</div>`;
  }
  const w = d.warnings || [];
  document.getElementById("warn").innerHTML = `<h2>告警（${w.length}）</h2>` + (w.length
    ? `<div class="list">${w.map(x => { const [cls, lab] = LV[x.level] || ["gray", x.level]; return `<div>${badge(cls, lab)} ${esc(x.text)}</div>`; }).join("")}</div>`
    : `<div class="muted">无告警</div>`);
  const rows = (d.sessions || []).map(s => `<tr>
    <td>${esc(s.title)}</td>
    <td>${s.source === "OpenAB" ? badge("info", "OpenAB") : badge("gray", "本地")}</td>
    <td>${esc(s.state)}</td>
    <td class="mono ${s.cwd_bug ? "bad-cell" : ""}">${s.cwd_bug ? "⚠ " : ""}${esc(s.cwd)}</td>
    <td>${esc(s.last || "")}</td>
    <td class="mono muted">${esc(s.id)}</td></tr>`).join("");
  document.getElementById("sess").innerHTML = `<h2>会话池（sessions.db 最近 ${(d.sessions || []).length} 条）</h2>`
    + (e.sessions ? `<div class="bad-cell">${esc(e.sessions)}</div>` : "")
    + (rows ? `<table><thead><tr><th>标题</th><th>来源</th><th>状态</th><th>工作目录</th><th>最后活动</th><th>ID</th></tr></thead><tbody>${rows}</tbody></table>` : `<div class="muted">无会话记录</div>`);
  const evs = (d.events || []).map(x => `<div><span class="t">${esc(x.time)}</span>${badge(x.kind === "错误" ? "bad" : x.kind === "派发" ? "ok" : "gray", x.kind)} ${esc(x.text)}</div>`).join("");
  document.getElementById("ev").innerHTML = `<h2>事件（openab.log，最新在前）</h2>`
    + (evs ? `<div class="list">${evs}</div>` : `<div class="muted">无事件${e.log ? "（" + esc(e.log) + "）" : ""}</div>`);
}
function renderRelay(rl, e) {
  const el = document.getElementById("relay");
  if (!rl) { el.innerHTML = `<h2>多角色接力</h2><div class="muted">${esc(e.relay || "无接力数据")}</div>`; return; }
  const TS = {doing: ["info", "进行中"], done: ["ok", "完成"], blocked: ["bad", "阻塞"]};
  const roles = rl.roles.map(r => esc(r.name)).join("，") + "（每个任务各自独立会话）";
  const rows = rl.tasks.map(t => {
    const [cls, lab] = TS[t.status] || ["gray", t.status];
    return `<tr><td>${esc(t.id)} ${esc(t.title)}</td><td>${badge(cls, lab)}</td><td>${esc(t.owner || "—")}</td>
      <td>${esc(t.round)}/${esc(t.max_rounds)} <span class="muted">会话 ${esc(t.sessions)}</span></td><td class="mono">${t.hops.map(h => esc(h)).join("<br>")}</td></tr>`;
  }).join("");
  el.innerHTML = `<h2>多角色接力（只显示状态与交接，不显示正文）</h2><div class="kv">
    <div>编排器</div><div>${rl.runner_active ? badge("ok", "运行中") : badge("gray", "空闲")} <span class="muted">${rl.heartbeat ? "心跳 " + esc(rl.heartbeat.ts) : "无心跳"}</span></div>
    <div>角色</div><div>${roles}</div></div>`
    + (rows ? `<table style="margin-top:8px"><thead><tr><th>任务</th><th>状态</th><th>当前角色</th><th>轮次</th><th>最近交接（角色 → 目标，结果）</th></tr></thead><tbody>${rows}</tbody></table>` : `<div class="muted">暂无任务</div>`);
}
async function refresh() {
  try {
    const r = await fetch("/api/status", {cache: "no-store"});
    if (!r.ok) throw new Error("HTTP " + r.status);
    const d = await r.json();
    render(d);
    renderRelay(d.relay, d.errors || {});
  } catch (err) {
    const run = document.getElementById("run");
    run.className = "badge bad";
    run.textContent = "面板取数失败：" + err.message;
  }
  setTimeout(refresh, 10000);
}
refresh();
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path
        if path == "/":
            return self.reply(200, "text/html; charset=utf-8", PAGE.encode("utf-8"))
        if path == "/api/status":
            body = json.dumps(collect(self.server.opts), ensure_ascii=False, default=str).encode("utf-8")
            return self.reply(200, "application/json; charset=utf-8", body)
        if path == "/healthz":
            return self.reply(200, "text/plain; charset=utf-8", b"ok")
        return self.reply(404, "text/plain; charset=utf-8", b"not found")

    def reply(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt_, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt_ % args))


def main():
    ap = argparse.ArgumentParser(description="OpenAB 多会话桥只读状态页")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8770)
    ap.add_argument("--openab-dir", default=r"\\wsl.localhost\Ubuntu\home\sigeer\openab")
    ap.add_argument("--sessions-db", default=SESSIONS_DB)
    ap.add_argument("--sessions-limit", type=int, default=12)
    ap.add_argument("--log-lines", type=int, default=4000)
    opts = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    srv = ThreadingHTTPServer((opts.host, opts.port), Handler)
    srv.opts = opts
    print(f"OpenAB dashboard (read-only): http://{opts.host}:{opts.port}/", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
