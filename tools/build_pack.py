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

import re
import struct
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(r"E:\Code\WH3-modding")
PACK_PATH_OVERRIDES = {
    "zzz_psw_merged": {
        "script/campaign/mod/psw_01_global_vars.lua": "script/campaign/mod/psw_全局变量总表.lua",
        "script/campaign/mod/psw_02_tianfu.lua": "script/campaign/mod/psw_天赋.lua",
        "script/campaign/mod/psw_03_tianfu_xiaoguo.lua": "script/campaign/mod/psw_天赋效果.lua",
    },
}
SCHEMA_DIR = Path.home() / "AppData" / "Roaming" / "FrodoWazEre" / "rpfm" / "config" / "schemas"
SCHEMA_PATHS = sorted(SCHEMA_DIR.glob("schema_*.ron"))

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
    if field_type == "I32":
        return struct.pack("<i", int(float(value or 0)))
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


# ------------------------------------------------------------- pack
def pack_reserved_files():
    notes = b'{\n  "pack_notes": "",\n  "file_notes": {}\n}'
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
        "dependencies_manager_v2.rpfm_reserved": b"[]",
        "notes.rpfm_reserved": notes,
        "settings.rpfm_reserved": settings.encode("utf-8"),
    }


def build(mod_name: str, out_path: Path | None = None):
    mod_root = ROOT / "mod_files" / mod_name
    if out_path is None:
        out_path = ROOT / "mod_output" / f"{mod_name}.pack"
    schema = Schema()
    files: dict[str, bytes] = {}

    for path in sorted((mod_root / "db").glob("*/*.tsv")):
        table, version, internal_path, rows = read_db_tsv(path)
        files[internal_path] = encode_db(table, version, rows, schema)
        print(f"db {internal_path}: {len(rows)} rows")

    for path in sorted((mod_root / "text").rglob("*.loc.tsv")):
        internal_path, rows = read_loc_tsv(path)
        files[internal_path] = encode_loc(rows)
        print(f"loc {internal_path}: {len(rows)} rows")

    for path in sorted((mod_root / "text").rglob("*.loc")):
        internal = path.relative_to(mod_root).as_posix().replace("/", "\\")
        files[internal] = path.read_bytes()
        print(f"file {internal}: {path.stat().st_size} bytes")

    for top in sorted(p for p in mod_root.iterdir() if p.is_dir() and p.name not in ("db", "text")):
        base = mod_root / top.name
        for path in sorted(base.rglob("*")):
            if path.is_file():
                internal = path.relative_to(mod_root).as_posix()
                internal = PACK_PATH_OVERRIDES.get(mod_name, {}).get(internal, internal)
                internal = internal.replace("/", "\\")
                files[internal] = path.read_bytes()
                print(f"file {internal}: {path.stat().st_size} bytes")

    files.update(pack_reserved_files())

    entries = sorted(files.items(), key=lambda item: item[0])
    index = bytearray()
    data = bytearray()
    for path, content in entries:
        index += struct.pack("<I", len(content))
        index += b"\x00"
        index += path.encode("utf-8")
        index += b"\x00"
        data += content

    header = bytearray()
    header += b"PFH5"
    header += struct.pack("<I", 3)
    header += b"\x00" * 8
    header += struct.pack("<I", len(entries))
    header += struct.pack("<I", len(index))
    header += struct.pack("<I", int(time.time()))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(bytes(header + index + data))

    # validate
    blob = out_path.read_bytes()
    assert blob[:4] == b"PFH5"
    count = struct.unpack_from("<I", blob, 0x10)[0]
    assert count == len(entries), (count, len(entries))
    print(f"Wrote {out_path} ({len(blob)} bytes, {count} files)")


if __name__ == "__main__":
    mod = sys.argv[1]
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    build(mod, out)
