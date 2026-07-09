from __future__ import annotations

import csv
import re
import struct
import time
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MOD_NAME = "cth_dragon_crossbow_overwrite"
MOD_ROOT = ROOT / "mod_files" / MOD_NAME
OUTPUT_PACK = ROOT / "mod_output" / f"{MOD_NAME}.pack"
SCHEMA_PATH = (
    Path.home()
    / "AppData"
    / "Roaming"
    / "FrodoWazEre"
    / "rpfm"
    / "config"
    / "schemas"
    / "schema_wh3.ron"
)

TARGET_UNIT = "wh3_main_cth_inf_dragon_guard_crossbowmen_0"
DONOR_UNIT = "wh3_dlc24_cth_inf_dragon_guard_crossbowmen_ror"
PEASANT_SPEARS = "wh3_main_cth_inf_peasant_spearmen_1"

NEW_MELEE_WEAPON = "cthdco_cth_dragon_crossbow_ror_melee_x2"
NEW_MISSILE_WEAPON = "cthdco_cth_dragon_crossbow_ror_bolt_x3"
NEW_PROJECTILE = "cthdco_cth_dragon_crossbow_ror_bolt_x3"
NEW_ENTITY = "cthdco_cth_dragon_guard_crossbow_fast_180"
INTERNAL = "!!cthdco_dragon_crossbow_overwrite"


def read_tsv(table: str):
    path = ROOT / "gamedata" / "db" / table / "data__.tsv"
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    header = lines[0].split("\t")
    meta = lines[1].split("\t")[0]
    table_name, version, _ = meta[1:].split(";", 2)
    rows = []
    for line in lines[2:]:
        if not line:
            continue
        values = line.split("\t")
        rows.append(dict(zip(header, values)))
    return header, table_name, int(version), rows


def row_by(rows, column: str, value: str):
    matches = [row for row in rows if row.get(column) == value]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one row for {column}={value}, got {len(matches)}")
    return dict(matches[0])


def fmt_f32(value: float) -> str:
    return f"{value:.4f}"


def write_db_tsv(table: str, header: list[str], version: int, rows: list[dict[str, str]]):
    out_dir = MOD_ROOT / "db" / table
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{INTERNAL}.tsv"
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerow([f"#{table};{version};db/{table}/{INTERNAL}"] + [""] * (len(header) - 1))
        for row in rows:
            writer.writerow([row.get(column, "") for column in header])
    return path


def prepare_sources():
    generated = []

    land_header, land_table, land_version, land_rows = read_tsv("land_units_tables")
    land = row_by(land_rows, "key", TARGET_UNIT)
    donor_land = row_by(land_rows, "key", DONOR_UNIT)
    original_attack = int(land["melee_attack"])
    original_defence = int(land["melee_defence"])
    original_ammo = int(land["primary_ammo"])
    original_bonus_hit_points = int(land["bonus_hit_points"])
    original_healing_power = float(land["healing_power"])
    land.update(
        {
            "armour": "wh2_main_chainmail_110",
            "charge_bonus": "45",
            "man_entity": NEW_ENTITY,
            "melee_attack": str(original_attack + 45),
            "melee_defence": str(original_defence + 45),
            "bonus_hit_points": str(round(original_bonus_hit_points * 1.5)),
            "primary_melee_weapon": NEW_MELEE_WEAPON,
            "primary_missile_weapon": NEW_MISSILE_WEAPON,
            "primary_ammo": str(original_ammo * 3),
            "shield": "wh_missile_block_35_wood",
            "damage_mod_all": "30",
            "can_brace": "true",
            "healing_power": fmt_f32(original_healing_power * 4),
        }
    )
    generated.append(write_db_tsv(land_table, land_header, land_version, [land]))

    main_header, main_table, main_version, main_rows = read_tsv("main_units_tables")
    main = row_by(main_rows, "unit", TARGET_UNIT)
    main.update(
        {
            "create_time": "1",
            "num_men": "120",
            "recruitment_cost": "400",
            "upkeep_cost": "100",
            "melee_cp": "1500.0000",
            "missile_cp": "1500.0000",
        }
    )
    generated.append(write_db_tsv(main_table, main_header, main_version, [main]))

    melee_header, melee_table, melee_version, melee_rows = read_tsv("melee_weapons_tables")
    donor_melee = row_by(melee_rows, "key", donor_land["primary_melee_weapon"])
    donor_melee.update(
        {
            "key": NEW_MELEE_WEAPON,
            "damage": str(int(donor_melee["damage"]) * 2),
            "ap_damage": str(int(donor_melee["ap_damage"]) * 2 + 35),
        }
    )
    generated.append(write_db_tsv(melee_table, melee_header, melee_version, [donor_melee]))

    missile_header, missile_table, missile_version, missile_rows = read_tsv("missile_weapons_tables")
    donor_missile = row_by(missile_rows, "key", donor_land["primary_missile_weapon"])
    donor_projectile_key = donor_missile["default_projectile"]
    donor_missile.update({"key": NEW_MISSILE_WEAPON, "default_projectile": NEW_PROJECTILE})
    generated.append(write_db_tsv(missile_table, missile_header, missile_version, [donor_missile]))

    projectile_header, projectile_table, projectile_version, projectile_rows = read_tsv("projectiles_tables")
    donor_projectile = row_by(projectile_rows, "key", donor_projectile_key)
    donor_projectile.update(
        {
            "key": NEW_PROJECTILE,
            "effective_range": str(int(donor_projectile["effective_range"]) * 2),
            "calibration_distance": fmt_f32(float(donor_projectile["calibration_distance"]) * 2),
            "expiry_range": str(int(donor_projectile["expiry_range"]) * 2),
            "damage": str(int(donor_projectile["damage"]) * 3),
            "ap_damage": str(int(donor_projectile["ap_damage"]) * 3 + 35),
        }
    )
    generated.append(write_db_tsv(projectile_table, projectile_header, projectile_version, [donor_projectile]))

    entity_header, entity_table, entity_version, entity_rows = read_tsv("battle_entities_tables")
    entity = row_by(entity_rows, "key", "wh3_main_cth_dragon_guard_heavy_blood_dismembers")
    entity.update(
        {
            "key": NEW_ENTITY,
            "walk_speed": fmt_f32(float(entity["walk_speed"]) * 2),
            "run_speed": fmt_f32(float(entity["run_speed"]) * 2),
            "charge_speed": fmt_f32(float(entity["charge_speed"]) * 2),
            "hit_points": str(round(int(entity["hit_points"]) * 1.5)),
            "fire_arc_close": "180.0000",
        }
    )
    generated.append(write_db_tsv(entity_table, entity_header, entity_version, [entity]))

    attr_header, attr_table, attr_version, _ = read_tsv("unit_attributes_to_groups_junctions_tables")
    attr_rows = [
        {"attribute": "guerrilla_deploy", "attribute_group": TARGET_UNIT},
        {"attribute": "unbreakable", "attribute_group": TARGET_UNIT},
        {"attribute": "charge_defense", "attribute_group": TARGET_UNIT},
    ]
    generated.append(write_db_tsv(attr_table, attr_header, attr_version, attr_rows))

    ability_header, ability_table, ability_version, _ = read_tsv("land_units_to_unit_abilites_junctions_tables")
    ability_rows = [{"ability": "wh_main_unit_passive_regeneration", "land_unit": TARGET_UNIT}]
    generated.append(write_db_tsv(ability_table, ability_header, ability_version, ability_rows))

    bua_header, bua_table, bua_version, bua_rows = read_tsv("building_units_allowed_tables")
    peasant_rows = [row for row in bua_rows if row.get("unit") == PEASANT_SPEARS]
    if not peasant_rows:
        raise RuntimeError("No peasant spearmen building permissions found")
    new_bua = []
    for idx, row in enumerate(peasant_rows, start=1):
        out = dict(row)
        out["key"] = str(907100000 + idx)
        out["unit"] = TARGET_UNIT
        new_bua.append(out)
    generated.append(write_db_tsv(bua_table, bua_header, bua_version, new_bua))

    bullet_header, bullet_table, bullet_version, _ = read_tsv("ui_unit_bullet_point_unit_overrides_tables")
    bullet_rows = [
        {"bullet_point": "vanguard_deployment", "unit": TARGET_UNIT},
        {"bullet_point": "charge_reflector", "unit": TARGET_UNIT},
    ]
    generated.append(write_db_tsv(bullet_table, bullet_header, bullet_version, bullet_rows))

    return generated


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
    def __init__(self, path: Path):
        self.text = path.read_text(encoding="utf-8")
        self.cache: dict[tuple[str, int], list[tuple[str, str]]] = {}

    def table_block(self, table: str) -> str:
        marker = f'"{table}": ['
        start = self.text.index(marker)
        open_idx = self.text.index("[", start)
        close_idx = find_matching(self.text, open_idx, "[", "]")
        return self.text[open_idx + 1 : close_idx]

    def fields(self, table: str, version: int) -> list[tuple[str, str]]:
        key = (table, version)
        if key in self.cache:
            return self.cache[key]
        for table_version in top_level_tuples(self.table_block(table)):
            version_match = re.search(r"version:\s*(\d+)", table_version)
            if not version_match or int(version_match.group(1)) != version:
                continue
            fields_open = table_version.index("fields: [")
            list_open = table_version.index("[", fields_open)
            list_close = find_matching(table_version, list_open, "[", "]")
            fields = []
            for field in top_level_tuples(table_version[list_open + 1 : list_close]):
                name = re.search(r'name:\s*"([^"]+)"', field).group(1)
                field_type = re.search(r"field_type:\s*([A-Za-z0-9_]+)", field).group(1)
                fields.append((name, field_type))
            self.cache[key] = fields
            return fields
        raise KeyError(f"Schema definition not found for {table} v{version}")


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
    raise NotImplementedError(f"Unsupported schema field type: {field_type}")


def read_mod_tsv(path: Path):
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
    if version != 0:
        output += b"\xfc\xfd\xfe\xff"
        output += struct.pack("<I", version)
    output += b"\x01"
    output += struct.pack("<I", len(rows))
    for row in rows:
        for name, field_type in schema.fields(table, version):
            output += encode_value(row.get(name, ""), field_type)
    return output


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


def build_pack():
    schema = Schema(SCHEMA_PATH)
    files: dict[str, bytes] = {}
    for path in sorted((MOD_ROOT / "db").glob("*/*.tsv")):
        table, version, internal_path, rows = read_mod_tsv(path)
        files[internal_path] = encode_db(table, version, rows, schema)
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

    OUTPUT_PACK.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PACK.write_bytes(bytes(header + index + data))
    return entries


def write_readme(generated_paths: list[Path]):
    readme = MOD_ROOT / "README.md"
    source_list = "\n".join(f"- `{path.relative_to(MOD_ROOT).as_posix()}`" for path in generated_paths)
    readme.write_text(
        f"""# cth_dragon_crossbow_overwrite

覆盖原版震旦天廷龙弩手：

- 目标单位：`{TARGET_UNIT}`
- 武器母本：桂阴御赐军 `{DONOR_UNIT}`
- 新近战武器：`{NEW_MELEE_WEAPON}`，普通伤害为桂阴御赐军近战武器的 2 倍，破甲伤害在 2 倍后再 +35。
- 新远程武器：`{NEW_MISSILE_WEAPON}`，弹药为桂阴御赐军弩矢的 3 倍伤害、2 倍射程，破甲伤害在 3 倍后再 +35。
- 兵模 120，招募费 400，维持费 100，招募回合 1，近战/远程自动分 1500/1500。
- 近战攻防按原版天廷龙弩手 +45，冲锋 45，护甲 `wh2_main_chainmail_110`，保留盾牌。
- 生命值按原版 1.5 倍处理：`land_units_tables.bonus_hit_points` 与专用实体 `hit_points` 都同步提高。
- 新专用实体 `{NEW_ENTITY}`：行走/奔跑/冲锋速度翻倍，加速度不变，射击角 180。
- 添加先锋部署、永不战败、重生、抵御冲锋，`damage_mod_all=30`，`healing_power=4.0000`。
- 追加役农长柄矛手的全部招募建筑许可给原版天廷龙弩手。

生成源文件：

{source_list}

输出 pack：

- `mod_output/{MOD_NAME}.pack`

说明：普通 DB 追加不会删除原版已有的天廷龙弩手招募许可；本 MOD 让它获得役农长柄矛手同款建筑许可，因此在常规震旦建筑链中与役农长柄矛手一致，同时原版已有许可若仍被游戏读取也会保留。
""",
        encoding="utf-8",
    )


def validate_pack(entries):
    data = OUTPUT_PACK.read_bytes()
    if data[:4] != b"PFH5":
        raise RuntimeError("Invalid pack magic")
    count = struct.unpack_from("<I", data, 0x10)[0]
    if count != len(entries):
        raise RuntimeError(f"Pack entry count mismatch: {count} != {len(entries)}")
    index_size = struct.unpack_from("<I", data, 0x14)[0]
    data_offset = 0x1C + index_size
    if data_offset >= len(data):
        raise RuntimeError("Pack index offset is outside file")
    return len(data), count


def main():
    generated_paths = prepare_sources()
    write_readme(generated_paths)
    entries = build_pack()
    pack_size, count = validate_pack(entries)
    print(f"Generated {len(generated_paths)} TSV files")
    print(f"Generated {OUTPUT_PACK} ({pack_size} bytes, {count} packed files)")


if __name__ == "__main__":
    main()
