# -*- coding: utf-8 -*-
"""Generate DB fragment rows for zzz_czx_digimon units from ROSTER.tsv.

Idempotent: skips rows whose unit key already exists in the fragment.
Only emits rows for units with `ported` models unless --all is given
(ported = the unit key exists in variants_tables already, or listed via --units).

Usage:
  python tools/gen_digimon_db.py --units czx_dgm_wargreymon,czx_dgm_omegamon
  python tools/gen_digimon_db.py --all
"""
import argparse
import json
import sys
from pathlib import Path

MOD = Path(r"E:\Code\WH3-modding\mod_files\zzz_czx_digimon")
ROSTER = MOD / "ROSTER.tsv"
T = "\t"

# stat-band defaults when the roster row leaves a field implicit
# NOTE: anim/entity are placeholder vanilla keys for bipeds. Custom-skeleton
# units need their own animsuite bin + a battle_animations_table row
# (man_animation=<bin stem>, skeleton=<fit skeleton>) — see wargreymon.
STAGE_DEFAULTS = {
    "rookie":   dict(cls="inf_melee", spacing="wh_main_infantry", gse="small",
                     weapon="wh_dlc03_bst_gor_axe", shield="none",
                     entity="wh_main_infantry_standard_blood_dismembers",
                     anim="hu1_empire_sword_and_shield", armour_tmpl="wh2_main_body_{}"),
    "champion": dict(cls="inf_melee", spacing="wh_dlc03_bst_gor_rabble", gse="medium",
                     weapon="wh_dlc03_bst_gor_axe", shield="none",
                     entity="wh_dlc03_bst_inf_gor_blood_dismembers",
                     anim="hu6_gor_axe_and_shield", armour_tmpl="wh2_main_body_{}"),
    "ultimate": dict(cls="inf_melee", spacing="wh_main_monster", gse="large",
                     weapon="wh_dlc03_bst_minotaur_great_axe", shield="none",
                     entity="wh_dlc03_bst_inf_gor_blood_dismembers",
                     anim="hu6_gor_axe_and_shield", armour_tmpl="wh2_main_body_{}"),
    "mega":     dict(cls="inf_melee", spacing="wh_main_monster", gse="large",
                     weapon="wh2_main_lzd_stegadon", shield="none",
                     entity="wh_dlc03_bst_mon_minotaur_blood",
                     anim="hu6_gor_axe_and_shield", armour_tmpl="wh2_main_body_{}"),
    "boss":     dict(cls="inf_melee", spacing="wh_main_monster", gse="large",
                     weapon="wh2_main_lzd_stegadon", shield="none",
                     entity="wh_dlc03_bst_mon_minotaur_blood",
                     anim="hu6_gor_axe_and_shield", armour_tmpl="wh2_main_body_{}"),
}


def load_roster():
    lines = ROSTER.read_text(encoding="utf-8").splitlines()
    hdr = lines[0].split(T)
    out = []
    for l in lines[1:]:
        if not l or l.startswith("#"):
            continue
        f = l.split(T)
        out.append(dict(zip(hdr, f)))
    return out


# ---------- canonical-move ability system ----------
# Abilities are keyed czx_dgm_ab_<unit>_<n> and generated into
# !!czx_digimon_abilities.tsv fragments. Headers are borrowed verbatim from the
# swarm mod fragments so column layout never drifts.
SWARM_DB = Path(r"E:\Code\WH3-modding\mod_files\zzz_czx_swarm_units\db")

# move-name -> archetype. Names not listed fall back to classify_move().
MOVE_ARCH = {
    # explosions / nukes
    "盖亚能量炮": "explosion", "盖亚能量炮ZERO": "explosion", "后辐射": "explosion",
    "辉煌爆破": "explosion", "终极辉煌爆破": "explosion", "日冕飞溅": "explosion",
    "等离子柱": "explosion", "极乐净土": "explosion", "极乐净土X": "explosion",
    "君往何处": "explosion", "极限圣战": "explosion", "极限圣战X": "explosion",
    "全部删除": "explosion", "百万死亡": "explosion", "十亿死亡": "explosion",
    "神圣烈焰": "explosion", "启示录之光": "explosion", "星光爆破": "explosion",
    "震动脉冲": "explosion", "灾难之日": "explosion", "混沌降阶": "explosion",
    "堕落圣光": "explosion", "时空破灭": "explosion", "死亡演化": "explosion",
    "宏伟十字架": "explosion", "生死交错": "explosion", "种子炸弹": "explosion",
    "天国之门": "explosion", "七重天堂": "explosion", "梵笔闪": "explosion",
    # vortex / storm
    "战斗龙卷风": "vortex", "圣台风": "vortex", "倒龙卷": "vortex",
    "暴风螺旋": "vortex", "烈焰龙卷": "vortex", "火焰飓风": "vortex",
    "大海啸": "vortex", "终极湍流": "vortex", "极寒暴风雪": "vortex",
    "暴风神气旋": "vortex", "螺旋翼": "missiles", "失乐园": "vortex", "暗黑": "vortex",
    # keyword-ambiguous names pinned explicitly
    "廿年之路": "melee", "金属风暴X": "missiles", "剑灵风暴X": "missiles",
    "巨剪钳夹": "melee", "爆尾横扫": "melee", "爆炎火焰弹": "missiles",
    "排气烈焰": "missiles", "冰牙撕咬": "melee", "拉拉旋转": "melee",
    "微笑拍打": "melee", "加农球冲撞": "melee", "圣枪突刺": "melee",
    "双重境界": "melee", "偃月大回旋": "melee", "幻龙冲击": "missiles",
    "水流冲击": "missiles", "湮没猎鸟": "missiles", "高雅蔷薇": "melee",
    "炎狱魔镰": "melee", "神圣之足": "melee", "死亡之爪": "melee",
    "影翼斩": "missiles", "皇家救星": "melee", "皇家救星X": "melee",
    "超级电击": "missiles", "植物电击": "missiles", "龙兽克星": "melee",
    "剑灵突击": "missiles", "剑灵暴走": "missiles",
    # defence / ward
    "勇气之盾": "ward", "聚合光束盾": "ward", "金刚界曼荼罗": "ward",
    "死符": "ward", "升天光环": "ward",
    # regen
    "博爱之吻": "regen",
    # frenzy-style passive
    "蔷薇之心": "frenzy",
    # active rage buff
    "狂战士之吼": "buff", "战损狂暴": "buff",
    # hex / debuff
    "毒蔓藤": "hex", "小狗咆哮": "hex", "速入噩梦": "hex", "妖精粉": "hex",
    "恶梦扩散": "hex", "猫眼凝视": "hex", "震魂吼": "hex", "花环束缚": "hex",
    "诱惑花粉": "hex", "禁断诱惑": "hex", "灵魂数据化": "hex",
    "悲伤蓝调": "hex", "黑暗绝望": "hex", "时空悖论": "hex",
}

_ARCH_FALLBACK = "missiles"  # unknown moves default to a projectile attack


def classify_move(name):
    if name in MOVE_ARCH:
        return MOVE_ARCH[name]
    if any(k in name for k in "龙卷/旋风/风暴/气旋/湍流/飓风/海啸".split("/")):
        return "vortex"
    if any(k in name for k in "爆/破灭/死亡/删除/湮/浩劫/净土".split("/")):
        return "explosion"
    if any(k in name for k in "炮/热线/光束/激光/弹/射击/矢/箭/标枪/雷电/闪电/雷光/吐息/喷射/加农/冲击波/火焰/吐/枪/飞翼/流星/陨/粉/波".split("/")):
        return "missiles"
    if any(k in name for k in "剑/斩/刃/爪/蹴/踢/拳/鞭/槌/俯冲/撞击/冲/击/刀/头槌/耳光/掌掴/武装/裁决/绞杀/碎击/焰".split("/")):
        return "melee"
    if any(k in name for k in "盾/结界/圣光/光环/天堂/门/符/铠/装".split("/")):
        return "ward"
    return _ARCH_FALLBACK


# archetype -> generator spec. `tier` scales magnitudes.
# usa values mirror swarm templates verbatim; unset cols default to "".
def _usa_base():
    return dict(
        active_time="-1.0", recharge_time="-1.0", num_uses="-1",
        effect_range="0.0", affect_self="true", num_effected_friendly_units="0",
        num_effected_enemy_units="0", update_targets_every_frame="false",
        initial_recharge="-1.0", target_friends="false", target_enemies="false",
        target_ground="false", target_intercept_range="0.0",
        always_affect_self="false", only_affect_target="false",
        wind_up_time="0.0", passive="true", mana_cost="0.0", min_range="0.0",
        miscast_chance="0.0", voiceover_state="vo_battle_special_ability_generic_response",
        additional_melee_cp="0.0", additional_missile_cp="0.0",
        target_ground_under_allies="false", target_ground_under_enemies="false",
        miscast_global_bonus="true", target_self="false", use_loop_stance="false",
        update_phase_by_ability_duration="false", spawn_is_transformation="false",
        spawn_is_decoy="false", only_affect_owned_units="false",
        current_mana_moves_to_reserve="false",
        spawn_shares_health_and_fatigue="false", affect_siege_equipment="true",
        shared_recharge_time="-1.0", intensity_based_activation="false",
        autoresolver_usage="buff_self", autoresolver_targets="1",
        display_stops_when_display_expires="false", autoresolve_cp_multiplier="1.0",
        can_be_copied_to_transformation_unit="true",
    )


def _phase_base(duration="-1.0", effect_type="positive"):
    return dict(
        duration=duration, effect_type=effect_type, cant_move="false",
        freeze_fatigue="false", fatigue_change_ratio="0.0",
        inspiration_aura_range_mod="0.0", ability_recharge_change="0.0",
        hp_change_frequency="0.0", damage_amount="0", max_damaged_entities="0",
        resurrect="false", mana_regen_mod="0.0", mana_max_depletion_mod="0.0",
        imbue_magical="false", imbue_ignition="0", is_hidden_in_ui="false",
        affects_allies="true", affects_enemies="true", replenish_ammo="0.0",
        freeze_recharge="false", heal_amount="0.0", barrier_heal_amount="0.0",
        remove_magical="false", execute_ratio="0.0",
    )


def ability_spec(arch, tier):
    """Return (ua_fields, usa_fields, phase_fields|None, effects, junc, tip)."""
    f = 1.0 + 0.25 * (tier - 1)  # tier1=1.0 .. tier5=2.0
    ua = dict(requires_effect_enabling="false",
              uniqueness="wh_main_anc_group_uncommon", is_unit_upgrade="false",
              is_hidden_in_ui="false", is_hidden_in_ui_for_enemy="false")
    tip = {
        "explosion": "凝聚全身能量释放毁灭性爆炸，重创周围敌军。",
        "missiles": "向前方敌军发射能量弹幕。",
        "vortex": "在目标区域召唤肆虐的漩涡，持续吞噬敌阵。",
        "melee": "一定时间内大幅提升近战攻击与武器威力。",
        "buff": "进入狂暴状态，攻击与冲锋大幅强化，但防御下降。",
        "frenzy": "被动强化冲锋与近战攻击。",
        "ward": "被动强化护甲与远程抗性。",
        "regen": "战斗中持续恢复生命值。",
        "hex": "削弱周围敌军的攻击、防御与士气。",
        "poison": "攻击附带毒素效果。",
    }[arch]
    if arch == "explosion":
        ua.update(icon_name="wh2_dlc09_lord_abilities_venom_wave",
                  type="wh_type_explosion", is_unit_upgrade="true",
                  source_type="active")
        usa = _usa_base()
        usa.update(active_time="3.0", recharge_time="90.0",
                   num_uses=str(2 + (tier >= 4)), affect_self="true",
                   passive="false", initial_recharge="0.0",
                   targetting_aoe="wh_abilities_generic_explosion",
                   vortex="wh2_dlc09_abilities_venom_wave",
                   ai_usage="aoe_centred_on_self", audio="wh_group_character",
                   additional_melee_cp="150.0", autoresolver_usage="damage_aoe",
                   autoresolver_targets="2")
        return ua, usa, None, [], dict(target_self="true"), tip
    if arch == "missiles":
        ua.update(icon_name="wh2_dlc10_unit_abilities_frost_breath",
                  type="wh_type_magic_missiles", source_type="active")
        usa = _usa_base()
        usa.update(recharge_time=str(75.0 - 5.0 * tier),
                   num_uses=str(2 + (tier >= 3)), affect_self="false",
                   passive="false", initial_recharge="0.0",
                   activated_projectile="wh2_dlc10_unit_abilities_frost_breath",
                   target_enemies="true", target_intercept_range="90.0",
                   wind_up_time="1.0", wind_up_stance="cast_forward_short",
                   targetting_aoe="wh_spell_generic_missiles",
                   passive_aoe="wh_spell_generic_missiles",
                   ai_usage="projectile_explosive_ap",
                   audio="wh_main_spell_bound_fireball",
                   special_ability_display="fire_short",
                   voiceover_state="vo_battle_special_ability_spell_cast_negative",
                   additional_missile_cp="50.0", autoresolver_usage="damage_unit")
        return ua, usa, None, [], dict(target_self="true"), tip
    if arch == "vortex":
        ua.update(icon_name="wh2_dlc09_lord_abilities_sand_storm",
                  type="wh_type_vortex", is_unit_upgrade="true",
                  source_type="active")
        usa = _usa_base()
        usa.update(active_time="14.0", recharge_time="90.0", num_uses="3",
                   affect_self="false", passive="false", initial_recharge="0.0",
                   target_enemies="true", target_ground="true",
                   target_intercept_range="100.0", wind_up_time="3.0",
                   targetting_aoe="wh_abilities_generic_vortex",
                   passive_aoe="wh_abilities_generic_vortex",
                   vortex="wh2_dlc09_abilities_sand_storm",
                   ai_usage="vortex_ap", audio="wh_group_unit_click",
                   additional_missile_cp="150.0",
                   autoresolver_usage="damage_aoe", autoresolver_targets="3")
        return ua, usa, None, [], dict(target_self="false"), tip
    if arch == "melee":
        ua.update(icon_name="wh_main_unit_passive_frenzy",
                  type="wh_type_augment", is_unit_upgrade="true",
                  source_type="active")
        usa = _usa_base()
        usa.update(active_time="25.0", recharge_time="90.0", passive="false",
                   initial_recharge="0.0",
                   targetting_aoe="wh_abilities_generic_buff_no_ring",
                   ai_usage="augment_melee_self", audio="wh_group_character",
                   additional_melee_cp="150.0", autoresolver_usage="buff_self")
        ph = _phase_base("25.0")
        ph.update(imbue_magical="true",
                  phase_display="wh_main_generic_buff_attack",
                  phase_audio="wh_ability_positive")
        fx = [(f"{1 + 0.15 * tier:.2f}", "stat_melee_damage_base", "mult"),
              (f"{1 + 0.15 * tier:.2f}", "stat_melee_damage_ap", "mult"),
              (f"{5 + 2 * tier:.0f}", "stat_melee_attack", "add"),
              (f"{1 + 0.05 * tier:.2f}", "stat_charge_bonus", "mult")]
        return ua, usa, ph, fx, dict(target_self="true"), tip
    if arch == "buff":
        ua.update(icon_name="wh2_dlc10_lord_abilities_red_ruin",
                  type="wh_type_augment", is_unit_upgrade="true",
                  source_type="active")
        usa = _usa_base()
        usa.update(active_time="35.0", recharge_time="90.0", passive="false",
                   initial_recharge="0.0",
                   targetting_aoe="wh_abilities_generic_buff_no_ring",
                   ai_usage="augment_melee_self", audio="wh_group_character",
                   additional_melee_cp="150.0", autoresolver_usage="buff_self")
        ph = _phase_base("35.0")
        ph.update(phase_display="wh_main_generic_buff_attack",
                  phase_audio="wh_ability_positive")
        fx = [(f"{1 + 0.2 * tier:.2f}", "stat_melee_damage_ap", "mult"),
              (f"{1 + 0.2 * tier:.2f}", "stat_melee_damage_base", "mult"),
              (f"{-12 - 2 * tier:.0f}", "stat_melee_defence", "add"),
              (f"{1 + 0.05 * tier:.2f}", "stat_charge_bonus", "mult"),
              ("1.15", "scalar_speed", "mult"),
              (f"{5 + tier:.0f}", "stat_melee_attack", "add")]
        return ua, usa, ph, fx, dict(target_self="true"), tip
    if arch == "frenzy":
        ua.update(icon_name="wh_main_unit_passive_frenzy", type="wh_type_augment",
                  source_type="passive")
        usa = _usa_base()
        ph = _phase_base()
        fx = [(f"{1 + 0.05 * tier:.2f}", "stat_charge_bonus", "mult"),
              (f"{4 + tier:.0f}", "stat_melee_attack", "add")]
        return ua, usa, ph, fx, dict(target_self="true"), tip
    if arch == "ward":
        ua.update(icon_name="wh_magic_item_passive_armour",
                  type="wh_type_augment", source_type="passive")
        usa = _usa_base()
        ph = _phase_base()
        fx = [(f"{8 + 4 * tier:.0f}", "stat_armour", "add"),
              (f"{8 + 4 * tier:.0f}", "stat_resistance_missile", "add"),
              (f"{4 + 2 * tier:.0f}", "stat_resistance_all", "add")]
        return ua, usa, ph, fx, dict(target_self="true"), tip
    if arch == "regen":
        ua.update(icon_name="wh_main_unit_passive_regeneration",
                  type="wh_type_regeneration", source_type="passive",
                  uniqueness="wh_main_anc_group_common")
        usa = _usa_base()
        usa.update(targetting_aoe="wh_abilities_generic_regeneration_no_ring",
                   additional_melee_cp="50.0", additional_missile_cp="50.0")
        ph = _phase_base()
        ph.update(hp_change_frequency="1.0",
                  heal_amount="0.001" if tier < 5 else "0.0015")
        return ua, usa, ph, [], dict(target_self="true"), tip
    if arch == "hex":
        ua.update(icon_name="wh2_dlc15_unit_passive_nightgoblin_poison",
                  type="wh_type_area_of_hexes", is_unit_upgrade="true",
                  source_type="active")
        usa = _usa_base()
        usa.update(active_time="20.0", recharge_time="90.0",
                   effect_range="45.0", affect_self="false",
                   num_effected_enemy_units="-1", passive="false",
                   initial_recharge="0.0",
                   targetting_aoe="wh_abilities_generic_debuff",
                   passive_aoe="wh_abilities_generic_debuff",
                   active_aoe="wh_abilities_generic_debuff",
                   ai_usage="augment_melee_self", audio="wh_group_character",
                   additional_missile_cp="150.0",
                   autoresolver_usage="debuff_unit", autoresolver_targets="3")
        ph = _phase_base("20.0", "negative")
        ph.update(affects_allies="false", affects_enemies="true",
                  phase_audio="wh_ability_negative")
        fx = [(f"{-4 - 2 * tier:.0f}", "stat_melee_attack", "add"),
              (f"{-4 - 2 * tier:.0f}", "stat_melee_defence", "add"),
              (f"{-4 - tier:.0f}", "stat_morale", "add")]
        return ua, usa, ph, fx, dict(target_self="false",
                                     target_enemies="true"), tip
    if arch == "speed":
        ua.update(icon_name="wh2_main_unit_passive_scurry_away",
                  type="wh_type_augment", source_type="passive")
        usa = _usa_base()
        ph = _phase_base()
        fx = [("1.15", "scalar_speed", "mult"),
              ("2.0", "scalar_entity_acceleration_modifier", "mult")]
        return ua, usa, ph, fx, dict(target_self="true"), tip
    if arch == "poison":
        ua.update(icon_name="wh2_dlc15_unit_passive_nightgoblin_poison",
                  type="wh_type_augment", source_type="passive")
        usa = _usa_base()
        ph = _phase_base()
        ph["imbue_contact"] = "wh_main_unit_contact_poison"
        return ua, usa, ph, [], dict(target_self="true"), tip
    raise ValueError(arch)


_UID = [789910000]


def _uid_next(lines, hdr):
    """unique_id must be globally unique AND stable across generator runs —
    seed from the max already present in the file."""
    if "unique_id" in hdr:
        i = hdr.index("unique_id")
        for r in lines:
            v = r.split("\t")[i] if len(r.split("\t")) > i else ""
            if v.strip().isdigit():
                _UID[0] = max(_UID[0], int(v))
    _UID[0] += 1
    return str(_UID[0])


def _frag_header(tbl):
    p = SWARM_DB / tbl / "!!czx_swarm_units.tsv"
    ls = p.read_text(encoding="utf-8").splitlines()
    return ls[0], ls[1].replace("!!czx_swarm_units", "!!czx_digimon_abilities")


def ensure_frag(tbl):
    """Ensure db/<tbl>/!!czx_digimon_abilities.tsv exists; return (path, hdr, lines)."""
    p = MOD / "db" / tbl / "!!czx_digimon_abilities.tsv"
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        h, meta = _frag_header(tbl)
        p.write_text(h + "\n" + meta + "\n", encoding="utf-8")
    return load_frag("db/" + tbl + "/!!czx_digimon_abilities.tsv")


def emit_ability(u, idx, move):
    """Write one canonical-move ability for unit u; returns ability key."""
    key = f"czx_dgm_ab_{u['key'][8:]}_{idx}"
    arch = classify_move(move)
    ua, usa, ph, fx, junc, tip = ability_spec(arch, int(u["tier"]))

    p, hdr, lines = ensure_frag("unit_abilities_tables")
    if not already(lines, key):
        row = [""] * len(hdr)
        setf(row, hdr, "key", key)
        for n, v in ua.items():
            setf(row, hdr, n, v)
        lines.append(T.join(row)); save(p, lines)

    p, hdr, lines = ensure_frag("unit_special_abilities_tables")
    if not already(lines, key):
        usa["unique_id"] = _uid_next(lines, hdr)
        row = [""] * len(hdr)
        setf(row, hdr, "key", key)
        for n, v in usa.items():
            setf(row, hdr, n, v)
        lines.append(T.join(row)); save(p, lines)

    if ph is not None:
        p, hdr, lines = ensure_frag("special_ability_phases_tables")
        if not already(lines, key):
            row = [""] * len(hdr)
            setf(row, hdr, "id", key)
            for n, v in ph.items():
                setf(row, hdr, n, v)
            lines.append(T.join(row)); save(p, lines)
        p, hdr, lines = ensure_frag(
            "special_ability_to_special_ability_phase_junctions_tables")
        if not already(lines, key):
            row = [""] * len(hdr)
            setf(row, hdr, "order", "1")
            setf(row, hdr, "phase", key)
            setf(row, hdr, "special_ability", key)
            setf(row, hdr, "target_self", junc.get("target_self", "true"))
            setf(row, hdr, "target_friends", junc.get("target_friends", "false"))
            setf(row, hdr, "target_enemies", junc.get("target_enemies", "false"))
            lines.append(T.join(row)); save(p, lines)
        if fx:
            p, hdr, lines = ensure_frag("special_ability_phase_stat_effects_tables")
            if not already(lines, key):
                for val, stat, how in fx:
                    row = [""] * len(hdr)
                    setf(row, hdr, "phase", key)
                    setf(row, hdr, "value", val)
                    setf(row, hdr, "stat", stat)
                    setf(row, hdr, "how", how)
                    lines.append(T.join(row))
                save(p, lines)

    # unit junction
    rel = "db/land_units_to_unit_abilites_junctions_tables/!!czx_digimon_units.tsv"
    p, hdr, lines = load_frag(rel)
    if not any(l.split(T)[0] == key for l in lines[2:] if l.strip()):
        row = [""] * len(hdr)
        setf(row, hdr, "ability", key)
        setf(row, hdr, "land_unit", u["key"])
        lines.append(T.join(row)); save(p, lines)

    # loc
    lp = MOD / "text" / "db" / "!!!czx_digimon_CN.loc.tsv"
    loc = lp.read_text(encoding="utf-8").splitlines()
    nk = "unit_abilities_onscreen_name_" + key
    tk = "unit_abilities_tooltip_text_" + key
    if not any(l.startswith(nk + T) for l in loc):
        loc.append(nk + T + move + T)
        loc.append(tk + T + f"{u['cn']}的必杀技「{move}」——{tip}" + T)
        lp.write_text("\n".join(loc) + "\n", encoding="utf-8")
    print(f"    +ab {key} [{arch}] {move}")
    return key


def load_frag(rel):
    p = MOD / rel
    lines = p.read_text(encoding="utf-8").splitlines()
    return p, lines[0].split(T), lines


def save(p, lines):
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")


def already(lines, key):
    return any(key in l.split(T) for l in lines[2:])


def setf(row, hdr, name, val):
    for i, h in enumerate(hdr):
        if h.lstrip("﻿") == name:
            row[i] = val
            return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--units", default="")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--entity", default="")
    ap.add_argument("--weapon", default="")
    ap.add_argument("--mod", default="")
    args = ap.parse_args()
    if args.mod:
        global MOD, ROSTER
        MOD = Path(r"E:\Code\WH3-modding\mod_files") / args.mod
        ROSTER = MOD / "ROSTER.tsv"

    roster = load_roster()
    want = set(args.units.split(",")) if args.units else None
    units = [r for r in roster if args.all or (want and r["key"] in want)]
    if not units:
        print("no units selected"); return

    for u in units:
        key, stage = u["key"], u["stage"]
        d = dict(STAGE_DEFAULTS[stage])
        n = int(u["num_men"])
        if n == 1:
            d["weapon"] = "wh2_main_lzd_stegadon"
        elif n <= 8:
            d["weapon"] = "wh_dlc03_bst_minotaur_great_axe"
        if n <= 8 and stage != "rookie":
            d["spacing"] = "wh_main_monster"
            d["gse"] = "large"
        # optional roster/CLI overrides for custom-skeleton units
        d["anim"] = u.get("anim") or d["anim"]
        d["entity"] = u.get("entity") or args.entity or d["entity"]
        d["weapon"] = u.get("weapon") or args.weapon or d["weapon"]
        skel_name = u.get("skel", "")
        print("==", key, stage, u["form"], f"x{n}")

        # --- land_units ---
        rel = "db/land_units_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            vals = dict(
                accuracy="0", armour=d["armour_tmpl"].format(u["armour"]),
                campaign_action_points="2100", category="inf_melee",
                charge_bonus=u["charge"], **{"class": "inf_mel"},
                historical_description_text=key, key=key,
                man_animation=d["anim"], man_entity=d["entity"],
                melee_attack=u["ma"], melee_defence=u["md"], morale=u["morale"],
                bonus_hit_points=u["hp"], mount="", num_mounts="0",
                primary_melee_weapon=d["weapon"], primary_missile_weapon="",
                rank_depth="1", shield=d["shield"], short_description_text=key,
                spacing=d["spacing"], training_level="trained",
                articulated_record="", engine="", is_male="true",
                visibility_spotting_range_min="40.0",
                visibility_spotting_range_max="1500.0",
                attribute_group="czx_dgm_" + u["attr"],
                spot_dist_tree="60", spot_dist_scrub="80", reload="0",
                selection_vo="vo_sel_default",
                selected_vo_secondary="vo_sel_default",
                selected_vo_tertiary="vo_sel_culture",
                hiding_scalar="1.0",
                ground_stat_effect_group=d["gse"],
                secondary_ammo="0", primary_ammo="0",
                damage_mod_flame="0", damage_mod_magic="0", num_engines="0",
                damage_mod_physical="0", damage_mod_missile="0",
                damage_mod_all="0", ai_usage_group="melee_gatecrusher",
                can_skirmish="false", can_brace="false",
                mounted_draught="false", sync_locomotion="false",
                capture_tier="medium", key_building_capture_tier="medium",
                score_capture_tier="medium",
                harmony_amplification_type="", first_person="",
                ar_unit_category="domination_monsters", healing_power="",
                spell_mastery="", infinite_secondary_ammo="false",
                default_guard_mode="false",
            )
            # mounted_draught column name in file is 'mounted_draughts'
            vals["mounted_draughts"] = vals.pop("mounted_draught")
            for name, v in vals.items():
                setf(row, hdr, name, v)
            lines.append(T.join(row))
            save(p, lines)
            print("  +land_units")

        # --- main_units ---
        rel = "db/main_units_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            is_sem = u["num_men"] == "1"
            vals = {
                "additional_building_requirement": "", "campaign_cap": "-1",
                "caste": "monster" if is_sem else "monstrous_infantry",
                "create_time": "2", "is_naval": "false", "land_unit": key,
                "num_men": u["num_men"], "multiplayer_cap": "0",
                "multiplayer_cost": u["cost"],
                "naval_unit": "wh_main_shp_transport", "num_ships": "1",
                "min_men_per_ship": "1", "max_men_per_ship": u["num_men"],
                "recruitment_cost": u["cost"], "unit": key,
                "upkeep_cost": str(int(int(u["cost"]) * 0.25)),
                "weight": "very_heavy" if is_sem else "medium",
                "resource_requirement": "", "special_edition_mask": "0",
                "in_encyclopedia": "true",
                "audio_voiceover_culture": "wh2_main_vo_culture_Stegadon",
                "ui_unit_group_land": "chong_zu",
                "tier": u["tier"],
                "is_high_threat": "true" if is_sem else "false",
                "porthole_camera": "liz_stegadon" if is_sem else "bst_gor",
                "mount": "", "use_hitpoints_in_campaign": "true",
                "porthole_composite_scene": "", "melee_cp": u["cost"] + ".0",
                "missile_cp": "0.0", "can_siege": "true",
                "audio_voiceover_culture_override": "vo_culture_None",
                "restrict_xp_gain_in_campaign": "false",
                "audio_voiceover_actor_group": "wh_main_vo_actor_default",
                "food_cost": "0", "has_spoken_vo": "false",
                "is_monstrous": "true" if is_sem else "false",
                "multiplayer_qb_cap": "2",
                "vo_is_dragon": "false", "vo_is_dinosaur": "true",
                "optional_ui_element": "", "barrier_health": "0.0",
                "can_be_bribed": "true", "point_allowance_weight": "1",
                "is_renown": "false",
            }
            for name, v in vals.items():
                setf(row, hdr, name, v)
            lines.append(T.join(row))
            save(p, lines)
            print("  +main_units")

        # --- unit_variants / variants ---
        rel = "db/unit_variants_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            for name, v in {"faction": "", "name": key, "unit": key,
                            "variant": key, "unit_card": key}.items():
                setf(row, hdr, name, v)
            lines.append(T.join(row)); save(p, lines); print("  +unit_variants")

        rel = "db/variants_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            for name, v in {"variant_name": key, "tech_folder": "",
                            "variant_filename": key, "low_poly_filename": "",
                            "mount_scale": "1.0", "scale": "1.0",
                            "scale_variation": "0.05",
                            "super_low_poly_filename": ""}.items():
                setf(row, hdr, name, v)
            lines.append(T.join(row)); save(p, lines); print("  +variants")

        # --- unit_set junction ---
        rel = "db/unit_set_to_unit_junctions_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            for name, v in {"exclude": "false", "unit_caste": "",
                            "unit_category": "", "unit_class": "",
                            "unit_record": key, "unit_set": "skv_chongzu"}.items():
                setf(row, hdr, name, v)
            lines.append(T.join(row)); save(p, lines); print("  +unit_set")

        # --- descriptions ---
        for rel in ("db/unit_description_historical_texts_tables/!!czx_digimon_units.tsv",
                    "db/unit_description_short_texts_tables/!!czx_digimon_units.tsv"):
            p, hdr, lines = load_frag(rel)
            if not already(lines, key):
                row = [key] + [""] * (len(hdr) - 1)
                lines.append(T.join(row)); save(p, lines)
                print("  +", rel.split("/")[1])

        # --- abilities junction: single_entity for true SEM only ---
        if stage in ("mega", "boss") and u["num_men"] == "1":
            rel = "db/land_units_to_unit_abilites_junctions_tables/!!czx_digimon_units.tsv"
            p, hdr, lines = load_frag(rel)
            if not already(lines, key):
                row = [""] * len(hdr)
                setf(row, hdr, "ability", "wh3_main_unit_passive_single_entity")
                setf(row, hdr, "land_unit", key)
                lines.append(T.join(row)); save(p, lines)
                print("  +single_entity")

        # --- cost values ---
        rel = "db/battle_currency_units_cost_values_tables/!!czx_digimon_units.tsv"
        p, hdr, lines = load_frag(rel)
        if not already(lines, key):
            row = [""] * len(hdr)
            setf(row, hdr, "cost_value", u["cost"] + ".0")
            setf(row, hdr, "currency_type", "supplies_currency")
            setf(row, hdr, "item_type", key)
            lines.append(T.join(row)); save(p, lines); print("  +cost_values")

        # --- battle_animations_table (custom skeleton only) ---
        if skel_name:
            rel = "db/battle_animations_table_tables/!!czx_digimon_units.tsv"
            p, hdr, lines = load_frag(rel)
            anim_key = d["anim"]
            if not any(l.split(T)[0].lstrip("﻿") == anim_key for l in lines[2:]):
                lines.append(anim_key + T + skel_name)
                save(p, lines)
                print("  +battle_animations", anim_key, "->", skel_name)

        # --- canonical-move abilities ---
        for i, move in enumerate(
                [m for m in (u.get("abilities") or "").split("|") if m][:4], 1):
            emit_ability(u, i, move)

    print("done")


if __name__ == "__main__":
    main()
