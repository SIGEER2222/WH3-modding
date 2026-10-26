# -*- coding: utf-8 -*-
"""wh3-relay Mattermost 一键初始化：admin(human) + team + channel + 4 bot + token + 头像。

用法：python provision.py [--reset]
幂等：重复跑只补缺的部分。产物写 ../_agent_relay/relay.env（gitignored）。
"""
import argparse
import io
import json
import sys
import time
import urllib.request
import urllib.error
import uuid
from pathlib import Path

BASE = "http://127.0.0.1:8065"
HERE = Path(__file__).resolve().parent
ENV_OUT = HERE.parent / "_agent_relay" / "relay.env"
ICON_DIR = Path(r"E:\Code\ai-workspace\scripts\2026-10-26\slack_apps\icons")

ADMIN = {"username": "sigeer", "email": "sigeer@wh3-relay.local", "password": "Wh3-relay!2026"}
TEAM = {"name": "wh3", "display_name": "WH3 Modding", "type": "O"}
CHANNEL = {"name": "relay", "display_name": "wh3-relay", "type": "O"}
BOTS = [
    ("生产", "wh3-producer", "生产（读写执行）"),
    ("审计", "wh3-auditor", "审计（只读核对）"),
    ("验证", "wh3-verifier", "验证（独立复核证据）"),
    ("编排", "wh3-orchestrator", "编排器（任务卡/交接）"),
]


def api(method, path, tok=None, body=None, raw=None, ctype=None, ok=(200, 201)):
    url = BASE + "/api/v4" + path
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", ctype or "application/json")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        txt = e.read().decode()[:300]
        if e.code in ok:
            return e.code, {}
        raise RuntimeError(f"{method} {path} -> {e.code}: {txt}")


def wait_ready(timeout=120):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            s, _ = api("GET", "/system/ping")
            if s == 200:
                return
        except Exception:
            pass
        time.sleep(2)
    raise SystemExit("Mattermost 未就绪")


def multipart(fields, file_field, fname, fbytes):
    b = uuid.uuid4().hex
    buf = io.BytesIO()
    for k, v in fields.items():
        buf.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode())
    buf.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{file_field}\"; filename=\"{fname}\"\r\n"
              f"Content-Type: image/png\r\n\r\n".encode())
    buf.write(fbytes)
    buf.write(f"\r\n--{b}--\r\n".encode())
    return buf.getvalue(), f"multipart/form-data; boundary={b}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reset", action="store_true", help="重建 bots（不删 admin/team/channel）")
    a = ap.parse_args()
    wait_ready()
    print("server ready")

    # 1) admin = human（首个用户自动 system_admin）
    try:
        _, u = api("POST", "/users", body=ADMIN)
        print("admin created:", u["id"])
    except RuntimeError as e:
        if e.args and "403" not in str(e) and "taken" not in str(e) and "already" not in str(e):
            raise
        print("admin exists / signup closed")
    # 登录拿 token
    req = urllib.request.Request(BASE + "/api/v4/users/login",
                                 data=json.dumps({"login_id": ADMIN["username"], "password": ADMIN["password"]}).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        adm_tok = r.headers["Token"]
        me = json.loads(r.read().decode())
    human_id = me["id"]
    print("admin token ok, human_id =", human_id)

    api("PUT", "/config/patch", adm_tok, {"ServiceSettings": {"EnableBotAccountCreation": True}})

    # 2) team / channel
    try:
        _, team = api("POST", "/teams", adm_tok, TEAM)
    except RuntimeError as e:
        if "taken" not in str(e) and "already" not in str(e):
            raise
        _, team = api("GET", "/teams/name/wh3", adm_tok)
    team_id = team["id"]
    api("POST", f"/teams/{team_id}/members", adm_tok, {"team_id": team_id, "user_id": human_id}, ok=(200, 201, 400))
    try:
        _, ch = api("POST", "/channels", adm_tok, {**CHANNEL, "team_id": team_id})
    except RuntimeError as e:
        if "taken" not in str(e) and "already" not in str(e):
            raise
        _, ch = api("GET", f"/teams/{team_id}/channels/name/relay", adm_tok)
    chan_id = ch["id"]
    api("POST", f"/channels/{chan_id}/members", adm_tok, {"user_id": human_id}, ok=(200, 201, 400))
    print(f"team={team_id} channel={chan_id}")

    # 3) bots + tokens + avatar + channel member
    env_lines = [
        "# agent_relay Mattermost 凭据（本文件被 .gitignore 排除，不入库）",
        "CHAT_PLATFORM=mattermost",
        f"MM_URL={BASE}",
        f"MM_CHANNEL={chan_id}",
        f"MM_HUMAN_ID={human_id}",
        f"MM_TEAM={team_id}",
    ]
    for role, uname, desc in BOTS:
        try:
            _, bot = api("POST", "/bots", adm_tok, {"username": uname, "display_name": f"wh3-{role}", "description": desc})
        except RuntimeError as e:
            if "taken" not in str(e) and "already" not in str(e):
                raise
            _, bots = api("GET", "/bots?include_deleted=false", adm_tok)
            bot = next(b for b in bots if b["username"] == uname)
        uid = bot["user_id"]
        # bot personal access token
        _, tk = api("POST", f"/users/{uid}/tokens", adm_tok, {"description": "agent_relay"})
        token = tk["token"]
        # avatar
        icon = ICON_DIR / f"icon_{role}.png"
        if icon.exists():
            try:
                data, ct = multipart({}, "image", icon.name, icon.read_bytes())
                api("POST", f"/users/{uid}/image", adm_tok, raw=data, ctype=ct)
            except Exception as e:
                print(f"  {role} 头像上传失败（忽略）：{e}")
        api("POST", f"/teams/{team_id}/members", adm_tok, {"team_id": team_id, "user_id": uid}, ok=(200, 201, 400))
        api("POST", f"/channels/{chan_id}/members", adm_tok, {"user_id": uid}, ok=(200, 201, 400))
        env_lines += [f"MM_UID_{role}={uid}", f"MM_USER_{role}={uname}", f"CHAT_TOKEN_{role}={token}"]
        print(f"bot {role}: uid={uid} token={token[:12]}…")

        if role == "编排":
            env_lines.append(f"CHAT_BOT_TOKEN={token}")

    ENV_OUT.parent.mkdir(parents=True, exist_ok=True)
    ENV_OUT.write_text("\n".join(env_lines) + "\n", encoding="utf-8")
    print("wrote", ENV_OUT)
    print("DONE - web:", BASE, "| channel: #relay @ wh3")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
