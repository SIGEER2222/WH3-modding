# -*- coding: utf-8 -*-
"""WH3 campaign progress dashboard — local web server (stdlib only).

Usage:
    python web_progress/server.py [--port 8321] [--save-dir <path>]

Endpoints:
    GET /                     dashboard page
    GET /static/<file>        static assets
    GET /api/saves            list save files (newest first)
    GET /api/summary?id=<name>  parsed campaign summary (cached per save mtime)
"""

import hashlib
import json
import os
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)

from parser.campaign import summarize_save  # noqa: E402

try:
    import gamedb          # noqa: E402
    import bonuscalc       # noqa: E402
    _BONUS_OK = True
except Exception:          # noqa: BLE001 - run without bonus support
    gamedb = None
    bonuscalc = None
    _BONUS_OK = False

import timeline as timeline_mod  # noqa: E402
import locdb  # noqa: E402
import digest as digest_mod  # noqa: E402

DEFAULT_SAVE_DIR = r"C:\Users\22448\AppData\Roaming\The Creative Assembly\Warhammer3\save_games"
CACHE_DIR = os.path.join(ROOT, "cache")
STATIC_DIR = os.path.join(ROOT, "static")

SAVE_DIR = DEFAULT_SAVE_DIR
PORT = 8321

_locks = {}
_locks_guard = threading.Lock()


def _lock_for(key):
    with _locks_guard:
        if key not in _locks:
            _locks[key] = threading.Lock()
        return _locks[key]


def _nearest_region(x, y, region_xy, max_dist=60.0):
    if x is None or y is None or not region_xy:
        return None
    best = None
    best_d = max_dist * max_dist
    for k, xy in region_xy.items():
        d = (xy[0] - x) * (xy[0] - x) + (xy[1] - y) * (xy[1] - y)
        if d < best_d:
            best_d = d
            best = k
    return best


def _commander_cn(cmd):
    if not cmd:
        return None
    parts = []
    for elem in ("forename", "family_name", "clan_name", "other"):
        k = cmd.get(elem)
        if k:
            t = locdb.char_name(k)
            if t:
                parts.append(t)
    return "·".join(parts) if parts else None


def _merged_loc():
    """gamedb (modded playset) loc over vanilla locdb loc, once."""
    if locdb._loc is None:
        locdb._load_loc()
    if _BONUS_OK and gamedb is not None:
        db = gamedb.load()
        if db and not getattr(locdb, "_gamedb_merged", False):
            merged = dict(locdb._loc)
            merged.update(db.get("loc") or {})
            locdb._loc = merged
            locdb._gamedb_merged = True
    return gamedb.load() if _BONUS_OK and gamedb else None


def localize_summary(s):
    """Attach *_cn display fields to a raw schema>=5 summary (in place)."""
    save = s.get("save") or {}
    player = s.get("player") or {}
    world = s.get("world") or {}
    factions = s.get("factions") or []
    region_xy = world.get("region_xy") or {}
    gdb = _merged_loc()
    gunits = (gdb or {}).get("units") or {}

    save["campaign_cn"] = locdb.campaign_name(save.get("campaign"))
    names = {"factions": {}, "regions": {}}
    for f in factions:
        k = f.get("key")
        if k:
            cn = locdb.faction_name(k)
            f["name_cn"] = cn or k
            names["factions"][k] = cn or k
    for r in (world.get("regions") or []):
        k = r.get("key")
        if k:
            cn = locdb.region_name(k)
            r["name_cn"] = cn or k
            names["regions"][k] = cn or k
        if r.get("owner"):
            r["owner_cn"] = locdb.faction_name(r["owner"]) or r["owner"]
        r["buildings_named"] = [
            {"key": b, "name": locdb.building_name(b) or b}
            for b in (r.get("buildings") or [])
        ]
    s["names"] = names

    if not player:
        return s
    player["faction_cn"] = locdb.faction_name(player.get("key")) or player.get("key")

    for a in (player.get("armies") or []):
        a["province_cn"] = locdb.province_name(a.get("province")) if a.get("province") else None
        if a.get("province_cn"):
            a["location_cn"] = a["province_cn"]
        else:
            rk = _nearest_region(a.get("x"), a.get("y"), region_xy)
            a["location_cn"] = ((locdb.region_name(rk) or rk) + " 附近") if rk else None
        if a.get("garrison_of"):
            a["garrison_cn"] = locdb.region_name(a["garrison_of"]) or a["garrison_of"]
        cmdr = None
        for u in (a.get("units") or []):
            cat = gunits.get(u.get("key"))
            u["name_cn"] = (cat or {}).get("name") or locdb.unit_name(u.get("key")) or u.get("key")
            stats = locdb.unit_stats(u.get("key")) or {}
            if cat:
                stats = dict(stats)
                stats["upkeep"] = cat.get("upkeep_cost") or stats.get("upkeep")
                stats["recruit_cost"] = cat.get("recruitment_cost") or stats.get("recruit_cost")
            u["power"] = stats.get("mp_cost")
            u["num_men"] = stats.get("num_men")
            u["tier"] = stats.get("tier")
            u["upkeep"] = stats.get("upkeep")
            if u.get("strength") and u["num_men"] == 1:
                u["strength_kind"] = "hp"
            elif u.get("strength"):
                u["strength_kind"] = "men"
            cn2 = _commander_cn(u.get("commander"))
            if cn2:
                u["commander_cn"] = cn2
                if cmdr is None:
                    cmdr = cn2
        if cmdr is None:
            for nk in (a.get("commander_keys") or []):
                t = locdb.char_name(nk)
                if t:
                    cmdr = t
                    break
        a["commander_cn"] = cmdr
        a["unit_count"] = len(a.get("units") or [])
        a["power_estimate"] = sum(u["power"] or 0 for u in (a.get("units") or [])) or None
        a["upkeep_estimate"] = sum(u["upkeep"] or 0 for u in (a.get("units") or [])) or None

    for c in (player.get("characters") or []):
        c["type_cn"] = locdb.agent_type_cn(c.get("type"))
        rk = _nearest_region(c.get("x"), c.get("y"), region_xy)
        c["near_cn"] = (locdb.region_name(rk) or rk) if rk else None

    member_by_mid = {}
    for m in (player.get("members") or []):
        m["name_cn"] = locdb.member_name(m.get("name"))
        m["type_cn"] = locdb.agent_type_cn(m.get("type"))
        m["subtype_cn"] = locdb.subtype_name(m.get("subtype"))
        rk = _nearest_region(m.get("x"), m.get("y"), region_xy)
        m["near_cn"] = (locdb.region_name(rk) or rk) if rk else None
        if m.get("member_id") is not None:
            member_by_mid[m["member_id"]] = m

    # fill army commander names from the member record (unit name blocks
    # only carry the lord leading each unit slot; commander_member_id is
    # the army's actual commanding character)
    for a in (player.get("armies") or []):
        m = member_by_mid.get(a.get("commander_member_id"))
        if m is not None:
            a["commander_member"] = m
            if not a.get("commander_cn") and m.get("name_cn"):
                a["commander_cn"] = m["name_cn"]

    for b in (player.get("faction_bundles") or []):
        b["name_cn"] = locdb.bundle_name(b.get("key")) or b.get("key")

    for d in (player.get("diplomacy") or []):
        d["name_cn"] = locdb.faction_name(d.get("key")) or d.get("key")
        d["stance_cn"] = locdb.stance_cn(d.get("stance"))

    for m in (player.get("missions") or []):
        m["title_cn"] = locdb.mission_title(m.get("title_loc")) or m.get("id")
        m["desc_cn"] = locdb.mission_desc(m.get("desc_loc"))
        m["status_cn"] = locdb.mission_status_cn(m.get("status"))

    player["ancillary_named"] = [
        {"key": a, "name": locdb.ancillary_name(a) or a}
        for a in (player.get("ancillaries") or [])
    ]
    player["resources_named"] = [
        {"key": k, "value": v, "name": locdb.pooled_name(k) or k}
        for k, v in (player.get("resources") or {}).items()
    ]

    for r in (player.get("regions") or []):
        r["name_cn"] = locdb.region_name(r.get("key")) or r.get("key")
        r["buildings_named"] = [
            {"key": b, "name": locdb.building_name(b) or b}
            for b in (r.get("buildings") or [])
        ]

    world["wars_named"] = [
        {"a": a, "b": b,
         "a_cn": locdb.faction_name(a) or a, "b_cn": locdb.faction_name(b) or b}
        for a, b in (world.get("wars") or [])
    ]
    return s


_EVENT_TEXT = None


def _event_cn(e):
    """One timeline event -> a short Chinese line (mirrors app.js EVENT_STYLES)."""
    t = e.get("type")
    k = e.get("key")
    d = e.get("detail") or {}
    f = lambda x: (locdb.faction_name(x) or x) if x else "?"
    turn = e.get("turn")
    pre = "T%s " % turn if isinstance(turn, int) else ""
    if t == "war_declared":
        return pre + "宣战：对 " + f(k)
    if t == "war_ended":
        return pre + "停战：与 " + f(k)
    if t == "faction_destroyed":
        return pre + "派系灭亡：" + f(k)
    if t == "faction_emerged":
        return pre + "派系出现：" + f(k)
    if t == "units_dropped":
        return pre + "军力骤减：%s（%s 单位）" % (f(k), d.get("delta"))
    if t == "units_surge":
        return pre + "军力激增：%s（+%s 单位）" % (f(k), d.get("delta"))
    if t == "forces_dropped":
        return pre + "军团被歼：%s（-%s 队）" % (f(k), -(d.get("delta") or 0))
    if t == "forces_surge":
        return pre + "军团扩充：%s（+%s 队）" % (f(k), d.get("delta"))
    if t == "characters_dropped":
        return pre + "角色折损：%s（-%s 名）" % (f(k), -(d.get("delta") or 0))
    if t == "player_characters_changed":
        delta = d.get("delta") or 0
        return pre + ("新角色加入：+%d 名" % delta if delta > 0
                      else "角色折损：%d 名" % delta)
    if t == "building_completed":
        return pre + "%s 建成 %s" % ((locdb.region_name(k) or k),
                                             (locdb.building_name(d.get("building")) or d.get("building")))
    if t == "building_lost":
        return pre + "%s 失去 %s" % ((locdb.region_name(k) or k),
                                             (locdb.building_name(d.get("building")) or d.get("building")))
    if t == "ancillary_gained":
        return pre + "获得装备：" + (locdb.ancillary_name(d.get("item")) or str(d.get("item")))
    if t == "ancillary_lost":
        return pre + "失去装备：" + (locdb.ancillary_name(d.get("item")) or str(d.get("item")))
    if t == "mission_issued":
        return pre + "发布任务：%s（%s）" % (
            d.get("mission"), locdb.mission_status_cn(d.get("status")))
    if t == "mission_status":
        return pre + "任务 %s：%s → %s" % (
            d.get("mission"), locdb.mission_status_cn(d.get("from")),
            locdb.mission_status_cn(d.get("to")))
    if t == "storm_spawned":
        return pre + "魔法风暴生成：" + str(d.get("storm"))
    if t == "storm_ended":
        return pre + "风暴消散：" + str(d.get("storm"))
    if t == "crisis_triggered":
        return pre + "终局危机触发！"
    return pre + str(t)


def localize_timeline_data(data):
    """Attach Chinese names to a timeline payload (events + series) in place."""
    if not data:
        return data
    for e in (data.get("events") or []):
        if e.get("key"):
            e["key_cn"] = locdb.faction_name(e["key"]) or locdb.region_name(e["key"]) or e["key"]
        d = e.get("detail") or {}
        if d.get("building"):
            d["building_cn"] = locdb.building_name(d["building"]) or d["building"]
        if d.get("item"):
            d["item_cn"] = locdb.ancillary_name(d["item"]) or d["item"]
        if d.get("mission"):
            d["mission_cn"] = locdb.mission_title(d["mission"]) or d["mission"]
        e["text_cn"] = _event_cn(e)
    for key, sers in (data.get("series") or {}).items():
        sers["name_cn"] = locdb.faction_name(key) or key
    return data


def find_saves():
    """List .save files newest first."""
    out = []
    try:
        entries = os.listdir(SAVE_DIR)
    except OSError as exc:
        return {"error": "cannot list save dir %s: %s" % (SAVE_DIR, exc), "saves": []}
    for name in entries:
        if not name.lower().endswith(".save"):
            continue
        path = os.path.join(SAVE_DIR, name)
        try:
            st = os.stat(path)
        except OSError:
            continue
        out.append({
            "id": urllib.parse.quote(name),
            "name": name,
            "mtime": int(st.st_mtime),
            "size": st.st_size,
        })
    out.sort(key=lambda x: -x["mtime"])
    return {"save_dir": SAVE_DIR, "saves": out}


def cache_path_for(info):
    key = "v7|%s|%d|%d" % (info["name"], info["size"], info["mtime"])
    digest = hashlib.sha1(key.encode("utf-8")).hexdigest()
    return os.path.join(CACHE_DIR, digest + ".json"), key


TIMELINE_PATH = os.path.join(CACHE_DIR, "timeline.json")
TL = {"building": False, "done": 0, "total": 0, "error": None, "started": None}
_tl_lock = threading.Lock()


def _session_key(save_name, turn):
    """Save filenames embed <turn><session_id>; strip the turn digits to get
    the campaign session key (falls back to the raw number)."""
    import re
    m = re.search(r"(\d{6,})", save_name or "")
    if not m or not isinstance(turn, int):
        return m.group(1) if m else (save_name or "?")
    num = m.group(1)
    return num[len(str(turn)):] or num


def _timeline_worker(limit):
    try:
        listing = find_saves()
        saves = listing["saves"]
        if limit:
            saves = saves[:limit]
        TL["total"] = len(saves)
        TL["done"] = 0
        by_session = {}
        for info in saves:  # newest first
            code, summary = get_summary(info["id"])
            TL["done"] += 1
            if code != 200:
                continue
            turn = summary["save"].get("turn")
            key = _session_key(info["name"], turn)
            by_session.setdefault(key, []).append(summary)
        sessions = []
        for key, sums in by_session.items():
            data = timeline_mod.build_timeline(sums)
            data["session_key"] = key
            sessions.append({
                "key": key,
                "campaign": data.get("campaign"),
                "save_count": data.get("save_count"),
                "turn_span": [data["points"][0]["turn"], data["points"][-1]["turn"]] if data.get("points") else None,
                "events": len(data.get("events") or []),
                "data": data,
            })
        sessions.sort(key=lambda s: -s["save_count"])
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = TIMELINE_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"schema": timeline_mod.SCHEMA + 100, "sessions": sessions}, f, ensure_ascii=False)
        os.replace(tmp, TIMELINE_PATH)
    except Exception as exc:  # noqa: BLE001
        TL["error"] = repr(exc)
    finally:
        TL["building"] = False


def start_timeline_build(limit=None):
    with _tl_lock:
        if TL["building"]:
            return False
        TL["building"] = True
        TL["error"] = None
        TL["started"] = time.time()
    threading.Thread(target=_timeline_worker, args=(limit,), daemon=True).start()
    return True


def timeline_status(session=None, strict=False):
    if TL["building"]:
        return {"status": "building", "done": TL["done"], "total": TL["total"],
                "elapsed": round(time.time() - (TL["started"] or time.time()))}
    if TL["error"]:
        return {"status": "error", "error": TL["error"]}
    if os.path.isfile(TIMELINE_PATH):
        try:
            with open(TIMELINE_PATH, "r", encoding="utf-8") as f:
                blob = json.load(f)
            sessions = blob.get("sessions") or []
            if sessions and blob.get("schema") == timeline_mod.SCHEMA + 100:
                primary = sessions[0]
                if session:
                    matched = None
                    for s in sessions:
                        if s["key"] == session:
                            matched = s
                            break
                    if matched is None and strict:
                        return {"status": "ready",
                                "active_sessions": [
                                    {"key": s["key"], "campaign": s["campaign"],
                                     "save_count": s["save_count"],
                                     "turn_span": s["turn_span"], "events": s["events"]}
                                    for s in sessions
                                ],
                                "data": None}
                    if matched is not None:
                        primary = matched
                return {
                    "status": "ready",
                    "active_sessions": [
                        {"key": s["key"], "campaign": s["campaign"], "save_count": s["save_count"],
                         "turn_span": s["turn_span"], "events": s["events"]}
                        for s in sessions
                    ],
                    "data": localize_timeline_data(primary["data"]),
                }
        except (OSError, ValueError):
            pass
    return {"status": "empty"}


def get_summary_raw(save_id):
    """Raw cached parse (schema>=5, no *_cn fields)."""
    return _get_summary(save_id)


def get_summary(save_id):
    code, obj = _get_summary(save_id)
    if code == 200:
        obj = localize_summary(obj)
    return code, obj


def _get_summary(save_id):
    name = urllib.parse.unquote(save_id)
    if os.path.basename(name) != name or "/" in name or "\\" in name or ":" in name:
        return 400, {"error": "bad save id"}
    path = os.path.join(SAVE_DIR, name)
    if not os.path.isfile(path):
        return 404, {"error": "save not found: %s" % name}
    st = os.stat(path)
    info = {"name": name, "size": st.st_size, "mtime": int(st.st_mtime)}
    cpath, key = cache_path_for(info)
    if os.path.isfile(cpath):
        try:
            with open(cpath, "r", encoding="utf-8") as f:
                return 200, json.load(f)
        except (OSError, ValueError):
            pass
    with _lock_for(key):
        # double-check cache after acquiring the lock
        if os.path.isfile(cpath):
            try:
                with open(cpath, "r", encoding="utf-8") as f:
                    return 200, json.load(f)
            except (OSError, ValueError):
                pass
        summary = summarize_save(path)
        summary["save_file"] = {"name": name, "mtime": info["mtime"], "size": info["size"]}
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = cpath + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(summary, f, ensure_ascii=False)
        os.replace(tmp, cpath)
        return 200, summary


class Handler(BaseHTTPRequestHandler):
    server_version = "WH3Progress/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (self.address_string(), fmt % args))

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"),
                   "application/json; charset=utf-8")

    def do_GET(self):
        parsed = urllib.parse.urlsplit(self.path)
        route = parsed.path
        if route == "/":
            route = "/static/index.html"
        if route.startswith("/static/"):
            fname = os.path.normpath(urllib.parse.unquote(route[len("/static/"):]))
            if fname.startswith("..") or os.path.isabs(fname):
                self._json(400, {"error": "bad path"})
                return
            fpath = os.path.join(STATIC_DIR, fname)
            if not os.path.isfile(fpath):
                self._json(404, {"error": "not found"})
                return
            ext = os.path.splitext(fpath)[1].lower()
            ctypes = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
                      ".css": "text/css; charset=utf-8", ".png": "image/png", ".svg": "image/svg+xml"}
            with open(fpath, "rb") as f:
                self._send(200, f.read(), ctypes.get(ext, "application/octet-stream"))
            return
        if route == "/api/saves":
            self._json(200, find_saves())
            return
        if route == "/api/timeline":
            qs = urllib.parse.parse_qs(parsed.query)
            self._json(200, timeline_status((qs.get("session") or [None])[0]))
            return
        if route == "/api/timeline/build":
            qs = urllib.parse.parse_qs(parsed.query)
            limit = None
            if qs.get("limit"):
                try:
                    limit = max(2, int(qs["limit"][0]))
                except ValueError:
                    limit = None
            started = start_timeline_build(limit)
            self._json(200, {"started": started})
            return
        if route == "/api/brief":
            qs = urllib.parse.parse_qs(parsed.query)
            save_id = (qs.get("id") or [""])[0]
            fmt = (qs.get("format") or ["json"])[0]
            if not save_id:
                self._json(400, {"error": "missing id"})
                return
            try:
                code, obj = get_summary(save_id)
                if code != 200:
                    self._json(code, obj)
                    return
                # pull recent events from the built timeline if available —
                # same session as this save, and only events <= its turn
                events = []
                turn = ((obj.get("save") or {}).get("turn"))
                name = urllib.parse.unquote(save_id)
                sess = _session_key(name, turn)
                tl = timeline_status(sess, strict=True)
                if tl.get("status") == "ready":
                    data = tl.get("data") or {}
                    kept = [
                        e for e in (data.get("events") or [])
                        if not isinstance(turn, int)
                        or not isinstance(e.get("turn"), int)
                        or e["turn"] <= turn
                    ]
                    for e in kept[:15]:
                        events.append(e.get("text_cn") or _event_cn(e))
                d = digest_mod.build_digest(obj, events=events)
                if fmt in ("md", "text", "markdown"):
                    body = digest_mod.digest_to_markdown(d).encode("utf-8")
                    self._send(200, body, "text/plain; charset=utf-8")
                    return
                self._json(200, d)
            except Exception as exc:  # noqa: BLE001
                self._json(500, {"error": "brief failed: %r" % (exc,)})
            return
        if route == "/api/summary":
            qs = urllib.parse.parse_qs(parsed.query)
            save_id = (qs.get("id") or [""])[0]
            if not save_id:
                self._json(400, {"error": "missing id"})
                return
            try:
                code, obj = get_summary(save_id)
            except Exception as exc:  # noqa: BLE001 - report parse failures to UI
                self._json(500, {"error": "parse failed: %r" % (exc,)})
                return
            self._json(code, obj)
            return
        if route == "/api/army":
            qs = urllib.parse.parse_qs(parsed.query)
            save_id = (qs.get("id") or [""])[0]
            if not save_id:
                self._json(400, {"error": "missing id"})
                return
            try:
                idx = int((qs.get("i") or ["0"])[0])
            except ValueError:
                idx = 0
            self._json(*_army_detail(save_id, idx))
            return
        if route == "/api/icon":
            qs = urllib.parse.parse_qs(parsed.query)
            name = (qs.get("name") or [""])[0]
            if not name or ".." in name:
                self._json(400, {"error": "bad name"})
                return
            res = gamedb.read_image(name) if (gamedb and gamedb.load()) else None
            if not res:
                self._json(404, {"error": "no icon"})
                return
            blob, ext = res
            self._send(200, blob, "image/png" if ext == "png" else
                       "application/octet-stream")
            return
        self._json(404, {"error": "not found"})


def _army_detail(save_id, army_index):
    """Unit cards + resolved campaign bonuses for one player army."""
    if not _BONUS_OK:
        return 503, {"error": "bonus module unavailable"}
    db = gamedb.load()
    if db is None:
        return 503, {"error": "gamedb load failed: %s" % gamedb.error()}
    code, obj = _get_summary(save_id)
    if code != 200:
        return code, obj
    ctx = _bonus_ctx()
    rep = bonuscalc.army_report(ctx, obj, army_index)
    if rep is None:
        return 404, {"error": "army index out of range"}
    rep["playset"] = db.get("playset_name")
    return 200, rep


_bonus_ctx_cache = {"fingerprint": None, "ctx": None}


def _bonus_ctx():
    db = gamedb.load()
    fp = db.get("cache_path") if db else None
    if _bonus_ctx_cache["ctx"] is None or _bonus_ctx_cache["fingerprint"] != fp:
        _bonus_ctx_cache["ctx"] = bonuscalc.Ctx(db)
        _bonus_ctx_cache["fingerprint"] = fp
    return _bonus_ctx_cache["ctx"]


def main():
    global PORT, SAVE_DIR
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--port" and i + 1 < len(args):
            PORT = int(args[i + 1])
            i += 2
        elif args[i] == "--save-dir" and i + 1 < len(args):
            SAVE_DIR = args[i + 1]
            i += 2
        else:
            i += 1
    class _Server(ThreadingHTTPServer):
        # SO_REUSEADDR on Windows lets a second process steal the same port —
        # stale instances then alternate responses. Disable it so a second
        # bind fails loudly instead of shadowing the live server.
        allow_reuse_address = False

    httpd = _Server(("127.0.0.1", PORT), Handler)
    print("WH3 campaign progress dashboard: http://127.0.0.1:%d" % PORT)
    print("save dir: %s" % SAVE_DIR)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
