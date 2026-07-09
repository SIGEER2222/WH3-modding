from __future__ import annotations

import csv
import math
import re
import struct
import time
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MOD_NAME = "cth_grand_cannon_overwrite"
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

TARGET_UNIT = "wh3_main_cth_art_grand_cannon_0"
PEASANT_SPEARS = "wh3_main_cth_inf_peasant_spearmen_1"

NEW_MELEE_WEAPON = "cthgco_cth_grand_cannon_melee_ap60"
NEW_MISSILE_WEAPON = "cthgco_cth_grand_cannon_high_1000_750"
NEW_MISSILE_WEAPON_EXPLOSIVE = "cthgco_cth_grand_cannon_high_1000_750_explosive"
NEW_PROJECTILE = "cthgco_cth_grand_cannon_high_1000_750"
NEW_PROJECTILE_EXPLOSIVE = "cthgco_cth_grand_cannon_high_1000_750_explosive"
NEW_PROJECTILE_EXPLOSION = "cthgco_cth_grand_cannon_high_1000_750_explosion"
NEW_MISSILE_WEAPON_JUNCTION_ID = "907201001"
ENABLE_EXPLOSIVE_EFFECT = "cthgco_effect_enable_grand_cannon_explosive_ammo"
ENABLE_EXPLOSIVE_BUNDLE = "cthgco_bundle_grand_cannon_explosive_ammo"
NEW_ARTICULATED_RECORD = "cthgco_cth_art_grand_cannon_articulation_fast"
NEW_ARTICULATED_ENTITY = "cthgco_cth_art_grand_cannon_articulation_fast"
NEW_DRAUGHT_MOUNT = "cthgco_cth_mnt_oxen_draught_artillery_fast"
NEW_DRAUGHT_ENTITY = "cthgco_cth_veh_oxen_draught_artillery_fast"
NEW_ENGINE = "cthgco_cth_art_grand_cannon_fast"
NEW_ENGINE_ENTITY = "cthgco_cth_art_grand_cannon_fast"
NEW_CREW_ENTITY = "cthgco_cth_artillery_crew_fast"
CAMPAIGN_SCRIPT = "cthgco_grand_cannon_ammo.lua"
INTERNAL = "!!cthgco_grand_cannon_overwrite"


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


def write_campaign_script() -> Path:
    out_dir = MOD_ROOT / "script" / "campaign" / "mod"
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / CAMPAIGN_SCRIPT
    path.write_text(
        f"""local CTHGCO_AMMO_BUNDLE = "{ENABLE_EXPLOSIVE_BUNDLE}"

cm:add_first_tick_callback(function()
\tlocal faction_list = cm:get_faction_list()

\tfor i = 0, faction_list:num_items() - 1 do
\t\tlocal faction = faction_list:item_at(i)

\t\tif faction and not faction:is_null_interface() then
\t\t\tcm:apply_effect_bundle(CTHGCO_AMMO_BUNDLE, faction:name(), -1)
\t\tend
\tend
end)
""",
        encoding="utf-8",
    )
    return path


def prepare_sources():
    generated = []

    land_header, land_table, land_version, land_rows = read_tsv("land_units_tables")
    land = row_by(land_rows, "key", TARGET_UNIT)
    original_attack = int(land["melee_attack"])
    original_defence = int(land["melee_defence"])
    original_ammo = int(land["primary_ammo"])
    original_bonus_hit_points = int(land["bonus_hit_points"])
    original_healing_power = float(land["healing_power"])
    original_melee_weapon = land["primary_melee_weapon"]
    original_man_entity = land["man_entity"]
    original_articulated_record = land["articulated_record"]
    original_mount = land["mount"]
    land.update(
        {
            "armour": "wh2_main_heavy_metal_160",
            "articulated_record": NEW_ARTICULATED_RECORD,
            "charge_bonus": "25",
            "engine": NEW_ENGINE,
            "man_entity": NEW_CREW_ENTITY,
            "melee_attack": str(original_attack + 50),
            "melee_defence": str(original_defence + 50),
            "bonus_hit_points": str(original_bonus_hit_points * 2),
            "mount": NEW_DRAUGHT_MOUNT,
            "primary_melee_weapon": NEW_MELEE_WEAPON,
            "primary_missile_weapon": NEW_MISSILE_WEAPON,
            "primary_ammo": str(original_ammo * 5),
            "num_engines": str(int(land["num_engines"]) * 2),
            "damage_mod_all": "50",
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
            "num_men": str(int(main["num_men"]) * 2),
            "melee_cp": "1000.0000",
            "missile_cp": "2000.0000",
        }
    )
    generated.append(write_db_tsv(main_table, main_header, main_version, [main]))

    melee_header, melee_table, melee_version, melee_rows = read_tsv("melee_weapons_tables")
    melee_weapon = row_by(melee_rows, "key", original_melee_weapon)
    melee_weapon.update(
        {
            "key": NEW_MELEE_WEAPON,
            "ap_damage": str(int(melee_weapon["ap_damage"]) + 60),
        }
    )
    generated.append(write_db_tsv(melee_table, melee_header, melee_version, [melee_weapon]))

    missile_header, missile_table, missile_version, missile_rows = read_tsv("missile_weapons_tables")
    missile_weapon = row_by(missile_rows, "key", "wh3_main_cth_grand_cannon_ball")
    original_projectile_key = missile_weapon["default_projectile"]
    missile_weapon.update({"key": NEW_MISSILE_WEAPON, "default_projectile": NEW_PROJECTILE})
    explosive_missile_weapon = dict(missile_weapon)
    explosive_missile_weapon.update(
        {
            "key": NEW_MISSILE_WEAPON_EXPLOSIVE,
            "default_projectile": NEW_PROJECTILE,
        }
    )
    generated.append(write_db_tsv(missile_table, missile_header, missile_version, [missile_weapon, explosive_missile_weapon]))

    projectile_header, projectile_table, projectile_version, projectile_rows = read_tsv("projectiles_tables")
    projectile = row_by(projectile_rows, "key", original_projectile_key)
    original_range = int(projectile["effective_range"])
    original_expiry_range = int(projectile["expiry_range"])
    original_damage = int(projectile["damage"])
    original_ap_damage = int(projectile["ap_damage"])
    muzzle_velocity = 1000.0
    max_arc_range = 750
    max_elevation = 88.0
    arc_gravity = muzzle_velocity * muzzle_velocity / max_arc_range
    min_arc_range = math.ceil(muzzle_velocity * muzzle_velocity * math.sin(math.radians(max_elevation * 2)) / arc_gravity)
    expiry_range = math.floor(max_arc_range * original_expiry_range / original_range)
    projectile.update(
        {
            "key": NEW_PROJECTILE,
            "trajectory_sight": "high",
            "effective_range": str(max_arc_range),
            "minimum_range": str(min_arc_range),
            "max_elevation": str(int(max_elevation)),
            "muzzle_velocity": fmt_f32(muzzle_velocity),
            "damage": str(original_damage * 2),
            "ap_damage": str(original_ap_damage * 2),
            "base_reload_time": "6.0000",
            "calibration_distance": fmt_f32(float(max_arc_range)),
            "gravity": fmt_f32(arc_gravity),
            "fixed_elevation": "45",
            "expiry_range": str(expiry_range),
        }
    )

    little_grom_projectile = row_by(projectile_rows, "key", "wh3_main_ksl_little_grom_cannon_ball")
    little_grom_explosive_projectile = row_by(projectile_rows, "key", "wh3_main_ksl_little_grom_cannon_ball_explosive")
    explosive_damage_ratio = int(little_grom_explosive_projectile["damage"]) / int(little_grom_projectile["damage"])
    explosive_ap_damage_ratio = int(little_grom_explosive_projectile["ap_damage"]) / int(little_grom_projectile["ap_damage"])
    explosive_projectile = dict(projectile)
    explosive_projectile.update(
        {
            "key": NEW_PROJECTILE_EXPLOSIVE,
            "shot_type": little_grom_explosive_projectile["shot_type"],
            "explosion_type": NEW_PROJECTILE_EXPLOSION,
            "damage": str(round(int(projectile["damage"]) * explosive_damage_ratio)),
            "ap_damage": str(round(int(projectile["ap_damage"]) * explosive_ap_damage_ratio)),
            "projectile_shot_type_display": little_grom_explosive_projectile["projectile_shot_type_display"],
            "building_damage_multiplier": fmt_f32(float(projectile["building_damage_multiplier"]) * 2),
        }
    )
    generated.append(write_db_tsv(projectile_table, projectile_header, projectile_version, [projectile, explosive_projectile]))

    explosion_header, explosion_table, explosion_version, explosion_rows = read_tsv("projectiles_explosions_tables")
    little_grom_explosion = row_by(explosion_rows, "key", "wh3_main_ksl_little_grom_cannon_ball_explosive")
    explosion_damage_ratio = float(little_grom_explosion["detonation_damage"]) / int(little_grom_projectile["damage"])
    explosion_ap_damage_ratio = float(little_grom_explosion["detonation_damage_ap"]) / int(little_grom_projectile["ap_damage"])
    explosion = dict(little_grom_explosion)
    explosion.update(
        {
            "key": NEW_PROJECTILE_EXPLOSION,
            "detonation_damage": fmt_f32(round(int(projectile["damage"]) * explosion_damage_ratio)),
            "detonation_damage_ap": fmt_f32(round(int(projectile["ap_damage"]) * explosion_ap_damage_ratio)),
        }
    )
    generated.append(write_db_tsv(explosion_table, explosion_header, explosion_version, [explosion]))

    mwp_header, mwp_table, mwp_version, _ = read_tsv("missile_weapons_to_projectiles_tables")
    mwp_rows = [{"missile_weapon": NEW_MISSILE_WEAPON_EXPLOSIVE, "projectile": NEW_PROJECTILE_EXPLOSIVE}]
    generated.append(write_db_tsv(mwp_table, mwp_header, mwp_version, mwp_rows))

    weapon_junction_header, weapon_junction_table, weapon_junction_version, _ = read_tsv("unit_missile_weapon_junctions_tables")
    weapon_junction_rows = [
        {
            "id": NEW_MISSILE_WEAPON_JUNCTION_ID,
            "missile_weapon": NEW_MISSILE_WEAPON_EXPLOSIVE,
            "unit": TARGET_UNIT,
            "battle_entity_stats_override": "",
        }
    ]
    generated.append(write_db_tsv(weapon_junction_table, weapon_junction_header, weapon_junction_version, weapon_junction_rows))

    effects_header, effects_table, effects_version, effects_rows = read_tsv("effects_tables")
    enable_effect = row_by(effects_rows, "effect", "wh3_main_effect_projectile_enable_explosive_ksl_little_grom")
    enable_effect.update({"effect": ENABLE_EXPLOSIVE_EFFECT})
    generated.append(write_db_tsv(effects_table, effects_header, effects_version, [enable_effect]))

    ebv_header, ebv_table, ebv_version, _ = read_tsv("effect_bonus_value_missile_weapon_junctions_tables")
    ebv_rows = [
        {
            "bonus_value_id": "enable",
            "effect": ENABLE_EXPLOSIVE_EFFECT,
            "missile_weapon_junction": NEW_MISSILE_WEAPON_JUNCTION_ID,
        }
    ]
    generated.append(write_db_tsv(ebv_table, ebv_header, ebv_version, ebv_rows))

    bundle_header, bundle_table, bundle_version, _ = read_tsv("effect_bundles_tables")
    bundle_rows = [
        {
            "key": ENABLE_EXPLOSIVE_BUNDLE,
            "localised_description": "",
            "localised_title": "",
            "bundle_target": "faction",
            "priority": "1",
            "ui_icon": "",
            "is_global_effect": "false",
            "show_in_3d_space": "false",
            "owner_only": "true",
        }
    ]
    generated.append(write_db_tsv(bundle_table, bundle_header, bundle_version, bundle_rows))

    b2e_header, b2e_table, b2e_version, _ = read_tsv("effect_bundles_to_effects_junctions_tables")
    b2e_rows = [
        {
            "effect_bundle_key": ENABLE_EXPLOSIVE_BUNDLE,
            "effect_key": ENABLE_EXPLOSIVE_EFFECT,
            "effect_scope": "faction_to_force_own_unseen",
            "value": "1.0000",
            "advancement_stage": "start_turn_completed",
        }
    ]
    generated.append(write_db_tsv(b2e_table, b2e_header, b2e_version, b2e_rows))

    mount_header, mount_table, mount_version, mount_rows = read_tsv("mounts_tables")
    mount = row_by(mount_rows, "key", original_mount)
    original_mount_entity = mount["entity"]
    mount.update({"key": NEW_DRAUGHT_MOUNT, "entity": NEW_DRAUGHT_ENTITY})
    generated.append(write_db_tsv(mount_table, mount_header, mount_version, [mount]))

    entity_header, entity_table, entity_version, entity_rows = read_tsv("battle_entities_tables")
    crew_entity = row_by(entity_rows, "key", original_man_entity)
    crew_entity.update(
        {
            "key": NEW_CREW_ENTITY,
            "walk_speed": fmt_f32(float(crew_entity["walk_speed"]) * 2),
            "run_speed": fmt_f32(float(crew_entity["run_speed"]) * 2),
            "charge_speed": fmt_f32(float(crew_entity["charge_speed"]) * 2),
            "hit_points": str(int(crew_entity["hit_points"]) * 2),
            "fire_arc_close": "180.0000",
        }
    )
    engine_entity = row_by(entity_rows, "key", "wh3_main_cth_art_grand_cannon")
    engine_entity.update(
        {
            "key": NEW_ENGINE_ENTITY,
            "walk_speed": fmt_f32(float(engine_entity["walk_speed"]) * 2),
            "run_speed": fmt_f32(float(engine_entity["run_speed"]) * 2),
            "charge_speed": fmt_f32(float(engine_entity["charge_speed"]) * 2),
            "hit_points": str(int(engine_entity["hit_points"]) * 2),
            "fire_arc_close": "180.0000",
        }
    )
    draught_entity = row_by(entity_rows, "key", original_mount_entity)
    draught_entity.update(
        {
            "key": NEW_DRAUGHT_ENTITY,
            "walk_speed": fmt_f32(float(draught_entity["walk_speed"]) * 2),
            "run_speed": fmt_f32(float(draught_entity["run_speed"]) * 2),
            "charge_speed": fmt_f32(float(draught_entity["charge_speed"]) * 2),
            "hit_points": str(int(draught_entity["hit_points"]) * 2),
            "fire_arc_close": "180.0000",
        }
    )
    articulated_entity = row_by(entity_rows, "key", original_articulated_record)
    articulated_entity.update(
        {
            "key": NEW_ARTICULATED_ENTITY,
            "walk_speed": fmt_f32(float(articulated_entity["walk_speed"]) * 2),
            "run_speed": fmt_f32(float(articulated_entity["run_speed"]) * 2),
            "charge_speed": fmt_f32(float(articulated_entity["charge_speed"]) * 2),
            "hit_points": str(int(articulated_entity["hit_points"]) * 2),
            "fire_arc_close": "180.0000",
        }
    )
    generated.append(
        write_db_tsv(
            entity_table,
            entity_header,
            entity_version,
            [crew_entity, engine_entity, draught_entity, articulated_entity],
        )
    )

    engine_header, engine_table, engine_version, engine_rows = read_tsv("battlefield_engines_tables")
    engine = row_by(engine_rows, "key", "wh3_main_cth_art_grand_cannon")
    engine.update(
        {
            "key": NEW_ENGINE,
            "battle_entity": NEW_ENGINE_ENTITY,
            "missile_weapon": NEW_MISSILE_WEAPON,
        }
    )
    generated.append(write_db_tsv(engine_table, engine_header, engine_version, [engine]))

    articulated_header, articulated_table, articulated_version, articulated_rows = read_tsv(
        "land_unit_articulated_vehicles_tables"
    )
    articulated_record = row_by(articulated_rows, "key", original_articulated_record)
    articulated_record.update({"key": NEW_ARTICULATED_RECORD, "articulated_entity": NEW_ARTICULATED_ENTITY})
    generated.append(write_db_tsv(articulated_table, articulated_header, articulated_version, [articulated_record]))

    articulation_node_header, articulation_node_table, articulation_node_version, articulation_node_rows = read_tsv(
        "articulation_nodes_in_land_articulated_vehicles_tables"
    )
    new_articulation_nodes = []
    for row in articulation_node_rows:
        if row.get("land_unit_articulated_vehicle") == original_articulated_record:
            out = dict(row)
            out["land_unit_articulated_vehicle"] = NEW_ARTICULATED_RECORD
            new_articulation_nodes.append(out)
    if not new_articulation_nodes:
        raise RuntimeError("No grand cannon articulation nodes found")
    generated.append(
        write_db_tsv(articulation_node_table, articulation_node_header, articulation_node_version, new_articulation_nodes)
    )

    first_person_header, first_person_table, first_person_version, first_person_rows = read_tsv("first_person_engines_tables")
    first_person = row_by(first_person_rows, "key", "wh3_main_cth_art_grand_cannon")
    first_person.update(
        {
            "key": NEW_ENGINE,
            "half_horizontal_fire_arc": "90.0000",
            "reload_time": "6.0000",
        }
    )
    generated.append(write_db_tsv(first_person_table, first_person_header, first_person_version, [first_person]))

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
        out["key"] = str(907200000 + idx)
        out["unit"] = TARGET_UNIT
        new_bua.append(out)
    generated.append(write_db_tsv(bua_table, bua_header, bua_version, new_bua))

    bullet_header, bullet_table, bullet_version, _ = read_tsv("ui_unit_bullet_point_unit_overrides_tables")
    bullet_rows = [
        {"bullet_point": "vanguard_deployment", "unit": TARGET_UNIT},
        {"bullet_point": "charge_reflector", "unit": TARGET_UNIT},
    ]
    generated.append(write_db_tsv(bullet_table, bullet_header, bullet_version, bullet_rows))

    generated.append(write_campaign_script())

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
    for path in sorted((MOD_ROOT / "script").glob("**/*")):
        if path.is_file():
            internal_path = path.relative_to(MOD_ROOT).as_posix().replace("/", "\\")
            files[internal_path] = path.read_bytes()
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
        f"""# cth_grand_cannon_overwrite

覆盖原版震旦巨炮：

- 目标单位：`{TARGET_UNIT}`
- 炮弹弹道：`high` 高角分支测试版，弹速 1000，45 度计算最远约 750m；反推 `gravity=1333.3333`，88 度计算最近约 52.32m（表内取 `minimum_range=53`），`effective_range=750`，`max_elevation=88`。
- 巨炮门数：`land_units_tables.num_engines` 4 -> 8；炮组人数 `main_units_tables.num_men` 44 -> 88。
- 生命值翻倍：炮组实体与火炮实体都使用专用 key 并把 `hit_points` 翻倍；`bonus_hit_points` 同步 48 -> 96。
- 护甲使用当前原版最高护甲 key：`wh2_main_heavy_metal_160`。
- 移动速度翻倍：炮组和火炮实体的 `walk_speed`、`run_speed`、`charge_speed` 翻倍；`acceleration` 保持原值。
- 近战攻防按原版巨炮 +50，冲锋加成 25。
- 新近战武器 `{NEW_MELEE_WEAPON}`：破甲杀伤 +60。
- 新远程武器 `{NEW_MISSILE_WEAPON}`：保留原版巨炮弹药表现，远程伤害 x2，炮弹飞行速度固定为 1000，装填时间固定为 6，弹药 x5；弹道为非 fixed 的 `high` 分支，`minimum_range=53`、`effective_range=750`。
- 追加可切换爆破弹药 `{NEW_MISSILE_WEAPON_EXPLOSIVE}`：参考亚雷鸣炮的 `unit_missile_weapon_junctions_tables` + `missile_weapons_to_projectiles_tables` 链路，直伤按亚雷鸣炮爆破弹比例降为普通弹 50%（`88/352`），并添加半径 7 的范围爆炸（`detonation_damage=50.0000`、`detonation_damage_ap=76.0000`）。
- 巨炮炮组与炮身专用实体 `fire_arc_close` 改为 180 度。
- 添加抵御冲锋、先锋部署、永不战败、再生，`damage_mod_all=50`，`healing_power=4.0000`。
- 近战/远程自动分为 1000/2000，招募回合 1。
- 追加役农长柄矛手的全部招募建筑许可给原版巨炮。

生成源文件：

{source_list}

输出 pack：

- `mod_output/{MOD_NAME}.pack`

说明：普通 DB 追加不会删除原版已有的巨炮招募许可；本 MOD 让它额外获得役农长柄矛手同款建筑许可，因此在常规震旦建筑链中与役农长柄矛手一致，同时原版已有许可若仍被游戏读取也会保留。
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
    print(f"Generated {len(generated_paths)} source files")
    print(f"Generated {OUTPUT_PACK} ({pack_size} bytes, {count} packed files)")


if __name__ == "__main__":
    main()
