#!/usr/bin/env python3
"""server.py — czx talk 的 Web UI：本地 HTTP 服务 + 叙事 feed 页面。

用法：
  python server.py                     # 静态回放（读 out/campaign_log.jsonl）
  python server.py --live [--seed 1]   # 实时模拟：后台跑 sim，前端轮询出流
端口：8787。无任何三方依赖（stdlib only）。
"""
import json, os, sys, threading, time, argparse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

ROOT = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(ROOT, "out", "campaign_log.jsonl")

PAGE = """<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">
<title>czx · 战史实录</title><style>
body{background:#14100c;color:#d8cdb4;font-family:"Segoe UI",serif;margin:0}
#hd{position:sticky;top:0;background:#1c1712;border-bottom:1px solid #4a3b28;
    padding:10px 16px;display:flex;gap:14px;align-items:center}
#hd h1{font-size:16px;margin:0;color:#c9a45c}
#hd .meta{color:#8a7d63;font-size:12px}
.badge{font-size:11px;padding:1px 8px;border-radius:8px;border:1px solid}
.dilemma{color:#c99ae0;border-color:#7a4d96}.event_feed{color:#7fb0d8;border-color:#3f6a8c}
.battle_bark{color:#e08a7f;border-color:#8c4a3f}
#feed{padding:8px 16px 80px;max-width:900px;margin:0 auto}
.ev{padding:7px 4px;border-bottom:1px solid #241e16;line-height:1.55}
.ev .t{color:#6a5f4d;font-size:11px;margin-right:8px}
.ev .sp{color:#c9a45c;font-weight:600}
.ev .tx{white-space:pre-wrap}
.filters label{margin-right:12px;font-size:12px;cursor:pointer}
</style></head><body>
<div id="hd"><h1>⚔ 战史实录</h1>
 <span class="meta" id="meta">载入中…</span>
 <span class="filters" style="margin-left:auto">
  <label><input type="checkbox" checked data-ch="dilemma"> 檄文</label>
  <label><input type="checkbox" checked data-ch="battle_bark"> 战阵</label>
  <label><input type="checkbox" checked data-ch="event_feed"> 世界</label>
 </span></div>
<div id="feed"></div>
<script>
let last=0, chans={dilemma:1,battle_bark:1,event_feed:1};
document.querySelectorAll('.filters input').forEach(cb=>cb.onchange=e=>{chans[e.target.dataset.ch]=e.target.checked?1:0;paint()});
const feed=document.getElementById('feed'); let evs=[];
async function poll(){
 try{const r=await fetch('/api/feed?after='+last);const d=await r.json();
  if(d.events.length){evs=evs.concat(d.events);last=d.events[d.events.length-1].id;paint()}
  document.getElementById('meta').textContent=`回合 ${d.state.turn} · 存活派系 ${d.state.alive} · 事件 ${d.state.total}`+(d.state.done?' · 已统一':'');
 }catch(e){}
 setTimeout(poll,1200)}
function paint(){feed.innerHTML=evs.filter(e=>chans[e.channel]).map(e=>
 `<div class="ev"><span class="t">T${e.turn}</span><span class="badge ${e.channel}">${e.channel}</span> <span class="sp">${e.speaker}</span> <span class="tx">${e.text}</span></div>`).join('');
 window.scrollTo(0,document.body.scrollHeight)}
poll();
</script></body></html>"""


class Feed:
    """事件缓冲：live 模式 sim 线程 append；静态模式从 JSONL 读。"""
    def __init__(self):
        self.events = []           # {id,turn,channel,speaker,text}
        self.state = {"turn": 0, "alive": 0, "total": 0, "done": False}
        self.lock = threading.Lock()

    def push(self, rec):
        ln = rec.get("line") or {}
        with self.lock:
            self.events.append({"id": rec["id"], "turn": rec["turn"],
                                "channel": ln.get("channel", "event_feed"),
                                "speaker": ln.get("speaker", ""),
                                "text": ln.get("text", "")})
            self.state["turn"] = rec["turn"]
            self.state["alive"] = rec["state"]["alive"]
            self.state["total"] = len(self.events)

FEED = Feed()


def sim_worker(seed):
    """实时模拟：跑 sim，逐事件推入 FEED（节流 ~0.15s/事件）。"""
    import sim_campaign
    eng_path = os.path.join(ROOT, "out", "campaign_log.jsonl")
    # 直接把 sim 的世界循环跑起来，但事件要走 FEED——用临时文件中转
    tmp = os.path.join(ROOT, "out", "_live.jsonl")
    open(tmp, "w").close()

    import io
    from contextlib import redirect_stdout
    # 简化：直接调用 sim.run 但逐事件落盘太重；改为 sim 里 eng.fire 后置 hook 不可行，
    # 所以：跑 sim 到临时文件 → 按节流回放进 FEED（先生成全部，再流式吐出）
    stats = sim_campaign.run(seed=seed, out_path=tmp)
    for line in open(tmp, encoding="utf-8"):
        FEED.push(json.loads(line))
        time.sleep(0.15)
    FEED.state["done"] = True
    FEED.state["turn"] = stats["turns"]


def load_static():
    for line in open(LOG, encoding="utf-8"):
        FEED.push(json.loads(line))
    FEED.state["done"] = True


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        u = urlparse(self.path)
        if u.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers(); self.wfile.write(body)
        elif u.path == "/api/feed":
            after = int(parse_qs(u.query).get("after", [0])[0])
            with FEED.lock:
                evs = [e for e in FEED.events if e["id"] > after]
                st = dict(FEED.state)
            body = json.dumps({"events": evs[:500], "state": st},  # 从头分页，追平后再实时
                              ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers(); self.wfile.write(body)
        else:
            self.send_response(404); self.end_headers()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--port", type=int, default=8787)
    a = ap.parse_args()
    if a.live:
        threading.Thread(target=sim_worker, args=(a.seed,), daemon=True).start()
    elif os.path.exists(LOG):
        load_static()
    print(f"http://localhost:{a.port}  ({'live sim' if a.live else 'static replay'})")
    ThreadingHTTPServer(("127.0.0.1", a.port), H).serve_forever()


if __name__ == "__main__":
    main()
