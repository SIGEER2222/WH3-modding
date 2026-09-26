# -*- coding: utf-8 -*-
"""WH3 运行时排查只读 CLI —— 固化 scratch 里反复重写的一次性取证脚本。

用法（Windows Python313 与 WSL python3 均可，自动映射 X:\\ <-> /mnt/x/）：

  wh3diag.py paths                          打印解析到的游戏目录
  wh3diag.py ls <pack> [--grep PAT] [--raw] pack 索引枚举
  wh3diag.py meta <pack>                    PFH5 头/依赖块/rpfm_reserved/分隔符统计
  wh3diag.py cat <pack> <内部路径> [--lines A-B] [--hex N]
  wh3diag.py which <子串> [--exact] [--scope data|ws|out|all]
                                            跨包反查谁提供了内部路径
  wh3diag.py db <pack> [--match SUB] [--rows N]
                                            按 schema_wh3.ron 解码 DB 表片段
  wh3diag.py scriptlog [--marker PAT]... [--tail N] [--glob PAT]
                                            script_log_*.txt 枚举统计
  wh3diag.py usedmods [--file NAME] [--grep PAT] [--diff OTHER]
  wh3diag.py compat <pack> [--dep PACK]... [--emit FIX_NAME]
                                            9.x 兼容审计：旧版 DB 表 / 悬空
                                            外键（含已知改名建议）/ 过期 twui
                                            拷贝；--emit 生成补丁源到
                                            mod_files/<FIX_NAME>/
  wh3diag.py crashes [--last N] [--dump MDMP] [--regs] [--stack]

除 ``compat --emit``（只写 mod_files/）外全部只读；不启动游戏、不写游戏目录。
pack 参数可以是文件名（自动在 data\\ / workshop content\\1142710 /
mod_output 里找）或完整路径。compat 需 Windows Python313（zstandard）。
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_gamedata import (
    SCHEMA_RON,
    decode_db_table,
    iter_pack_index,
    load_schema,
    parse_loc,
    read_pack_header,
    read_pack_payload,
)

ROOT = Path(__file__).resolve().parents[1]
MOD_OUTPUT = ROOT / "mod_output"


# ------------------------------------------------------------------ paths

def _first_dir(cands):
    for c in cands:
        if c and Path(c).is_dir():
            return Path(c)
    return None


def local_path(s: str) -> Path:
    """Accept 'X:\\..' / 'X:/..' / '%APPDATA%\\..' / POSIX paths."""
    if os.name != "posix":
        return Path(os.path.expandvars(s))
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", s)
    if m:
        return Path("/mnt") / m.group(1).lower() / m.group(2).replace("\\", "/")
    m = re.match(r"^%([A-Za-z]+)%[\\/](.*)$", s)
    if m:
        sub = {"APPDATA": "AppData/Roaming",
               "LOCALAPPDATA": "AppData/Local"}.get(m.group(1).upper())
        rest = m.group(2).replace("\\", "/")
        if sub:
            hits = sorted(
                glob.glob("/mnt/[a-z]/Users/*/" + sub + "/" + rest))
            if hits:
                return Path(hits[0])
    return Path(s)


def game_root() -> Path | None:
    cands = [os.environ.get("WH3_GAME_ROOT"),
             r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III",
             "/mnt/e/Program Files (x86)/Steam2/steamapps/common/Total War WARHAMMER III",
             "/e/Program Files (x86)/Steam2/steamapps/common/Total War WARHAMMER III"]
    return _first_dir(c for c in cands if c)


def data_dir() -> Path | None:
    g = game_root()
    return (g / "data") if g else None


def workshop_dir() -> Path | None:
    g = game_root()
    if not g:
        return None
    return _first_dir([g.parent.parent / "workshop" / "content" / "1142710"])


def appdata_wh3() -> Path | None:
    cands = [os.environ.get("WH3_APPDATA")]
    ad = os.environ.get("APPDATA")
    if ad:
        cands.append(str(Path(ad) / "The Creative Assembly" / "Warhammer3"))
    cands += sorted(glob.glob(
        "/mnt/[a-z]/Users/*/AppData/Roaming/The Creative Assembly/Warhammer3"))
    return _first_dir(c for c in cands if c)


def schema_ron() -> Path | None:
    # project copy first: tools/schema is synced with upstream rpfm-schemas,
    # while the RPFM appdata copy is whatever the installed RPFM shipped.
    for c in (ROOT / "tools" / "schema" / "schema_wh3.ron", SCHEMA_RON):
        if c and Path(c).is_file():
            return Path(c)
    return None


def resolve_pack(s: str) -> Path:
    p = local_path(s)
    if p.is_file():
        return p
    name = Path(s.replace("\\", "/")).name
    for base in (data_dir(), MOD_OUTPUT):
        if base and (base / name).is_file():
            return base / name
    ws = workshop_dir()
    if ws:
        hits = sorted(ws.glob("*/" + name))
        if hits:
            return hits[0]
    d = data_dir()
    if d:
        for f in sorted(d.glob("*.pack")):
            if f.name.casefold() == name.casefold():
                return f
    sys.exit(f"pack not found: {s} (tried data/, workshop 1142710, mod_output/)")


def _mtime(p: Path) -> str:
    return time.strftime("%m-%d %H:%M:%S", time.localtime(p.stat().st_mtime))


# ------------------------------------------------------------------ packs

def cmd_paths(_a):
    for k, v in (("game_root", game_root()), ("data", data_dir()),
                 ("workshop", workshop_dir()), ("appdata_wh3", appdata_wh3()),
                 ("mod_output", MOD_OUTPUT if MOD_OUTPUT.is_dir() else None),
                 ("schema_ron", schema_ron())):
        print(f"{k:14} {v}")


def _print_header(pack: Path, h: dict):
    deps = f" deps={h['deps']}" if h["deps"] else ""
    print(f"{pack.name} [{pack.parent}]")
    print(f"  {h['magic']} type={h['pack_type']} files={h['file_count']}"
          f" depcnt={h['dep_count']} depsz={h['dep_size']}"
          f" indexsz={h['index_size']} data@0x{h['data_offset']:x}"
          f" filesize={h['file_size']}{deps}")


def cmd_ls(a):
    pack = resolve_pack(a.pack)
    h = read_pack_header(pack)
    if h is None:
        sys.exit(f"not a PFH5/PFH6 pack: {pack}")
    _print_header(pack, h)
    pat = a.grep.casefold() if a.grep else None
    n = 0
    for e in iter_pack_index(pack):
        if pat and pat not in e.name.casefold():
            continue
        flag = "z" if e.compressed else "-"
        if a.raw:
            print(f"  {e.size:>9} {flag} {e.name}  raw={e.raw_name!r}")
        else:
            print(f"  {e.size:>9} {flag} {e.name}")
        n += 1
    print(f"-- {n}/{h['file_count']} entries")


def cmd_meta(a):
    pack = resolve_pack(a.pack)
    h = read_pack_header(pack)
    if h is None:
        sys.exit(f"not a PFH5/PFH6 pack: {pack}")
    _print_header(pack, h)
    n = bs = fs = comp = 0
    reserved = []
    for e in iter_pack_index(pack):
        n += 1
        comp += e.compressed
        bs += e.raw_name.count(b"\\")
        fs += e.raw_name.count(b"/")
        if e.name.endswith(".rpfm_reserved"):
            reserved.append(e)
    print(f"  parsed={n} compressed={comp} separators: backslash={bs} slash={fs}")
    for e in reserved:
        payload = read_pack_payload(pack, e)
        print(f"  == {e.name} ({len(payload)}B) ==")
        try:
            text = payload.decode("utf-8")
        except UnicodeDecodeError:
            text = repr(payload[:400])
        print("    " + text[:600].replace("\n", "\n    "))


def _find_entry(pack: Path, internal: str):
    want = internal.replace("\\", "/").casefold()
    subs = []
    for e in iter_pack_index(pack):
        if e.name.casefold() == want:
            return e
        if want in e.name.casefold():
            subs.append(e)
    if len(subs) == 1:
        return subs[0]
    if subs:
        sys.exit("ambiguous internal path; matches:\n  "
                 + "\n  ".join(e.name for e in subs[:30]))
    sys.exit(f"no entry matching {internal!r} in {pack.name}")


def cmd_cat(a):
    pack = resolve_pack(a.pack)
    e = _find_entry(pack, a.internal)
    payload = read_pack_payload(pack, e)
    print(f"# {pack.name} -> {e.name} ({len(payload)}B)", file=sys.stderr)
    if a.hex:
        data = payload[: a.hex]
        for off in range(0, len(data), 16):
            chunk = data[off : off + 16]
            hexs = " ".join(f"{b:02x}" for b in chunk)
            print(f"{off:08x}  {hexs:<47}  "
                  + "".join(chr(b) if 32 <= b < 127 else "." for b in chunk))
        return
    if a.lines:
        lo, _, hi = a.lines.partition("-")
        lines = payload.decode("utf-8", "replace").splitlines()
        lo_i, hi_i = int(lo or 1) - 1, int(hi or len(lines))
        for i, line in enumerate(lines[lo_i:hi_i], lo_i + 1):
            print(f"{i:>6}: {line}")
        return
    sys.stdout.buffer.write(payload)


def cmd_which(a):
    pat = a.substr.replace("\\", "/")
    scopes = {"data": [], "ws": [], "out": []}
    d = data_dir()
    if d and a.scope in ("data", "all"):
        scopes["data"] = sorted(d.glob("*.pack"))
    ws = workshop_dir()
    if ws and a.scope in ("ws", "all"):
        scopes["ws"] = sorted(ws.glob("*/*.pack"))
    if MOD_OUTPUT.is_dir() and a.scope in ("out", "all"):
        scopes["out"] = sorted(MOD_OUTPUT.glob("*.pack"))
    total_packs = total_hits = 0
    for scope, packs in scopes.items():
        for p in packs:
            hits = []
            try:
                for e in iter_pack_index(p):
                    if a.exact:
                        # bare filename -> compare basename; with '/' -> full path
                        lhs = (e.name if "/" in pat else e.name.rsplit("/", 1)[-1])
                        ok = lhs.casefold() == pat.casefold()
                    else:
                        ok = pat.casefold() in e.name.casefold()
                    if ok:
                        hits.append(e.name)
            except (OSError, struct.error) as exc:
                print(f"  !! {p.name}: unreadable ({exc})")
                continue
            total_packs += 1
            if hits:
                total_hits += len(hits)
                label = p.name if scope != "ws" else f"{p.parent.name}/{p.name}"
                print(f"{scope:>4}  {label}  ({len(hits)})")
                for name in hits[: a.rows]:
                    print(f"        {name}")
                if len(hits) > a.rows:
                    print(f"        ... +{len(hits) - a.rows} more")
    print(f"-- {total_hits} hits in {total_packs} packs scanned")


def cmd_db(a):
    pack = resolve_pack(a.pack)
    ron = schema_ron()
    schemas = load_schema(ron) if ron else {}
    if not ron:
        print("warning: schema_wh3.ron not found; decode will fail",
              file=sys.stderr)
    matched = 0
    for e in iter_pack_index(pack):
        if not e.name.startswith("db/"):
            continue
        if a.match and a.match.casefold() not in e.name.casefold():
            continue
        matched += 1
        table = e.name.split("/")[1] if "/" in e.name else ""
        payload = read_pack_payload(pack, e)
        try:
            ver, fields, rows = decode_db_table(
                table, payload, schemas.get(table, {}))
        except Exception as exc:
            print(f"# {e.name}  DECODE FAIL: {exc}")
            print(f"#   first bytes: {payload[:64].hex()}")
            continue
        print(f"# {e.name}  table={table} v{ver} rows={len(rows)}")
        print("\t".join(fields))
        for row in rows[: a.rows if a.rows else None]:
            print("\t".join(row))
        if a.rows and len(rows) > a.rows:
            print(f"... +{len(rows) - a.rows} rows")
    if not matched:
        print("no db/ entries matched", file=sys.stderr)


# ------------------------------------------------------------- game logs

def cmd_scriptlog(a):
    g = game_root()
    if not g:
        sys.exit("game root not found")
    files = sorted(g.glob(a.glob), key=lambda p: p.stat().st_mtime)
    if not files:
        sys.exit(f"no {a.glob} under {g}")
    markers = [re.compile(m) for m in (a.marker or [])]
    load_re = re.compile(r"Loading mod file \[([^\]]*)\]")
    counts = []
    print(f"{'mtime':<15} {'size':>7} {'loads':>5}  last_loaded  markers")
    for p in files[-a.last:]:
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        loads = load_re.findall(text)
        counts.append(len(loads))
        mk = " ".join(f"{m.pattern}={len(m.findall(text))}" for m in markers)
        last = loads[-1] if loads else "-"
        print(f"{p.name[-15:]:<15} {p.stat().st_size:>7} {len(loads):>5}"
              f"  {last}  {mk}  [{_mtime(p)}]")
    if len(counts) >= 3:
        full = max(counts)
        for p, c in zip(files[-a.last:], counts):
            if 0 < c < full * 0.8:
                print(f"NOTE: {p.name} 枚举截断于 {c}/{full} —— 崩在脚本加载中段")
            elif c == 0 and p.stat().st_size < 300:
                print(f"NOTE: {p.name} 仅 {p.stat().st_size}B stub —— 崩在脚本枚举之前")
    if a.tail:
        p = files[-1]
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        print(f"== tail {a.tail} of {p.name} ==")
        for line in lines[-a.tail:]:
            print(line)


def _parse_modlist(path: Path):
    """Return [(lineno, kind, value)] for add_working_directory/mod lines."""
    out = []
    for i, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        m = re.match(r'\s*(add_working_directory|mod)\s+"([^"]+)"', line)
        if m:
            out.append((i, m.group(1), m.group(2)))
    return out


def _resolve_listing(name: str) -> Path:
    p = local_path(name)
    if p.is_file():
        return p
    g = game_root()
    if g and (g / name).is_file():
        return g / name
    sys.exit(f"mod list file not found: {name}")


def cmd_usedmods(a):
    main_f = _resolve_listing(a.file)
    entries = _parse_modlist(main_f)
    if a.diff:
        other = _resolve_listing(a.diff)
        oe = _parse_modlist(other)
        a_mods = {v: i for i, k, v in entries if k == "mod"}
        b_mods = {v: i for i, k, v in oe if k == "mod"}
        print(f"-- only in {main_f.name}:")
        for v, i in a_mods.items():
            if v not in b_mods:
                print(f"   line {i}: {v}")
        print(f"-- only in {other.name}:")
        for v, i in b_mods.items():
            if v not in a_mods:
                print(f"   line {i}: {v}")
        both = [v for v in a_mods if v in b_mods]
        moved = [v for v in both if a_mods[v] != b_mods[v]]
        if moved:
            print("-- moved:")
            for v in moved:
                print(f"   {v}: {a_mods[v]} -> {b_mods[v]}")
        return
    pos = 0
    for i, kind, v in entries:
        if a.grep and a.grep.casefold() not in v.casefold():
            continue
        if kind == "mod":
            pos += 1
            print(f"{pos:>4} (line {i:>4})  {v}")
        else:
            print(f"     (line {i:>4})  +dir {v}")
    print(f"-- {pos} mods in {main_f}")


# ------------------------------------------------------------ crash dumps

_CTX_REG_OFF = 0x78  # AMD64 CONTEXT: rax..rip start here
_CTX_REGS = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
             "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15", "rip"]


def _mdmp_parse(path: Path):
    """Return (exc, modules, regs) from a minidump; exc=None if no stream 6."""
    with path.open("rb") as f:
        head = f.read(64 * 1024)
        if head[:4] != b"MDMP":
            return None, [], None
        _sig, _ver, nstreams, dir_rva = struct.unpack_from("<IIII", head, 0)
        streams = {}
        for i in range(nstreams):
            st, sz, rva = struct.unpack_from("<III", head, dir_rva + i * 12)
            streams[st] = (rva, sz)

        def at(rva, sz):
            f.seek(rva)
            return f.read(sz)

        exc = None
        if 6 in streams:
            buf = at(*streams[6])
            if len(buf) >= 168:
                tid = struct.unpack_from("<I", buf, 0)[0]
                code, flags = struct.unpack_from("<II", buf, 8)
                _rec, addr = struct.unpack_from("<QQ", buf, 16)
                npc = struct.unpack_from("<I", buf, 32)[0]
                params = struct.unpack_from(
                    "<" + "Q" * min(npc, 15), buf, 40)
                ctx_sz, ctx_rva = struct.unpack_from("<II", buf, 160)
                exc = {"tid": tid, "code": code, "flags": flags, "addr": addr,
                       "params": params, "ctx": (ctx_rva, ctx_sz)}
        mods = []
        if 4 in streams:
            buf = at(*streams[4])
            n = struct.unpack_from("<I", buf, 0)[0]
            for j in range(min(n, 8000)):
                off = 4 + j * 108
                if off + 108 > len(buf):
                    break
                base = struct.unpack_from("<Q", buf, off)[0]
                size = struct.unpack_from("<I", buf, off + 8)[0]
                nrva = struct.unpack_from("<I", buf, off + 20)[0]
                nl = struct.unpack_from("<I", at(nrva, 4), 0)[0]
                name = at(nrva + 4, nl).decode("utf-16le", "replace")
                mods.append((base, size, name))
        regs = None
        if exc and exc["ctx"][1] >= 0x100:
            ctx = at(exc["ctx"][0], exc["ctx"][1])
            if len(ctx) >= 0x100:
                regs = {n: struct.unpack_from("<Q", ctx, _CTX_REG_OFF + i * 8)[0]
                        for i, n in enumerate(_CTX_REGS)}
    return exc, mods, regs


def _mod_at(mods, addr):
    for base, size, name in sorted(mods):
        if base <= addr < base + size:
            base_name = name.replace("\\", "/").rsplit("/", 1)[-1]
            return f"{base_name}+0x{addr - base:x}"
    return None


def _stack_txt(mdmp: Path) -> str:
    st = mdmp.with_suffix(".stack.txt")
    if not st.is_file():
        st = mdmp.parent / (mdmp.stem + ".stack.txt")
    if not st.is_file():
        return ""
    names = [w for w in st.read_text(errors="replace").split() if w.strip()]
    return ">".join(names[:12])


def _dump_line(p: Path, a):
    exc, mods, regs = _mdmp_parse(p)
    if exc is None:
        print(f"{p.name}  no exception stream")
        return
    code = f"0x{exc['code']:08x}"
    loc = _mod_at(mods, exc["addr"]) or f"0x{exc['addr']:x}"
    params = ",".join(hex(x) for x in exc["params"][:4])
    line = (f"{p.name[:22]:<22} {code} addr={loc}"
            f" params=[{params}] [{_mtime(p)}]")
    if regs:
        rip_loc = _mod_at(mods, regs["rip"]) or f"0x{regs['rip']:x}"
        line += f" rip={rip_loc}"
    print(line)
    if a.regs and regs:
        print("    " + " ".join(f"{k}=0x{v:x}" for k, v in regs.items()))
    if a.stack:
        st = _stack_txt(p)
        if st:
            print(f"    stack.txt: {st}")


def cmd_crashes(a):
    if a.dump:
        _dump_line(local_path(a.dump), a)
        return
    cr = local_path(a.dir) if a.dir else (
        appdata_wh3() / "crash_report" if appdata_wh3() else None)
    if not cr or not cr.is_dir():
        sys.exit("crash_report dir not found (set WH3_APPDATA or --dir)")
    dumps = sorted(cr.glob("D*.mdmp"), key=lambda p: p.stat().st_mtime)
    for p in dumps[-a.last:]:
        _dump_line(p, a)


# ------------------------------------------------------------- compat audit

def _db_hdr_ver(data: bytes):
    """DB fragment header version; None = markerless v0 layout."""
    p = 0
    while p + 4 <= len(data):
        marker = data[p:p + 4]
        if marker == b"\xfd\xfe\xfc\xff":
            p += 4
            ln = struct.unpack_from("<H", data, p)[0]
            p += 2 + ln * 2
        elif marker == b"\xfc\xfd\xfe\xff":
            return struct.unpack_from("<i", data, p + 4)[0]
        else:
            break
    return None


_SCHEMA_REFS = None


def _schema_refs():
    """{table: {version: [(name, type, is_key, (ref_table, ref_col)|None)]}}"""
    global _SCHEMA_REFS
    if _SCHEMA_REFS is not None:
        return _SCHEMA_REFS
    ron = schema_ron()
    _SCHEMA_REFS = {}
    if not ron:
        return _SCHEMA_REFS
    text = ron.read_text(encoding="utf-8")
    table_re = re.compile(r'(?m)^ {8}"([^"]+)": \[')
    name_re = re.compile(r'name: "((?:[^"\\]|\\.)*)"')
    type_re = re.compile(r"field_type: (\w+)")
    key_re = re.compile(r"is_key: (true|false)")
    ref_re = re.compile(
        r'is_reference: (None|Some\(\(\s*"((?:[^"\\]|\\.)*)"\s*,'
        r'\s*"((?:[^"\\]|\\.)*)"\s*\)\))')
    matches = list(table_re.finditer(text))
    for i, m in enumerate(matches):
        block = text[m.end(): matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        versions = {}
        for vm in re.finditer(r"version: (\d+),\s*fields: \[", block):
            seg = block[vm.end(): block.find("localised_fields", vm.end())]
            fields = []
            # split on the start of each "( ... )" field block
            for chunk in re.split(r"\(\s*\n", seg)[1:]:
                nm, tm = name_re.search(chunk), type_re.search(chunk)
                if not nm or not tm:
                    continue
                km, rm = key_re.search(chunk), ref_re.search(chunk)
                fields.append((
                    nm.group(1), tm.group(1),
                    bool(km) and km.group(1) == "true",
                    (rm.group(2), rm.group(3))
                    if rm and rm.group(1) != "None" else None))
            versions[int(vm.group(1))] = fields
        _SCHEMA_REFS[m.group(1)] = versions
    return _SCHEMA_REFS


def _simple_schema(table):
    return {v: [(n, t) for n, t, *_ in fs]
            for v, fs in _schema_refs().get(table, {}).items()}


def _vanilla_packs():
    """data\\*.pack minus mod-built packs (identified by *.rpfm_reserved)."""
    d = data_dir()
    out = []
    for p in sorted(d.glob("*.pack")) if d else []:
        try:
            if not any(e.name.endswith(".rpfm_reserved")
                       for e in iter_pack_index(p)):
                out.append(p)
        except Exception:
            pass
    return out


def _vanilla_db_versions(van_packs):
    """table -> set of header versions seen in vanilla packs."""
    ver = {}
    for p in van_packs:
        for e in iter_pack_index(p):
            if e.name.startswith("db/"):
                t = e.name.split("/")[1]
                ver.setdefault(t, set()).add(
                    _db_hdr_ver(read_pack_payload(p, e)))
    return ver


def _vanilla_keys(van_packs, need):
    """{table: {col: set(values)}} for the requested (table -> cols)."""
    out = {}
    todo = {t: set(c) for t, c in need.items()}
    for p in van_packs:
        for e in iter_pack_index(p):
            if e.name.startswith("db/"):
                t = e.name.split("/")[1]
                if t not in todo:
                    continue
                try:
                    _v, fn, rows = decode_db_table(
                        t, read_pack_payload(p, e), _simple_schema(t))
                except Exception:
                    continue
                cols = out.setdefault(t, {})
                for c in todo[t]:
                    if c in fn:
                        i = fn.index(c)
                        cols.setdefault(c, set()).update(r[i] for r in rows)
            elif (e.name.startswith("animations/database/battle/bin/")
                    and e.name.endswith(".animpack")
                    and "battle_animations_table" in todo):
                out.setdefault("battle_animations_table", {}) \
                    .setdefault("key", set()).add(e.name.rsplit("/", 1)[-1][:-9])
    return out


# New trailing columns introduced by a game update: vanilla-typical defaults
# used when --emit re-encodes a stale fragment at the current version.
COMPAT_NEWCOL_DEFAULTS = {
    ("battle_vortexs_tables", "follow_target"): "false",
    ("battle_vortexs_tables", "subsequent_vortex"): "",
    ("battle_vortexs_tables", "subsequent_vortex_delay"): "0.0",
    ("land_units_to_unit_abilites_junctions_tables", "culture"): "*",
    ("special_ability_groups_to_units_junctions_tables",
     "group_page_order"): "0",
    ("slot_sets_tables", "non_owner_composite_scene"): "",
    ("battlefield_engines_tables", "crew_reserve_distance_offset"): "0.0",
    ("building_levels_tables",
     "override_startpos_settlement_display_building"): "false",
    ("campaign_settlement_display_buildings_tables", "devastated_bmd"): "",
    ("campaign_settlement_display_buildings_tables",
     "devastated_occupied_bmd"): "",
    ("mercenary_unit_groups_tables", "ui_order"): "0",
    ("missile_weapons_tables",
     "hide_secondary_range_ammo_statistics_ui"): "false",
    ("pooled_resource_factor_junctions_tables", "sort_order"): "0",
    ("ritual_targets_tables", "max_range_ap"): "-1",
    ("agent_subtypes_tables", "audio_force_contextual_vo"): "false",
    ("battle_entities_tables", "stop_before_turn"): "false",
    ("campaign_character_art_sets_tables",
     "prebattle_separation_offset"): "0.0",
    ("land_units_tables", "default_guard_mode"): "false",
    ("building_culture_variants_tables", "building_frame_override"): "",
}

# Vanilla keys confirmed renamed/removed by Update 9.0 (see references §10.32).
# compat reports suggest these; --emit applies them.
COMPAT_KEY_RENAMES = {
    "wh3_main_sla_cav": "wh3_dlc27_sla_cav_tormentors",
    "wh3_main_sla_cav_1": "wh3_dlc27_sla_cav_1_tormentors",
    "wh3_main_sla_cav_2": "wh3_dlc27_sla_cav_2_tormentors",
    "wh3_main_sla_cav_4": "wh3_dlc27_sla_cav_4_tormentors",
    "wh3_dlc20_group_chs_festus": "wh3_dlc20_group_chs_festus_glottkin",
    "skv_infantry": "skv_all",
    "vmp_corpses": "vmp_corpse_units",
    "wh2_dlc11_emp_spearmen_swordsmen_flagellants_halberdiers": "emp_infantry",
}

# Values that are never dangling (wildcards / engine sentinels).
_REF_NOOP = {"", "0", "false", "none", "None", "*", "-1"}


def _canon_lines(text: str):
    canon = re.sub(
        r"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}",
        "G", text)
    return {l.strip() for l in canon.splitlines() if l.strip()}


def _twui_verdict(mod_text: str, van_text: str):
    """('stale-copy'|'rewrite'|'custom', mod_only, van_only, ver_mod, ver_van)"""
    vm = re.search(r'version="(\d+)"', mod_text[:2000])
    vv = re.search(r'version="(\d+)"', van_text[:2000])
    om = _canon_lines(mod_text) - _canon_lines(van_text)
    ov = _canon_lines(van_text) - _canon_lines(mod_text)
    return om, ov, (vm.group(1) if vm else "?"), (vv.group(1) if vv else "?")


def _emit_fix(pack: Path, mod_name: str, stale, keyfixes, twui_shadows):
    """Write mod_files/<mod_name>/ source: TSVs for stale/keyfix fragments,
    vanilla payloads for stale twui copies, plus notes/."""
    import csv
    mdir = ROOT / "mod_files" / mod_name
    made = []
    for internal, table, old_ver, new_ver, fn, rows in stale + keyfixes:
        ss = _simple_schema(table)
        new_fields = [n for n, _t in ss.get(new_ver, [])] or list(fn)
        tsv_dir = mdir / "db" / table
        tsv_dir.mkdir(parents=True, exist_ok=True)
        frag = internal.split("/")[-1]
        tsv_path = tsv_dir / (mod_name + "__" + frag + ".tsv")
        # key columns for post-rename dedupe
        ks = [n for n, _t, k, _r in _schema_refs().get(table, {})
              .get(new_ver if new_ver is not None else 0, []) if k]
        seen = set()
        out_rows = []
        dropped = 0
        for r in rows:
            d = dict(zip(fn, r))
            for c in new_fields:
                if c not in d:
                    d[c] = COMPAT_NEWCOL_DEFAULTS.get((table, c), "")
                elif d[c] in COMPAT_KEY_RENAMES:
                    d[c] = COMPAT_KEY_RENAMES[d[c]]
            if ks:
                key = tuple(d.get(k, "") for k in ks)
                if key in seen:
                    dropped += 1
                    continue
                seen.add(key)
            out_rows.append(d)
        with tsv_path.open("w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter="\t", lineterminator="\n")
            w.writerow(new_fields)
            w.writerow(["#%s;%d;%s" % (table, new_ver or 0, internal)])
            for d in out_rows:
                w.writerow([d.get(c, "") for c in new_fields])
        made.append(str(tsv_path.relative_to(ROOT)))
        if dropped:
            print(f"  dedupe: {frag} dropped {dropped} key-colliding rows")
    for internal, van_entry_pack, van_entry in twui_shadows:
        payload = read_pack_payload(van_entry_pack, van_entry)
        out = mdir / internal.replace("/", os.sep)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(payload)
        made.append(str(out.relative_to(ROOT)))
    ndir = mdir / "notes"
    ndir.mkdir(parents=True, exist_ok=True)
    if not (ndir / "dependencies.txt").exists():
        (ndir / "dependencies.txt").write_text(pack.name + "\n", encoding="utf-8")
    if not (ndir / "alias.txt").exists():
        (ndir / "alias.txt").write_text(mod_name, encoding="utf-8")
    if not (ndir / "pack_notes.txt").exists():
        (ndir / "pack_notes.txt").write_text(
            "兼容补丁：%s 的旧版 DB 分片按当前原版版本重编码并同路径遮蔽"
            "（含改名键修正与过期 twui 还原）。需排在目标 pack 之前。" % pack.name,
            encoding="utf-8")
    if not (mdir / "preview.png").exists():
        pngs = list(pack.parent.glob("*.png"))
        if pngs:
            (mdir / "preview.png").write_bytes(pngs[0].read_bytes())
    print(f"-- emitted {len(made)} files under mod_files/{mod_name}")
    for m in made:
        print("   ", m)


def cmd_compat(a):
    pack = resolve_pack(a.pack)
    schema = _schema_refs()
    if not schema:
        sys.exit("schema_wh3.ron not found (run wh3diag.py paths)")
    van_packs = _vanilla_packs()
    van_ver = _vanilla_db_versions(van_packs)
    print(f"{pack.name}: vanilla baseline packs={len(van_packs)}")

    # ---- pass 1: decode + collect
    stale, keyfix_needed, dec_fail, ref_need = [], [], [], {}
    decoded = []
    for e in iter_pack_index(pack):
        if not e.name.startswith("db/"):
            continue
        table = e.name.split("/")[1]
        data = read_pack_payload(pack, e)
        hv = _db_hdr_ver(data)
        vv = van_ver.get(table)
        try:
            ver, fn, rows = decode_db_table(table, data, _simple_schema(table))
        except Exception as exc:
            dec_fail.append((e.name, hv, str(exc)))
            continue
        decoded.append((e.name, table, ver, fn, rows))
        if vv is None:
            continue
        cur = max(v for v in vv if v is not None) if any(
            v is not None for v in vv) else None
        if hv != cur:
            stale.append((e.name, table, hv, cur if cur is not None else 0,
                          fn, rows))
        # dangling refs need the target columns
        sfields = schema.get(table, {}).get(
            ver if ver is not None else 0, [])
        for c_i, (fname, _t, _k, ref) in enumerate(sfields):
            if ref:
                tt = ref[0] if ref[0].endswith("_tables") else ref[0] + "_tables"
                ref_need.setdefault(tt, set()).add(ref[1])

    # ---- pass 2: vanilla keysets only where needed
    key_universe = _vanilla_keys(van_packs, ref_need)
    # merge mod's own column values (self-references) + dep packs
    extra = [pack] + [resolve_pack(d) for d in (a.dep or [])]
    for prov in extra:
        for e in iter_pack_index(prov):
            if e.name.startswith("db/"):
                t = e.name.split("/")[1]
                if t not in ref_need:
                    continue
                try:
                    _v, fn, rows = decode_db_table(
                        t, read_pack_payload(prov, e), _simple_schema(t))
                except Exception:
                    continue
                for c in ref_need[t]:
                    if c in fn:
                        i = fn.index(c)
                        key_universe.setdefault(t, {}).setdefault(
                            c, set()).update(r[i] for r in rows)
            # file-provided keys: an animpack's filename stem IS the
            # battle_animations_table key it registers (no db row needed)
            elif (e.name.startswith("animations/database/battle/bin/")
                    and e.name.endswith(".animpack")
                    and "battle_animations_table" in ref_need):
                key_universe.setdefault("battle_animations_table", {}) \
                    .setdefault("key", set()).add(e.name.rsplit("/", 1)[-1][:-9])
    dangling = []
    for internal, table, ver, fn, rows in decoded:
        sfields = schema.get(table, {}).get(
            ver if ver is not None else 0, [])
        if not sfields:
            continue
        for r_i, row in enumerate(rows):
            for c_i, (fname, _t, _k, ref) in enumerate(sfields):
                if not ref or c_i >= len(row):
                    continue
                val = row[c_i]
                if val in _REF_NOOP:
                    continue
                tt = ref[0] if ref[0].endswith("_tables") else ref[0] + "_tables"
                tgt = key_universe.get(tt, {}).get(ref[1])
                if tgt is not None and val not in tgt:
                    dangling.append((internal, table, r_i, fname,
                                     ".".join(ref), val))
                    if val in COMPAT_KEY_RENAMES:
                        keyfix_needed.append(internal)

    # ---- pass 3: non-db formats
    twui_stale, fmt_notes = [], []
    van_files = {}
    need_twui = [e.name for e in iter_pack_index(pack)
                 if e.name.casefold().endswith(".twui.xml")]
    if need_twui:
        for p in van_packs:
            for e in iter_pack_index(p):
                if e.name.casefold().endswith(".twui.xml"):
                    van_files.setdefault(e.name.casefold(), (p, e))
        for name in need_twui:
            ent = _find_entry(pack, name)
            mtext = read_pack_payload(pack, ent).decode("utf-8", "replace")
            hit = van_files.get(name.casefold())
            if not hit:
                continue
            vtext = read_pack_payload(*hit).decode("utf-8", "replace")
            om, ov, vm, vv2 = _twui_verdict(mtext, vtext)
            verdict = "rewrite" if len(om) > 200 else (
                "stale-copy" if (vm != vv2 or len(ov) > 50) else "tweak")
            fmt_notes.append((name, vm, vv2, len(om), len(ov), verdict))
            if verdict == "stale-copy":
                twui_stale.append((name, hit[0], hit[1]))

    # ---- report
    print("\n== stale DB versions ==")
    for internal, table, hv, cv, fn, rows in stale:
        ss = _simple_schema(table)
        newcols = [n for n, _t in ss.get(cv, []) if n not in fn]
        print(f"  v{hv} -> v{cv}  {internal}  rows={len(rows)}"
              f"  new_cols={newcols}")
    for internal, hv, msg in dec_fail:
        print(f"  DECODE-FAIL v{hv}  {internal}  {msg}")
    print("\n== dangling references ==")
    seen = {}
    for internal, table, r_i, col, ref, val in dangling:
        seen.setdefault((table, col, val), []).append((internal, r_i))
    for (table, col, val), locs in sorted(seen.items()):
        fix = COMPAT_KEY_RENAMES.get(val, "")
        print(f"  {table}.{col} = {val}  x{len(locs)}"
              + (f"  -> rename {fix}" if fix else "  (dead key, no rename)"))
    print("\n== twui / formats ==")
    for name, vm, vv2, om, ov, verdict in fmt_notes:
        print(f"  {name}  mod_v{vm} van_v{vv2} +{om}/-{ov}  {verdict}")
    if not fmt_notes:
        print("  (no vanilla-shadowed twui)")
    # ---- emit
    if a.emit:
        stale_paths = {s[0] for s in stale}
        kf = [(d[0], d[1], d[2], d[2], d[3], d[4]) for d in decoded
              if d[0] in set(keyfix_needed) and d[0] not in stale_paths]
        _emit_fix(pack, a.emit, stale + kf, [], twui_stale)


# ------------------------------------------------------------------ main

def main() -> int:
    ap = argparse.ArgumentParser(
        prog="wh3diag.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("paths", help="print resolved game dirs")

    p = sub.add_parser("ls", help="list pack index entries")
    p.add_argument("pack")
    p.add_argument("--grep", default="")
    p.add_argument("--raw", action="store_true",
                   help="also show raw index path bytes (invisible chars)")

    p = sub.add_parser("meta", help="pack header + deps + rpfm_reserved")
    p.add_argument("pack")

    p = sub.add_parser("cat", help="print one packed file")
    p.add_argument("pack")
    p.add_argument("internal")
    p.add_argument("--lines", default="", metavar="A-B")
    p.add_argument("--hex", type=int, default=0, metavar="N",
                   help="hexdump first N bytes")

    p = sub.add_parser("which", help="find packs providing an internal path")
    p.add_argument("substr")
    p.add_argument("--exact", action="store_true")
    p.add_argument("--scope", choices=["data", "ws", "out", "all"],
                   default="all")
    p.add_argument("--rows", type=int, default=20,
                   help="max paths shown per pack")

    p = sub.add_parser("db", help="decode db/ tables in a pack via schema")
    p.add_argument("pack")
    p.add_argument("--match", default="")
    p.add_argument("--rows", type=int, default=25, help="0 = all rows")

    p = sub.add_parser("scriptlog", help="script_log_*.txt load stats")
    p.add_argument("--marker", action="append", default=[],
                   help="regex counted per log (repeatable)")
    p.add_argument("--tail", type=int, default=0,
                   help="print last N lines of newest log")
    p.add_argument("--last", type=int, default=15)
    p.add_argument("--glob", default="script_log_*.txt")

    p = sub.add_parser("usedmods", help="parse used_mods.txt-style lists")
    p.add_argument("--file", default="used_mods.txt")
    p.add_argument("--grep", default="")
    p.add_argument("--diff", default="", metavar="OTHER",
                   help="compare mod sets with another list file")

    p = sub.add_parser(
        "compat",
        help="9.x compat audit: stale db versions, dangling refs, twui drift")
    p.add_argument("pack")
    p.add_argument("--dep", action="append", metavar="PACK",
                   help="dependency pack whose keys also satisfy refs")
    p.add_argument("--emit", metavar="FIX_NAME",
                   help="write patch source under mod_files/<FIX_NAME>/")

    p = sub.add_parser("crashes", help="crash_report mdmp summary")
    p.add_argument("--last", type=int, default=15)
    p.add_argument("--dir", default="")
    p.add_argument("--dump", default="", help="parse a single .mdmp")
    p.add_argument("--regs", action="store_true")
    p.add_argument("--stack", action="store_true")

    a = ap.parse_args()
    {
        "paths": cmd_paths,
        "ls": cmd_ls,
        "meta": cmd_meta,
        "cat": cmd_cat,
        "which": cmd_which,
        "db": cmd_db,
        "scriptlog": cmd_scriptlog,
        "usedmods": cmd_usedmods,
        "compat": cmd_compat,
        "crashes": cmd_crashes,
    }[a.cmd](a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
