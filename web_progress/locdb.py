# -*- coding: utf-8 -*-
"""Chinese localisation + unit-stat lookups for the WH3 progress dashboard.

Loads (lazily, once per process):
  - bilingual/localisation__.loc_CN.tsv   key -> 中文文本
  - gamedata/db/main_units_tables/data__.tsv   unit key -> {num_men, cost, upkeep, tier}
  - gamedata/db/land_units_tables/data__.tsv   unit key -> combat stats

All resolvers degrade gracefully: unknown keys (MOD content) return the raw key.
"""

import csv
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
WORKSPACE = os.path.dirname(ROOT)
LOC_TSV = os.path.join(WORKSPACE, "bilingual", "localisation__.loc_CN.tsv")
MAIN_UNITS_TSV = os.path.join(WORKSPACE, "gamedata", "db", "main_units_tables", "data__.tsv")
LAND_UNITS_TSV = os.path.join(WORKSPACE, "gamedata", "db", "land_units_tables", "data__.tsv")

_loc = None
_units = None  # key -> dict(num_men, mp_cost, upkeep, tier, class, is_monstrous)

AGENT_TYPE_CN = {
    "general": "领主", "engineer": "工程师", "colonel": "驻军军官",
    "spy": "间谍", "wizard": "法师", "champion": "勇士",
    "dignitary": "贵族", "assassin": "刺客", "runesmith": "符文铁匠",
}

STANCE_CN = {
    "war": "交战", "neutral": "中立", "peace": "和平",
    "military_alliance": "军事同盟", "defensive_alliance": "防御同盟",
    "trade": "贸易协定", "trade_agreement": "贸易协定",
    "non_aggression_pact": "互不侵犯条约", "military_access": "军事通行权",
    "vassal": "附庸", "master": "宗主",
    "allied": "同盟", "client_state": "仆从国",
}

MISSION_STATUS_CN = {
    "ACTIVE": "进行中", "SUCCEEDED": "已完成", "COMPLETED": "已完成",
    "FAILED": "失败", "CANCELLED": "已取消", "ISSUED": "已发布",
}

STORM_CN = {
    "land_storm": "陆相魔法风暴", "wandering_storm": "游荡魔法风暴",
}


def _load_loc():
    global _loc
    if _loc is not None:
        return _loc
    _loc = {}
    try:
        with open(LOC_TSV, "r", encoding="utf-8-sig", newline="") as f:
            rd = csv.reader(f, delimiter="\t")
            for row in rd:
                if len(row) >= 2 and row[0] and row[0] != "key":
                    _loc[row[0]] = row[1]
    except OSError:
        pass
    return _loc


def _load_units():
    global _units
    if _units is not None:
        return _units
    _units = {}
    try:
        with open(MAIN_UNITS_TSV, "r", encoding="utf-8-sig", newline="") as f:
            rd = csv.DictReader(f, delimiter="\t")
            for row in rd:
                key = (row.get("unit") or row.get("land_unit") or "").strip()
                if not key:
                    continue
                _units[key] = {
                    "num_men": _int(row.get("num_men")),
                    "mp_cost": _int(row.get("multiplayer_cost")),
                    "recruit_cost": _int(row.get("recruitment_cost")),
                    "upkeep": _int(row.get("upkeep_cost")),
                    "tier": _int(row.get("tier")),
                    "caste": row.get("caste") or "",
                    "weight": row.get("weight") or "",
                    "is_monstrous": (row.get("is_monstrous") or "").lower() == "true",
                    "is_high_threat": (row.get("is_high_threat") or "").lower() == "true",
                }
    except OSError:
        pass
    try:
        with open(LAND_UNITS_TSV, "r", encoding="utf-8-sig", newline="") as f:
            rd = csv.DictReader(f, delimiter="\t")
            for row in rd:
                key = (row.get("key") or "").strip()
                if not key:
                    continue
                u = _units.setdefault(key, {})
                u["melee_attack"] = _int(row.get("melee_attack"))
                u["melee_defence"] = _int(row.get("melee_defence"))
                u["morale"] = _int(row.get("morale"))
                u["armour"] = _int(row.get("armour"))
                u["bonus_hp"] = _int(row.get("bonus_hit_points"))
                u["category"] = row.get("category") or ""
                u["class"] = row.get("class") or ""
    except OSError:
        pass
    return _units


def _int(v):
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return None


def loc_text(loc_key):
    """Resolve a loc key to Chinese text; follows one level of {{tr:key}} refs."""
    if not loc_key:
        return None
    loc = _load_loc()
    txt = loc.get(loc_key)
    if txt is None:
        return None
    txt = txt.strip()
    if txt.startswith("{{tr:") and txt.endswith("}}"):
        inner = txt[5:-2].strip()
        txt = (loc.get(inner, inner) or inner).strip() or inner
    if txt.startswith("[[") and "]]" in txt:
        txt = txt.split("]]", 1)[1]
    return txt or None


def faction_name(key):
    return loc_text("factions_screen_name_" + key) if key else None


def unit_name(key):
    if not key:
        return None
    return (loc_text("land_units_onscreen_name_" + key)
            or loc_text("agent_subtypes_onscreen_name_override_" + key))


def region_name(key):
    return loc_text("regions_onscreen_" + key) if key else None


def province_name(key):
    return loc_text("provinces_onscreen_" + key) if key else None


def building_name(key):
    if not key:
        return None
    return (loc_text("building_culture_variants_name_" + key)
            or loc_text("building_short_texts_name_" + key)
            or loc_text("building_settlement_only_name_" + key)
            or loc_text("buildings_screen_name_" + key))


def ancillary_name(key):
    return loc_text("ancillaries_onscreen_name_" + key) if key else None


def mission_title(loc_key):
    return loc_text(loc_key)


def strip_markup(txt):
    """Remove [[x:y]]...[[/x]] spans (keep inner text) and resolve {{tr:key}}."""
    if not txt:
        return txt
    import re
    def _tr(m):
        return loc_text(m.group(1)) or ""
    txt = re.sub(r"\{\{tr:([^}]+)\}\}", _tr, txt)
    txt = re.sub(r"\[\[[^\]]+\]\]", "", txt)
    txt = txt.replace("\\n", " ").replace("\n", " ").strip()
    return txt or None


def mission_desc(loc_key):
    return strip_markup(loc_text(loc_key))


def char_name(loc_key):
    return loc_text(loc_key)


def campaign_name(campaign_id):
    return loc_text("campaigns_onscreen_name_" + campaign_id) if campaign_id else None


def pooled_name(key):
    if not key:
        return None
    return (loc_text("pooled_resources_onscreen_name_" + key)
            or loc_text("pooled_resources_display_name_" + key))


def subtype_name(key):
    """agent subtype (传奇领主/将军...) -> Chinese."""
    if not key:
        return None
    return (loc_text("agent_subtypes_onscreen_name_override_" + key)
            or loc_text("agent_subtypes_onscreen_name_" + key))


def bundle_name(key):
    """effect bundle key -> Chinese title/description."""
    if not key:
        return None
    return (loc_text("effect_bundles_localised_title_" + key)
            or loc_text("effect_bundles_localised_description_" + key))


def skill_name(key):
    if not key:
        return None
    return loc_text("character_skills_localised_name_" + key)


def trait_name(key):
    if not key:
        return None
    return (loc_text("character_trait_levels_onscreen_name_" + key)
            or loc_text("character_traits_onscreen_name_" + key))


_NAME_JUNK = {"EFFECTS", "OTHER", "NONE", ""}


def member_name(name_dict):
    """CHARACTER_NAME element dict {forename: key-or-text, ...} -> display
    name. Unresolved names_name_* keys and junk literals are dropped."""
    if not name_dict:
        return None
    parts = []
    for e in ("forename", "family_name", "clan_name", "other"):
        v = name_dict.get(e)
        if not v or v in _NAME_JUNK:
            continue
        t = char_name(v)
        if t:
            parts.append(t)
        elif not v.startswith("names_name_"):
            parts.append(v)
    return "·".join(parts) if parts else None


def unit_stats(key):
    return _load_units().get(key)


def agent_type_cn(t):
    return AGENT_TYPE_CN.get(t, t or "?")


def stance_cn(s):
    return STANCE_CN.get(s, s or "?")


def mission_status_cn(s):
    return MISSION_STATUS_CN.get(s, s or "?")


def display(cn, key):
    """Chinese name if resolvable, else the raw key (for MOD content)."""
    if not key:
        return "?"
    return cn or key
