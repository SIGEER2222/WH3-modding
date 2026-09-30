# -*- coding: utf-8 -*-
"""WH3 工作区内容索引 —— 把 mod 源码 / gamedata / bilingual / pack 内容物
预索引到 SQLite，让「key/表/内部路径/loc/脚本内容 在哪定义、被谁覆盖」
从逐包扫描变成毫秒级查询。

用法（pack 解码要 zstandard —— build 必须 Windows Python313；查询任意 python）：

  wh3index.py build [--full] [--packs|--src]     增量建索引（默认）
  wh3index.py status [--stale]                  索引规模；--stale 逐个核对 pack mtime
  wh3index.py find <子串>                       全类别一把搜（db key/loc/path/包名/mod 名）
  wh3index.py path <内部路径> [--exact] [--playset]
                                                谁提供该文件（同路径遮蔽=靠前胜）
  wh3index.py key <子串> [--table T] [--playset]
                                                谁写了该主键 + 哪些行的外键引用它
                                                （行冲突=靠后胜；悬空引用排查入口）
  wh3index.py table <子串>                      哪些来源碰了这张表
  wh3index.py loc <子串> [--text]               loc key（或文本）反查
  wh3index.py grep <正则> [--ext SUF]           已存文本内容搜索（mod 源码+mod 包内 lua/xml/txt）
  wh3index.py pack <名子串>                     单包概览（表/行/loc 统计）
  wh3index.py mod <名>                          单个 mod_files 源概览
  wh3index.py show <key> [--table T] [--diff]   整行字段值；--diff 只列多来源间值不同的列
                                                （改数值：谁改了哪列、改成什么）
  wh3index.py links <key> [--depth N]           外键引用 BFS：unit→group→pool→faction
                                                招募/派系接线图（"扩充到别的派系"用）
  wh3index.py cols <table> [--ver N]            表字段清单+主键*/外键→标记（改 TSV 前对照）

索引文件：tools/_index/index.sqlite（gitignore: tools/_*/）。不改动被索引对象；
pack 侧只读。--playset 标注读 used_mods.txt（最近一次启动清单），非实时 state.db。
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_gamedata import (  # noqa: E402
    decode_db_table,
    iter_pack_index,
    load_schema,
    parse_loc,
    read_pack_payload,
)
import wh3diag  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
INDEX_DIR = ROOT / "tools" / "_index"
DB_PATH = INDEX_DIR / "index.sqlite"
MOD_FILES = ROOT / "mod_files"
GAMEDATA = ROOT / "gamedata"
BILINGUAL = ROOT / "bilingual"

TEXT_EXT = {".lua", ".xml", ".txt", ".csv", ".md"}
TEXT_CAP = 1_500_000  # bytes; larger text payloads stay path-only
ROW_CAP = 25


# ------------------------------------------------------------------ helpers

def canon(p: Path) -> str:
    """Canonical display path: Windows-style, so WSL/Win builders agree."""
    s = str(p)
    m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", s)
    if m:
        s = m.group(1).upper() + ":\\" + m.group(2).replace("/", "\\")
    return s


def _connect() -> sqlite3.Connection:
    INDEX_DIR.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(str(DB_PATH))
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA synchronous=OFF")
    con.executescript(
        """
        CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
        CREATE TABLE IF NOT EXISTS sources(
            id INTEGER PRIMARY KEY,
            src TEXT, origin TEXT, path TEXT, kind TEXT,
            size INT, mtime REAL,
            UNIQUE(src, origin, path));
        -- no secondary indexes on path/key: all queries are LIKE '%x%'
        -- (leading wildcard can't use them anyway)
        CREATE TABLE IF NOT EXISTS db_tables(
            id INTEGER PRIMARY KEY, name TEXT UNIQUE);
        CREATE TABLE IF NOT EXISTS db_rows(
            file_id INT, table_id INT, key TEXT, rownum INT,
            PRIMARY KEY(file_id, table_id, key, rownum));
        CREATE INDEX IF NOT EXISTS i_db_tbl ON db_rows(table_id);
        CREATE TABLE IF NOT EXISTS ref_rows(
            file_id INT, table_id INT, target TEXT, key TEXT, rownum INT,
            PRIMARY KEY(file_id, table_id, target, key, rownum));
        CREATE INDEX IF NOT EXISTS i_ref_tgt ON ref_rows(target);
        CREATE TABLE IF NOT EXISTS loc_rows(
            file_id INT, lang TEXT, key TEXT, text TEXT,
            PRIMARY KEY(file_id, key));
        CREATE TABLE IF NOT EXISTS texts(
            file_id INT PRIMARY KEY, content TEXT);
        """
    )
    return con


_TID_CACHE: dict[str, int] = {}


def _table_id(con, name: str) -> int:
    tid = _TID_CACHE.get(name)
    if tid is None:
        cur = con.execute(
            "INSERT OR IGNORE INTO db_tables(name) VALUES(?) RETURNING id",
            (name,))
        row = cur.fetchone()
        if row is None:
            row = con.execute(
                "SELECT id FROM db_tables WHERE name=?", (name,)).fetchone()
        tid = row[0]
        _TID_CACHE[name] = tid
    return tid


def _file_id(con, src, origin, path, kind, size, mtime) -> int:
    cur = con.execute(
        "INSERT INTO sources(src,origin,path,kind,size,mtime) "
        "VALUES(?,?,?,?,?,?) "
        "ON CONFLICT(src,origin,path) DO UPDATE SET "
        "kind=excluded.kind,size=excluded.size,mtime=excluded.mtime "
        "RETURNING id",
        (src, origin, path, kind, size, mtime))
    return cur.fetchone()[0]


def _drop(con, src, origin, path=None):
    """Delete a source file/pack and its derived rows."""
    q = "src=? AND origin=?" + (" AND path=?" if path else "")
    args = (src, origin) + ((path,) if path else ())
    ids = [r[0] for r in con.execute(
        f"SELECT id FROM sources WHERE {q}", args)]
    for chunk in (ids[i:i + 500] for i in range(0, len(ids), 500)):
        ph = ",".join("?" * len(chunk))
        for t in ("sources", "db_rows", "ref_rows", "loc_rows", "texts"):
            col = "id" if t == "sources" else "file_id"
            con.execute(f"DELETE FROM {t} WHERE {col} IN ({ph})", chunk)


# ------------------------------------------------------- schema key columns

_SCHEMA_KEYS: dict | None = None


def load_schema_meta() -> dict:
    """schema_wh3.ron -> {table: {version: {"keys", "refs", "defs"}}}.
    refs maps field_name -> "target_table.target_field";
    defs = [(name, field_type, is_key, ref_target|None)] in definition order."""
    global _SCHEMA_KEYS
    if _SCHEMA_KEYS is not None:
        return _SCHEMA_KEYS
    ron = wh3diag.schema_ron()
    tables: dict = {}
    if ron:
        text = Path(ron).read_text(encoding="utf-8")
        table_re = re.compile(r'(?m)^ {8}"([^"]+)": \[')
        matches = list(table_re.finditer(text))
        field_re = re.compile(
            r'name: "((?:[^"\\]|\\.)*)",\s*field_type: (\w+),\s*is_key: (true|false)')
        ref_re = re.compile(
            r'is_reference: Some\(\("([^"]+)",\s*"([^"]+)"\)\)')
        for i, m in enumerate(matches):
            block = text[m.end(): matches[i + 1].start()
                         if i + 1 < len(matches) else len(text)]
            vers: dict = {}
            for vm in re.finditer(r"version: (\d+),\s*fields: \[", block):
                vend = block.find("localised_fields", vm.end())
                seg = block[vm.end():vend]
                keys, refs, defs = [], {}, []
                fms = list(field_re.finditer(seg))
                for j, fm in enumerate(fms):
                    fblock = seg[fm.start(): fms[j + 1].start()
                                 if j + 1 < len(fms) else len(seg)]
                    is_key = fm.group(3) == "true"
                    rm = ref_re.search(fblock)
                    tgt = f"{rm.group(1)}.{rm.group(2)}" if rm else None
                    if is_key:
                        keys.append(fm.group(1))
                    if tgt:
                        refs[fm.group(1)] = tgt
                    defs.append((fm.group(1), fm.group(2), is_key, tgt))
                vers[int(vm.group(1))] = {"keys": keys, "refs": refs,
                                          "defs": defs}
            tables[m.group(1)] = vers
    _SCHEMA_KEYS = tables
    return tables


def key_indexes(table: str, version, fields: list[str]) -> list[int]:
    ks = load_schema_meta().get(table, {})
    ver = ks.get(version) or {}
    names = ver.get("keys")
    if not names:
        names = sorted({n for v in ks.values() for n in v.get("keys", [])},
                       key=lambda n: fields.index(n) if n in fields else 999)
    idx = [fields.index(n) for n in names if n in fields]
    return idx or [0]


def ref_indexes(table: str, version, fields: list[str]):
    """[(column_index, "target_table.target_col")] for is_reference fields.
    version=None (or unknown) falls back to the union over all versions."""
    ks = load_schema_meta().get(table, {})
    ver = ks.get(version) or {}
    refs = dict(ver.get("refs") or {})
    if version is None or not refs:
        for v in ks.values():
            for f, tgt in (v.get("refs") or {}).items():
                refs.setdefault(f, tgt)
    out = [(fields.index(f), tgt) for f, tgt in refs.items() if f in fields]
    return out


# ------------------------------------------------------------ source TSV

def _db_tsv_rows(fp: Path, table_hint: str):
    """Parse RPFM TSV -> (table, [(key, rownum)], [(target, value, rownum)])."""
    with fp.open("r", encoding="utf-8-sig", errors="replace", newline="") as f:
        header = f.readline()
        if not header:
            return table_hint, [], []
        fields = header.rstrip("\n").split("\t")
        meta = f.readline().strip()
        version = None
        if meta.startswith("#"):
            parts = meta[1:].split(";")
            if len(parts) >= 3 and parts[0]:
                table_hint = parts[0]
            try:
                version = int(parts[1])
            except (IndexError, ValueError):
                pass
        idx = key_indexes(table_hint, version, fields)
        ridx = ref_indexes(table_hint, version, fields)
        rows, refs = [], []
        for i, line in enumerate(f, 1):
            cells = line.rstrip("\n").split("\t")
            key = "|".join(cells[j] if j < len(cells) else "" for j in idx)
            rows.append((key, i))
            for j, tgt in ridx:
                if j < len(cells) and cells[j]:
                    refs.append((tgt, cells[j], i))
        return table_hint, rows, refs


def _loc_tsv_rows(fp: Path):
    rows = []
    with fp.open("r", encoding="utf-8-sig", errors="replace", newline="") as f:
        for i, line in enumerate(f):
            if i == 0 or line.startswith("#"):
                continue
            cells = line.rstrip("\n").split("\t")
            if len(cells) >= 2 and cells[0]:
                rows.append((cells[0], cells[1]))
    return rows


def _lang_of(path: str, fallback=""):
    p = path.casefold()
    if "_en.loc" in p or "_en.tsv" in p or "/en/" in p:
        return "EN"
    if "_cn" in p or "/cn/" in p:
        return "CN"
    return fallback


def _kind_of(path: str) -> str:
    p = path.casefold()
    if p.startswith("db/"):
        return "db"
    if p.endswith((".loc", ".loc.tsv")) or p.startswith("text/"):
        return "loc"
    ext = p.rsplit(".", 1)[-1] if "." in p else ""
    if ext == "lua":
        return "lua"
    if ext == "xml" or p.endswith(".twui.xml"):
        return "ui"
    if ext in ("txt", "csv", "md"):
        return "txt"
    return ext or "file"


def _read_text(b: bytes):
    if len(b) > TEXT_CAP or b"\x00" in b[:8192]:
        return None
    for enc in ("utf-8-sig", "utf-16"):
        try:
            return b.decode(enc)
        except UnicodeDecodeError:
            continue
    return None


# ------------------------------------------------------------------ build

def _diff(con, src, disk: dict[tuple[str, str], tuple[float, int]]):
    """Return (new/changed keys, removed keys) vs stored sources rows."""
    stored = {}
    for origin, path, mtime, size in con.execute(
            "SELECT origin,path,mtime,size FROM sources WHERE src=?", (src,)):
        stored[(origin, path)] = (mtime, size)
    changed = [k for k, v in disk.items()
               if k not in stored or abs(stored[k][0] - v[0]) > 1e-6
               or stored[k][1] != v[1]]
    removed = [k for k in stored if k not in disk]
    return changed, removed


def _index_mod_tsv(con, mod, rel, fp):
    if rel.startswith("db/"):
        table_hint = rel.split("/")[-2] if "/" in rel else ""
        table, rows, refs = _db_tsv_rows(fp, table_hint)
        st = fp.stat()
        fid = _file_id(con, "mod", mod, rel, "db", st.st_size, st.st_mtime)
        tid = _table_id(con, table)
        con.executemany(
            "INSERT OR REPLACE INTO db_rows VALUES(?,?,?,?)",
            [(fid, tid, k, n) for k, n in rows])
        con.executemany(
            "INSERT OR REPLACE INTO ref_rows VALUES(?,?,?,?,?)",
            [(fid, tid, tgt, k, n) for tgt, k, n in refs])
        return "db"
    if _kind_of(rel) == "loc" or rel.endswith(".loc.tsv"):
        rows = _loc_tsv_rows(fp)
        con.executemany(
            "INSERT OR REPLACE INTO loc_rows VALUES(?,?,?,?)",
            [(_file_id(con, "mod", mod, rel, "loc",
                       fp.stat().st_size, fp.stat().st_mtime),
              _lang_of(rel), k, t) for k, t in rows])
        return "loc"
    return _kind_of(rel)


def _build_mods(con, stats):
    if not MOD_FILES.is_dir():
        return
    disk = {}
    for moddir in sorted(MOD_FILES.iterdir()):
        if not moddir.is_dir():
            continue
        for fp in moddir.rglob("*"):
            if not fp.is_file():
                continue
            rel = fp.relative_to(moddir).as_posix()
            st = fp.stat()
            disk[(moddir.name, rel)] = (st.st_mtime, st.st_size)
    changed, removed = _diff(con, "mod", disk)
    for origin, path in removed:
        _drop(con, "mod", origin, path)
    for origin, rel in changed:
        fp = MOD_FILES / origin / rel
        _drop(con, "mod", origin, rel)
        st = fp.stat()
        try:
            if rel.casefold().endswith(".tsv"):
                kind = _index_mod_tsv(con, origin, rel, fp)
            else:
                kind = _kind_of(rel)
                if Path(rel).suffix.casefold() in TEXT_EXT:
                    txt = _read_text(fp.read_bytes())
                    if txt is not None:
                        con.execute(
                            "INSERT OR REPLACE INTO texts VALUES(?,?)",
                            (_file_id(con, "mod", origin, rel, kind,
                                      st.st_size, st.st_mtime), txt))
        except OSError as exc:
            stats["err"].append(f"mod:{origin}/{rel}: {exc}")
            kind = "file"
        _file_id(con, "mod", origin, rel, kind, st.st_size, st.st_mtime)
    stats["mod"] = len(disk)
    stats["mod_chg"] = len(changed)


def _build_gamedata(con, stats):
    if not GAMEDATA.is_dir():
        return
    disk = {}
    for fp in GAMEDATA.rglob("*"):
        if not fp.is_file() or fp.suffix == ".raw":
            continue
        rel = fp.relative_to(GAMEDATA).as_posix()
        st = fp.stat()
        disk[("vanilla", rel)] = (st.st_mtime, st.st_size)
    changed, removed = _diff(con, "gamedata", disk)
    for origin, path in removed:
        _drop(con, "gamedata", origin, path)
    for origin, rel in changed:
        fp = GAMEDATA / rel
        _drop(con, "gamedata", origin, rel)
        st = fp.stat()
        kind = _kind_of(rel)
        try:
            if rel.startswith("db/") and rel.endswith(".tsv"):
                table_hint = rel.split("/")[1] if "/" in rel else ""
                table, rows, refs = _db_tsv_rows(fp, table_hint)
                fid = _file_id(con, "gamedata", origin, rel, "db",
                               st.st_size, st.st_mtime)
                tid = _table_id(con, table)
                con.executemany(
                    "INSERT OR REPLACE INTO db_rows VALUES(?,?,?,?)",
                    [(fid, tid, k, n) for k, n in rows])
                con.executemany(
                    "INSERT OR REPLACE INTO ref_rows VALUES(?,?,?,?,?)",
                    [(fid, tid, tgt, k, n) for tgt, k, n in refs])
                kind = "db"
        except OSError as exc:
            stats["err"].append(f"gamedata:{rel}: {exc}")
        _file_id(con, "gamedata", origin, rel, kind, st.st_size, st.st_mtime)
    stats["gamedata"] = len(disk)
    stats["gd_chg"] = len(changed)


def _build_bilingual(con, stats):
    if not BILINGUAL.is_dir():
        return
    disk = {}
    for lang_dir in ("EN", "CN"):
        d = BILINGUAL / lang_dir
        if not d.is_dir():
            continue
        for fp in d.glob("*.tsv"):
            rel = fp.relative_to(BILINGUAL).as_posix()
            st = fp.stat()
            disk[(lang_dir, rel)] = (st.st_mtime, st.st_size)
    changed, removed = _diff(con, "bilingual", disk)
    for origin, path in removed:
        _drop(con, "bilingual", origin, path)
    for origin, rel in changed:
        fp = BILINGUAL / rel
        _drop(con, "bilingual", origin, rel)
        st = fp.stat()
        try:
            rows = _loc_tsv_rows(fp)
            fid = _file_id(con, "bilingual", origin, rel, "loc",
                           st.st_size, st.st_mtime)
            con.executemany(
                "INSERT OR REPLACE INTO loc_rows VALUES(?,?,?,?)",
                [(fid, origin, k, t) for k, t in rows])
        except OSError as exc:
            stats["err"].append(f"bilingual:{rel}: {exc}")
    stats["bilingual"] = len(disk)
    stats["bi_chg"] = len(changed)


def _all_packs():
    out = []
    d = wh3diag.data_dir()
    if d:
        out += [(p, "data") for p in sorted(d.glob("*.pack"))]
    ws = wh3diag.workshop_dir()
    if ws:
        out += [(p, "ws") for p in sorted(ws.glob("*/*.pack"))]
    if wh3diag.MOD_OUTPUT.is_dir():
        out += [(p, "out") for p in sorted(wh3diag.MOD_OUTPUT.glob("*.pack"))]
    return out


def _index_pack(con, pack: Path, scope: str, schemas, stats):
    """Index one pack: all internal paths; payload rows if it is a mod pack."""
    origin = canon(pack)
    label = pack.name if scope != "ws" else f"{pack.parent.name}/{pack.name}"
    try:
        entries = list(iter_pack_index(pack))
    except (OSError, struct.error) as exc:
        stats["err"].append(f"pack:{label}: {exc}")
        return
    is_mod = scope in ("ws", "out") or any(
        e.name.casefold().endswith(".rpfm_reserved") for e in entries)
    mtime = pack.stat().st_mtime
    for e in entries:
        fid = _file_id(con, "pack", origin, e.name, _kind_of(e.name),
                       e.size, mtime)
        e._fid = fid  # noqa: SLF001 - stash for payload pass
    stats["pack_files"] += len(entries)
    if not is_mod:
        return
    for e in entries:
        p = e.name.casefold()
        try:
            if p.startswith("db/") and "/" in e.name:
                table = e.name.split("/")[1]
                payload = read_pack_payload(pack, e)
                try:
                    ver, fields, rows = decode_db_table(
                        table, payload, schemas.get(table, {}))
                except Exception:
                    continue  # undecodable fragment stays path-indexed
                idx = key_indexes(table, ver, fields)
                ridx = ref_indexes(table, ver, fields)
                tid = _table_id(con, table)
                con.executemany(
                    "INSERT OR REPLACE INTO db_rows VALUES(?,?,?,?)",
                    [(e._fid, tid,
                      "|".join(r[j] if j < len(r) else "" for j in idx), i + 1)
                     for i, r in enumerate(rows)])
                con.executemany(
                    "INSERT OR REPLACE INTO ref_rows VALUES(?,?,?,?,?)",
                    [(e._fid, tid, tgt, r[j], i + 1)
                     for i, r in enumerate(rows)
                     for j, tgt in ridx if j < len(r) and r[j]])
                stats["pack_rows"] += len(rows)
            elif p.endswith(".loc"):
                payload = read_pack_payload(pack, e)
                try:
                    rows = parse_loc(payload)
                except Exception:
                    continue
                lang = _lang_of(e.name)
                con.executemany(
                    "INSERT OR REPLACE INTO loc_rows VALUES(?,?,?,?)",
                    [(e._fid, lang, k, t) for k, t, _tip in rows])
            elif Path(p).suffix in TEXT_EXT:
                txt = _read_text(read_pack_payload(pack, e))
                if txt is not None:
                    con.execute(
                        "INSERT OR REPLACE INTO texts VALUES(?,?)",
                        (e._fid, txt))
        except OSError as exc:
            stats["err"].append(f"pack:{label}:{e.name}: {exc}")


def _build_packs(con, stats):
    packs = _all_packs()
    disk_mtime = {}
    for p, _s in packs:
        try:
            disk_mtime[canon(p)] = p.stat().st_mtime
        except OSError:
            pass
    stored = {o: m for o, m in con.execute(
        "SELECT origin, MAX(mtime) FROM sources "
        "WHERE src='pack' GROUP BY origin")}
    scope_of = {canon(p): s for p, s in packs}
    ron = wh3diag.schema_ron()
    schemas = load_schema(Path(ron)) if ron else {}
    for origin in [o for o in stored if o not in disk_mtime]:
        _drop(con, "pack", origin)
        stats["pack_gone"] += 1
    for p, scope in packs:
        origin = canon(p)
        if origin not in disk_mtime:
            continue
        if origin in stored and abs(stored[origin] - disk_mtime[origin]) < 1e-6:
            continue
        _drop(con, "pack", origin)
        _index_pack(con, p, scope_of[origin], schemas, stats)
        stats["pack_chg"] += 1
    stats["packs"] = len(packs)


def cmd_build(a):
    con = _connect()
    if a.full:
        for t in ("sources", "db_rows", "ref_rows", "loc_rows",
                  "texts", "db_tables"):
            con.execute(f"DELETE FROM {t}")
        _TID_CACHE.clear()
    stats: dict = {"err": [], "pack_files": 0, "pack_rows": 0,
                   "pack_chg": 0, "pack_gone": 0}
    t0 = time.time()
    if not a.packs:
        _build_mods(con, stats)
        _build_gamedata(con, stats)
        _build_bilingual(con, stats)
    if not a.src:
        _build_packs(con, stats)
    con.execute("INSERT OR REPLACE INTO meta VALUES('built',?)",
                (time.strftime("%Y-%m-%d %H:%M:%S"),))
    con.commit()
    print(f"built in {time.time() - t0:.1f}s  ->  {DB_PATH}")
    for k in ("mod", "mod_chg", "gamedata", "gd_chg", "bilingual", "bi_chg",
              "packs", "pack_chg", "pack_gone", "pack_files", "pack_rows"):
        if k in stats:
            print(f"  {k:11} {stats[k]}")
    for e in stats["err"][:15]:
        print("  ERR", e)
    con.close()


# ------------------------------------------------------------------ query

_Q = ("SELECT s.src,s.origin,s.path{extra} FROM {t} r "
      "JOIN sources s ON s.id=r.file_id")


def _label(src, origin):
    if src == "mod":
        return f"mod:{origin}"
    if src == "gamedata":
        return "vanilla"
    if src == "bilingual":
        return f"loc:{origin}"
    name = origin.replace("\\", "/").rsplit("/", 1)[-1]
    low = origin.casefold()
    scope = ("ws" if "workshop" in low
             else "out" if "mod_output" in low else "data")
    return f"{scope}:{name}"


def _playset_map():
    """{canonical pack path (casefold): load pos} from used_mods.txt."""
    return {canon(p).casefold(): i
            for i, p in enumerate(wh3diag._used_mod_packs(mods_only=True))}


# ----------------------------------------------------------- row fetching

_PACK_SCHEMAS: dict | None = None
_PACK_ROW_CACHE: dict = {}
_TSV_ROW_CACHE: dict = {}


def _pack_schemas():
    global _PACK_SCHEMAS
    if _PACK_SCHEMAS is None:
        ron = wh3diag.schema_ron()
        _PACK_SCHEMAS = load_schema(Path(ron)) if ron else {}
    return _PACK_SCHEMAS


def _src_file(src, origin, path):
    if src == "mod":
        return MOD_FILES / origin / path
    if src == "gamedata":
        return GAMEDATA / path
    if src == "bilingual":
        return BILINGUAL / path
    return None


def _tsv_all(fp: Path):
    """-> (header_fields, [cells]) — data rows only, rownum-aligned (1-based)."""
    if fp in _TSV_ROW_CACHE:
        return _TSV_ROW_CACHE[fp]
    with fp.open("r", encoding="utf-8-sig", errors="replace", newline="") as f:
        header = f.readline().rstrip("\n").split("\t")
        f.readline()  # meta line
        data = [ln.rstrip("\n").split("\t") for ln in f]
    _TSV_ROW_CACHE[fp] = (header, data)
    return _TSV_ROW_CACHE[fp]


def _pack_db_rows(origin: str, internal: str):
    """-> (version, fields, rows) decoded from the pack entry, or None."""
    key = (origin, internal)
    if key in _PACK_ROW_CACHE:
        return _PACK_ROW_CACHE[key]
    pack = wh3diag.local_path(origin)
    out = None
    if pack.is_file():
        table = internal.split("/")[1] if "/" in internal else ""
        try:
            for e in iter_pack_index(pack):
                if e.name == internal:
                    try:
                        out = decode_db_table(
                            table, read_pack_payload(pack, e),
                            _pack_schemas().get(table, {}))
                    except Exception:
                        out = None
                    break
        except (OSError, struct.error):
            out = None
    _PACK_ROW_CACHE[key] = out
    return out


def fetch_row(con, file_id, rownum):
    """-> (src, origin, path, fields, cells) or None."""
    r = con.execute(
        "SELECT src,origin,path FROM sources WHERE id=?", (file_id,)).fetchone()
    if not r:
        return None
    src, origin, path = r
    if src in ("mod", "gamedata", "bilingual"):
        fp = _src_file(src, origin, path)
        if not fp or not fp.is_file():
            return None
        try:
            header, data = _tsv_all(fp)
        except OSError:
            return None
        if 1 <= rownum <= len(data):
            return src, origin, path, header, data[rownum - 1]
        return None
    if src == "pack":
        got = _pack_db_rows(origin, path)
        if not got:
            return None
        _ver, fields, rows = got
        if 1 <= rownum <= len(rows):
            return src, origin, path, fields, rows[rownum - 1]
    return None


def _row_refs(fields, cells, table):
    """[(col_name, value, ref_target)] non-empty outgoing FKs of a row."""
    out = []
    for j, tgt in ref_indexes(table, None, fields):
        if j < len(cells) and cells[j]:
            out.append((fields[j], cells[j], tgt))
    return out


def _fmt_cells(fields, cells, keep_empty=False):
    parts = []
    for n, v in zip(fields, cells):
        if v or keep_empty:
            parts.append(f"{n}={v}")
    return "  ".join(parts)


def cmd_status(a):
    if not DB_PATH.is_file():
        print("no index yet — run `wh3index.py build`")
        return
    con = _connect()
    print(f"index: {DB_PATH}  ({DB_PATH.stat().st_size / 1e6:.1f} MB)")
    row = con.execute("SELECT v FROM meta WHERE k='built'").fetchone()
    if row:
        print(f"built: {row[0]}")
    for t in ("sources", "db_rows", "ref_rows", "loc_rows",
              "texts", "db_tables"):
        n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"{t:9} {n}")
    for src, n in con.execute(
            "SELECT src, COUNT(DISTINCT origin) FROM sources GROUP BY src"):
        print(f"{src:9} origins={n}")
    disk_names = {p.name for p, _s in _all_packs()}
    stored_names = {o.replace("\\", "/").rsplit("/", 1)[-1]
                    for (o,) in con.execute(
                        "SELECT DISTINCT origin FROM sources "
                        "WHERE src='pack'")}
    missing = disk_names - stored_names
    gone = stored_names - disk_names
    print(f"packs on disk: {len(disk_names)}, indexed: {len(stored_names)}"
          + (f", NEW: {len(missing)}" if missing else "")
          + (f", GONE: {len(gone)}" if gone else ""))
    for n in sorted(missing)[:8]:
        print("   new:", n)
    if a.stale:
        stored = {o: m for o, m in con.execute(
            "SELECT origin, MAX(mtime) FROM sources "
            "WHERE src='pack' GROUP BY origin")}
        stale = [p.name for p, _s in _all_packs()
                 if canon(p) in stored
                 and abs(stored[canon(p)] - p.stat().st_mtime) > 1e-6]
        print(f"mtime-stale packs: {len(stale)}")
        for s in stale[:10]:
            print("   stale:", s)
    con.close()


def cmd_find(a):
    con = _connect()
    pat = f"%{a.substr}%"
    print(f"== db rows (key ~ {a.substr!r})")
    rows = list(con.execute(
        _Q.format(t="db_rows", extra=",t.name") +
        " JOIN db_tables t ON t.id=r.table_id "
        "WHERE r.key LIKE ? LIMIT ?", (pat, a.rows)))
    for src, o, p, t in rows:
        print(f"  {t}   {_label(src, o)}  {p}")
    tot = con.execute(
        "SELECT COUNT(*) FROM db_rows WHERE key LIKE ?", (pat,)).fetchone()[0]
    if tot > len(rows):
        print(f"  ... +{tot - len(rows)} more")
    rows = list(con.execute(
        _Q.format(t="ref_rows", extra=",t.name,r.target,r.key") +
        " JOIN db_tables t ON t.id=r.table_id "
        "WHERE r.key LIKE ? LIMIT ?", (pat, a.rows)))
    if rows:
        print("== references (引用该值的行)")
        for src, o, p, t, tgt, k in rows:
            print(f"  {t} →{tgt}  {k}   {_label(src, o)}  {p}")
    print("== loc keys")
    rows = list(con.execute(
        _Q.format(t="loc_rows", extra=",r.lang,r.key,r.text") +
        " WHERE r.key LIKE ? LIMIT ?", (pat, a.rows)))
    for src, o, p, lang, k, t in rows:
        print(f"  [{lang}] {k} = {t[:60]}   {_label(src, o)}")
    tot = con.execute(
        "SELECT COUNT(*) FROM loc_rows WHERE key LIKE ?", (pat,)).fetchone()[0]
    if tot > len(rows):
        print(f"  ... +{tot - len(rows)} more")
    print("== internal paths")
    rows = list(con.execute(
        "SELECT src,origin,path FROM sources WHERE path LIKE ? LIMIT ?",
        (pat, a.rows)))
    for src, o, p in rows:
        print(f"  {_label(src, o)}  {p}")
    tot = con.execute(
        "SELECT COUNT(*) FROM sources WHERE path LIKE ?", (pat,)).fetchone()[0]
    if tot > len(rows):
        print(f"  ... +{tot - len(rows)} more")
    print("== mods/packs")
    for src, o in con.execute(
            "SELECT DISTINCT src,origin FROM sources WHERE origin LIKE ? "
            "LIMIT ?", (pat, a.rows)):
        print(f"  {_label(src, o)}")
    con.close()


def cmd_path(a):
    con = _connect()
    pat = a.substr.replace("\\", "/")
    pmap = _playset_map() if a.playset else {}
    if a.exact:
        rows = [r for r in con.execute(
            "SELECT src,origin,path FROM sources") if
            (r[2] if "/" in pat else r[2].rsplit("/", 1)[-1]).casefold()
            == pat.casefold()]
    else:
        rows = list(con.execute(
            "SELECT src,origin,path FROM sources WHERE path LIKE ?",
            (f"%{pat}%",)))

    def sortkey(r):
        pos = pmap.get(r[1].casefold(), 10**6) if r[0] == "pack" else 10**6
        return (pos, r[0], r[2])
    rows.sort(key=sortkey)
    pack_pos = [pmap[o.casefold()] for s, o, _p in rows
                if s == "pack" and o.casefold() in pmap]
    winpos = min(pack_pos) if pack_pos else None  # file shadow: EARLIEST wins
    for src, o, p in rows[:a.rows]:
        pos = pmap.get(o.casefold()) if src == "pack" else None
        tag = f" pos{pos}" if pos is not None else ""
        win = " <== WINS(靠前遮蔽)" if pos is not None and pos == winpos else ""
        print(f"  {_label(src, o):36} {p}{tag}{win}")
    if len(rows) > a.rows:
        print(f"  ... +{len(rows) - a.rows} more")
    print(f"-- {len(rows)} provider rows")
    con.close()


def cmd_key(a):
    con = _connect()
    pmap = _playset_map() if a.playset else {}
    sql = (_Q.format(t="db_rows", extra=",t.name,r.key") +
           " JOIN db_tables t ON t.id=r.table_id WHERE r.key LIKE ?")
    args = [f"%{a.substr}%"]
    if a.table:
        sql += " AND t.name LIKE ?"
        args.append(f"%{a.table}%")
    rows = list(con.execute(sql, args))
    pack_pos = [pmap[o.casefold()] for s, o, _p, _t, _k in rows
                if s == "pack" and o.casefold() in pmap]
    winpos = max(pack_pos) if pack_pos else None  # row conflict: LAST wins
    for src, o, p, t, k in rows[:a.rows]:
        pos = pmap.get(o.casefold()) if src == "pack" else None
        tag = f" pos{pos}" if pos is not None else ""
        win = " <== WINS(靠后行胜出)" if pos is not None and pos == winpos else ""
        print(f"  {t:46} {k:44} {_label(src, o)}  {p}{tag}{win}")
    if len(rows) > a.rows:
        print(f"  ... +{len(rows) - a.rows} more")
    print(f"-- {len(rows)} key rows")
    # FK references to the same string
    sql = (_Q.format(t="ref_rows", extra=",t.name,r.target,r.key") +
           " JOIN db_tables t ON t.id=r.table_id WHERE r.key LIKE ?")
    args = [f"%{a.substr}%"]
    if a.table:
        sql += " AND t.name LIKE ?"
        args.append(f"%{a.table}%")
    refs = list(con.execute(sql, args))
    if refs:
        print("== references (这些行的外键列引用了该值)")
        for src, o, p, t, tgt, k in refs[:a.rows]:
            pos = pmap.get(o.casefold()) if src == "pack" else None
            tag = f" pos{pos}" if pos is not None else ""
            print(f"  {t:46} →{tgt}  {k:36} {_label(src, o)}{tag}")
        if len(refs) > a.rows:
            print(f"  ... +{len(refs) - a.rows} more")
    con.close()


def cmd_table(a):
    con = _connect()
    rows = list(con.execute(
        "SELECT t.name, s.src, s.origin, COUNT(*) c FROM db_rows r "
        "JOIN db_tables t ON t.id=r.table_id "
        "JOIN sources s ON s.id=r.file_id "
        "WHERE t.name LIKE ? GROUP BY t.name, s.src, s.origin "
        "ORDER BY t.name, c DESC", (f"%{a.substr}%",)))
    cur = None
    shown = 0
    for t, src, o, c in rows:
        if t != cur:
            print(f"{t}")
            cur = t
            shown = 0
        shown += 1
        if shown <= a.rows:
            print(f"    {c:>6} rows  {_label(src, o)}")
        elif shown == a.rows + 1:
            print("    ...")
    con.close()


def cmd_loc(a):
    con = _connect()
    col = "r.text" if a.text else "r.key"
    for src, o, p, lang, k, t in con.execute(
            _Q.format(t="loc_rows", extra=",r.lang,r.key,r.text") +
            f" WHERE {col} LIKE ? LIMIT ?", (f"%{a.substr}%", a.rows)):
        print(f"  [{lang or '?'}] {k}\n      {t[:120]}\n"
              f"      {_label(src, o)}  {p}")
    con.close()


def cmd_grep(a):
    con = _connect()
    try:
        rx = re.compile(a.pattern, re.IGNORECASE if a.i else 0)
    except re.error as exc:
        sys.exit(f"bad regex: {exc}")
    ext = a.ext.casefold() if a.ext else None
    hits = 0
    for src, o, p, content in con.execute(
            "SELECT s.src,s.origin,s.path,r.content FROM texts r "
            "JOIN sources s ON s.id=r.file_id"):
        if ext and not p.casefold().endswith(ext):
            continue
        for ln, line in enumerate(content.splitlines(), 1):
            if rx.search(line):
                print(f"  {_label(src, o)}  {p}:{ln}: {line.strip()[:110]}")
                hits += 1
                if hits >= a.rows:
                    print(f"-- capped at {a.rows}")
                    con.close()
                    return
    print(f"-- {hits} hits")
    con.close()


def cmd_pack(a):
    con = _connect()
    origins = [o for (o,) in con.execute(
        "SELECT DISTINCT origin FROM sources "
        "WHERE src='pack' AND origin LIKE ?", (f"%{a.substr}%",))]
    for o in origins[:8]:
        n = con.execute(
            "SELECT COUNT(*) FROM sources WHERE src='pack' AND origin=?",
            (o,)).fetchone()[0]
        print(f"{o}  ({n} files)")
        for top, c in con.execute(
                "SELECT SUBSTR(path,1,INSTR(path||'/','/')-1) d, COUNT(*) c "
                "FROM sources WHERE src='pack' AND origin=? "
                "GROUP BY d ORDER BY c DESC LIMIT 8", (o,)):
            print(f"    {c:>6}  {top}/")
        for t, c in con.execute(
                "SELECT t.name, COUNT(*) c FROM db_rows r "
                "JOIN db_tables t ON t.id=r.table_id "
                "JOIN sources s ON s.id=r.file_id "
                "WHERE s.src='pack' AND s.origin=? "
                "GROUP BY t.name ORDER BY c DESC LIMIT 12", (o,)):
            print(f"    db {c:>6}  {t}")
        nl = con.execute(
            "SELECT COUNT(*) FROM loc_rows r JOIN sources s ON s.id=r.file_id "
            "WHERE s.src='pack' AND s.origin=?", (o,)).fetchone()[0]
        if nl:
            print(f"    loc {nl:>6} rows")
    if not origins:
        print("-- no pack matches")
    con.close()


def cmd_mod(a):
    con = _connect()
    mods = [o for (o,) in con.execute(
        "SELECT DISTINCT origin FROM sources "
        "WHERE src='mod' AND origin LIKE ?", (f"%{a.substr}%",))]
    for m in mods[:8]:
        print(f"mod_files/{m}")
        for top, c in con.execute(
                "SELECT SUBSTR(path,1,INSTR(path||'/','/')-1) d, COUNT(*) "
                "FROM sources WHERE src='mod' AND origin=? "
                "GROUP BY d ORDER BY d", (m,)):
            print(f"    {c:>6}  {top}/")
        for t, c in con.execute(
                "SELECT t.name, COUNT(*) FROM db_rows r "
                "JOIN db_tables t ON t.id=r.table_id "
                "JOIN sources s ON s.id=r.file_id "
                "WHERE s.src='mod' AND s.origin=? "
                "GROUP BY t.name ORDER BY t.name", (m,)):
            print(f"    db {c:>6}  {t}")
        nl = con.execute(
            "SELECT COUNT(*) FROM loc_rows r JOIN sources s ON s.id=r.file_id "
            "WHERE s.src='mod' AND s.origin=?", (m,)).fetchone()[0]
        if nl:
            print(f"    loc {nl:>6} rows")
    if not mods:
        print("-- no mod matches")
    con.close()


# ------------------------------------------------- row-content commands

def cmd_show(a):
    """整行取值：索引定位 -> 回源文件/pack 按行号取真实字段值。"""
    con = _connect()
    sql = (_Q.format(t="db_rows", extra=",t.name,r.key,r.file_id,r.rownum") +
           " JOIN db_tables t ON t.id=r.table_id WHERE r.key LIKE ?")
    args = [f"%{a.substr}%"]
    if a.table:
        sql += " AND t.name LIKE ?"
        args.append(f"%{a.table}%")
    rows = list(con.execute(sql, args))
    if not rows:
        print("-- 0 rows")
        con.close()
        return
    if a.diff:
        groups: dict = {}
        for src, o, p, t, k, fid, rn in rows:
            groups.setdefault((t, k), []).append((src, o, p, fid, rn))
        for (t, k), members in groups.items():
            if len(members) < 2:
                continue
            print(f"== {t}  {k}  ({len(members)} providers)")
            fetched = []
            for src, o, p, fid, rn in members:
                fr = fetch_row(con, fid, rn)
                label = _label(src, o)
                fetched.append((label, fr))
            names: list[str] = []
            vals: list[dict] = []
            for label, fr in fetched:
                if not fr:
                    vals.append({})
                    continue
                _s, _o, _p, fields, cells = fr
                vals.append(dict(zip(fields, cells)))
                for f in fields:
                    if f not in names:
                        names.append(f)
            labels = [lb for lb, _f in fetched]
            for f in names:
                vs = [v.get(f, "") for v in vals]

                def _norm(v):
                    try:
                        return str(float(v))
                    except (ValueError, TypeError):
                        return v
                if len({_norm(v) for v in vs}) > 1:
                    line = " | ".join(
                        f"{lb}={v}" for lb, v in zip(labels, vs))
                    print(f"  {f:36} {line}")
        con.close()
        return
    for src, o, p, t, k, fid, rn in rows[:a.rows]:
        print(f"{t}  {k}   {_label(src, o)}  {p}:{rn}")
        fr = fetch_row(con, fid, rn)
        if not fr:
            print("    (row fetch failed)")
            continue
        _s, _o, _p, fields, cells = fr
        print("    " + _fmt_cells(fields, cells))
    if len(rows) > a.rows:
        print(f"... +{len(rows) - a.rows} more")
    con.close()


def cmd_links(a):
    """外键引用 BFS：X 被哪些行引用、那些行又指向谁 —— 招募/派系接线图。"""
    con = _connect()
    frontier = {a.substr}
    seen: set = set()
    # 定义侧：X 作为（部分）主键存在的行
    rows = list(con.execute(
        _Q.format(t="db_rows", extra=",t.name,r.key,r.file_id,r.rownum") +
        " JOIN db_tables t ON t.id=r.table_id "
        "WHERE r.key = ? OR r.key LIKE ? OR r.key LIKE ? OR r.key LIKE ?",
        (a.substr, a.substr + "|%", "%|" + a.substr, "%|" + a.substr + "|%")))
    if rows:
        print(f"== '{a.substr}' defined as (part of) PK:")
        for src, o, p, t, k, _f, rn in rows[:a.rows]:
            print(f"  {t}  {k}   {_label(src, o)}  {p}:{rn}")
        if len(rows) > a.rows:
            print(f"  ... +{len(rows) - a.rows} more")
    for depth in range(1, a.depth + 1):
        ph = ",".join("?" * len(frontier))
        refs = list(con.execute(
            _Q.format(t="ref_rows", extra=",t.name,r.target,r.key,r.file_id,r.rownum") +
            f" JOIN db_tables t ON t.id=r.table_id WHERE r.key IN ({ph})",
            tuple(frontier)))
        if not refs:
            break
        print(f"== depth {depth}: rows referencing "
              f"{sorted(frontier)[:6]}{'...' if len(frontier) > 6 else ''}")
        seen |= frontier
        frontier = set()
        groups: dict = {}
        for src, o, p, t, tgt, k, fid, rn in refs:
            groups.setdefault((t, tgt), []).append((src, o, p, fid, rn, k))
        for (t, tgt), members in groups.items():
            # dedupe identical rows across deployed/mod_output/source copies
            bycells: dict = {}
            for src, o, p, fid, rn, k in members:
                fr = fetch_row(con, fid, rn)
                cells = tuple(fr[4]) if fr else (f"?row{rn}",)
                bycells.setdefault(cells, []).append(
                    (_label(src, o), fid, rn, fr[3] if fr else []))
            shown = 0
            for cells, providers in bycells.items():
                shown += 1
                if shown > a.rows:
                    print(f"    ... +{len(bycells) - a.rows} distinct rows")
                    break
                labels = ",".join(lb for lb, _f, _r, _fld in providers)
                prov = next((pr for pr in providers if pr[3]), providers[0])
                _lb, fid, rn, fields = prov
                if fields:
                    idxs = [j for j in key_indexes(t, None, list(fields))
                            if j < len(cells)]
                    pk = "  ".join(f"{fields[j]}={cells[j]}" for j in idxs)
                else:
                    pk = " ".join(cells)
                print(f"  {t} :{rn}  [{labels}]")
                print(f"      pk {pk}")
                for col, val, rtgt in _row_refs(list(fields), list(cells), t):
                    print(f"      {col} → {val}   ({rtgt})")
                    frontier.add(val)
        frontier -= seen
    con.close()


def cmd_cols(a):
    """表列清单：字段类型+主键/外键标记（改 TSV 前对照用）。"""
    meta = load_schema_meta()
    names = [t for t in meta if a.substr.casefold() in t.casefold()]
    for t in sorted(names)[:8]:
        vers = meta[t]
        ver = a.ver if a.ver in vers else max(vers)
        defs = vers[ver]["defs"]
        print(f"{t}  v{ver}  ({len(defs)} fields"
              + ("" if a.ver in vers or not a.ver
                 else f"，无 v{a.ver} 取最新" ) + ")")
        for name, ftype, is_key, tgt in defs:
            mark = "*" if is_key else " "
            ref = f" →{tgt}" if tgt else ""
            print(f"  {mark}{name:44} {ftype}{ref}")
    if not names:
        print("-- no table matches")
    elif len(names) > 8:
        print(f"... +{len(names) - 8} more tables")


# ------------------------------------------------------------------ main

def main() -> int:
    ap = argparse.ArgumentParser(prog="wh3index.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add(name, fn, **kw):
        p = sub.add_parser(name, **kw)
        p.set_defaults(fn=fn)
        return p

    p = add("build", cmd_build)
    p.add_argument("--full", action="store_true")
    p.add_argument("--packs", action="store_true", help="只重建 pack 侧")
    p.add_argument("--src", action="store_true", help="只重建 mod/gamedata/bilingual")
    p = add("status", cmd_status)
    p.add_argument("--stale", action="store_true")
    for name, fn in (("find", cmd_find), ("path", cmd_path), ("key", cmd_key),
                     ("table", cmd_table), ("loc", cmd_loc), ("grep", cmd_grep),
                     ("pack", cmd_pack), ("mod", cmd_mod), ("show", cmd_show),
                     ("links", cmd_links), ("cols", cmd_cols)):
        p = add(name, fn)
        p.add_argument("substr" if name != "grep" else "pattern")
        p.add_argument("--rows", type=int, default=ROW_CAP)
        if name == "path":
            p.add_argument("--exact", action="store_true")
            p.add_argument("--playset", action="store_true")
        if name == "key":
            p.add_argument("--table")
            p.add_argument("--playset", action="store_true")
        if name == "loc":
            p.add_argument("--text", action="store_true")
        if name == "grep":
            p.add_argument("--ext")
            p.add_argument("-i", action="store_true")
        if name == "show":
            p.add_argument("--table")
            p.add_argument("--diff", action="store_true")
        if name == "links":
            p.add_argument("--depth", type=int, default=3)
        if name == "cols":
            p.add_argument("--ver", type=int)
    a = ap.parse_args()
    a.fn(a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
