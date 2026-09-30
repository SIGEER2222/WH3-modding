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
  wh3diag.py scriptlog [--marker PAT]... [--tail N] [--glob PAT] [--ui]
                                            script_log_*.txt 枚举统计；--ui
                                            列 [ui] 点击转储与错误跨度
  wh3diag.py grep <正则> [--scope used|data|ws|out|all] [--ext SUF]...
                                            搜包内文件内容（默认 used_mods
                                            全量包的 .lua/.twui.xml）
  wh3diag.py usedmods [--file NAME] [--grep PAT] [--diff OTHER]
  wh3diag.py compat <pack> [--dep PACK]... [--emit FIX_NAME]
                                            9.x 兼容审计：旧版 DB 表 / 悬空
                                            外键（含已知改名建议）/ 过期 twui
                                            拷贝；--emit 生成补丁源到
                                            mod_files/<FIX_NAME>/
  wh3diag.py crashes [--last N] [--dump MDMP] [--regs] [--stack]
  wh3diag.py events [--hours N] [--app]     Event 2004 OOM 闸门 + WER
                                            1000/1001 + 存活 WH3 进程
  wh3diag.py recent [--hours N] [--top N]   最近更新过的 pack/AppData 文件
                                            = 回归嫌疑清单（先查最近更新）
  wh3diag.py triage [--hours N] [--last N]  一键分诊：recent + crashes +
                                            scriptlog/[ui] + Event 2004 +
                                            存活进程 + AppData 判据文件；
                                            dump<->log 互近配对 + 签名分布
  wh3diag.py collect [--last N]             冻结 mutable 证据到
                                            scratch/crash_<ts>/（used_mods/
                                            state.db/prefs/滚动日志会被后续
                                            启动原地覆盖）

除 ``compat --emit``（只写 mod_files/）与 ``collect``（只写仓库 scratch/）
外全部只读；不启动游戏、不写游戏目录/AppData。
pack 参数可以是文件名（自动在 data\\ / workshop content\\1142710 /
mod_output 里找）或完整路径。compat 需 Windows Python313（zstandard）。
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import shutil
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


def _entry_twui_ver(pack: Path, pat: str):
    """version=\"N\" of the first .twui.xml entry whose name contains pat.

    Returns int >=0, -1 if matched but no version attr, "" if no match.
    """
    try:
        for e in iter_pack_index(pack):
            if pat in e.name.casefold():
                if not e.name.casefold().endswith(".twui.xml"):
                    return ""
                head = read_pack_payload(pack, e)[:512]
                m = re.search(rb'version="(\d+)"', head)
                return int(m.group(1)) if m else -1
    except (OSError, struct.error):
        return ""
    return ""


def _vanilla_twui_ver(pat: str):
    """max version=\"N\" among vanilla (non-mod-built) data packs; None if n/a."""
    best = None
    for p in _vanilla_packs():
        v = _entry_twui_ver(p, pat)
        if isinstance(v, int) and v >= 0:
            best = v if best is None else max(best, v)
    return best


def cmd_which(a):
    if a.playset:
        hits = _playset_providers(a.substr)
        if not hits:
            print(f"-- no used_mods pack provides {a.substr!r}")
            return
        pat = a.substr.replace("\\", "/").casefold()
        want_twui = a.substr.casefold().endswith(".twui.xml")
        van_v = _vanilla_twui_ver(pat) if want_twui else None
        print(f"-- {len(hits)} providers in playset load order "
              f"(靠前胜出 —— 首个为实际生效者):")
        for i, (pos, pack) in enumerate(hits):
            tag = " <== WINS" if i == 0 else ""
            ver = ""
            if want_twui:
                v = _entry_twui_ver(pack, pat)
                if isinstance(v, int):
                    ver = f"  v{v if v >= 0 else '?'}"
                    if van_v is not None and 0 <= v < van_v:
                        ver += f" [STALE 原版v{van_v}]"
            print(f"  #{pos:<3} {pack.name}{ver}{tag}")
        if van_v is not None:
            print(f"  vanilla 基线: v{van_v}（低于它的遮蔽者即过期拷贝）")
        return
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

def _ui_dumps(text: str):
    """Parse [ui] uicomponent click dumps -> [(ts, name, root_path)]."""
    clicks, cur = [], None
    for line in text.splitlines():
        m = re.match(r"\[ui\] <([\d.]+)s>\s+uicomponent (\S+)", line)
        if m:
            cur = [m.group(1), m.group(2), ""]
            clicks.append(cur)
        elif cur is not None and "path from root:" in line:
            cur[2] = line.split("path from root:", 1)[1].strip()
            cur = None
        elif cur is not None and not line.startswith("[ui]"):
            cur = None
    return clicks


def _scriptlog_ui(files, last):
    err_re = re.compile(r"SCRIPT ERROR, timestamp <([\d.]+)s>")
    print(f"{'mtime':<15} {'clicks':>6} {'errs':>5}  err_span   last-clicked")
    for p in files[-last:]:
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        clicks = _ui_dumps(text)
        errs = err_re.findall(text)
        span = f"{errs[0]}s→{errs[-1]}s" if errs else "-"
        tail = clicks[-1] if clicks else None
        print(f"{p.name[-15:]:<15} {len(clicks):>6} {len(errs):>5}  {span:<15}"
              f"  {tail[1] if tail else '-'}")
        for ts, name, path in clicks[-8:]:
            print(f"    <{ts}s> {name}  [{path}]")
    if files:
        banner = "*** output_uicomponent_on_click() called ***"
        p = files[-1]
        text = p.read_text(encoding="utf-8", errors="replace")
        if banner in text:
            print(f"NOTE: {p.name} 点击转储已启用 —— "
                  "每个 [ui] dump = 一次 click 事件分发")


def cmd_scriptlog(a):
    g = game_root()
    if not g:
        sys.exit("game root not found")
    files = sorted(g.glob(a.glob), key=lambda p: p.stat().st_mtime)
    if not files:
        sys.exit(f"no {a.glob} under {g}")
    if a.ui:
        _scriptlog_ui(files, a.last)
        return
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


def _powershell(script: str):
    """Run a PowerShell one-liner; returns stdout or None."""
    import subprocess
    exe = "powershell.exe" if os.name == "posix" else "powershell"
    try:
        r = subprocess.run(
            [exe, "-NoProfile", "-Command", script],
            capture_output=True, timeout=60)
        data = r.stdout or b""
        try:
            return data.decode("utf-8")
        except UnicodeDecodeError:
            return data.decode("gbk", "replace")  # OEM codepage output
    except (OSError, subprocess.SubprocessError):
        return None


def cmd_events(a):
    """OOM gate: System Event 2004 + Application WER 1000/1001 + live process."""
    hrs = a.hours
    print(f"== System Event 2004 (虚拟内存不足) last {hrs}h ==")
    out = _powershell(
        "Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004; "
        f"StartTime=(Get-Date).AddHours(-{hrs})}} -MaxEvents 10 "
        "| ForEach-Object { $_.TimeCreated.ToString('MM-dd HH:mm:ss') + ' | ' "
        "+ (($_.Message -split \"`n\") -join ' ~ ') }")
    if out is None:
        print("  powershell unavailable")
    else:
        print(out.strip() or "  (none)")
    if a.app:
        print(f"== Application Error 1000/1001 last {hrs}h ==")
        out = _powershell(
            "Get-WinEvent -FilterHashtable @{LogName='Application'; "
            f"Id=1000,1001; StartTime=(Get-Date).AddHours(-{hrs})}} "
            "-MaxEvents 15 | ForEach-Object { "
            "$_.TimeCreated.ToString('MM-dd HH:mm:ss') + ' | ' "
            "+ (($_.Message -split \"`n\" | Select-Object -First 3) -join ' ~ ') }")
        print((out or "").strip() or "  (none)")
    # Command line distinguishes a user launch from `game_startup_mode
    # battle` autotests and leftover watchers; fall back to bare Get-Process
    # if CIM is unavailable.
    out = _powershell(
        "Get-CimInstance Win32_Process -Filter \"Name='Warhammer3.exe'\" "
        "| ForEach-Object { $_.Name + ' pid=' + $_.ProcessId + ' started=' "
        "+ $_.CreationDate.ToString('MM-dd HH:mm:ss') + ' cmd=' "
        "+ $_.CommandLine }")
    procs = (out or "").strip()
    if not procs:
        out = _powershell(
            "Get-Process | Where-Object {$_.Name -match 'Warhammer|wh3'} "
            "| ForEach-Object { $_.Name + ' pid=' + $_.Id }")
        procs = (out or "").strip()
    print(f"== WH3 processes now ==\n{procs or '  (none)'}")
    if procs:
        print("NOTE: 有存活 WH3 进程 —— 并发干扰检查未过，先确认归属再归因"
              "（禁止杀玩家手动拉起/正在玩的进程；两段式启动会短暂出现"
              "父子两个 PID）")


# AppData subdirs that are pure crash/session OUTPUTS, not suspects — the
# suspect list cares about what *changed* (packs, prefs, cached setups), not
# the artifacts the crash itself produced.
_RECENT_APPDATA_NOISE = {"crash_report", "temp", "logs"}


def cmd_recent(a):
    """Recently-modified packs + AppData files = the regression suspect list."""
    cutoff = time.time() - a.hours * 3600
    pack_rows, app_rows, noise = [], [], 0
    for base, pat in ((data_dir(), "*.pack"),
                      (workshop_dir(), "*/*.pack"),
                      (MOD_OUTPUT if MOD_OUTPUT.is_dir() else None, "*.pack")):
        if not base:
            continue
        for p in base.glob(pat):
            try:
                st = p.stat()
            except OSError:
                continue
            if st.st_mtime >= cutoff:
                pack_rows.append((st.st_mtime, str(p)))
    aw = appdata_wh3()
    if aw:
        for p in aw.rglob("*"):
            if not p.is_file():
                continue
            try:
                rel = p.relative_to(aw)
            except ValueError:
                continue
            if rel.parts and rel.parts[0] in _RECENT_APPDATA_NOISE:
                try:
                    noise += p.stat().st_mtime >= cutoff
                except OSError:
                    pass
                continue
            try:
                st = p.stat()
            except OSError:
                continue
            if st.st_mtime >= cutoff:
                app_rows.append(
                    (st.st_mtime, "%APPDATA%/" + str(rel).replace("\\", "/")))
    fmt = "%m-%d %H:%M:%S"
    pack_rows.sort(reverse=True)
    app_rows.sort(reverse=True)
    print(f"== packs modified in last {a.hours:g}h "
          f"(data\\ + workshop + mod_output; {len(pack_rows)}) ==")
    for ts, p in pack_rows[: a.top]:
        print(f"  {time.strftime(fmt, time.localtime(ts))}  {p}")
    if len(pack_rows) > a.top:
        print(f"  ... +{len(pack_rows) - a.top} more")
    print(f"== AppData files modified in last {a.hours:g}h "
          f"({len(app_rows)}; {noise} dump/save-temp/log 输出物已略) ==")
    for ts, p in app_rows[: a.top]:
        print(f"  {time.strftime(fmt, time.localtime(ts))}  {p}")
    if len(app_rows) > a.top:
        print(f"  ... +{len(app_rows) - a.top} more")


def _resolve_pack_soft(name: str):
    """resolve_pack() without sys.exit -> Path | None."""
    p = local_path(name)
    if p.is_file():
        return p
    name = Path(name.replace("\\", "/")).name
    for base in (data_dir(), MOD_OUTPUT):
        if base and (base / name).is_file():
            return base / name
    ws = workshop_dir()
    if ws:
        hits = sorted(ws.glob("*/" + name))
        if hits:
            return hits[0]
    return None


def _used_mod_packs(mods_only: bool = True):
    """Resolve used_mods.txt entries to pack paths in LOAD ORDER.

    used_mods.txt lives at the GAME ROOT. ``mod "x.pack"`` lines are the
    authoritative load list (order preserved); ``add_working_directory``
    lines merely register ws search dirs and are expanded only when
    mods_only=False (content scans want max coverage).
    """
    g = game_root()
    if not g:
        return []
    used = g / "used_mods.txt"
    if not used.is_file():
        return []
    packs = []
    for _i, kind, v in _parse_modlist(used):
        if kind == "add_working_directory":
            if not mods_only:
                p = local_path(v)
                if p.is_dir():
                    packs.extend(sorted(p.glob("*.pack")))
            continue
        rp = _resolve_pack_soft(v)
        if rp:
            packs.append(rp)
    return list(dict.fromkeys(packs))


def _playset_providers(internal: str):
    """(pos, pack) pairs from used_mods `mod` entries providing the path."""
    pat = internal.replace("\\", "/").casefold()
    hits = []
    for pos, pack in enumerate(_used_mod_packs(mods_only=True)):
        try:
            names = [e.name.casefold() for e in iter_pack_index(pack)]
        except (OSError, struct.error):
            continue
        if any(pat in n for n in names):
            hits.append((pos, pack))
    return hits


def _dump_sig(p: Path):
    """Short inner-exception signature for a mdmp; None if unparseable."""
    try:
        exc, mods, _ = _mdmp_parse(p)
    except (OSError, struct.error):
        return None
    if exc is None:
        return "no-exc-stream"
    loc = _mod_at(mods, exc["addr"]) or f"0x{exc['addr']:x}"
    prm = ",".join(hex(x) for x in exc["params"][:2])
    return f"0x{exc['code']:08x} @{loc} [{prm}]"


def _event2004_times(hours):
    """Epoch times of System Event 2004 within the window (newest first)."""
    out = _powershell(
        "Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004; "
        f"StartTime=(Get-Date).AddHours(-{hours})}} -MaxEvents 30 "
        "| ForEach-Object { $_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') }")
    times = []
    for ln in (out or "").splitlines():
        try:
            times.append(time.mktime(time.strptime(ln.strip(),
                                                   "%Y-%m-%d %H:%M:%S")))
        except ValueError:
            pass
    return times


def _crash_onset(gap_h: float = 6.0, lookback_h: float = 168.0):
    """mtime of the earliest dump in the most recent crash cluster.

    Dumps separated by a >gap_h silence start a new cluster; the cluster's
    first dump approximates when the regression began — i.e. how far back
    'recently modified' suspects must reach.
    """
    aw = appdata_wh3()
    cr = aw / "crash_report" if aw else None
    if not cr or not cr.is_dir():
        return None
    cut = time.time() - lookback_h * 3600
    times = sorted(p.stat().st_mtime for p in cr.glob("D*.mdmp")
                   if p.stat().st_mtime >= cut)
    if not times:
        return None
    start = times[-1]
    for t in reversed(times[:-1]):
        if start - t > gap_h * 3600:
            break
        start = t
    return start


def cmd_triage(a):
    """One-shot crash triage: recent packs -> dumps -> scriptlog -> OOM gate."""
    hrs = a.hours
    onset = _crash_onset()
    if onset is not None:
        need = (time.time() - onset) / 3600 + 0.5
        if need > hrs:
            hrs = need
            print(f"(recent/events 窗口自动扩到 {hrs:.1f}h —— 对齐当前崩溃簇"
                  f"起点 {time.strftime('%m-%d %H:%M', time.localtime(onset))})")
    print("########## 1) 最近更新嫌疑（最近更新优先，禁止盲二分）")
    cmd_recent(argparse.Namespace(hours=hrs, top=15))

    g = game_root()
    aw = appdata_wh3()
    cr = aw / "crash_report" if aw else None
    dumps = sorted(cr.glob("D*.mdmp"), key=lambda p: p.stat().st_mtime)[-a.last:] \
        if cr and cr.is_dir() else []
    logs = sorted(g.glob("script_log_*.txt"),
                  key=lambda p: p.stat().st_mtime)[-a.last:] if g else []
    ev = _event2004_times(hrs)

    # dump<->log 配对：崩溃瞬间 script_log 最后 flush 的 mtime ≈ dump 写入时刻。
    # 必须双向互为最近——快速重开时无 dump 的会话会被单向窗口错配到隔壁 dump。
    PAIR_WIN = 180  # s
    dump_sig = {dp: _dump_sig(dp) for dp in dumps}
    log_t = {p: p.stat().st_mtime for p in logs}
    dump_t = {p: p.stat().st_mtime for p in dumps}
    def _nearest(pool, t):
        return min(pool, key=lambda p: abs(pool[p] - t), default=None)
    log_crash, dump_log = {}, {}
    for lp, lt in log_t.items():
        best = _nearest(dump_t, lt)
        if best is None or abs(dump_t[best] - lt) > PAIR_WIN:
            continue
        if _nearest(log_t, dump_t[best]) is not lp:
            continue  # 该 dump 属于更近的另一个 log
        log_crash[lp] = best
        dump_log[best] = lp

    print("\n########## 2) 最近 dump 签名（内层异常码）+ Event2004 邻近度")
    if not dumps:
        print("  (no dumps)")
    else:
        hist = {}
        for dp in dumps:
            s = dump_sig[dp] or "unparsed"
            m = re.search(r"\+0x([0-9a-f]+)", s)
            key = f"+0x{m.group(1)}" if m else s.split()[0]
            hist[key] = hist.get(key, 0) + 1
        print("  签名分布: " + " | ".join(
            f"{k}×{v}" for k, v in
            sorted(hist.items(), key=lambda x: -x[1])))
        if len(hist) > 1:
            print("  (多签名并存=不同根因，勿按单一结论归因)")
    for dp in dumps:
        t = dp.stat().st_mtime
        evs = ""
        if ev:
            d = min(ev, key=lambda e: abs(e - t))
            delta = d - t
            if abs(delta) <= 600:
                evs = f"  ev2004{delta:+.0f}s"
                if abs(delta) <= 60:
                    evs += "<=同刻命中=OOM嫌疑(§10.21)"
        print(f"  {dp.name[:22]:<22} {(dump_sig[dp] or 'unparsed'):<46}"
              f" [{_mtime(dp)}]  log={dump_log[dp].name if dp in dump_log else '-'}"
              f"{evs}")
        try:
            exc2, mods2, _r = _mdmp_parse(dp)
        except (OSError, struct.error):
            exc2 = None
        if exc2:
            h, _x = _sig_hint(exc2, mods2)
            if h:
                print(f"    ==> {h}")

    print("\n########## 3) script_log 阶段 + [ui] 点击序列")
    load_re = re.compile(r"Loading mod file \[([^\]]*)\]")
    err_re = re.compile(r"SCRIPT ERROR, timestamp <([\d.]+)s>")
    name_re = re.compile(r"script_log_(\d{6})_(\d{4})")
    counts = {}
    texts = {}
    for p in logs:
        try:
            texts[p] = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            texts[p] = ""
        counts[p] = len(load_re.findall(texts[p]))
    full = max(counts.values()) if counts else 0
    for p in logs:
        text = texts[p]
        loads_n = counts[p]
        clicks = _ui_dumps(text)
        errs = err_re.findall(text)
        last_click = clicks[-1][1] if clicks else "-"
        span = f"{errs[0]}-{errs[-1]}s" if errs else "-"
        crash = log_crash.get(p)
        sig = "-"
        if crash is not None:
            s = dump_sig.get(crash) or "unparsed"
            sig = " ".join(s.split()[:2])
        # 阶段判定：stub(<300B) / 枚举截断 / 运行时崩 / 存活
        if p.stat().st_size < 300:
            phase = "stub"
        elif full and loads_n < full * 0.8:
            phase = "enum-mid"
        elif crash is not None:
            phase = "run-crash"
        else:
            phase = "ok"
        # 会话墙钟：文件名 DDMMYY_HHMM 起点 → mtime 终点
        span_s = ""
        nm = name_re.match(p.name)
        if nm:
            d6, hm = nm.group(1), nm.group(2)
            try:
                st = time.mktime(time.strptime(
                    f"20{d6[4:6]}{d6[2:4]}{d6[0:2]} {hm}00",
                    "%Y%m%d %H%M%S"))
                dur = p.stat().st_mtime - st
                if 0 <= dur < 86400:
                    span_s = f" {hm[:2]}:{hm[2:]}+{dur:.0f}s"
            except ValueError:
                pass
        print(f"  {p.name[-15:]:<15} {p.stat().st_size:>7}B "
              f"loads={loads_n:>3} phase={phase:<9}{span_s} "
              f"errs={len(errs):>3}({span}) "
              f"last_click={last_click}  crash={sig}")
    print("  (phase: stub<300B | enum-mid<80%满载 | run-crash | ok=存活；"
          "crash=- = 该会话未产 dump)")

    print("\n########## 4) OOM 闸门（Event 2004）与并发检查")
    a2 = argparse.Namespace(hours=hrs, app=False)
    cmd_events(a2)
    if aw:
        print("\n########## 5) AppData 判据文件（mtime + 内容判定）")
        for rel in ("crash_report/bad_mods_report.txt",
                    "logs/modified.log", "logs/mp_log.txt"):
            p = aw / rel
            if not p.is_file():
                continue
            st = p.stat()
            extra = ""
            if rel.endswith("bad_mods_report.txt") and logs:
                # 最近会话窗口内被刷新 → DB 校验路线
                lp = logs[-1]
                lt_last = lp.stat().st_mtime
                nm = name_re.match(lp.name)
                if nm:
                    d6, hm = nm.group(1), nm.group(2)
                    try:
                        stt = time.mktime(time.strptime(
                            f"20{d6[4:6]}{d6[2:4]}{d6[0:2]} {hm}00",
                            "%Y%m%d %H%M%S"))
                        if stt - 60 <= st.st_mtime <= lt_last + 120:
                            extra = "  <= 最近会话内刷新→走DB校验路线(§二)"
                    except ValueError:
                        pass
            print(f"  {_mtime(p)}  {st.st_size:>7}B  {rel}{extra}")
            if extra:
                for ln in p.read_text(
                        encoding="utf-8", errors="replace").splitlines()[:6]:
                    if ln.strip():
                        print(f"      | {ln.strip()[:110]}")
        pref = aw / "scripts" / "preferences.script.txt"
        if pref.is_file():
            txt = pref.read_text(encoding="utf-8", errors="replace")
            vals = dict(re.findall(
                r"(?m)^(minimise_memory_usage|gfx_texture_quality"
                r"|gfx_unit_size|gfx_unit_quality|gfx_unlimited_video_memory)"
                r"\s+([^;#\s]+)", txt))
            # §10.19 修正：minimise=true + gfx=3(ultra) 仍会 OOM，须一起判
            bad = (vals.get("minimise_memory_usage") == "false"
                   or vals.get("gfx_texture_quality") == "3"
                   or vals.get("gfx_unit_size") == "3"
                   or vals.get("gfx_unit_quality") == "3")
            warn = ("  <= OOM 危险档位（prefs 被写回/未降档）→"
                    " tools/set_memory_safe_prefs.py" if bad else "")
            print(f"  {_mtime(pref)}  {pref.stat().st_size:>7}B  "
                  f"scripts/preferences.script.txt "
                  + " ".join(f"{k}={v}" for k, v in vals.items()) + warn)

        nce = aw / "logs" / "no_clean_exit"
        if nce.is_file():
            print(f"  {_mtime(nce)}  logs/no_clean_exit —— 上次非干净退出"
                  "或游戏正在运行（崩溃留痕/无 dump 时的佐证）")

        # 挂载进度：modified.log `Mod:` 行 vs used_mods.txt `mod` 行。
        # 差异大 = 崩在 pack 挂载期（+0x52a21a 族，§10.31）。
        mlog = aw / "logs" / "modified.log"
        used = g / "used_mods.txt" if g else None
        if mlog.is_file() and used and used.is_file():
            mlines = [l.split("Mod:", 1)[1].strip()
                      for l in mlog.read_text(encoding="utf-8",
                                              errors="replace").splitlines()
                      if l.startswith("Mod:")]
            expected = {v for _i, k, v in _parse_modlist(used) if k == "mod"}
            missing = sorted(expected - set(mlines))
            print(f"  挂载进度: Mod: {len(set(mlines))} 唯一 / used_mods "
                  f"{len(expected)} 唯一"
                  + (f"  最后挂载: {mlines[-1]}" if mlines else ""))
            if missing:
                note = ("  <== 大量未挂载=崩在 pack 挂载期（§10.31）"
                        if len(missing) > 5 else "")
                print("    used_mods 列出但无 Mod: 行: "
                      + ", ".join(missing[:8])
                      + (" ..." if len(missing) > 8 else "") + note)
            # §10.37 教训：管理器界面的 playset 可能在启动后又被改过
            sdb = local_path(r"%APPDATA%\WycccModManager\state.db")
            if sdb.is_file() and \
                    sdb.stat().st_mtime > used.stat().st_mtime:
                print(f"  !! state.db（{_mtime(sdb)}）比 used_mods.txt 新"
                      " —— playset 在上次启动后又被改过，清单可能失真")

            # 工坊文件盘点：used_mods 的 add_working_directory 逐目录验在盘
            # 且内含 .pack——工坊内容被整体抹除时（订阅丢失/缓存清除）
            # Mod: 行会是 0 或大面积缺失，此检查把"文件根本没下载"
            # 与"挂载期崩溃"区分开（2026-09-26 实测：89 项订阅被抹，
            # content/1142710 只剩 1 个目录）。
            wd = [v for _i, k, v in _parse_modlist(used)
                  if k == "add_working_directory"]
            if wd:
                gone, empty = [], []
                for raw in wd:
                    wdir = local_path(raw.strip().strip('"'))
                    if not wdir.is_dir():
                        gone.append(wdir.name)
                    elif not any(wdir.glob("*.pack")):
                        empty.append(wdir.name)
                if gone or empty:
                    print(f"  !! 工坊文件缺失: {len(gone)} 目录不存在"
                          f"/{len(empty)} 空目录（used_mods 共引用 "
                          f"{len(wd)} 个）——先恢复订阅再归因 mod 内容")
                    if gone:
                        print("    不存在: " + ", ".join(gone[:8])
                              + (" ..." if len(gone) > 8 else ""))
                    if empty:
                        print("    空目录: " + ", ".join(empty[:8])
                              + (" ..." if len(empty) > 8 else ""))

        # 存档版本指纹：读档期 dump（world-restore 空指针族）先比对
        # 存档写入 build 与当前 exe —— 跨版本存档在 mod 无关层面就会崩。
        sg = aw / "save_games"
        xv = _exe_version()
        if sg.is_dir() and xv:
            saves = sorted(sg.glob("*.save"),
                           key=lambda x: x.stat().st_mtime)
            if saves:
                newest = saves[-1]
                nvs, _ps = _save_stamps(newest)
                exe_major = xv.split(".")[0]
                mismatch = nvs and all(
                    v.split(".")[0] != exe_major for v in nvs)
                tag = ("  <== 最新存档写于旧大版本，读档崩溃先查跨版本"
                       "（§10.31）") if mismatch else ""
                print(f"  存档版本: 最新 {newest.name[:40]} "
                      f"戳={','.join(nvs) or '-'} | exe={xv}{tag}")


def cmd_collect(a):
    """Freeze mutable crash evidence into scratch/crash_<ts>/.

    Dumps and script_logs persist by timestamped name, but the playset
    (used_mods.txt / state.db), preferences, and rolling logs get overwritten
    in place by later launches — copy them before A/B testing mutates state.
    Writes ONLY to scratch/ (repo hygiene compliant); reads game files.
    """
    ts = time.strftime("%Y%m%d_%H%M%S")
    out = ROOT / "scratch" / f"crash_{ts}"
    out.mkdir(parents=True, exist_ok=True)
    g, aw = game_root(), appdata_wh3()
    copied = []

    def cp(src, name=None):
        if src is not None and src.is_file():
            shutil.copy2(src, out / (name or src.name))
            copied.append(name or src.name)

    if g:
        cp(g / "used_mods.txt")
        for p in sorted(g.glob("script_log_*.txt"),
                        key=lambda p: p.stat().st_mtime)[-a.last:]:
            cp(p)
    if aw:
        for rel in ("scripts/preferences.script.txt",
                    "crash_report/bad_mods_report.txt",
                    "logs/modified.log", "logs/mp_log.txt"):
            cp(aw / rel, rel.replace("/", "__"))
        cp(aw.parents[1] / "WycccModManager" / "state.db",
           "WycccModManager__state.db")
    man = [f"collect {ts}  last={a.last}", "", "== dump signatures (last 10) =="]
    cr = aw / "crash_report" if aw else None
    if cr and cr.is_dir():
        for dp in sorted(cr.glob("D*.mdmp"),
                         key=lambda p: p.stat().st_mtime)[-10:]:
            man.append(f"{dp.name}  {_dump_sig(dp) or 'unparsed'}  "
                       f"[{_mtime(dp)}]")
    man += ["", "== System Event2004 (72h) =="]
    for t in _event2004_times(72):
        man.append(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t)))
    man += ["", "== copied =="] + copied
    (out / "manifest.txt").write_text("\n".join(man), encoding="utf-8")
    print(f"-- frozen {len(copied)} files + manifest -> {out}")


def cmd_grep(a):
    """Search file *contents* (line-wise) inside packs."""
    rx = re.compile(a.pattern, re.I if a.i else 0)
    exts = tuple(x.lower() for x in
                 (a.ext if a.ext is not None else (".lua", ".twui.xml"))
                 if x)
    if a.scope == "used":
        packs = _used_mod_packs(mods_only=False)
        if not packs:
            sys.exit("used_mods.txt missing/empty under game root "
                     "(default scope=used needs it; use --scope all/data/ws)")
    else:
        packs = []
        d, ws = data_dir(), workshop_dir()
        if a.scope in ("data", "all") and d:
            packs += sorted(d.glob("*.pack"))
        if a.scope in ("ws", "all") and ws:
            packs += sorted(ws.glob("*/*.pack"))
        if a.scope in ("out", "all") and MOD_OUTPUT.is_dir():
            packs += sorted(MOD_OUTPUT.glob("*.pack"))
    print(f"[grep] /{a.pattern}/ over {len(packs)} packs"
          f" (exts: {' '.join(exts) or 'all'})")
    hits = 0
    for pack in packs:
        try:
            entries = list(iter_pack_index(pack))
        except (OSError, struct.error):
            continue
        for e in entries:
            if exts and not e.name.casefold().endswith(exts):
                continue
            try:
                data = read_pack_payload(pack, e)
            except (OSError, struct.error):
                continue
            if b"\x00" in data[:4096]:
                continue  # binary payload
            for n, line in enumerate(
                    data.decode("utf-8", "replace").splitlines(), 1):
                if rx.search(line):
                    print(f"{pack.name}\n  {e.name}:{n}\n    {line.strip()[:200]}")
                    hits += 1
                    if hits >= a.max:
                        print(f"-- stopped at --max {a.max}")
                        return
    print(f"-- {hits} matching lines")


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


# Inner exception signature -> verdict, for faults inside Warhammer3.exe.
# Offsets were recorded on the builds where each case was confirmed
# (8.1.1 / 9.0=build 25509431); CA updates shift them, so on a new build
# treat a table miss as "unknown", a hit as strong evidence.
# Details: references/crash_and_load_order_diagnostics.md §三.
_SIG_HINTS = {
    (0xC0000005, 0x1A0BE3B): "battle init 读 null+0x20 → AppData 军表悬空 "
                           "key / Lua 首帧写 gfx pref（§10.14/10.30）",
    (0xC0000005, 0x2CCD917): "matched-combat 套件查表 -1 → bin 内部名须 "
                           "==stem==DB key（§10.34）",
    (0xC0000005, 0x2CFE551): "battle setup 序列化空对象；vanilla 同崩=环境"
                           "竞态（§10.23）",
    (0xC0000005, 0x157ACC6): "战役/存档载入 junction 表悬空 key（§10.35）",
    (0xC0000005, 0x52A21A):  "9.0 pack 挂载期空指针 → 前端二分（§10.31）",
    (0xC0000005, 0x538A0A):  "9.0 挂载完成后悬空 key → compat 审计"
                           "（§10.31/10.33）",
    (0xC0000005, 0x1A957E7): "9.0 环境级早期 init，vanilla 同崩（§10.31）",
    (0xC0000005, 0x4E5B30):  "9.0 环境级早期 init，vanilla 同崩（§10.31）",
    (0xC0000005, 0x4926F0):  "启动 stub 空指针 / Steam 握手失败（§10.26）",
    (0xC0000005, 0x1BB9418): "uicomponent 事件分发空指针 → scriptlog --ui "
                           "看最后 click（§10.37）",
    (0xC0000005, 0x243AE98): "9.0 旧版存档 campaign_load（§10.31 遗留）",
    (0xC0000005, 0x257CE84): "存档 world-restore 读 0x1d1 → saveinfo 比对"
                           "存档写入版本 vs exe（§10.31）",
    (0xC0000005, 0x247670A): "存档 world-restore 读 0xa107 → saveinfo 比对"
                           "存档写入版本 vs exe（§10.31）",
    (0xC0000005, 0x22C0F80): "新开局 intro 序列窗（dismiss后0~2s）竞态读 "
                           "null+0x58 空虚表调用；mod 侧触发（vanilla A/B "
                           "存活定案）→ §10.40；查日志尾 [ui] dump+mod 回调",
    (0xC0000005, 0x22C8774): "intro 序列窗野指针写（mov [rax+0x351],bl → "
                           "释放页 UAF 写）→ mod 回调内联重 UI 撞 overlay/"
                           "flyover 析构；global_lua_guard 已挂 intro-settle "
                           "门控（v1 待实测）→ §10.40",
    (0xC0000005, 0x132C34C): "intro 序列窗写违规（mov [rdi+rcx*8],rax → "
                           "非法数组基址 0x4/哨兵 0xa0000000a）→ "
                           "同 +0x22c8774 族，flyover 起步段可命中 → §10.40",
    (0xC0000005, 0x1413537): "新开局 init ~1s 读 null+0xe0 + WER fastfail "
                           "c0000409@+0x113c0f1；当次工坊内容正被抹除"
                           "（订阅全丢）——先查 triage 工坊文件盘点",
    (0xC0000005, 0x112E6A6): "野读巨大偏移（params[1]~0x56xxxxxxxx，非 "
                           "null+小偏移）→ mod 侧 SimulateLClick 不可见/"
                           "越权佣兵按钮、或枚举 mercenary_pool "
                           "unit_record 触发；09-28 定案=czx_vmp_pool_probe "
                           "（§10.40 邻近族，UI 派发期原生工作）",
}


def _sig_hint(exc, mods):
    """(hint_text, exact_table_hit) for a parsed exception stream."""
    code, addr, params = exc["code"], exc["addr"], exc["params"]
    for base, size, name in sorted(mods):
        if base <= addr < base + size:
            mod = name.replace("\\", "/").rsplit("/", 1)[-1]
            if mod.casefold() == "warhammer3.exe":
                h = _SIG_HINTS.get((code, addr - base))
                if h:
                    return h, True
            break
    if code == 0xE06D7363:
        if params and params[0] == 0x19930520:
            return ("std::bad_alloc = OOM → 先查 Event 2004"
                    "（§10.19/10.21）", False)
        return "C++ 未捕获异常（§10.11）", False
    if code == 0xC0000005:
        if params and params[0] == 0x8:
            return ("DEP 执行违例（rip 跳进非模块地址）= UAF/坏虚表"
                    "（§10.12a/10.13/10.36）", False)
        if params and params[0] in (0, 1) and params[1] < 0x10000:
            return "读/写 null+小偏移 = 空指针类（对照 §三 表）", False
    if code == 0xC0000409:
        return "通用 fail-fast 外壳，须看内层异常码（§10.13）", False
    if code == 0xC000041D:
        return "fatal user callback / TSF-IME-overlay 交互（§10.11）", False
    return None, False


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
    rip_outside = False
    if regs:
        rip_loc = _mod_at(mods, regs["rip"])
        rip_outside = rip_loc is None
        line += f" rip={rip_loc or hex(regs['rip']) + '(模块外)'}"
    print(line)
    hint, exact = _sig_hint(exc, mods)
    if hint:
        print(f"    ==> {hint}")
    if rip_outside:
        print("    ==> rip 不在任何已加载模块内 = 坏函数指针/虚表 UAF"
              "（§10.12a/10.36）")
    if a.regs and regs:
        print("    " + " ".join(f"{k}=0x{v:x}" for k, v in regs.items()))
    if a.stack:
        st = _stack_txt(p)
        if st:
            print(f"    stack.txt: {st}")
    return exact


def _resolve_dump(spec: str) -> Path:
    """Bare filename / D<ts> stem also resolves against crash_report dir."""
    p = local_path(spec)
    if p.is_file():
        return p
    cr = appdata_wh3()
    cr = cr / "crash_report" if cr else None
    if cr and cr.is_dir():
        name = Path(spec).name
        for cand in (cr / name, cr / (name + ".mdmp"),
                     cr / (name.replace("D", "D", 1) + ".mdmp")):
            if cand.is_file():
                return cand
        hits = sorted(cr.glob(f"*{name}*"), key=lambda x: x.stat().st_mtime)
        if hits:
            return hits[-1]
    return p


_EXE_VER_CACHE = {}


def _exe_version():
    """Warhammer3.exe FileVersion (e.g. '9.0.0.0'); '' if unresolved."""
    if "v" not in _EXE_VER_CACHE:
        g = game_root()
        exe = g / "Warhammer3.exe" if g else None
        v = ""
        if exe and exe.is_file():
            w = str(exe)
            m = re.match(r"^/mnt/([a-zA-Z])/(.*)$", w)
            if m:  # WSL path -> Windows form for PowerShell
                w = m.group(1).upper() + ":\\" + \
                    m.group(2).replace("/", "\\")
            out = _powershell(
                f"(Get-Item '{w}').VersionInfo.FileVersion")
            v = (out or "").strip().splitlines()[0].strip() \
                if out and out.strip() else ""
        _EXE_VER_CACHE["v"] = v
    return _EXE_VER_CACHE["v"]


def _save_stamps(path):
    """Version stamps embedded in a .save (writing-build fingerprint).

    CA records `vX.Y.Z Build NNNNN…` and `Patch_X_Y` tokens in the save
    metadata region; a save written before a major patch keeps the old
    build stamp — the primary cross-version-incompatibility signal.
    Returns (sorted version set, sorted patch set).
    """
    try:
        data = Path(path).read_bytes()
    except OSError:
        return set(), set()
    vs = {m.group(1).decode() for m in re.finditer(rb"v(\d+\.\d+\.\d+)", data)}
    ps = {f"{m.group(1).decode()}.{m.group(2).decode()}"
          for m in re.finditer(rb"Patch_(\d+)_(\d+)", data)}
    return sorted(vs), sorted(ps)


def _resolve_save(spec):
    """Bare save name / stem resolves against save_games dir."""
    p = local_path(spec)
    if p.is_file():
        return p
    aw = appdata_wh3()
    sg = aw / "save_games" if aw else None
    if sg and sg.is_dir():
        name = Path(spec).name
        for cand in (sg / name, sg / (name + ".save")):
            if cand.is_file():
                return cand
        hits = sorted(sg.glob(f"*{name}*"), key=lambda x: x.stat().st_mtime)
        if hits:
            return hits[-1]
    return p


def cmd_saveinfo(a):
    """Save-file writing-build fingerprint vs current exe version."""
    p = _resolve_save(a.name)
    if not p.is_file():
        sys.exit(f"save not found: {a.name} (looked in save_games too)")
    vs, ps = _save_stamps(p)
    xv = _exe_version()
    print(f"{p.name}  {p.stat().st_size // 1024 // 1024}MB  "
          f"[{_mtime(p)}]")
    print(f"  存档内 build 戳: {', '.join(vs) or '(none)'}"
          + (f"  patch: {', '.join(ps)}" if ps else ""))
    print(f"  当前 exe: {xv or 'unresolved'}")
    if vs and xv:
        save_major = max(vs, key=lambda s: [int(x) for x in s.split(".")])
        if save_major.split(".")[0] != xv.split(".")[0]:
            print("  <== 跨版本存档：写于 "
                  f"{save_major}，当前 exe {xv} —— 读档崩溃先按"
                  "跨版本存档归因（§10.31），不要先动 mod")


def cmd_crashes(a):
    if a.dump:
        _dump_line(_resolve_dump(a.dump), a)
        return
    cr = local_path(a.dir) if a.dir else (
        appdata_wh3() / "crash_report" if appdata_wh3() else None)
    if not cr or not cr.is_dir():
        sys.exit("crash_report dir not found (set WH3_APPDATA or --dir)")
    dumps = sorted(cr.glob("D*.mdmp"), key=lambda p: p.stat().st_mtime)
    hit = False
    for p in dumps[-a.last:]:
        hit = _dump_line(p, a) or hit
    if hit:
        print("-- ==> 判定按录制时 build 的偏移；大版本更新后偏移漂移，"
              "新 build 上未命中不等于排除同类根因")


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
    # WH2 → WH3(DLC29) 复活池改名；2026-09-28 zzz_czx_vmp_raise_dead 用旧键
    # 致 bad_mods 闪退实证
    "wh_main_vmp_vampire_merc_pool": "wh3_dlc29_vmp_raise_dead_faction",
    "wh_main_vmp_province_pool": "wh3_dlc29_vmp_raise_dead_province",
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
    p.add_argument("--playset", action="store_true",
                   help="only active playset; ordered by load order,"
                        " first = actual winner (靠前胜出)")
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
    p.add_argument("--ui", action="store_true",
                   help="list [ui] click dumps + SCRIPT ERROR span per log;"
                        " last-clicked component is the suspect")

    p = sub.add_parser(
        "grep",
        help="search file CONTENTS inside packs (default: all packs in"
             " used_mods.txt; add_working_directory dirs expanded)")
    p.add_argument("pattern", help="python regex matched per line")
    p.add_argument("--scope",
                   choices=["used", "data", "ws", "out", "all"],
                   default="used",
                   help="used = packs referenced by used_mods.txt")
    p.add_argument("--ext", action="append", default=None, metavar="SUF",
                   help="file suffix filter, default .lua/.twui.xml;"
                        " repeatable; --ext '' disables filtering")
    p.add_argument("-i", action="store_true", help="case-insensitive")
    p.add_argument("--max", type=int, default=300,
                   help="stop after N matching lines")

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

    p = sub.add_parser(
        "events",
        help="OOM gate: System Event 2004 + WER 1000/1001 + live WH3 procs")
    p.add_argument("--hours", type=int, default=24)
    p.add_argument("--app", action="store_true",
                   help="also list Application Error 1000/1001")

    p = sub.add_parser(
        "recent",
        help="packs (data/ws/out) + AppData files modified within N hours"
             " = regression suspect list")
    p.add_argument("--hours", type=int, default=24)
    p.add_argument("--top", type=int, default=30)

    p = sub.add_parser(
        "triage",
        help="one-shot crash triage: recent packs + dump sigs + scriptlog"
             " phase/ui-clicks + Event 2004 + live procs + AppData freshness")
    p.add_argument("--hours", type=int, default=24,
                   help="window for 'recent' and Event 2004")
    p.add_argument("--last", type=int, default=6,
                   help="how many dumps / script_logs to show")

    p = sub.add_parser(
        "collect",
        help="freeze mutable evidence (used_mods/state.db/prefs/logs)"
             " into scratch/crash_<ts>/ before A/B mutates state")
    p.add_argument("--last", type=int, default=6,
                   help="how many recent script_logs to copy")

    p = sub.add_parser(
        "saveinfo",
        help="save-file writing-build fingerprint vs exe version"
             " (cross-version save detection; bare name resolves"
             " against save_games)")
    p.add_argument("name", help=".save path / filename / stem")

    a = ap.parse_args()
    {
        "paths": cmd_paths,
        "ls": cmd_ls,
        "meta": cmd_meta,
        "cat": cmd_cat,
        "which": cmd_which,
        "db": cmd_db,
        "scriptlog": cmd_scriptlog,
        "grep": cmd_grep,
        "usedmods": cmd_usedmods,
        "compat": cmd_compat,
        "crashes": cmd_crashes,
        "events": cmd_events,
        "recent": cmd_recent,
        "triage": cmd_triage,
        "collect": cmd_collect,
        "saveinfo": cmd_saveinfo,
    }[a.cmd](a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
