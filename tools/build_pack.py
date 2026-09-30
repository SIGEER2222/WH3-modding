# -*- coding: utf-8 -*-
"""Build a WH3 .pack from a mod_files/<mod>/ source directory.

Usage: python tools/build_pack.py <mod_name> [output.pack]

Sources under mod_files/<mod_name>/:
- db/<table>/*.tsv          -> encoded DB tables (path from TSV metadata row)
- text/**/*.loc.tsv         -> encoded binary .loc (path = same, minus .tsv)
- script/**, ui/**, etc.    -> copied verbatim preserving relative path

Output: mod_output/<mod_name>.pack (PFH5, uncompressed).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import struct
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK_PATH_OVERRIDES = {
    "zzz_psw_merged": {
        "script/campaign/mod/psw_01_global_vars.lua": "script/campaign/mod/psw_全局变量总表.lua",
        "script/campaign/mod/psw_02_tianfu.lua": "script/campaign/mod/psw_天赋.lua",
        "script/campaign/mod/psw_03_tianfu_xiaoguo.lua": "script/campaign/mod/psw_天赋效果.lua",
    },
}
def _schema_paths() -> list[Path]:
    sub = Path("AppData/Roaming/FrodoWazEre/rpfm/config/schemas")
    dirs = [Path.home() / sub]
    # WSL: Path.home() is the Linux home; also scan Windows profiles under /mnt/?/Users.
    for mnt in Path("/mnt").glob("*/Users/*/"):
        dirs.append(mnt / sub)
    paths = []
    for d in dirs:
        try:
            paths.extend(d.glob("schema_*.ron"))
        except (PermissionError, OSError):
            continue
    paths = sorted(paths)
    # Repo-pinned latest schema wins per-version conflicts (Schema merges all
    # texts; later files overwrite earlier definitions for the same version).
    pinned = Path(__file__).resolve().parent / "_dl" / "schema_wh3.ron"
    if pinned.exists():
        paths = [p for p in paths if p.name != pinned.name] + [pinned]
    return paths


SCHEMA_PATHS = _schema_paths()

# Hard-coded schema for land_units_tables v54, discovered by parsing vanilla db.pack.
LAND_UNITS_TABLES_V54_FIELDS = [
    ("accuracy", "I32"),
    ("armour", "StringU8"),
    ("campaign_action_points", "I32"),
    ("category", "StringU8"),
    ("charge_bonus", "I32"),
    ("class", "StringU8"),
    ("historical_description_text", "StringU8"),
    ("key", "StringU8"),
    ("man_animation", "OptionalStringU8"),
    ("man_entity", "StringU8"),
    ("melee_attack", "I32"),
    ("melee_defence", "I32"),
    ("morale", "I32"),
    ("bonus_hit_points", "I32"),
    ("mount", "OptionalStringU8"),
    ("num_mounts", "I32"),
    ("primary_melee_weapon", "StringU8"),
    ("primary_missile_weapon", "OptionalStringU8"),
    ("rank_depth", "I32"),
    ("shield", "StringU8"),
    ("short_description_text", "StringU8"),
    ("spacing", "StringU8"),
    ("training_level", "StringU8"),
    ("articulated_record", "OptionalStringU8"),
    ("engine", "OptionalStringU8"),
    ("is_male", "Boolean"),
    ("visibility_spotting_range_min", "F32"),
    ("visibility_spotting_range_max", "F32"),
    ("attribute_group", "OptionalStringU8"),
    ("spot_dist_tree", "I32"),
    ("spot_dist_scrub", "I32"),
    ("reload", "I32"),
    ("selection_vo", "StringU8"),
    ("selected_vo_secondary", "StringU8"),
    ("selected_vo_tertiary", "StringU8"),
    ("hiding_scalar", "F32"),
    ("ground_stat_effect_group", "OptionalStringU8"),
    ("secondary_ammo", "I32"),
    ("primary_ammo", "I32"),
    ("damage_mod_flame", "I32"),
    ("damage_mod_magic", "I32"),
    ("num_engines", "I32"),
    ("damage_mod_physical", "I32"),
    ("damage_mod_missile", "I32"),
    ("damage_mod_all", "I32"),
    ("ai_usage_group", "StringU8"),
    ("can_skirmish", "Boolean"),
    ("can_brace", "Boolean"),
    ("mounted_draughts", "Boolean"),
    ("sync_locomotion", "Boolean"),
    ("capture_tier", "StringU8"),
    ("key_building_capture_tier", "StringU8"),
    ("score_capture_tier", "StringU8"),
    ("harmony_amplification_type", "OptionalStringU8"),
    ("first_person", "OptionalStringU8"),
    ("ar_unit_category", "OptionalStringU8"),
    ("healing_power", "F32"),
    ("spell_mastery", "F32"),
    ("infinite_secondary_ammo", "Boolean"),
    ("default_guard_mode", "Boolean"),
]


# ------------------------------------------------------------- schema parse
def find_matching(text: str, start: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    in_string = False
    escape = False
    for idx in range(start, len(text)):
        char = text[idx]
        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
        else:
            if char == '"':
                in_string = True
            elif char == open_ch:
                depth += 1
            elif char == close_ch:
                depth -= 1
                if depth == 0:
                    return idx
    raise ValueError("No matching bracket")


def top_level_tuples(block: str) -> list[str]:
    tuples = []
    idx = 0
    while idx < len(block):
        if block[idx] == '"':
            idx += 1
            while idx < len(block):
                if block[idx] == "\\":
                    idx += 2
                elif block[idx] == '"':
                    idx += 1
                    break
                else:
                    idx += 1
        elif block[idx] == "(":
            end = find_matching(block, idx, "(", ")")
            tuples.append(block[idx : end + 1])
            idx = end + 1
        else:
            idx += 1
    return tuples


class Schema:
    def __init__(self, paths: list[Path] | None = None):
        import os
        env = os.environ.get("RPFM_SCHEMA_WH3")
        if env:
            paths = [Path(env)]
        if paths is None:
            paths = SCHEMA_PATHS
        self.texts = [p.read_text(encoding="utf-8") for p in paths]
        self.cache: dict[tuple[str, int], list[tuple[str, str]]] = {}

    def table_blocks(self, table: str) -> list[str]:
        blocks = []
        for text in self.texts:
            marker = f'"{table}": ['
            if marker in text:
                start = text.index(marker)
                open_idx = text.index("[", start)
                close_idx = find_matching(text, open_idx, "[", "]")
                blocks.append(text[open_idx + 1 : close_idx])
        return blocks

    def _parse_fields(self, table_version: str) -> list[tuple[str, str]]:
        fields_open = table_version.index("fields: [")
        list_open = table_version.index("[", fields_open)
        list_close = find_matching(table_version, list_open, "[", "]")
        fields = []
        for field in top_level_tuples(table_version[list_open + 1 : list_close]):
            name = re.search(r'name:\s*"([^"]+)"', field).group(1)
            field_type = re.search(r"field_type:\s*([A-Za-z0-9_]+)", field).group(1)
            fields.append((name, field_type))
        return fields

    def fields(self, table: str, version: int) -> list[tuple[str, str]]:
        key = (table, version)
        if key in self.cache:
            return self.cache[key]

        blocks = self.table_blocks(table)
        if not blocks:
            raise KeyError(f"Schema definition not found for {table} v{version}")

        # Find exact version, or the closest lower version, or the highest version.
        candidates = {}
        for block in blocks:
            for table_version in top_level_tuples(block):
                version_match = re.search(r"version:\s*(\d+)", table_version)
                if not version_match:
                    continue
                v = int(version_match.group(1))
                candidates[v] = self._parse_fields(table_version)

        if version in candidates:
            fields = candidates[version]
        else:
            lower = [v for v in candidates if v <= version]
            if lower:
                chosen = max(lower)
            else:
                chosen = max(candidates)
            print(f"[warn] schema for {table} v{version} not found, using v{chosen}")
            fields = candidates[chosen]
        self.cache[key] = fields
        return fields


# ------------------------------------------------------------- db encode
def encode_string(value: str) -> bytes:
    data = value.encode("utf-8")
    return struct.pack("<H", len(data)) + data


def encode_value(value: str, field_type: str) -> bytes:
    value = "" if value is None else str(value)
    if field_type == "StringU8":
        return encode_string(value)
    if field_type == "OptionalStringU8":
        return b"\x00" if value == "" else b"\x01" + encode_string(value)
    if field_type == "Boolean":
        return b"\x01" if value.lower() == "true" else b"\x00"
    if field_type in ("I32", "ColourRGB", "ColourU32"):
        return struct.pack("<i", int(float(value or 0)))
    if field_type == "I16":
        return struct.pack("<h", int(float(value or 0)))
    if field_type == "I24":
        return int(float(value or 0)).to_bytes(3, "little", signed=True)
    if field_type == "I64":
        return struct.pack("<q", int(float(value or 0)))
    if field_type == "F32":
        return struct.pack("<f", float(value or 0))
    if field_type == "F64":
        return struct.pack("<d", float(value or 0))
    raise NotImplementedError(f"Unsupported schema field type: {field_type}")


def read_db_tsv(path: Path):
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    header = lines[0].split("\t")
    meta = lines[1].split("\t")[0]
    table, version, internal_path = meta[1:].split(";", 2)
    rows = []
    for line in lines[2:]:
        if not line:
            continue
        rows.append(dict(zip(header, line.split("\t"))))
    return table, int(version), internal_path.replace("/", "\\"), rows


def encode_db(table: str, version: int, rows: list[dict[str, str]], schema: Schema) -> bytes:
    table_uuid = str(uuid.uuid4())
    output = b"\xfd\xfe\xfc\xff"
    output += struct.pack("<H", len(table_uuid))
    output += table_uuid.encode("utf-16le")
    if version == 0:
        # Version 0 DB tables omit the separator; the flag byte is still 0x01
        # (verified against vanilla db.pack / RPFM packs — writing 0 here crashes the game).
        output += b"\x01"
        output += struct.pack("<I", len(rows))
    else:
        output += b"\xfc\xfd\xfe\xff"
        output += struct.pack("<I", version)
        output += b"\x01"
        output += struct.pack("<I", len(rows))
    for row in rows:
        for name, field_type in schema.fields(table, version):
            output += encode_value(row.get(name, ""), field_type)
    return output


# ------------------------------------------------------------- loc encode
def read_loc_tsv(path: Path):
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    meta = lines[1].split("\t")[0]
    _, _, internal_path = meta[1:].split(";", 2)
    rows = []
    for line in lines[2:]:
        if not line:
            continue
        parts = line.split("\t")
        key, text = parts[0], parts[1] if len(parts) > 1 else ""
        tooltip = parts[2] if len(parts) > 2 else "0"
        rows.append((key, text.replace("\\n", "\n"), tooltip))
    return internal_path.replace("/", "\\"), rows


def encode_loc(rows) -> bytes:
    out = bytearray()
    out += b"\xff\xfeLOC\x00"
    out += struct.pack("<i", 1)
    out += struct.pack("<i", len(rows))
    for key, text, tooltip in rows:
        k = key.encode("utf-16le")
        out += struct.pack("<H", len(key)) + k
        t = text.encode("utf-16le")
        out += struct.pack("<H", len(text)) + t
        out += b"\x01" if str(tooltip).strip() in ("1", "true") else b"\x00"
    return bytes(out)


# ------------------------------------------------------------- loc completeness gate
# 单位 MOD 必须为每个新增单位提供完整说明（名称 + 短描述 + 长背景描述），
# 技能同理。缺 key 或描述是占位符（与单位名相同/过短）时直接拒绝打包。
MIN_HISTORICAL_LEN = 40  # 低于此长度视为存根（原版单位背景通常是整段文字）
VANILLA_DB = Path(__file__).resolve().parent.parent / "gamedata" / "db"


def _vanilla_keys(table: str, col: str) -> set[str]:
    """原版已存在的主键集合。沿用 vanilla 键的 overwrite 行由原版 loc 兜底，
    gate 只卡真正新增的键；gamedata 缺失时返回空集（退化为全量检查）。"""
    tsv = VANILLA_DB / table / "data__.tsv"
    keys: set[str] = set()
    if not tsv.is_file():
        return keys
    with tsv.open(encoding="utf-8-sig", errors="replace") as f:
        header = f.readline().rstrip("\n").split("\t")
        f.readline()  # #table;version;path 元数据行
        try:
            idx = header.index(col)
        except ValueError:
            return keys
        for line in f:
            cells = line.split("\t")
            if len(cells) > idx and cells[idx].strip():
                keys.add(cells[idx].strip())
    return keys


def check_unit_loc_coverage(db_rows: dict, loc_keys: dict, mod_name: str) -> None:
    unit_keys = [r.get("unit", "").strip() for r in db_rows.get("main_units_tables", [])]
    unit_keys = [k for k in unit_keys if k]
    ability_keys = [r.get("key", "").strip() for r in db_rows.get("unit_abilities_tables", [])]
    ability_keys = [k for k in ability_keys if k]
    vanilla_u = _vanilla_keys("main_units_tables", "unit")
    vanilla_a = _vanilla_keys("unit_abilities_tables", "key")
    unit_keys = [k for k in unit_keys if k not in vanilla_u]
    ability_keys = [k for k in ability_keys if k not in vanilla_a]
    if not unit_keys and not ability_keys:
        return

    problems: list[str] = []
    for key in unit_keys:
        for prefix in (
            f"units_onscreen_name_{key}",
            f"land_units_onscreen_name_{key}",
            f"unit_description_short_texts_text_{key}",
            f"unit_description_historical_texts_text_{key}",
        ):
            if prefix not in loc_keys or not loc_keys[prefix].strip():
                problems.append(f"缺少/为空: {prefix}")
        hist = loc_keys.get(f"unit_description_historical_texts_text_{key}", "").strip()
        short = loc_keys.get(f"unit_description_short_texts_text_{key}", "").strip()
        name = loc_keys.get(f"units_onscreen_name_{key}", "").strip()
        if hist and len(hist) < MIN_HISTORICAL_LEN:
            problems.append(
                f"背景描述过短({len(hist)}字<{MIN_HISTORICAL_LEN}): unit_description_historical_texts_text_{key}"
            )
        if short and name and short == name:
            problems.append(f"短描述是占位符(等于单位名): unit_description_short_texts_text_{key}")
        if hist and name and hist == name:
            problems.append(f"背景描述是占位符(等于单位名): unit_description_historical_texts_text_{key}")
    for key in ability_keys:
        for prefix in (
            f"unit_abilities_onscreen_name_{key}",
            f"unit_abilities_tooltip_text_{key}",
        ):
            if prefix not in loc_keys or not loc_keys[prefix].strip():
                problems.append(f"缺少/为空: {prefix}")

    if problems:
        listing = "\n".join("  - " + p for p in problems)
        sys.exit(
            f"error: {mod_name} 的单位/技能缺少完整说明 loc，已拒绝打包:\n{listing}\n"
            "每个新增单位必须有: units_onscreen_name_*、land_units_onscreen_name_*、\n"
            f"unit_description_short_texts_text_*、unit_description_historical_texts_text_* (>= {MIN_HISTORICAL_LEN} 字);\n"
            "每个新增技能必须有: unit_abilities_onscreen_name_*、unit_abilities_tooltip_text_*。"
        )


# ------------------------------------------------------------- pack
def pack_dependencies(mod_root: Path) -> list[str]:
    dep_file = mod_root / "notes" / "dependencies.txt"
    if not dep_file.is_file():
        return []
    deps: list[str] = []
    for raw_line in dep_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        deps.append(line)
    return deps


def pack_reserved_files(pack_notes: str = "", dependencies: list[str] | None = None):
    notes = (
        '{\n  "pack_notes": ' + json.dumps(pack_notes) + ',\n  "file_notes": {}\n}'
    ).encode("utf-8")
    deps = json.dumps(
        [[True, dep] for dep in (dependencies or [])],
        ensure_ascii=False,
        indent=2,
    ).encode("utf-8")
    settings = (
        '{\n'
        '  "settings_text": {\n'
        '    "diagnostics_files_to_ignore": "",\n'
        '    "import_files_to_ignore": ""\n'
        "  },\n"
        '  "settings_string": {\n'
        '    "compression_format": "None"\n'
        "  },\n"
        '  "settings_bool": {\n'
        '    "disable_autosaves": false,\n'
        '    "do_not_generate_existing_locs": false\n'
        "  },\n"
        '  "settings_number": {}\n'
        "}"
    )
    return {
        "dependencies_manager_v2.rpfm_reserved": deps,
        "notes.rpfm_reserved": notes,
        "settings.rpfm_reserved": settings.encode("utf-8"),
    }


def read_src_bytes(path: Path) -> bytes:
    """Read a source file, transparently unwrapping CA pack-compressed blobs.

    Some asset exports dump the raw pack entry bytes: [u32 decompressed_size]
    followed by a zstd frame (magic 28 B5 2F FD). We store entries
    uncompressed, so feeding such a blob through raw makes the game parse
    compressed bytes as the real format -> garbage header fields -> giant
    allocations (observed 22-38GB commit spikes -> bad_alloc crash).
    Unwrap in memory and self-heal the source file.
    """
    data = path.read_bytes()
    if len(data) >= 8 and data[4:8] == b"\x28\xb5\x2f\xfd":
        import zstandard as zstd
        dec = zstd.ZstdDecompressor().decompress(data[4:], max_output_size=256_000_000)
        if int.from_bytes(data[:4], "little") == len(dec):
            path.write_bytes(dec)
            print(f"  !! unwrapped zstd-container source {path.name}: {len(data)} -> {len(dec)}B")
            return dec
        print(f"  warning: {path} looks zstd-packed but size header mismatches; packed raw")
    return data


def build(mod_name: str, out_path: Path | None = None):
    mod_root = ROOT / "mod_files" / mod_name
    if out_path is None:
        out_path = ROOT / "mod_output" / f"{mod_name}.pack"
    schema = Schema()
    files: dict[str, bytes] = {}
    db_rows: dict[str, list[dict[str, str]]] = {}

    for path in sorted((mod_root / "db").glob("*/*.tsv")):
        table, version, internal_path, rows = read_db_tsv(path)
        files[internal_path] = encode_db(table, version, rows, schema)
        db_rows.setdefault(table, []).extend(rows)
        print(f"db {internal_path}: {len(rows)} rows")

    loc_keys: dict[str, str] = {}
    for path in sorted((mod_root / "text").rglob("*.loc.tsv")):
        internal_path, rows = read_loc_tsv(path)
        files[internal_path] = encode_loc(rows)
        for k, text, _tooltip in rows:
            loc_keys[k] = text
        print(f"loc {internal_path}: {len(rows)} rows")

    check_unit_loc_coverage(db_rows, loc_keys, mod_name)

    for path in sorted((mod_root / "text").rglob("*.loc")):
        internal = path.relative_to(mod_root).as_posix().replace("/", "\\")
        files[internal] = path.read_bytes()
        print(f"file {internal}: {path.stat().st_size} bytes")

    for top in sorted(p for p in mod_root.iterdir() if p.is_dir() and p.name not in ("db", "text", "notes")):
        base = mod_root / top.name
        for path in sorted(base.rglob("*")):
            if path.is_file():
                internal = path.relative_to(mod_root).as_posix()
                internal = PACK_PATH_OVERRIDES.get(mod_name, {}).get(internal, internal)
                internal = internal.replace("/", "\\")
                files[internal] = read_src_bytes(path)
                print(f"file {internal}: {path.stat().st_size} bytes")

    notes_path = mod_root / "notes" / "pack_notes.txt"
    pack_notes = notes_path.read_text(encoding="utf-8").strip() if notes_path.is_file() else ""
    if not pack_notes:
        sys.exit(
            "error: mod_files/%s/notes/pack_notes.txt missing or empty; "
            "every mod must carry a description (goes into pack notes.rpfm_reserved "
            "and Mod Manager user_mod_data)" % mod_name
        )
    print(f"notes: {pack_notes[:60]}...")
    dependencies = pack_dependencies(mod_root)
    if dependencies:
        print(f"dependencies: {', '.join(dependencies)}")
    files.update(pack_reserved_files(pack_notes, dependencies))

    entries = sorted(files.items(), key=lambda item: item[0])
    index = bytearray()
    data = bytearray()
    for path, content in entries:
        index += struct.pack("<I", len(content))
        index += b"\x00"
        index += path.encode("utf-8")
        index += b"\x00"
        data += content

    dep_block = b"".join(dep.encode("utf-8") + b"\x00" for dep in dependencies)
    header = bytearray()
    header += b"PFH5"
    header += struct.pack("<I", 3)
    header += struct.pack("<I", len(dependencies))
    header += struct.pack("<I", len(dep_block))
    header += struct.pack("<I", len(entries))
    header += struct.pack("<I", len(index))
    header += struct.pack("<I", int(time.time()))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(bytes(header + dep_block + index + data))

    # validate
    blob = out_path.read_bytes()
    assert blob[:4] == b"PFH5"
    count = struct.unpack_from("<I", blob, 0x10)[0]
    assert count == len(entries), (count, len(entries))
    print(f"Wrote {out_path} ({len(blob)} bytes, {count} files)")

    preview = mod_root / "preview.png"
    if preview.is_file():
        png_out = out_path.with_suffix(".png")
        shutil.copy2(preview, png_out)
        print(f"preview -> {png_out}")
    else:
        print("warning: no preview.png in mod_files/" + mod_name)


# ------------------------------------------------------------- deploy
GAME_DATA_DIR = Path(
    r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data"
)
STATE_DB = Path(os.environ.get("APPDATA", "")) / "WycccModManager" / "state.db"
PLAYSET_KEY = "current_playset_id:warhammer3"
ENABLED_ORDER_KEY = "enabled_order:warhammer3"


def local_mod_id(pack_path: Path) -> str:
    canonical = str(pack_path.resolve()).replace("\\", "/").casefold()
    return "local:data:" + hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:18]


def deploy(mod_name: str, pack_path: Path, alias: str = "",
           deploy_name: str = "", replace_id: str = ""):
    """Deploy pack + preview into game data/, then register in state.db:
    upsert user_mod_data (alias+notes) and add to the current playset.
    Fails outright when the Mod Manager display text is unavailable."""
    mod_root = ROOT / "mod_files" / mod_name
    notes = (mod_root / "notes" / "pack_notes.txt").read_text(
        encoding="utf-8").strip()
    if not alias:
        alias_file = mod_root / "notes" / "alias.txt"
        alias = alias_file.read_text(encoding="utf-8").strip() \
            if alias_file.is_file() else ""
    if not alias:
        sys.exit(
            "error: no alias for %s; write mod_files/%s/notes/alias.txt "
            "(Mod Manager display name) or pass --alias" % (mod_name, mod_name))

    deploy_name = deploy_name or f"{mod_name}.pack"
    dst = GAME_DATA_DIR / deploy_name
    for attempt in range(3):
        try:
            shutil.copy2(pack_path, dst)
            break
        except PermissionError:
            if attempt == 2:
                sys.exit(
                    "error: %s is locked (game running?). "
                    "Close the game, then rerun --deploy." % dst)
            print(f"pack locked, retry {attempt + 1}/3 ...")
            time.sleep(5)
    preview = pack_path.with_suffix(".png")
    if preview.is_file():
        shutil.copy2(preview, dst.with_suffix(".png"))
    print(f"deployed -> {dst}")

    mod_id = local_mod_id(dst)
    shutil.copy2(STATE_DB, str(STATE_DB) + f".bak_deploy_{mod_name}")
    db = sqlite3.connect(STATE_DB)
    now = int(time.time() * 1000)
    db.execute(
        "INSERT INTO user_mod_data(mod_id, alias, notes, updated_at) "
        "VALUES(?, ?, ?, ?) ON CONFLICT(mod_id) DO UPDATE SET "
        "alias=excluded.alias, notes=excluded.notes, updated_at=excluded.updated_at",
        (mod_id, alias, notes, now))
    print(f"user_mod_data <- {mod_id} | {alias}")

    # Optional Mod Manager category: notes/mod_type.txt holds one type id or
    # display name per line (language/ui/unit/feature/overhaul/visual or a
    # custom type name like 补丁). Deploy stamps it into user_mod_data so the
    # manager UI shows the right type without manual tagging.
    type_file = mod_root / "notes" / "mod_type.txt"
    if type_file.is_file():
        wanted = [l.strip() for l in
                  type_file.read_text(encoding="utf-8").splitlines()
                  if l.strip() and not l.strip().startswith("#")]
        if wanted:
            builtin = {"language", "ui", "unit", "feature", "overhaul",
                       "visual", "unknown"}
            name2id = {}
            for row in db.execute(
                    "SELECT id, name FROM custom_mod_types"):
                name2id[row[1].casefold()] = row[0]
            for zh, en in {"语言包": "language", "UI": "ui", "单位": "unit",
                           "功能": "feature", "大修": "overhaul",
                           "美化": "visual", "未知": "unknown"}.items():
                name2id.setdefault(zh.casefold(), en)
            ids = []
            for w in wanted:
                tid = w if w in builtin else name2id.get(w.casefold(), w)
                if tid not in ids:
                    ids.append(tid)
            db.execute(
                "UPDATE user_mod_data SET mod_type=?, mod_types=? "
                "WHERE mod_id=?",
                (ids[0], json.dumps(ids, ensure_ascii=False), mod_id))
            print(f"mod_type <- {ids}")

    playset_id = db.execute(
        "SELECT value FROM app_state WHERE key=?", (PLAYSET_KEY,)).fetchone()[0]
    if replace_id:
        cur = db.execute(
            "UPDATE playset_items SET mod_id=? WHERE playset_id=? AND mod_id=?",
            (mod_id, playset_id, replace_id))
        print(f"playset_items replace {replace_id} -> {mod_id}: {cur.rowcount} row(s)")
        row = db.execute(
            "SELECT value FROM app_state WHERE key=?", (ENABLED_ORDER_KEY,)).fetchone()
        order = json.loads(row[0]) if row else []
        order = [mod_id if x == replace_id else x for x in order]
        if mod_id not in order:
            order.append(mod_id)
        db.execute("UPDATE app_state SET value=? WHERE key=?",
                   (json.dumps(order), ENABLED_ORDER_KEY))
    else:
        exists = db.execute(
            "SELECT position FROM playset_items WHERE playset_id=? AND mod_id=?",
            (playset_id, mod_id)).fetchone()
        if exists:
            print(f"already in playset at pos {exists[0]}")
        else:
            pos = db.execute(
                "SELECT COALESCE(MAX(position)+1, 0) FROM playset_items "
                "WHERE playset_id=?", (playset_id,)).fetchone()[0]
            db.execute(
                "INSERT INTO playset_items(playset_id, mod_id, position) "
                "VALUES(?, ?, ?)", (playset_id, mod_id, pos))
            print(f"playset_items insert at pos {pos}")
        row = db.execute(
            "SELECT value FROM app_state WHERE key=?", (ENABLED_ORDER_KEY,)).fetchone()
        order = json.loads(row[0]) if row else []
        if mod_id not in order:
            order.append(mod_id)
            db.execute("UPDATE app_state SET value=? WHERE key=?",
                       (json.dumps(order), ENABLED_ORDER_KEY))
    db.commit()
    db.close()
    print("state.db updated (backup: .bak_deploy_%s)" % mod_name)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Build a WH3 .pack from mod_files/<mod>/")
    ap.add_argument("mod")
    ap.add_argument("out", nargs="?", help="output .pack path (default mod_output/<mod>.pack)")
    ap.add_argument("--deploy", action="store_true",
                    help="copy to game data/, register in Mod Manager state.db "
                         "(user_mod_data alias+notes + playset)")
    ap.add_argument("--deploy-name", default="",
                    help="deploy under a different pack filename, e.g. <mod>2.pack")
    ap.add_argument("--alias", default="",
                    help="Mod Manager display name (default: notes/alias.txt)")
    ap.add_argument("--replace", default="", metavar="OLD_MOD_ID",
                    help="replace this mod_id in the playset instead of appending")
    args = ap.parse_args()

    out = Path(args.out) if args.out else None
    build(args.mod, out)
    if args.deploy:
        pack = out or ROOT / "mod_output" / f"{args.mod}.pack"
        deploy(args.mod, pack, alias=args.alias,
               deploy_name=args.deploy_name, replace_id=args.replace)
