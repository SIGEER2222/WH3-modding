# -*- coding: utf-8 -*-
"""Append DB rows for the 5 new infested units to zzz_czx_swarm_units.

Clones vanilla donor land_units/main_units rows, rewrites keys/stats, and
mirrors the permission/building/grouping pattern used by existing czx units.
"""
from pathlib import Path

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "zzz_czx_swarm_units"
GAMEDB = ROOT / "gamedata" / "db"

# ---------------------------------------------------------------- donors
DONOR_LAND = {
    "czx_baolongshou": "wh2_main_lzd_mon_stegadon_0",
    "czx_inf_tank": "wh_main_emp_veh_steam_tank_driver",
    "czx_dehaka": "wh2_dlc17_bst_mon_ghorgon_0",
    "czx_inf_diamondback": "wh2_dlc16_wef_mon_giant_spiders_0",
    "czx_inf_marine": "wh_main_emp_inf_handgunners",
}
DONOR_MAIN = DONOR_LAND  # same keys in both tables

# land_units column overrides per unit
LAND_OVR = {
    "czx_baolongshou": dict(
        melee_attack="46", melee_defence="36", morale="70",
        bonus_hit_points="9600", charge_bonus="70",
        armour="wh2_main_body_120", ground_stat_effect_group="large",
        ai_usage_group="melee_gatecrusher",
    ),
    "czx_inf_tank": dict(
        melee_attack="36", melee_defence="22", morale="100",
        bonus_hit_points="9052", charge_bonus="80",
        engine="czx_inf_tank_engine",
        ai_usage_group="ranged_direct_highvalue",
    ),
    "czx_dehaka": dict(
        melee_attack="62", melee_defence="42", morale="90",
        bonus_hit_points="11800", charge_bonus="50",
        armour="wh2_main_body_60",
        ai_usage_group="melee_gatecrusher",
    ),
    "czx_inf_diamondback": dict(
        melee_attack="34", melee_defence="28", morale="60",
        bonus_hit_points="700", charge_bonus="35", rank_depth="4",
        ground_stat_effect_group="large",
        ai_usage_group="melee_flanker",
    ),
    "czx_inf_marine": dict(
        melee_attack="18", melee_defence="20", morale="70",
        bonus_hit_points="70", charge_bonus="6",
        armour="wh2_main_body_30",
        attribute_group="czx_zerg_beast",
        ai_usage_group="ranged_direct",
    ),
}

# main_units column overrides per unit
MAIN_OVR = {
    "czx_baolongshou": dict(
        num_men="1", min_men_per_ship="1", max_men_per_ship="1",
        tier="4", recruitment_cost="2000", upkeep_cost="500",
        multiplayer_cost="2000", melee_cp="2000.0", missile_cp="0.0",
        weight="very_heavy", is_monstrous="true", is_high_threat="true",
        multiplayer_qb_cap="2", campaign_cap="-1", vo_is_dinosaur="true",
    ),
    "czx_inf_tank": dict(
        num_men="3", min_men_per_ship="1", max_men_per_ship="1",
        tier="4", recruitment_cost="2200", upkeep_cost="550",
        multiplayer_cost="2200", melee_cp="700.0", missile_cp="1400.0",
        weight="very_heavy", is_high_threat="true",
        multiplayer_qb_cap="2", campaign_cap="-1",
        has_spoken_vo="false", audio_voiceover_actor_group="wh_main_vo_actor_default",
        audio_voiceover_culture="wh2_dlc09_vo_culture_Tomb_Scorpion",
    ),
    "czx_dehaka": dict(
        num_men="1", min_men_per_ship="1", max_men_per_ship="1",
        tier="5", recruitment_cost="2400", upkeep_cost="600",
        multiplayer_cost="2200", melee_cp="2200.0", missile_cp="0.0",
        weight="very_heavy", is_monstrous="true", is_high_threat="true",
        multiplayer_qb_cap="1", campaign_cap="-1",
    ),
    "czx_inf_diamondback": dict(
        num_men="16", min_men_per_ship="1", max_men_per_ship="60",
        tier="3", recruitment_cost="1200", upkeep_cost="300",
        multiplayer_cost="1200", melee_cp="1200.0", missile_cp="0.0",
        weight="heavy", is_high_threat="false", is_monstrous="true",
        multiplayer_qb_cap="3", campaign_cap="-1",
    ),
    "czx_inf_marine": dict(
        num_men="90", min_men_per_ship="1", max_men_per_ship="120",
        tier="2", recruitment_cost="650", upkeep_cost="165",
        multiplayer_cost="650", melee_cp="120.0", missile_cp="500.0",
        weight="medium", is_high_threat="false",
        multiplayer_qb_cap="6", campaign_cap="-1",
        has_spoken_vo="false", audio_voiceover_actor_group="wh_main_vo_actor_default",
        audio_voiceover_culture="wh2_dlc09_vo_culture_Tomb_Scorpion",
    ),
}

CN_NAME = {
    "czx_baolongshou": "暴龙兽",
    "czx_inf_tank": "被感染的坦克",
    "czx_dehaka": "德哈卡",
    "czx_inf_diamondback": "被感染的响尾蛇",
    "czx_inf_marine": "被感染的枪兵",
}
DESC = {
    "czx_baolongshou": "原始虫群锻造的活体攻城兽。暴龙兽覆满几丁质重甲，头顶巨角足以挑翻城墙，冲锋时如整片大地向敌阵碾压过去。",
    "czx_inf_tank": "被虫群寄生的蒸汽坦克。装甲缝隙间生满蠕动的生物质，主炮喷吐的不再是炮弹，而是腐蚀性的胆汁团块。",
    "czx_dehaka": "原始异虫的首领德哈卡。他不断猎杀强者、汲取精华，身躯庞大却异常迅捷，双臂一挥便能撕碎重装步兵。",
    "czx_inf_diamondback": "被感染的响尾蛇战车。多足底盘披着虫化装甲，高速游走于战场边缘，用酸蚀唾液撕咬敌军侧翼。",
    "czx_inf_marine": "被感染的陆战队员。寄生体接管了残躯，步枪里射出的弹丸裹着活性虫酸，命中处血肉溃烂。",
}
SHORT = {k: v for k, v in CN_NAME.items()}

# custom abilities ---------------------------------------------------------
ABILITY_UID = 789900116
ABILITIES = [
    # key, icon, type, phase stat effects [(stat,value,how)], extra phase cols
    dict(key="czx_ability_baolongshou_primal_fury",
         icon="wh_main_unit_passive_frenzy", type="wh_type_augment",
         stats=[("stat_melee_attack", "8.0", "add"),
                ("stat_charge_bonus", "1.15", "mult"),
                ("scalar_speed", "1.1", "mult")],
         phase_extra={}, cn_name="原始狂怒",
         cn_tip="暴龙兽的原始血性被激发，攻击、速度与冲锋威力持续提升。"),
    dict(key="czx_ability_inf_tank_infested_hull",
         icon="wh_magic_item_passive_armour", type="wh_type_augment",
         stats=[("stat_armour", "15.0", "add"),
                ("stat_resistance_missile", "15.0", "add")],
         phase_extra={}, cn_name="感染装甲",
         cn_tip="增生的生物质覆盖装甲接缝，提升护甲并削弱来袭弹药的杀伤。"),
    dict(key="czx_ability_dehaka_essence_leech",
         icon="wh_main_unit_passive_regeneration", type="wh_type_regeneration",
         stats=[("stat_weakness_flame", "-20.0", "add")],
         phase_extra={"hp_change_frequency": "1.0",
                      "heal_amount": "0.0010000000474974513"},
         cn_name="精华汲取",
         cn_tip="德哈卡汲取战场上的生命精华，伤口随时间缓慢愈合，但火焰仍能克制这种再生。"),
    dict(key="czx_ability_diamondback_blitz",
         icon="wh2_main_unit_passive_scurry_away", type="wh_type_augment",
         stats=[("scalar_speed", "1.15", "mult"),
                ("stat_charge_bonus", "1.2", "mult"),
                ("scalar_entity_acceleration_modifier", "2.0", "mult")],
         phase_extra={}, cn_name="闪电突袭",
         cn_tip="响尾蛇的虫化肢体爆发力惊人，移动与冲锋速度大幅提高。"),
    dict(key="czx_ability_marine_infested_rounds",
         icon="wh2_dlc15_unit_passive_nightgoblin_poison", type="wh_type_augment",
         stats=[],
         phase_extra={"imbue_contact": "wh_main_unit_contact_poison"},
         cn_name="感染弹丸",
         cn_tip="枪兵的弹丸浸透虫酸，命中目标会造成中毒效果。"),
]
UNIT_ABILITIES = {
    "czx_baolongshou": ["wh3_main_unit_passive_single_entity",
                        "czx_ability_baolongshou_primal_fury"],
    "czx_inf_tank": ["wh3_main_unit_passive_single_entity",
                     "czx_ability_inf_tank_infested_hull"],
    "czx_dehaka": ["wh3_main_unit_passive_single_entity",
                   "czx_ability_dehaka_essence_leech"],
    "czx_inf_diamondback": ["czx_ability_diamondback_blitz"],
    "czx_inf_marine": ["czx_ability_marine_infested_rounds"],
}

COST_SUPPLIES = {
    "czx_baolongshou": "800.0",
    "czx_inf_tank": "900.0",
    "czx_dehaka": "900.0",
    "czx_inf_diamondback": "500.0",
    "czx_inf_marine": "300.0",
}

UNIT_KEYS = list(DONOR_LAND.keys())


def load_gamedata_row(table, key, keycol="key"):
    f = open(GAMEDB / table / "data__.tsv", encoding="utf-8-sig")
    hdr = f.readline().rstrip("\n").split("\t")
    for line in f:
        r = line.rstrip("\n").split("\t")
        if len(r) > 2 and r[hdr.index(keycol)] == key:
            return hdr, r
    raise KeyError(f"{table}:{key}")


def existing_keys(rows, col=0):
    return {l.split("\t")[col] for l in rows if l.strip()}


def mod_tsv(table, fname="!!czx_swarm_units"):
    p = MOD / "db" / table / f"{fname}.tsv"
    lines = p.read_text(encoding="utf-8-sig").splitlines()
    return p, lines[0].split("\t"), lines[1], lines[2:]


def append_rows(path, header, meta, rows):
    with open(path, "ab") as f:
        for r in rows:
            f.write(("\t".join(r) + "\r\n").encode("utf-8"))


def filter_new(rows, new, col):
    """Drop rows whose key already exists in column `col` of existing data."""
    have = {l.split("\t")[col] for l in rows if l.strip()}
    return [r for r in new if r[col] not in have]


def clone_row(hdr, row, key, ovr):
    d = dict(zip(hdr, row))
    d["key"] = key
    d.update(ovr)
    return [d.get(c, "") for c in hdr]


def main():
    # ---------------- land_units ----------------
    p, hdr, meta, rows = mod_tsv("land_units_tables")
    have = existing_keys(rows, hdr.index("key"))
    new = []
    for u in UNIT_KEYS:
        if u in have:
            continue
        gh, gr = load_gamedata_row("land_units_tables", DONOR_LAND[u])
        r = clone_row(gh, gr, u, LAND_OVR[u])
        d = dict(zip(gh, r))
        d["historical_description_text"] = u
        d["short_description_text"] = u
        d["attribute_group"] = LAND_OVR[u].get("attribute_group", "czx_zerg_beast")
        r = [d.get(c, "") for c in gh]
        new.append([r[gh.index(c)] if c in gh else "" for c in hdr])
    append_rows(p, hdr, meta, new)
    print("land_units +", len(new))

    # ---------------- main_units ----------------
    p, hdr, meta, rows = mod_tsv("main_units_tables")
    have = existing_keys(rows, hdr.index("land_unit"))
    new = []
    for u in UNIT_KEYS:
        if u in have:
            continue
        # main row key may differ from land key (e.g. steam tank uses a
        # separate "imperial_supply" main record) — match by land_unit col
        gh, gr = load_gamedata_row("main_units_tables", DONOR_MAIN[u],
                                   "land_unit")
        d = dict(zip(gh, gr))
        d["unit"] = u
        d["land_unit"] = u
        d.update(MAIN_OVR[u])
        d["ui_unit_group_land"] = "chong_zu"
        new.append([d.get(c, "") for c in hdr])
    append_rows(p, hdr, meta, new)
    print("main_units +", len(new))

    # ---------------- unit_variants / variants ----------------
    p, hdr, meta, rows = mod_tsv("unit_variants_tables")
    # steam tank crew marines ride the engine — crew variant shows marine vmd
    crew_variant = {"czx_inf_tank": "czx_inf_marine"}
    new = filter_new(rows, [["", u, u, crew_variant.get(u, u), u]
                            for u in UNIT_KEYS], 1)
    append_rows(p, hdr, meta, new)
    p, hdr, meta, rows = mod_tsv("variants_tables")
    new = filter_new(rows, [[u, "", u, "", "1.0", "1.0", "0.05", ""]
                            for u in UNIT_KEYS], 0)
    append_rows(p, hdr, meta, new)
    print("variants/unit_variants done")

    # ---------------- descriptions ----------------
    for t in ("unit_description_short_texts_tables",
              "unit_description_historical_texts_tables"):
        p, hdr, meta, rows = mod_tsv(t)
        new = filter_new(rows, [[u] for u in UNIT_KEYS], 0)
        append_rows(p, hdr, meta, new)
    print("desc tables done")

    # ---------------- unit set ----------------
    p, hdr, meta, rows = mod_tsv("unit_set_to_unit_junctions_tables")
    new = filter_new(rows, [["false", "", "", "", u, "skv_chongzu"]
                            for u in UNIT_KEYS], 4)
    append_rows(p, hdr, meta, new)
    print("unit_set done")

    # ---------------- custom battle permissions ----------------
    p, hdr, meta, rows = mod_tsv("units_custom_battle_permissions_tables",
                                 "!!czx_all_factions")
    facs = []
    for l in rows:
        pp = l.split("\t")
        if len(pp) > 2 and pp[0] and pp[0] not in facs:
            facs.append(pp[0])
    new = filter_new(rows, [[f, "false", u, "true", "true", "", "", "",
                             "false", "", "false"]
                            for u in UNIT_KEYS for f in facs], 2)
    append_rows(p, hdr, meta, new)
    print("custom_battle +", len(new))

    # ---------------- military groupings ----------------
    p, hdr, meta, rows = mod_tsv(
        "units_to_groupings_military_permissions_tables", "!!czx_all_factions")
    mgs = []
    for l in rows:
        pp = l.split("\t")
        if len(pp) > 1 and pp[1] and pp[1] not in mgs:
            mgs.append(pp[1])
    new = filter_new(rows, [[u, g] for u in UNIT_KEYS for g in mgs], 0)
    append_rows(p, hdr, meta, new)
    print("mil groups +", len(new))

    # ---------------- building_units_allowed ----------------
    p, hdr, meta, rows = mod_tsv("building_units_allowed_tables",
                                 "!!czx_all_factions")
    have_units = {l.split("\t")[1] for l in rows if l.strip()}
    # building list cloned from czx_mangshou rows
    blds = [l.split("\t")[0] for l in rows
            if l.split("\t")[1] == "czx_mangshou"]
    blds = list(dict.fromkeys(blds))
    maxkey = max(int(l.split("\t")[3]) for l in rows
                 if len(l.split("\t")) > 3 and l.split("\t")[3].isdigit())
    new = []
    k = maxkey + 1
    for u in UNIT_KEYS:
        if u in have_units:
            continue
        for bld in blds:
            new.append([bld, u, "0", str(k), "0", "", "false"])
            k += 1
    append_rows(p, hdr, meta, new)
    print("buildings +", len(new), "keys to", k - 1)

    # ---------------- abilities ----------------
    p, hdr, meta, rows = mod_tsv("unit_abilities_tables")
    new = filter_new(rows, [[a["key"], "false", a["icon"], "", a["type"], "",
                             "wh_main_anc_group_uncommon", "false", "false",
                             "passive", "", "false"] for a in ABILITIES], 0)
    append_rows(p, hdr, meta, new)

    p, hdr, meta, rows = mod_tsv("unit_special_abilities_tables")
    # clone the plain passive row so all 74 columns stay aligned
    tpl = None
    for l in rows:
        if l.split("\t")[0] == "czx_ability_ultralisk_chitinous_plating":
            tpl = l.split("\t")
            break
    have = existing_keys(rows, 0)
    new = []
    for i, a in enumerate(ABILITIES):
        if a["key"] in have:
            continue
        d = dict(zip(hdr, tpl))
        d["key"] = a["key"]
        d["unique_id"] = str(ABILITY_UID + i)
        new.append([d.get(c, "") for c in hdr])
    append_rows(p, hdr, meta, new)

    # special ability phases: clone a plain passive phase row
    p, hdr, meta, rows = mod_tsv("special_ability_phases_tables")
    tpl = None
    for l in rows:
        if l.split("\t")[2] == "czx_ability_ultralisk_chitinous_plating":
            tpl = l.split("\t")
            break
    have = existing_keys(rows, 2)
    new = []
    for a in ABILITIES:
        if a["key"] in have:
            continue
        d = dict(zip(hdr, tpl))
        d["id"] = a["key"]
        d.update(a["phase_extra"])
        new.append([d.get(c, "") for c in hdr])
    append_rows(p, hdr, meta, new)

    # phase junctions
    p, hdr, meta, rows = mod_tsv(
        "special_ability_to_special_ability_phase_junctions_tables")
    new = filter_new(rows, [["1", a["key"], a["key"], "true", "false",
                             "false"] for a in ABILITIES], 2)
    append_rows(p, hdr, meta, new)

    # stat effects
    p, hdr, meta, rows = mod_tsv("special_ability_phase_stat_effects_tables")
    new = filter_new(rows, [[a["key"], v, s, h] for a in ABILITIES
                            for s, v, h in a["stats"]], 0)
    append_rows(p, hdr, meta, new)

    # ability -> unit junctions
    p, hdr, meta, rows = mod_tsv(
        "land_units_to_unit_abilites_junctions_tables")
    have = {tuple(l.split("\t")) for l in rows if l.strip()}
    new = [r for r in [[ab, u] for u, abl in UNIT_ABILITIES.items()
                       for ab in abl] if tuple(r) not in have]
    append_rows(p, hdr, meta, new)
    print("abilities done")

    # ---------------- supplies cost ----------------
    p, hdr, meta, rows = mod_tsv("battle_currency_units_cost_values_tables")
    new = filter_new(rows, [[COST_SUPPLIES[u], "supplies_currency", u]
                            for u in UNIT_KEYS], 2)
    append_rows(p, hdr, meta, new)

    # ---------------- battlefield_engines (new file) ----------------
    be_hdr = ["destroyed_model", "destruction_animation", "engine_type",
              "gun_animation_table", "key", "missile_weapon", "model",
              "battle_entity", "asset_folder", "variant",
              "draught_attachment_point", "tech_folder",
              "rider_attachment_point", "destruct_model", "destruct_anim",
              "destruct_meta", "audio_armour_type", "riders_shoot_behaviour",
              "scale"]
    be_dir = MOD / "db" / "battlefield_engines_tables"
    be_dir.mkdir(parents=True, exist_ok=True)
    row = dict(zip(be_hdr, [
        r"warmachines\engines\emp_steam_tank\emp_steam_tank_destroyed_01.wsmodel",
        "emp_steam_tank_destruct", "Generic_No_Crew_Rotate", "wm_steam_tank01",
        "czx_inf_tank_engine", "", "czx_inf_tank", "wh_main_emp_veh_steam_tank",
        "", "", "", r"warmachines\engines\emp_steam_tank\tech", "", "", "",
        "", "war_machine_metal", "all_riders_shooting", "1.0"]))
    be_path = be_dir / "!!czx_swarm_units.tsv"
    with open(be_path, "wb") as f:
        f.write(b"\xef\xbb\xbf")
        f.write(("\t".join(be_hdr) + "\r\n").encode("utf-8"))
        f.write(("#battlefield_engines_tables;23;"
                 "db/battlefield_engines_tables/!!czx_swarm_units\r\n")
                .encode("utf-8"))
        f.write(("\t".join(row[c] for c in be_hdr) + "\r\n").encode("utf-8"))
    print("battlefield_engines written")

    # ---------------- loc ----------------
    loc = MOD / "text" / "db" / "!!!czx_swarm_units_CN.loc.tsv"
    have_loc = {l.split("\t")[0] for l in
                loc.read_text(encoding="utf-8-sig").splitlines()
                if l.strip()}
    loc_lines = []
    for u in UNIT_KEYS:
        loc_lines.append(f"units_onscreen_name_{u}\t{CN_NAME[u]}\t")
        loc_lines.append(f"land_units_onscreen_name_{u}\t{CN_NAME[u]}\t")
        loc_lines.append(
            f"unit_description_short_texts_text_{u}\t{SHORT[u]}\t")
        loc_lines.append(
            f"unit_description_historical_texts_text_{u}\t{DESC[u]}\t")
    for a in ABILITIES:
        loc_lines.append(
            f"unit_abilities_onscreen_name_{a['key']}\t{a['cn_name']}\t")
        loc_lines.append(
            f"unit_abilities_tooltip_text_{a['key']}\t{a['cn_tip']}\t")
    loc_lines = [l for l in loc_lines
                 if l.split("\t")[0] not in have_loc]
    with open(loc, "ab") as f:
        for l in loc_lines:
            f.write((l + "\r\n").encode("utf-8"))
    print("loc +", len(loc_lines))


if __name__ == "__main__":
    main()
