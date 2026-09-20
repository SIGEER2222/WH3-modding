# -*- coding: utf-8 -*-
"""Generate czx_swarm_expansion TSV source files.

Patch for the 虫群帝国 (Imperial Arbiter / skv_chongzu) WH3 mod:
- cishe (刺蛇) unit size +50% (num_men 8 -> 12)
- new units: czx_feilong (飞龙, carrion donor), czx_zhanglang (蟑螂, tomb scorpion donor)

凯瑞甘已移除（2026-09-19）：czx_kerrigan / czx_kerrigan_lord 全部删除，
刀锋女王改由「英灵召唤 (Summon Servant)」workshop 3552538974 提供。
注意：OUT 仍指向旧目录名 mod_files/czx_swarm_expansion；现行源码在
mod_files/zzz_czx_swarm_expansion（含手工新增的 script/ui/variantmeshes）。
"""
from pathlib import Path

OUT = Path(r"E:\Code\WH3-modding\mod_files\czx_swarm_expansion")


def w(table, header, version, rows):
    p = OUT / "db" / table / "!!czx_swarm_expansion.tsv"
    p.parent.mkdir(parents=True, exist_ok=True)
    lines = ["\t".join(header), f"#{table};{version};db/{table}/!!czx_swarm_expansion"]
    lines += ["\t".join(r) for r in rows]
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", p)


VANILLA_DB = Path(r"E:\Code\WH3-modding\gamedata\db")


def vanilla_table(table):
    path = VANILLA_DB / table / "data__.tsv"
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    table_name, version, _ = lines[1].split("\t")[0][1:].split(";", 2)
    return lines[0].split("\t"), int(version), [line.split("\t") for line in lines[2:] if line]


def cloned_row(table, source_key, new_key, replacements=None):
    header, _, rows = vanilla_table(table)
    key_index = header.index("key") if "key" in header else header.index("id")
    for row in rows:
        if row[key_index] == source_key:
            cloned = list(row)
            cloned[key_index] = new_key
            for field, value in (replacements or {}).items():
                cloned[header.index(field)] = str(value)
            return header, cloned
    raise KeyError(f"{table}: donor row not found: {source_key}")


def cloned_field_row(table, field, source_value, new_value):
    header, _, rows = vanilla_table(table)
    idx = header.index(field)
    for row in rows:
        if row[idx] == source_value:
            cloned = list(row)
            cloned[idx] = new_value
            return header, cloned
    raise KeyError(f"{table}: donor {field} not found: {source_value}")


def cloned_field_rows(table, field, source_value, new_value):
    header, _, rows = vanilla_table(table)
    idx = header.index(field)
    cloned_rows = []
    for row in rows:
        if row[idx] == source_value:
            cloned = list(row)
            cloned[idx] = new_value
            cloned_rows.append(cloned)
    if not cloned_rows:
        raise KeyError(f"{table}: donor {field} not found: {source_value}")
    return header, cloned_rows


# ---------------------------------------------------------------- main_units
MU_H = ("additional_building_requirement campaign_cap caste create_time is_naval "
        "land_unit num_men multiplayer_cap multiplayer_cost naval_unit num_ships "
        "min_men_per_ship max_men_per_ship recruitment_cost unit upkeep_cost weight "
        "resource_requirement special_edition_mask in_encyclopedia "
        "audio_voiceover_culture ui_unit_group_land tier is_high_threat "
        "porthole_camera mount use_hitpoints_in_campaign porthole_composite_scene "
        "melee_cp missile_cp can_siege audio_voiceover_culture_override "
        "restrict_xp_gain_in_campaign audio_voiceover_actor_group food_cost "
        "has_spoken_vo is_monstrous multiplayer_qb_cap vo_is_dragon vo_is_dinosaur "
        "optional_ui_element barrier_health can_be_bribed point_allowance_weight "
        "is_renown").split()

# cishe override: 8 -> 12 men (+50%)
CISHE = ["", "-1", "monstrous_infantry", "1", "false", "cishe", "12", "0", "1950",
         "wh_main_shp_transport", "1", "1", "12", "1950", "cishe", "208", "heavy",
         "", "0", "true", "wh2_dlc09_vo_culture_Sepulchral_Stalker", "chong_zu",
         "5", "true", "tmb_stalkers", "", "false", "", "300.0", "1650.0", "false",
         "vo_culture_None", "false", "wh_main_vo_actor_default", "0", "false",
         "true", "1", "false", "false", "", "0.0", "true", "1", "false"]

FEILONG_MU = ["", "0", "war_beast", "1", "false", "czx_feilong", "24", "0", "350",
              "wh_main_shp_transport", "1", "1", "24", "450", "czx_feilong", "120",
              "heavy", "", "0", "true", "wh2_dlc09_vo_culture_Carrion", "chong_zu",
              "1", "false", "tmb_carrion", "", "false", "", "350.0", "0.0",
              "false", "vo_culture_None", "false", "wh_main_vo_actor_default",
              "0", "false", "false", "6", "false", "false", "", "0.0", "true",
              "1", "false"]

ZHANGLANG_MU = ["", "0", "monster", "2", "false", "czx_zhanglang", "1", "0",
                "1000", "wh_main_shp_transport", "1", "1", "1", "1200",
                "czx_zhanglang", "300", "super_heavy", "", "0", "true",
                "wh2_dlc09_vo_culture_Tomb_Scorpion", "chong_zu", "3", "true",
                "tmb_tomb_scorpion", "", "true", "", "1000.0", "0.0", "true",
                "vo_culture_None", "false", "wh_main_vo_actor_default", "0",
                "false", "true", "3", "false", "false", "", "0.0", "true", "1",
                "false"]

w("main_units_tables", MU_H, 7,
  [CISHE, FEILONG_MU, ZHANGLANG_MU])

# ---------------------------------------------------------------- land_units
LU_H = ("accuracy armour campaign_action_points category charge_bonus class "
        "historical_description_text key man_animation man_entity melee_attack "
        "melee_defence morale bonus_hit_points mount num_mounts "
        "primary_melee_weapon primary_missile_weapon rank_depth shield "
        "short_description_text spacing training_level articulated_record engine "
        "is_male visibility_spotting_range_min visibility_spotting_range_max "
        "attribute_group spot_dist_tree spot_dist_scrub reload selection_vo "
        "selected_vo_secondary selected_vo_tertiary hiding_scalar "
        "ground_stat_effect_group secondary_ammo primary_ammo damage_mod_flame "
        "damage_mod_magic num_engines damage_mod_physical damage_mod_missile "
        "damage_mod_all ai_usage_group can_skirmish can_brace mounted_draughts "
        "sync_locomotion capture_tier key_building_capture_tier "
        "score_capture_tier harmony_amplification_type first_person "
        "ar_unit_category healing_power spell_mastery infinite_secondary_ammo "
        "default_guard_mode").split()

FEILONG_LU = ["10", "wh2_main_body_20", "2100", "inf_melee", "12", "inf_mel",
              "czx_feilong", "czx_feilong", "bi1b_carrion",
              "wh2_dlc09_tmb_flying_carrion", "26", "46", "35", "202", "", "0",
              "wh2_cld09_tmb_carrion", "", "5", "none", "czx_feilong",
              "wh2_dlc09_tmb_carrions", "trained", "", "", "true", "40.0",
              "1500.0", "wh2_dlc09_tmb_mon_carrion_0", "60", "80", "0",
              "vo_sel_default", "vo_sel_melee", "vo_sel_culture", "1.0", "small",
              "0", "0", "0", "0", "0", "0", "0", "0",
              "flying_melee_flanker_undead", "false", "false", "false", "false",
              "cant_capture", "cant_capture", "cant_capture", "", "", "melee",
              "1.0", "1.0", "false", "false"]

ZHANGLANG_LU = ["0", "wh2_dlc10_bone_90", "2100", "inf_melee", "45", "inf_mel",
                "czx_zhanglang", "czx_zhanglang", "sc1_scorpion01",
                "wh2_dlc09_tmb_mon_tomb_scorpion", "35", "33", "55", "6012", "",
                "0", "wh2_dlc09_tmb_scorpion_claws", "", "1", "none",
                "czx_zhanglang", "wh_main_monster", "trained", "", "", "true",
                "40.0", "1500.0", "wh2_dlc09_tmb_mon_tomb_scorpion_0", "60",
                "80", "0", "vo_sel_default", "vo_sel_default", "vo_sel_culture",
                "1.0", "large", "0", "0", "0", "20", "0", "0", "0", "0",
                "melee_gatecrusher_undead", "false", "false", "false", "false",
                "medium", "medium", "domination_monsters", "", "", "melee",
                "1.0", "1.0", "false", "false"]

w("land_units_tables", LU_H, 54,
  [FEILONG_LU, ZHANGLANG_LU])

# ---------------------------------------------------------------- variants
w("unit_variants_tables",
  "faction\tname\tunit\tvariant\tunit_card".split("\t"), 5,
  [["", "czx_feilong", "czx_feilong", "wh2_dlc09_tmb_carrion",
    "czx_feilong"],
   ["", "czx_zhanglang", "czx_zhanglang", "wh2_dlc09_tmb_scorpion",
    "czx_zhanglang"]])

# ---------------------------------------------------------------- descriptions
for t in ("unit_description_short_texts_tables",
          "unit_description_historical_texts_tables"):
    w(t, ["key"], 0,
      [["czx_feilong"], ["czx_zhanglang"]])

# ---------------------------------------------------------------- recruitment
BUA_H = "building\tunit\tXP\tkey\tconditions\tfaction\tenabled".split("\t")
rows = []
k = 789789900
for b in ("wh_main_emp_forges_1", "wh_main_emp_forges_2",
          "wh_main_emp_forges_3", "wh_main_emp_forges_4"):
    for u in ("czx_feilong", "czx_zhanglang"):
        rows.append([b, u, "0", str(k), "0", "", "false"])
        k += 1
w("building_units_allowed_tables", BUA_H, 4, rows)

UGM_H = "unit\tmilitary_group".split("\t")
rows = []
for u in ("czx_feilong", "czx_zhanglang"):
    for g in ("wh_main_group_empire", "wh_main_group_empire_reikland"):
        rows.append([u, g])
w("units_to_groupings_military_permissions_tables", UGM_H, 0, rows)

UCB_H = ("faction\tgeneral_unit\tunit\tsiege_unit_attacker\tsiege_unit_defender"
         "\tgeneral_portrait\tgeneral_uniform\tset_piece_character"
         "\tcampaign_exclusive\tarmory_item_set\tsupports_upgrades").split("\t")
rows = [["wh_main_emp_empire", "false", u, "true", "true", "", "", "", "false",
         "", "false"] for u in ("czx_feilong", "czx_zhanglang")]
w("units_custom_battle_permissions_tables", UCB_H, 11, rows)

w("unit_set_to_unit_junctions_tables",
  "exclude\tunit_caste\tunit_category\tunit_class\tunit_record\tunit_set"
  .split("\t"), 1,
  [["false", "", "", "", u, "skv_chongzu"]
   for u in ("czx_feilong", "czx_zhanglang")])

w("battle_currency_units_cost_values_tables",
  "cost_value\tcurrency_type\titem_type".split("\t"), 0,
  [["425.0", "supplies_currency", "czx_feilong"],
   ["1000.0", "supplies_currency", "czx_zhanglang"]])

SC2_UNIT_ABILITIES = (
    ("czx_ability_mutalisk_regeneration", "wh_main_unit_passive_regeneration", 789900101),
    ("czx_ability_roach_regenerative_tissue", "wh_main_unit_passive_regeneration", 789900102),
    ("czx_ability_zergling_adrenal_glands", "wh_main_unit_passive_frenzy", 789900103),
    ("czx_ability_ultralisk_frenzied", "wh_main_unit_passive_frenzy", 789900104),
)

ability_rows = []
for new_key, donor_key, _ in SC2_UNIT_ABILITIES:
    header, row = cloned_row("unit_abilities_tables", donor_key, new_key)
    ability_rows.append(row)
w("unit_abilities_tables", header, 17, ability_rows)

special_rows = []
for new_key, donor_key, unique_id in SC2_UNIT_ABILITIES:
    header, row = cloned_row("unit_special_abilities_tables", donor_key, new_key,
                             {"unique_id": unique_id})
    special_rows.append(row)
w("unit_special_abilities_tables", header, 74, special_rows)

phase_rows = []
phase_junction_rows = []
phase_stat_rows = []
ui_effect_rows = []
phase_header = phase_junction_header = phase_stat_header = ui_effect_header = None
for new_key, donor_key, _ in SC2_UNIT_ABILITIES:
    header, row = cloned_field_row("special_ability_phases_tables", "id", donor_key, new_key)
    phase_header = header
    phase_rows.append(row)
    header, row = cloned_field_row(
        "special_ability_to_special_ability_phase_junctions_tables",
        "special_ability", donor_key, new_key)
    phase_junction_header = header
    row[header.index("phase")] = new_key
    phase_junction_rows.append(row)
    try:
        header, row = cloned_field_row("special_ability_phase_stat_effects_tables",
                                       "phase", donor_key, new_key)
        phase_stat_header = header
        phase_stat_rows.append(row)
    except KeyError:
        pass
    try:
        header, row = cloned_field_row("unit_abilities_to_additional_ui_effects_juncs_tables",
                                       "ability", donor_key, new_key)
        ui_effect_header = header
        ui_effect_rows.append(row)
    except KeyError:
        pass
w("special_ability_phases_tables", phase_header, 44, phase_rows)
w("special_ability_to_special_ability_phase_junctions_tables",
  phase_junction_header, 2, phase_junction_rows)
if phase_stat_rows:
    w("special_ability_phase_stat_effects_tables", phase_stat_header, 3, phase_stat_rows)
if ui_effect_rows:
    w("unit_abilities_to_additional_ui_effects_juncs_tables",
      ui_effect_header, 0, ui_effect_rows)

w("land_units_to_unit_abilites_junctions_tables",
  "ability\tland_unit".split("\t"), 0,
  [["czx_ability_mutalisk_regeneration", "czx_feilong"],
   ["czx_ability_roach_regenerative_tissue", "czx_zhanglang"],
   ["czx_ability_zergling_adrenal_glands", "gou"],
   ["czx_ability_ultralisk_frenzied", "leishou"],
   ["wh3_main_unit_passive_single_entity", "czx_zhanglang"]])

# ---------------------------------------------------------------- loc
loc = OUT / "text" / "db" / "czx_swarm_expansion_CN.loc.tsv"
loc.parent.mkdir(parents=True, exist_ok=True)
loc_rows = [
    ("land_units_onscreen_name_czx_feilong", "飞龙（异龙）", ""),
    ("land_units_onscreen_name_czx_zhanglang", "蟑螂（劫掠者）", ""),
    ("unit_description_short_texts_text_czx_feilong",
     "虫群的空中猎手，遮天蔽日地扑向敌人。", ""),
    ("unit_description_short_texts_text_czx_zhanglang",
     "厚重的甲壳下是虫群不知疲倦的毁灭之力。", ""),
    ("unit_description_historical_texts_text_czx_feilong",
     "异龙是虫群最常见的飞行生物，成群结队地撕开敌人的阵线。", ""),
    ("unit_description_historical_texts_text_czx_zhanglang",
     "蟑螂可以在恶劣环境中持续作战，用强酸与利爪碾碎猎物。", ""),
    ("unit_abilities_onscreen_name_czx_ability_mutalisk_regeneration",
     "组织再生", ""),
    ("unit_abilities_tooltip_text_czx_ability_mutalisk_regeneration",
     "飞龙的组织持续再生能力。", ""),
    ("unit_abilities_onscreen_name_czx_ability_roach_regenerative_tissue",
     "再生组织", ""),
    ("unit_abilities_tooltip_text_czx_ability_roach_regenerative_tissue",
     "蟑螂在战斗中快速修复受损组织。", ""),
    ("unit_abilities_onscreen_name_czx_ability_zergling_adrenal_glands",
     "肾上腺素", ""),
    ("unit_abilities_tooltip_text_czx_ability_zergling_adrenal_glands",
     "跳虫进入高速狂热状态，持续追猎敌人。", ""),
    ("unit_abilities_onscreen_name_czx_ability_ultralisk_frenzied",
     "狂暴甲壳", ""),
    ("unit_abilities_tooltip_text_czx_ability_ultralisk_frenzied",
     "雷兽不易被常规控制效果打断。", ""),
]
lines = ["key\ttext\ttooltip",
         "#Loc;1;text/db/czx_swarm_expansion_CN.loc"]
lines += ["\t".join(r) for r in loc_rows]
loc.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("wrote", loc)
