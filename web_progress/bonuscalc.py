# -*- coding: utf-8 -*-
"""Resolve save-captured campaign effect bundles into unit stat bonuses.

bundle key -> junction rows (effect, scope, value) + inline effects
trait    -> character_trait_levels -> trait_level_effects rows
skill    -> character_skill_level_to_effects_junctions rows (level<=learned)
ancillary-> ancillary_to_effects rows

Each (effect, scope, value) is checked against campaign_effect_scopes
(holder kind / target / ownership / location reach). Effects resolving to
unit stats feed per-unit stat deltas; the rest list as non-stat text.
"""

# bonus_value_id -> (stat_key, how): add=flat, pct=%of base,
# res=percentage points, flag=boolean, ""=not a card stat
BVID_MAP = {
    "melee_attack_mod": ("melee_attack", "add"),
    "melee_attack_mod_mult": ("melee_attack", "pct"),
    "melee_defence_mod": ("melee_defence", "add"),
    "melee_defence_mod_mult": ("melee_defence", "pct"),
    "armour_mod": ("armour_value", "add"),
    "armour_mod_mult": ("armour_value", "pct"),
    "morale": ("morale", "add"),
    "leadership": ("morale", "add"),
    "charge_add": ("charge_bonus", "add"),
    "charge_bonus": ("charge_bonus", "add"),
    "charge_bonus_for_land_units": ("charge_bonus", "add"),
    "charge_bonus_mod_mult": ("charge_bonus", "pct"),
    "melee_damage_mod_add": ("melee_damage", "add"),
    "melee_damage_mod_mult": ("melee_damage", "pct"),
    "melee_damage_ap_mod_add": ("melee_ap_damage", "add"),
    "melee_damage_ap_mod_mult": ("melee_ap_damage", "pct"),
    "missile_damage_mod_add": ("missile_damage", "add"),
    "missile_damage_mod_mult": ("missile_damage", "pct"),
    "missile_damage_ap_mod_add": ("missile_ap_damage", "add"),
    "missile_damage_ap_mod_mult": ("missile_ap_damage", "pct"),
    "missile_explosion_damage_ap_mod_add": ("missile_ap_damage", "add"),
    "missile_explosion_damage_mod_add": ("missile_damage", "add"),
    "ammo_mod": ("ammo", "pct"),
    "range_mod": ("range", "pct"),
    "range_mod_add": ("range", "add"),
    "reload": ("reload", "pct"),
    "accuracy_mod": ("accuracy", "pct"),
    "mod_land_movement_battle": ("speed", "pct"),
    "mod_land_movement_campaign": ("", ""),
    "unit_mass_percentage_mod": ("mass", "pct"),
    "missile_block_chance_mod": ("shield", "res"),
    "damage_vs_infantry": ("melee_bonus_v_infantry", "add"),
    "damage_vs_large_entities": ("melee_bonus_v_large", "add"),
    "unit_damage_resistance_physical_mod": ("physical_resistance", "res"),
    "unit_damage_resistance_missile_mod": ("missile_resistance", "res"),
    "unit_damage_resistance_magic_mod": ("magic_resistance", "res"),
    "unit_damage_resistance_flame_mod": ("fire_resistance", "res"),
    "unit_damage_resistance_all_mod": ("ward_save", "res"),
    "damage_resistance_physical_mod": ("physical_resistance", "res"),
    "damage_resistance_missile_mod": ("missile_resistance", "res"),
    "damage_resistance_magic_mod": ("magic_resistance", "res"),
    "damage_resistance_flame_mod": ("fire_resistance", "res"),
    "unit_fatigue_resistance_mod": ("fatigue_resistance", "pct"),
    "unit_xp_mod": ("unit_rank", "add"),
    "battle_barrier_health": ("barrier", "add"),
    "battle_barrier_health_mod": ("barrier", "pct"),
    "hitpoints_mod": ("health", "pct"),
    "general_bodyguard_size_mod": ("health", "pct"),
    "health_mod": ("health", "pct"),
    "unit_stat_bonus_attack": ("melee_attack", "add"),
    "unit_stat_bonus_defence": ("melee_defence", "add"),
    "unit_stat_bonus_morale": ("morale", "add"),
    "unit_stat_bonus_armour": ("armour_value", "add"),
    "unit_stat_bonus_weapon": ("melee_damage", "add"),
    "unit_stat_bonus_ammunition": ("ammo", "add"),
    "unit_stat_bonus_charge_bonus_mod": ("charge_bonus", "add"),
    "unit_stat_bonus_accuracy_mod": ("accuracy", "add"),
    "cost_mod": ("recruitment_cost", "pct"),
    "cost_percentage_mod": ("recruitment_cost", "pct"),
    "upkeep_mod": ("upkeep_cost", "pct"),
    "mercenary_cost_mod": ("recruitment_cost", "pct"),
    "recruitment_cost_mod": ("recruitment_cost", "pct"),
    "unit_is_magical": ("magical_attacks", "flag"),
    "unit_flaming_attack_mod": ("flaming_attacks", "flag"),
    "unit_unbreakable": ("unbreakable", "flag"),
    "unbreakable": ("unbreakable", "flag"),
    "no_upkeep": ("no_upkeep", "flag"),
    "replenishment_percentage_bonus": ("_army_replenishment", "add"),
    "post_battle_unit_saving_chance_mod": ("_army_casualty_save", "add"),
    "post_battle_unit_saving_replenishment_mod": ("_army_casualty_save", "add"),
    "post_battle_increase_enemy_loot_mod": ("_army_loot", "add"),
    "recruit_time_mod": ("_army_recruit_time", "add"),
    "global_recruit_time_mod": ("_faction_recruit_time", "add"),
    "xp_gain_rate_mod": ("_unit_xp_gain", "pct"),
    "unit_cap": ("_unit_cap", "add"),
    "unit_allowance_point_cap_mod": ("_unit_cap", "add"),
    "mercenary_province_pool_capacity_mod": ("_merc_pool", "add"),
    "mercenary_province_pool_replenishment_mod": ("_merc_pool", "add"),
    "mercenary_unit_xp_mod": ("_merc_xp", "add"),
    "minimum_xp_gain_from_eligible_battle": ("_unit_xp_gain", "add"),
    "recruitment_disabled": ("_recruit_disabled", "flag"),
    "winds_of_magic_mod": ("_wom", "add"),
    "miscast_percentage_mod": ("miscast", "pct"),
    "melee_attack_mod_general": ("melee_attack", "add"),
    "melee_defence_mod_general": ("melee_defence", "add"),
    "enable": ("_grant", "flag"),
    "enable_overchage": ("_grant", "flag"),
    "disable": ("_deny", "flag"),
    "uses_mod": ("_ability_uses", "add"),
    "recharge_mod": ("_ability_recharge", "pct"),
    "active_time_mod": ("_ability_duration", "pct"),
    "effect_range_mod": ("_ability_range", "pct"),
    "target_intercept_range_mod": ("_ability_range", "pct"),
}

HOLDER_SOURCES = {
    "faction": {"faction", "province_if_capital", "technology"},
    "force": {"force", "army", "navy"},
    "character": {"character", "agent", "general",
                  "character_when_commanding", "character_if_faction_leader",
                  "character_if_in_region_with_own_foreign_slot",
                  "character_if_in_sea_region"},
    "region": {"region", "province", "building", "force_building",
               "foreign_building", "foreign_host_faction", "settlement"},
}

TARGET_ALL_UNITS = {"force", "army", "navy"}
TARGET_CHARACTERS = {"character"}
TARGET_GENERAL = {"character_when_commanding",
                  "character_when_commanding_army",
                  "character_when_commanding_no_colonel",
                  "character_if_faction_leader"}

LOC_CONDITIONAL = {"provincewide", "regionwide", "provincewide_geographical",
                   "provincewide_when_governor", "sea_regionwide",
                   "neighbour_region", "neighbour_faction_province",
                   "neighbour_provincewide_geographical",
                   "force_sphere_of_influencewide",
                   "region_sphere_of_influence",
                   "foreign_buildingwide", "foreign_host_factionwide",
                   "bloodgroundwide"}

STAT_CN = {
    "melee_attack": "近战攻击", "melee_defence": "近战防御",
    "morale": "士气", "armour_value": "护甲强度", "charge_bonus": "冲锋加成",
    "melee_damage": "武器威力", "melee_ap_damage": "破甲杀伤",
    "missile_damage": "远程威力", "missile_ap_damage": "远程破甲",
    "ammo": "弹药量", "range": "射程", "reload": "装填", "accuracy": "精准",
    "speed": "移动速度", "mass": "质量", "shield": "盾牌格挡",
    "melee_bonus_v_infantry": "反步兵加成", "melee_bonus_v_large": "反大型加成",
    "physical_resistance": "物理抗性", "missile_resistance": "远程抗性",
    "magic_resistance": "魔法抗性", "fire_resistance": "火焰抗性",
    "ward_save": "特保", "fatigue_resistance": "疲劳抗性",
    "unit_rank": "经验等级", "health": "生命值", "barrier": "魔屏",
    "recruitment_cost": "招募成本", "upkeep_cost": "维持费",
    "magical_attacks": "魔法攻击", "flaming_attacks": "火焰攻击",
    "unbreakable": "不会溃逃", "no_upkeep": "免维持费",
    "weapon_strength": "武器威力", "missile_strength": "远程威力",
    "_army_replenishment": "补员率", "_army_casualty_save": "战后单位保留",
    "_army_loot": "战后掠夺", "_army_recruit_time": "招募时间",
    "_faction_recruit_time": "全局招募时间", "_unit_xp_gain": "经验获取",
    "_unit_cap": "容量", "_merc_pool": "佣兵池", "_merc_xp": "佣兵经验",
    "_recruit_disabled": "禁止招募", "_wom": "魔法之风",
    "_grant": "授予", "_deny": "禁用", "miscast": "失误概率",
}

_CARD_STATS = [
    "melee_attack", "melee_defence", "weapon_strength", "charge_bonus",
    "morale", "health", "armour_value", "shield", "speed", "mass",
    "missile_strength", "ammo", "range", "accuracy",
    "melee_bonus_v_infantry", "melee_bonus_v_large",
    "physical_resistance", "missile_resistance", "magic_resistance",
    "fire_resistance", "ward_save",
]


class Ctx:
    """Precomputed lookups over gamedb rows."""

    def __init__(self, db):
        rows = db.get("rows") or {}
        self.loc = db.get("loc") or {}
        self.units = db.get("units") or {}
        self.effects = rows.get("effects_tables") or {}
        self.bundles = rows.get("effect_bundles_tables") or {}
        self.scopes = rows.get("campaign_effect_scopes_tables") or {}
        self.statmods = rows.get("unit_stat_modifiers_tables") or {}
        self.xp_rows = rows.get("unit_experience_bonuses_tables") or {}
        self.land = rows.get("land_units_tables") or {}
        self.main = rows.get("main_units_tables") or {}
        self.subtype_of_unit = {}
        for k, v in (rows.get("agent_subtypes_tables") or {}).items():
            u = v.get("associated_unit_override")
            if u:
                self.subtype_of_unit[u] = k

        def group_by(table, *cols):
            out = {}
            for row in (rows.get(table) or {}).values():
                key = tuple(row.get(c) or "" for c in cols)
                out.setdefault(key if len(cols) > 1 else key[0],
                               []).append(row)
            return out

        self.bundle_fx = group_by(
            "effect_bundles_to_effects_junctions_tables", "effect_bundle_key")
        self.basic = group_by(
            "effect_bonus_value_basic_junction_tables", "effect")
        self.bv_rec = group_by(
            "effect_bonus_value_unit_record_junctions_tables", "effect")
        self.bv_sets = group_by(
            "effect_bonus_value_ids_unit_sets_tables", "effect")
        self.bv_list = group_by(
            "effect_bonus_value_unit_list_junctions_tables", "effect")
        self.bv_class = group_by(
            "effect_bonus_value_unit_class_junction_tables", "effect")
        self.bv_class_sm = group_by(
            "effect_bonus_value_unit_class_stat_modifiers_junctions_tables",
            "effect")
        self.bv_ability = group_by(
            "effect_bonus_value_unit_ability_junctions_tables", "effect")
        self.bv_attr = group_by(
            "effect_bonus_value_unit_attribute_junctions_tables", "effect")
        self.bv_phase = group_by(
            "effect_bonus_value_special_ability_phase_record_junctions_tables",
            "effect")
        self.trait_fx = group_by("trait_level_effects_tables", "trait_level")
        self.anc_fx = group_by("ancillary_to_effects_tables", "ancillary")
        self.skill_fx = group_by(
            "character_skill_level_to_effects_junctions_tables",
            "character_skill_key")
        self.tech_fx = group_by(
            "technology_effects_junction_tables", "technology")
        self.set_defs = rows.get("unit_sets_tables") or {}
        self.set_rows = group_by(
            "unit_set_to_unit_junctions_tables", "unit_set")
        self.unit_lists = group_by(
            "unit_to_unit_list_junctions_tables", "unit_list")

        tl = rows.get("character_trait_levels_tables") or {}
        self.trait_levels = {}
        for r in tl.values():
            t = r.get("trait")
            if t:
                self.trait_levels.setdefault(t, []).append(
                    (r.get("threshold_points") or 0, r.get("key")))
        for t in self.trait_levels:
            self.trait_levels[t].sort()

    # ---------- localisation ----------
    def text(self, key):
        if not key:
            return None
        v = self.loc.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
        return None

    def effect_name(self, key):
        return self.text("effects_onscreen_name_" + (key or ""))

    def bundle_name(self, key):
        return (self.text("effect_bundles_localised_title_" + (key or ""))
                or self.text("effect_bundles_localised_description_"
                             + (key or "")))

    def skill_name(self, key):
        return self.text("character_skills_localised_name_" + (key or ""))

    def anc_name(self, key):
        return self.text("ancillaries_onscreen_name_" + (key or ""))

    def trait_name(self, key):
        return (self.text("character_traits_localised_name_" + (key or ""))
                or self.text("character_trait_levels_name_" + (key or "")))

    def stat_name(self, stat_key):
        return (self.text("unit_stat_localisations_onscreen_name_" + stat_key)
                or STAT_CN.get(stat_key) or stat_key)

    def unit_in_set(self, set_key, unit):
        rows = self.set_rows.get(set_key) or []
        if not rows:
            return False
        matched = False
        for r in rows:
            ok = True
            for f, col in (("unit_record", "key"), ("unit_caste", "caste"),
                           ("unit_category", "category"),
                           ("unit_class", "class")):
                want = r.get(f)
                if want and str(unit.get(col) or "") != want:
                    ok = False
                    break
            if not ok:
                continue
            if r.get("exclude"):
                return False
            matched = True
        if matched:
            d = self.set_defs.get(set_key) or {}
            if d.get("use_unit_exp_level_range"):
                rank = unit.get("rank") or 0
                lo = d.get("min_unit_exp_level_inclusive") or 0
                hi = d.get("max_unit_exp_level_inclusive") or 99
                if not (lo <= rank <= hi):
                    return False
        return matched


def _scope_for(ctx, scope_key):
    return ctx.scopes.get(scope_key) if scope_key else None


def scope_check(ctx, scope_key, holder, army_province, holder_region):
    """-> (applies, conditional, note) for a scope on a given holder."""
    row = _scope_for(ctx, scope_key)
    if row is None:
        return True, False, None
    src = row.get("source") or ""
    own = row.get("ownership") or "yours"
    loc = row.get("location") or ""
    terr = row.get("territory") or ""

    allowed = HOLDER_SOURCES.get(holder, {holder})
    if src and src not in allowed:
        return False, False, "scope 持有者不符(%s)" % src
    if own == "enemy":
        return False, False, "作用于敌军"
    if own == "allied":
        return False, False, "作用于盟友"

    conditional = False
    note = None
    if loc in ("provincewide", "provincewide_geographical",
               "provincewide_when_governor"):
        conditional = True
        note = "省内"
        if holder == "region" and holder_region and army_province                 and holder_region != army_province:
            return False, True, "不在该省"
    elif loc == "regionwide":
        conditional = True
        note = "区域内"
        if holder == "region" and holder_region and army_province                 and holder_region != army_province:
            return False, True, "不在该区域"
    elif loc in LOC_CONDITIONAL:
        conditional = True
        note = "范围限定(%s)" % loc
    if terr and terr not in ("any", ""):
        conditional = True
        note = (note or "") + (" 领土限定(%s)" % terr)
    return True, conditional, note


def target_kind(ctx, scope_key):
    """-> 'all'|'characters'|'general'|'other' for the scope target."""
    row = _scope_for(ctx, scope_key)
    tgt = (row or {}).get("target") or ""
    if tgt in TARGET_ALL_UNITS:
        return "all"
    if tgt in TARGET_CHARACTERS:
        return "characters"
    if tgt in TARGET_GENERAL:
        return "general"
    return "other"


def _iter_bundle_rows(ctx, bundle):
    """Effective rows for a save bundle.

    The save's ADDITIONAL_EFFECTS list is the evaluated instance: its first
    row per (effect, scope) carries the live value; repeated rows are
    cumulative lifetime totals the engine stores alongside. Use the inline
    first-occurrence when present, fall back to the DB junction template."""
    key = bundle.get("key")
    covered = set()
    for e in bundle.get("effects") or []:
        sig = (e.get("effect"), e.get("scope"))
        if sig in covered:
            continue
        covered.add(sig)
        yield {"effect": e.get("effect"),
               "scope": e.get("scope"),
               "value": e.get("value"),
               "stage": None,
               "bundle": key}
    for j in ctx.bundle_fx.get(key) or []:
        sig = (j.get("effect_key"), j.get("effect_scope"))
        if sig in covered:
            continue
        yield {"effect": j.get("effect_key"),
               "scope": j.get("effect_scope"),
               "value": j.get("value"),
               "stage": j.get("advancement_stage"),
               "bundle": key}


def _iter_member_effects(ctx, member):
    for b in member.get("bundles") or []:
        for r in _iter_bundle_rows(ctx, b):
            r["via"] = "bundle:%s" % (b.get("key"))
            yield r
    for t in member.get("traits") or []:
        keys = []
        if t.get("stage"):
            keys.append(t["stage"])
        elif t.get("key"):
            for thr, k in ctx.trait_levels.get(t["key"], []):
                if (t.get("points") or 0) >= thr:
                    keys.append(k)
            keys = keys[-1:]
        for k in keys:
            for j in ctx.trait_fx.get(k) or []:
                yield {"effect": j.get("effect"),
                       "scope": j.get("effect_scope"),
                       "value": j.get("value"), "stage": None,
                       "via": "trait:%s" % k}
    for anc in member.get("ancillaries") or []:
        for j in ctx.anc_fx.get(anc) or []:
            yield {"effect": j.get("effect"),
                   "scope": j.get("effect_scope"),
                   "value": j.get("value"), "stage": None,
                   "via": "ancillary:%s" % anc}
    for s in member.get("skills") or []:
        learned = s.get("level") or 1
        for j in ctx.skill_fx.get(s.get("key")) or []:
            if (j.get("level") or 1) <= learned:
                yield {"effect": j.get("effect_key"),
                       "scope": j.get("effect_scope"),
                       "value": j.get("value"), "stage": None,
                       "via": "skill:%s" % s.get("key")}


def collect_army_effects(ctx, summary, army):
    """Gather every effect row that could reach this army's units."""
    player = summary.get("player") or {}
    province = army.get("province")
    by_id = {m.get("member_id"): m for m in player.get("members") or []
             if m.get("member_id") is not None}
    chars = {c.get("id"): c for c in player.get("characters") or []
             if c.get("id") is not None}

    out = []

    def add(row, holder, source_kind, source_label, cond=False, note=None):
        row = dict(row)
        row.update(holder=holder, source_kind=source_kind,
                   source=source_label, conditional=cond, note=note)
        out.append(row)

    for b in player.get("faction_bundles") or []:
        for r in _iter_bundle_rows(ctx, b):
            ok, cond, note = scope_check(ctx, r.get("scope"), "faction",
                                         province, None)
            if ok:
                add(r, "faction", "faction_bundle",
                    ctx.bundle_name(b.get("key")) or b.get("key"),
                    cond, note)

    for b in army.get("bundles") or []:
        for r in _iter_bundle_rows(ctx, b):
            ok, cond, note = scope_check(ctx, r.get("scope"), "force",
                                         province, None)
            if ok:
                add(r, "force", "force_bundle",
                    ctx.bundle_name(b.get("key")) or b.get("key"),
                    cond, note)

    # characters embedded in this army: commander + anyone whose
    # char.force_id matches, plus AGENT_CONTAINER role ids as fallback.
    fid = army.get("force_id")
    member_ids = []
    seen_mid = set()
    for c in chars.values():
        if c.get("force_id") is not None and c.get("force_id") == fid                 and c.get("member_id") is not None:
            kind = "general" if c.get("id") == army.get("commander_id")                 else (c.get("type") or "agent")
            member_ids.append((c["member_id"], kind))
            seen_mid.add(c["member_id"])
    for cid in army.get("agent_cqis") or []:
        c = chars.get(cid)
        if c and c.get("member_id") is not None                 and c["member_id"] not in seen_mid:
            member_ids.append((c["member_id"], c.get("type") or "agent"))
            seen_mid.add(c["member_id"])
    for mid, kind in member_ids:
        m = by_id.get(mid)
        if not m:
            continue
        label = m.get("subtype") or kind
        for r in _iter_member_effects(ctx, m):
            ok, cond, note = scope_check(ctx, r.get("scope"), "character",
                                         province, None)
            if ok:
                r["via_kind"] = kind
                r["member_id"] = mid
                add(r, "character", "character:%s" % kind, label,
                    cond, note)

    for r in player.get("regions") or []:
        if not province or r.get("province") != province:
            continue
        for b in r.get("bundles") or []:
            for row in _iter_bundle_rows(ctx, b):
                ok, cond, note = scope_check(ctx, row.get("scope"), "region",
                                             province, r.get("province"))
                if ok:
                    add(row, "region", "region:%s" % r.get("key"),
                        ctx.bundle_name(b.get("key")) or b.get("key"),
                        cond, note)
    return out


def _effect_bvids(ctx, effect_key, unit):
    """(bvid, qualifier) pairs an effect yields for this unit.

    Multiple junction rows naming the same bonus_value_id via different
    target sets are a UNION match — the game applies the bvid once, so
    dedupe per bvid here."""
    seen = set()

    def emit(bvid, qual):
        if not bvid or bvid in seen:
            return
        seen.add(bvid)
        yield bvid, qual

    for j in ctx.basic.get(effect_key) or []:
        yield from emit(j.get("bonus_value_id"), None)
    for j in ctx.bv_rec.get(effect_key) or []:
        if j.get("unit_record_key") == unit.get("key"):
            yield from emit(j.get("bonus_value_id"), "record")
    for j in ctx.bv_sets.get(effect_key) or []:
        if ctx.unit_in_set(j.get("unit_set"), unit):
            yield from emit(j.get("bonus_value_id"),
                            "set:%s" % j.get("unit_set"))
    for j in ctx.bv_list.get(effect_key) or []:
        members = {r.get("unit") for r in
                   ctx.unit_lists.get(j.get("unit_list")) or []}
        if unit.get("key") in members:
            yield from emit(j.get("bonus_value_id"),
                            "list:%s" % j.get("unit_list"))
    for j in ctx.bv_class.get(effect_key) or []:
        if j.get("unit_class") and j.get("unit_class") == unit.get("class"):
            yield from emit(j.get("bonus_value_id"), "class")
    for j in ctx.bv_class_sm.get(effect_key) or []:
        if j.get("class") and j.get("class") == unit.get("class"):
            sm = ctx.statmods.get(j.get("stat_modifier")) or {}
            yield from emit("__statmod__:%s" % (sm.get("stat") or
                                                j.get("stat_modifier")),
                            "how:%s" % (sm.get("how") or "add"))
    for j in ctx.bv_ability.get(effect_key) or []:
        yield from emit("ability:%s" % (j.get("unit_ability") or ""),
                        "ability")
    for j in ctx.bv_attr.get(effect_key) or []:
        yield from emit("attribute:%s" % (j.get("unit_attribute") or ""),
                        "attribute")
    for j in ctx.bv_phase.get(effect_key) or []:
        yield from emit("phase:%s" % (j.get("special_ability_phase")
                                      or j.get("phase") or ""), "phase")


def unit_ctx(ctx, unit_dict, general_mid):
    key = unit_dict.get("key")
    cat = ctx.units.get(key) or {}
    land = ctx.land.get(key) or {}
    main = ctx.main.get(key) or {}
    mid = unit_dict.get("commander_member_id")
    return {
        "key": key,
        "caste": cat.get("caste") or main.get("caste") or "",
        "category": land.get("category") or cat.get("category") or "",
        "class": land.get("class") or cat.get("class") or "",
        "rank": unit_dict.get("rank") or 0,
        "member_id": mid,
        "is_general": mid is not None and mid == general_mid,
        "is_character": mid is not None
        or (main.get("caste") or cat.get("caste") or "")
        in ("lord", "hero"),
    }


def rank_bonus(ctx, stat, rank):
    """unit_experience_bonuses: value + rate*L + scalar*L(L-1)/2.

    growth_scalar is the per-rank increment delta (arithmetic series);
    rank9 -> +9.7 MA / +38 morale, matching known vanilla gold chevrons.
    [需验证: 与游戏内面板对拍]"""
    if not rank:
        return 0.0
    r = ctx.xp_rows.get("stat_" + stat) or ctx.xp_rows.get(stat)
    if not r:
        return 0.0
    v = r.get("value") or 0
    rate = r.get("growth_rate") or 0.0
    sc = r.get("growth_scalar") or 0.0
    return v + rate * rank + sc * rank * (rank - 1) / 2.0


def army_report(ctx, summary, army_index):
    """Full bonus resolution for one army."""
    armies = (summary.get("player") or {}).get("armies") or []
    if not (0 <= army_index < len(armies)):
        return None
    army = armies[army_index]
    effects = collect_army_effects(ctx, summary, army)

    for r in effects:
        ek = r.get("effect")
        info = ctx.effects.get(ek) or {}
        r["name"] = ctx.effect_name(ek) or ek
        r["has_loc"] = ctx.effect_name(ek) is not None
        r["icon"] = info.get("icon")
        r["category"] = info.get("category")
        r["positive_good"] = info.get("is_positive_value_good")
        r["target_kind"] = target_kind(ctx, r.get("scope"))
        r["scope_key"] = r.get("scope")
        srow = _scope_for(ctx, r.get("scope")) or {}
        r["scope_loc"] = srow.get("location") or ""

    report = {"index": army_index, "effects": effects}
    general_mid = army.get("commander_member_id")
    units = []
    for i, u in enumerate(army.get("units") or []):
        uc = unit_ctx(ctx, u, general_mid)
        base = dict(ctx.units.get(uc["key"]) or {})
        deltas = {}
        grants = []
        misc = []
        for r in effects:
            tk = r["target_kind"]
            if tk == "other":
                continue
            if tk == "characters":
                if not uc["is_character"]:
                    continue
                # 'character' location = the holder itself only
                if (r.get("scope_loc") or "") == "character"                         and r.get("holder") == "character"                         and r.get("member_id") is not None                         and uc.get("member_id") is not None                         and r["member_id"] != uc["member_id"]:
                    continue
            if tk == "general" and not uc["is_general"]:
                continue
            val = r.get("value")
            for bvid, qual in _effect_bvids(ctx, r.get("effect"), uc):
                bvs = bvid or ""
                if bvs.startswith("ability:") or bvs.startswith(
                        "attribute:") or bvs.startswith("phase:"):
                    kind, k = bvs.split(":", 1)
                    locmap = {"ability": "unit_abilities_onscreen_name_",
                              "attribute": "unit_attributes_bullet_text_",
                              "phase": "special_ability_phases_name_"}
                    grants.append({
                        "kind": kind, "key": k,
                        "name": ctx.text(locmap[kind] + k) or k,
                        "source": r["source"]})
                    continue
                if bvs.startswith("__statmod__:"):
                    stat2 = bvs[len("__statmod__:"):]
                    d = deltas.setdefault(stat2, {"add": 0.0, "pct": 0.0,
                                                  "res": 0.0, "flags": 0,
                                                  "rows": []})
                    d["rows"].append({"name": r["name"], "value": val,
                                      "bvid": stat2,
                                      "source": r["source"],
                                      "kind": r["source_kind"],
                                      "cond": r.get("conditional"),
                                      "note": r.get("note")})
                    if isinstance(val, (int, float)):
                        d["add"] += val
                    continue
                stat, how = BVID_MAP.get(bvs, (None, None))
                if stat is None:
                    misc.append({"bvid": bvs, "effect": r.get("effect"),
                                 "name": r["name"], "value": val,
                                 "source": r["source"],
                                 "scope": r.get("scope")})
                    continue
                if stat.startswith("_"):
                    misc.append({"bvid": bvs, "effect": r.get("effect"),
                                 "name": r["name"], "value": val,
                                 "stat": ctx.stat_name(stat),
                                 "source": r["source"],
                                 "scope": r.get("scope"),
                                 "cond": r.get("conditional")})
                    continue
                d = deltas.setdefault(stat, {"add": 0.0, "pct": 0.0,
                                             "res": 0.0, "flags": 0,
                                             "rows": []})
                d["rows"].append({
                    "name": r["name"], "value": val, "bvid": bvs,
                    "source": r["source"], "kind": r["source_kind"],
                    "cond": r.get("conditional"), "note": r.get("note"),
                })
                if not isinstance(val, (int, float)):
                    continue
                if how == "add":
                    d["add"] += val
                elif how == "pct":
                    d["pct"] += val
                elif how == "res":
                    d["res"] += val
                elif how == "flag":
                    d["flags"] += 1
        final = {}
        mods = {}
        xp_map = {"melee_attack": "melee_attack",
                  "melee_defence": "melee_defence",
                  "morale": "morale", "accuracy": "accuracy"}
        for stat in _CARD_STATS:
            bv = base.get(stat)
            if stat == "weapon_strength":
                bv = (base.get("melee_damage") or 0) +                     (base.get("melee_ap_damage") or 0)
            if stat == "missile_strength":
                bv = (base.get("missile_damage") or 0) +                     (base.get("missile_ap_damage") or 0)
            d = deltas.get(stat)
            rb = rank_bonus(ctx, xp_map.get(stat, stat), u.get("rank"))
            if bv is None and d is None and not rb:
                continue
            bvf = float(bv or 0)
            add = (d or {}).get("add", 0.0)
            pct = (d or {}).get("pct", 0.0)
            res = (d or {}).get("res", 0.0)
            fin = bvf * (1 + pct / 100.0) + add + res + rb
            final[stat] = round(fin, 1)
            if add or pct or res or rb:
                mods[stat] = {
                    "base": bv, "final": round(fin, 1),
                    "add": round(add, 2), "pct": round(pct, 2),
                    "res": round(res, 2), "rank_bonus": round(rb, 2),
                    "name": ctx.stat_name(stat),
                    "rows": (d or {}).get("rows", []),
                }
        units.append({
            "key": uc["key"], "name": base.get("name") or uc["key"],
            "icon": base.get("icon"), "caste": uc["caste"],
            "strength": u.get("strength"), "hp": u.get("hp"),
            "rank": u.get("rank"), "xp": u.get("xp"),
            "is_character": uc["is_character"],
            "is_general": uc["is_general"],
            "base": {s: base.get(s) for s in _CARD_STATS
                     if base.get(s) is not None},
            "final": final, "mods": mods,
            "grants": grants, "misc": misc,
        })
    report["units"] = units
    report["army_level_effects"] = [r for r in effects
                                    if r["target_kind"] == "other"]
    return report
