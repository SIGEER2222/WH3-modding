# -*- coding: utf-8 -*-
"""Export vanilla WH3 data into gamedata/ and bilingual/.

Rebuilt after the D: drive copy was lost. Sources:
- CA pack files under the game's ``data/`` directory (PFH5).
- RPFM schema ``schema_wh3.ron`` for DB table field definitions.

Outputs:
- ``gamedata/db/<table_name>/<internal>.tsv``  decoded DB tables (RPFM TSV layout).
- ``gamedata/script/...``                     vanilla Lua/scripts.
- ``gamedata/ui/...``                         vanilla UI text files (twui/xml/csv/txt).
- ``bilingual/EN/<file>.loc.tsv``             English localisation rows.
- ``bilingual/CN/<file>.loc.tsv``             Chinese localisation rows.
- ``bilingual/localisation__.loc_CN.tsv``     merged CN key->text lookup.

Pack format and DB binary layout follow the verified notes in
``wh3-pack-forensics`` and ``wyccc-warhammer-mod-manager/backend``.
"""

from __future__ import annotations

import io
import re
import struct
import sys
import time
import zlib
from dataclasses import dataclass
from pathlib import Path

try:
    import lz4.frame
except ImportError:  # pragma: no cover
    lz4 = None
try:
    import zstandard
except ImportError:  # pragma: no cover
    zstandard = None

GAME_DATA = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data")
WORKSPACE = Path(r"E:\Code\WH3-modding")
import os
_SCHEMA_ENV = os.environ.get("RPFM_SCHEMA_WH3")
_TOOLS_RON = Path(__file__).resolve().parent / "schema" / "schema_wh3.ron"
_RPFM_RON = (Path.home()
             / "AppData/Roaming/FrodoWazEre/rpfm/config/schemas/schema_wh3.ron")
SCHEMA_RON = Path(next(
    str(c) for c in (_SCHEMA_ENV, _TOOLS_RON, _RPFM_RON) if c and Path(c).is_file()
))

# CA-owned pack prefixes; user mods in data/ are excluded.
CA_PACK_RE = re.compile(
    r"^(anim|audio_|boot|commontextures|data|db|local_|models|movies|shaders|"
    r"skyboxes|tcamp|terrain|tile|ui|variants|vegetation|vfx|warmachines)",
    re.IGNORECASE,
)
# Packs worth scanning for gamedata content (skip pure media packs for speed).
GAMEDATA_PACK_RE = re.compile(
    r"^(boot|data|db|tcamp|ui_?|models\.pack$|local_)", re.IGNORECASE
)
UI_TEXT_EXT = {".xml", ".csv", ".txt", ".json", ".hlsl", ".shader", ".material"}

ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"
LZ4_MAGIC = b"\x04\x22\x4d\x18"
LOC_MAGIC = b"LOC\x00"


# ---------------------------------------------------------------- pack read

@dataclass
class PackEntry:
    name: str
    payload: bytes


@dataclass
class PackIndexEntry:
    """Index-only view of a packed file (no payload read)."""
    name: str        # '/'-normalised utf-8 path
    raw_name: bytes  # raw index bytes (invisible-char forensics)
    size: int
    compressed: bool
    offset: int      # payload offset inside the pack file


def read_pack_header(path: Path) -> dict | None:
    """Parse the 28-byte PFH5/PFH6 header + dependency block."""
    with path.open("rb") as f:
        header = f.read(28)
        if len(header) != 28 or header[:4] not in (b"PFH5", b"PFH6"):
            return None
        ptype, dep_cnt, dep_size, fcnt, isz, stamp = struct.unpack_from(
            "<6i", header, 4)
        deps_raw = f.read(dep_size) if 0 < dep_size < 16 * 1024 * 1024 else b""
        file_size = f.seek(0, 2)
    deps = [d.decode("utf-8", "replace") for d in deps_raw.split(b"\0") if d]
    return {
        "magic": header[:4].decode("ascii", "replace"),
        "pack_type": ptype,
        "dep_count": dep_cnt,
        "dep_size": dep_size,
        "file_count": fcnt,
        "index_size": isz,
        "timestamp": stamp,
        "deps": deps,
        "data_offset": 28 + dep_size + isz,
        "file_size": file_size,
    }


def iter_pack_index(path: Path):
    """Yield PackIndexEntry for every file in the pack index (no payload I/O)."""
    h = read_pack_header(path)
    if h is None:
        return
    with path.open("rb") as f:
        f.seek(28 + h["dep_size"])
        index = f.read(h["index_size"])
    cursor = 0
    offset = h["data_offset"]
    for _ in range(h["file_count"]):
        if cursor + 5 > len(index):
            break
        size = struct.unpack_from("<i", index, cursor)[0]
        compressed = index[cursor + 4] == 1
        cursor += 5
        end = index.find(b"\0", cursor)
        if end < 0:
            break
        raw = index[cursor:end]
        name = raw.decode("utf-8", errors="replace").replace("\\", "/")
        cursor = end + 1
        yield PackIndexEntry(name, raw, size, compressed, offset)
        offset += size


def read_pack_payload(path: Path, entry: PackIndexEntry) -> bytes:
    """Read (and decompress when flagged) one packed file's payload."""
    with path.open("rb") as f:
        f.seek(entry.offset)
        payload = f.read(entry.size)
    if (entry.compressed or payload[:4] in (ZSTD_MAGIC, LZ4_MAGIC)
            or payload[4:8] in (ZSTD_MAGIC, LZ4_MAGIC)):
        try:
            payload = _decompress(payload)
        except Exception:
            pass  # keep raw on failure
    return payload


def iter_pack_entries(path: Path, prefixes=()):
    """Yield PackEntry for index entries whose path starts with a prefix."""
    prefixes = tuple(p.casefold() for p in prefixes)
    for e in iter_pack_index(path):
        if prefixes and not any(e.name.casefold().startswith(p)
                                for p in prefixes):
            continue
        yield PackEntry(e.name, read_pack_payload(path, e))


def _decompress(raw: bytes) -> bytes:
    """Decompress a payload that carries a zstd/lz4 frame (maybe at offset 4)
    or CA's LZMA block (u32 dsize + 0x5d props + u32 dict + raw LZMA1)."""
    # CA LZMA: [u32 dsize][0x5d][u32 dict][LZMA1 raw stream]
    if len(raw) >= 13 and raw[4] == 0x5D:
        declared = struct.unpack_from("<I", raw, 0)[0]
        if 0 < declared <= 512 * 1024 * 1024:
            try:
                import lzma
                filt = [{"id": lzma.FILTER_LZMA1,
                         "dict_size": struct.unpack_from("<I", raw, 5)[0],
                         "lc": 3, "lp": 0, "pb": 2}]
                out = lzma.LZMADecompressor(
                    lzma.FORMAT_RAW, filters=filt).decompress(raw[9:])
                if len(out) == declared:
                    return out
            except Exception:
                pass
    offsets = []
    for off in (0, 4):
        if raw[off : off + 4] in (ZSTD_MAGIC, LZ4_MAGIC):
            offsets.append(off)
    if not offsets:
        m = min(32, len(raw) - 4)
        for i in range(m + 1):
            if raw[i : i + 4] in (ZSTD_MAGIC, LZ4_MAGIC):
                offsets.append(i)
    for off in offsets:
        magic = raw[off : off + 4]
        if magic == ZSTD_MAGIC and zstandard is not None:
            dctx = zstandard.ZstdDecompressor()
            declared = struct.unpack_from("<I", raw, off - 4)[0] if off >= 4 else 0
            try:
                if 0 < declared <= 512 * 1024 * 1024:
                    return dctx.decompress(raw[off:], max_output_size=declared)
                return dctx.stream_reader(io.BytesIO(raw[off:])).read(512 * 1024 * 1024)
            except zstandard.ZstdError:
                pass
        if magic == LZ4_MAGIC and lz4 is not None:
            try:
                return lz4.frame.decompress(raw[off:])
            except Exception:
                pass
        for wbits in (-zlib.MAX_WBITS, zlib.MAX_WBITS):
            try:
                return zlib.decompress(raw[off:], wbits)
            except zlib.error:
                pass
    raise ValueError("unknown compression")


# ------------------------------------------------------------ schema parse

def load_schema(ron_path: Path) -> dict[str, dict[int, list[tuple[str, str]]]]:
    """Parse schema_wh3.ron -> {table: {version: [(field_name, field_type)]}}.

    Field order is the definition order (binary order), not ca_order.
    """
    text = ron_path.read_text(encoding="utf-8")
    tables: dict[str, dict[int, list[tuple[str, str]]]] = {}
    # Table blocks start at 8-space indent: "name": [
    table_re = re.compile(r'(?m)^ {8}"([^"]+)": \[')
    matches = list(table_re.finditer(text))
    field_re = re.compile(
        r'name: "((?:[^"\\]|\\.)*)",\s*field_type: (\w+),'
    )
    for i, m in enumerate(matches):
        block = text[m.end() : matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        versions: dict[int, list[tuple[str, str]]] = {}
        for vm in re.finditer(r"version: (\d+),\s*fields: \[", block):
            vstart = vm.end()
            # fields list ends at "],\n ... localised_fields"
            vend = block.find("localised_fields", vstart)
            segment = block[vstart:vend]
            versions[int(vm.group(1))] = field_re.findall(segment)
        tables[m.group(1)] = versions
    return tables


# ------------------------------------------------------------- db decode

def _read_str8(raw: bytes, p: int):
    ln = struct.unpack_from("<H", raw, p)[0]
    p += 2
    b = raw[p : p + ln]
    try:
        s = b.decode("utf-8")
    except UnicodeDecodeError:
        s = b.decode("latin-1")
    return s, p + ln


def _read_str16(raw: bytes, p: int):
    ln = struct.unpack_from("<H", raw, p)[0]
    p += 2
    return raw[p : p + ln * 2].decode("utf-16le", "replace"), p + ln * 2


def _read_field(raw: bytes, p: int, ftype: str):
    if ftype == "Boolean":
        v = raw[p]
        if v not in (0, 1):
            raise ValueError("bad bool")
        return ("true" if v else "false"), p + 1
    if ftype in ("I32", "ColourRGB", "ColourU32"):
        return str(struct.unpack_from("<i", raw, p)[0]), p + 4
    if ftype == "I16":
        return str(struct.unpack_from("<h", raw, p)[0]), p + 2
    if ftype == "I64":
        return str(struct.unpack_from("<q", raw, p)[0]), p + 8
    if ftype == "I24":
        v = int.from_bytes(raw[p : p + 3], "little", signed=True)
        return str(v), p + 3
    if ftype == "F32":
        return repr(struct.unpack_from("<f", raw, p)[0]), p + 4
    if ftype == "F64":
        return repr(struct.unpack_from("<d", raw, p)[0]), p + 8
    if ftype == "StringU8":
        return _read_str8(raw, p)
    if ftype == "StringU16":
        return _read_str16(raw, p)
    if ftype == "OptionalStringU8":
        flag = raw[p]
        if flag == 0:
            return "", p + 1
        if flag != 1:
            raise ValueError("bad opt flag")
        return _read_str8(raw, p + 1)
    if ftype == "OptionalStringU16":
        flag = raw[p]
        if flag == 0:
            return "", p + 1
        if flag != 1:
            raise ValueError("bad opt flag")
        return _read_str16(raw, p + 1)
    raise ValueError(f"unsupported type {ftype}")


def decode_db_table(table: str, payload: bytes, schemas):
    """Return (version, field_names, rows[list[list[str]]]) or raise."""
    p = 0
    version = None
    while p + 4 <= len(payload):
        marker = payload[p : p + 4]
        if marker == b"\xfd\xfe\xfc\xff":
            p += 4
            ln = struct.unpack_from("<H", payload, p)[0]
            p += 2 + ln * 2
        elif marker == b"\xfc\xfd\xfe\xff":
            p += 4
            version = struct.unpack_from("<i", payload, p)[0]
            p += 4
        else:
            break
    # mystery byte + row count
    if p + 5 > len(payload):
        raise ValueError("no row header")
    data_start = p + 1
    count = struct.unpack_from("<i", payload, data_start)[0]
    data_start += 4
    if count < 0 or count > 10_000_000:
        raise ValueError("bad row count")

    candidates = []
    if version is not None and version in schemas:
        candidates.append(version)
    candidates += [v for v in schemas if v not in candidates]

    for ver in candidates:
        fields = schemas[ver]
        try:
            q = data_start
            rows = []
            for _ in range(count):
                row = []
                for _name, ftype in fields:
                    val, q = _read_field(payload, q, ftype)
                    row.append(val)
                rows.append(row)
            if q != len(payload):
                continue
            return ver, [n for n, _ in fields], rows
        except (ValueError, IndexError, struct.error):
            continue
    raise ValueError(f"no schema version fits (header version={version})")


def write_db_tsv(out: Path, table: str, internal: str, version: int,
                 fields: list[str], rows: list[list[str]]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8-sig", newline="") as f:
        f.write("\t".join(fields) + "\n")
        meta = f"#{table};{version};db/{table}/{internal}"
        f.write(meta + "\t" * (len(fields) - 1) + "\n")
        for row in rows:
            f.write("\t".join(row) + "\n")


# ------------------------------------------------------------ loc decode

def parse_loc(payload: bytes):
    """Yield (key, text, tooltip) rows from a .loc payload."""
    if len(payload) < 14 or payload[:2] != b"\xff\xfe" or payload[2:6] != LOC_MAGIC:
        raise ValueError("not a loc file")
    count = struct.unpack_from("<i", payload, 10)[0]
    p = 14
    rows = []
    for _ in range(count):
        klen = struct.unpack_from("<H", payload, p)[0]; p += 2
        key = payload[p : p + klen * 2].decode("utf-16le", "replace"); p += klen * 2
        tlen = struct.unpack_from("<H", payload, p)[0]; p += 2
        text = payload[p : p + tlen * 2].decode("utf-16le", "replace"); p += tlen * 2
        tooltip = payload[p]; p += 1
        rows.append((key, text, tooltip))
    return rows


def _esc(s: str) -> str:
    return s.replace("\t", " ").replace("\r", " ").replace("\n", "\\n")


def write_loc_tsv(out: Path, rows) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8-sig", newline="") as f:
        f.write("key\ttext\ttooltip\n")
        for key, text, tooltip in rows:
            f.write(f"{_esc(key)}\t{_esc(text)}\t{tooltip}\n")


# ------------------------------------------------------------------ main

def ca_packs() -> list[Path]:
    return sorted(
        p for p in GAME_DATA.glob("*.pack") if CA_PACK_RE.match(p.name)
    )


def main() -> None:
    t0 = time.time()
    gamedata = WORKSPACE / "gamedata"
    bilingual = WORKSPACE / "bilingual"
    schemas = load_schema(SCHEMA_RON)
    print(f"schema tables: {len(schemas)}", flush=True)

    packs = ca_packs()
    report = {"db_ok": 0, "db_raw": [], "script": 0, "ui": 0, "loc_errors": []}
    db_seen: set[str] = set()

    for pack in packs:
        if not GAMEDATA_PACK_RE.match(pack.name):
            continue
        for entry in iter_pack_entries(pack, ("db/", "script/", "ui/")):
            name = entry.name
            if name.startswith("db/"):
                parts = name.split("/")
                if len(parts) < 3 or not parts[-1]:
                    continue
                table = parts[1]
                internal = parts[-1]
                out = gamedata / "db" / table / (internal + ".tsv")
                if name in db_seen:
                    continue
                db_seen.add(name)
                try:
                    ver, fields, rows = decode_db_table(table, entry.payload, schemas.get(table, {}))
                    write_db_tsv(out, table, internal, ver, fields, rows)
                    report["db_ok"] += 1
                except Exception as exc:
                    raw_out = gamedata / "db" / table / (internal + ".raw")
                    raw_out.parent.mkdir(parents=True, exist_ok=True)
                    raw_out.write_bytes(entry.payload)
                    report["db_raw"].append(f"{name} ({pack.name}): {exc}")
            elif name.startswith("script/"):
                out = gamedata / name
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(entry.payload)
                report["script"] += 1
            elif name.startswith("ui/"):
                if Path(name).suffix.casefold() not in UI_TEXT_EXT:
                    continue
                out = gamedata / name
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(entry.payload)
                report["ui"] += 1

    # ------------------------------------------------------- localisation
    loc_targets = {
        "EN": ["local_en.pack"],
        "CN": ["local_cn.pack", "local_zh.pack"],
    }
    merged_cn = []
    for lang, pack_names in loc_targets.items():
        for pack_name in pack_names:
            pack = GAME_DATA / pack_name
            if not pack.exists():
                continue
            for entry in iter_pack_entries(pack, ("text/",)):
                if not entry.name.casefold().endswith(".loc"):
                    continue
                rel = Path(entry.name).name  # loc file name
                try:
                    rows = parse_loc(entry.payload)
                except Exception as exc:
                    report["loc_errors"].append(f"{entry.name} ({pack_name}): {exc}")
                    continue
                write_loc_tsv(bilingual / lang / (rel + ".tsv"), rows)
                if lang == "CN":
                    merged_cn.extend(rows)

    merged_path = bilingual / "localisation__.loc_CN.tsv"
    seen = set()
    with merged_path.open("w", encoding="utf-8-sig", newline="") as f:
        f.write("key\ttext\ttooltip\n")
        for key, text, tooltip in merged_cn:
            if key in seen:
                continue
            seen.add(key)
            f.write(f"{_esc(key)}\t{_esc(text)}\t{tooltip}\n")

    print(f"db tables decoded: {report['db_ok']}")
    print(f"script files:      {report['script']}")
    print(f"ui text files:     {report['ui']}")
    print(f"merged CN loc rows:{len(seen)}")
    print(f"db undecoded:      {len(report['db_raw'])}")
    for line in report["db_raw"][:40]:
        print("  RAW:", line)
    for line in report["loc_errors"][:20]:
        print("  LOCERR:", line)
    print(f"done in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    sys.exit(main())
