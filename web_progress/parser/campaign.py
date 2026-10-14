# -*- coding: utf-8 -*-
"""Campaign summary extractor for WH3 save games.

Walks the inner CAMPAIGN_SAVE_GAME ESF tree once and collects:
  - save header (turn, season, campaign id, version, player faction, mods)
  - per-faction: key, treasury, army/force count, unit count, character count
  - player detail: forces with unit record keys, characters (type/rank/position)

Field paths verified against real WH3 v9.x saves (see scratch/save_parser_research).
"""

import struct

from .esf import (COORD_2D, UTF16, EsfFile, walk_esf,
                  U32, U32_ZERO, U32_ONE, U32_BYTE, U32_16BIT, U32_24BIT)

SCHEMA = 7

# u32-typed primitive markers; compressed encodings all decode to ints.
# Layout comments below follow WH3SaveEditor/src/tables.py (verified in-game).
_U32 = frozenset((U32, U32_ZERO, U32_ONE, U32_BYTE, U32_16BIT, U32_24BIT))

_AGENT_TYPES = {
    "general", "engineer", "colonel", "spy", "wizard", "champion",
    "dignitary", "assassin", "runesmith", "dignitary_2",
}

_ARR_I8 = 0x5A
_ARR_I16 = 0x5B
_ARR_U16 = 0x57
_ARR_U8 = 0x56
_ARR_U32 = 0x48
_ARR_U64 = 0x49


def decode_int_array(marker, data, start, end):
    if marker == _ARR_I16:
        return list(struct.unpack_from("<%dh" % ((end - start) // 2), data, start))
    if marker == _ARR_I8:
        return list(struct.unpack_from("<%db" % (end - start), data, start))
    if marker == _ARR_U16:
        return list(struct.unpack_from("<%dH" % ((end - start) // 2), data, start))
    if marker == _ARR_U8:
        return list(data[start:end])
    if marker == _ARR_U32:
        return list(struct.unpack_from("<%dI" % ((end - start) // 4), data, start))
    if marker == _ARR_U64:
        return list(struct.unpack_from("<%dQ" % ((end - start) // 8), data, start))
    return None


class _Null:
    """Sink collector that drops everything."""

    __slots__ = ()

    def primitive(self, marker, value):
        pass

    def array(self, marker, start, end):
        pass


NULL = _Null()


class HeaderCollector:
    """Direct primitives of SAVE_GAME_HEADER, in file order:
    [0] player faction key, [1] leader portrait, [2]+[3] turn number,
    [4] season (utf16), [5] flag path, [6] player faction display name,
    [8] save name, [9] campaign id, [11] game version string."""

    __slots__ = ("ext", "values")

    def __init__(self, ext):
        self.ext = ext
        self.values = []

    def primitive(self, marker, value):
        self.values.append(value)
        if len(self.values) == 1:
            self.ext.player_key = value

    def array(self, marker, start, end):
        pass


class ModCollector:
    """mod_history_block_name: one group per mod = [pack name, id, flag, u8]."""

    __slots__ = ("ext", "values")

    def __init__(self, ext):
        self.ext = ext
        self.values = []
        ext.mods.append(self)

    def primitive(self, marker, value):
        self.values.append(value)

    def array(self, marker, start, end):
        pass


class FactionCollector:
    __slots__ = ("ext", "index", "scalars", "is_player", "treasury", "econ_extra",
                 "forces", "units", "characters", "econ_data", "diplo_rows",
                 "region_keys", "bundles", "fnum")

    def __init__(self, ext):
        self.ext = ext
        self.index = len(ext.factions)
        self.scalars = []
        self.is_player = False
        self.treasury = None
        self.econ_extra = []
        self.forces = 0
        self.units = 0
        self.characters = 0
        self.econ_data = None
        self.diplo_rows = None
        self.region_keys = []
        self.bundles = []
        self.fnum = None
        ext.factions.append(self)
        ext.cur_faction = self

    @property
    def key(self):
        for v in self.scalars[:4]:
            if isinstance(v, str):
                return v
        return None

    def primitive(self, marker, value):
        self.scalars.append(value)
        # FACTION children[0] = numeric faction id (diplomacy rows index by it)
        if self.fnum is None and marker in _U32 \
                and isinstance(value, int) and not isinstance(value, bool):
            self.fnum = value
        if len(self.scalars) == 2 and not self.is_player:
            player_key = self.ext.player_key
            self.is_player = player_key is not None and value == player_key

    def array(self, marker, start, end):
        pass


class EconCollector:
    """FACTION_ECONOMICS direct primitives: [0] treasury, rest unknown metrics."""

    __slots__ = ("fc", "values")

    def __init__(self, fc):
        self.fc = fc
        self.values = []

    def primitive(self, marker, value):
        if len(self.values) < 8:
            self.values.append(value)
            if len(self.values) == 1:
                self.fc.treasury = value

    def array(self, marker, start, end):
        pass


class CharCollector:
    """Player CHARACTER record (post-LOCOMOTABLE primitives).
    Direct u32 children (WH3SaveEditor-verified):
    [0] character_id, [1] family_member_id, [2] force_id, [3] unit_id."""

    __slots__ = ("ext", "values", "coord", "u32s")

    def __init__(self, ext):
        self.ext = ext
        self.values = []
        self.coord = None
        self.u32s = []
        ext.player_characters.append(self)

    def primitive(self, marker, value):
        self.values.append(value)
        if marker in _U32 and isinstance(value, int) \
                and not isinstance(value, bool) and len(self.u32s) < 8:
            self.u32s.append(value)

    def array(self, marker, start, end):
        pass


class LocoCollector:
    __slots__ = ("char", "coord")

    def __init__(self, char):
        self.char = char
        self.coord = None

    def primitive(self, marker, value):
        if marker == COORD_2D and self.char.coord is None:
            self.char.coord = value

    def array(self, marker, start, end):
        pass


class ForceCollector:
    """Player MILITARY_FORCE: army display name (first non-empty UTF16),
    location (province key + settlement loc string), position (first COORD_2D),
    and per-unit details via UnitCollector."""

    __slots__ = ("ext", "unit_keys", "units", "name", "province", "settlement_loc",
                 "x", "y", "name_keys", "refs", "bundles", "agent_cqis", "stance")

    def __init__(self, ext):
        self.ext = ext
        self.unit_keys = []
        self.units = []
        self.name = None
        self.province = None
        self.settlement_loc = None
        self.x = None
        self.y = None
        self.name_keys = []
        self.refs = []
        self.bundles = []
        self.agent_cqis = []
        self.stance = None
        ext.player_forces.append(self)

    def primitive(self, marker, value):
        if marker == UTF16:
            if self.name is None and isinstance(value, str) and value:
                self.name = value
        elif marker in _U32 and isinstance(value, int) \
                and not isinstance(value, bool):
            # leading own u32s (WH3SaveEditor): [force_id, commander char_id]
            if len(self.refs) < 2 and not self.name_keys:
                self.refs.append(value)
        elif marker == COORD_2D:
            if self.x is None:
                self.x, self.y = value
        elif isinstance(value, str) and value:
            if "_province_" in value and value.startswith("wh"):
                if self.province is None:
                    self.province = value
            elif "settlement:" in value or "onscreen_name_settlement" in value:
                if self.settlement_loc is None:
                    self.settlement_loc = value
            elif value.startswith("names_name_"):
                if len(self.name_keys) < 4:
                    self.name_keys.append(value)

    def array(self, marker, start, end):
        pass


class UnitCollector:
    """One UNIT record inside a player force. Collects raw primitives; the
    key / strength pair / hp / rank / commander name are derived in post."""

    __slots__ = ("ext", "force", "prims", "commander", "stat_blocks", "_key")

    def __init__(self, ext, force):
        self.ext = ext
        self.force = force
        self.prims = []
        self.commander = {}
        self.stat_blocks = []
        self._key = None
        force.units.append(self)
        ext.cur_unit = self

    @property
    def key(self):
        return self._key

    def primitive(self, marker, value):
        self.prims.append((marker, value))
        if self._key is None and isinstance(value, str) and value:
            self._key = value
            self.force.unit_keys.append(value)

    def array(self, marker, start, end):
        pass


class NameElementCollector:
    """CHARACTER_NAME subtree: the localisation key and the element-type
    marker live in *different* small groups (['names_name_x'] then
    ['forename','OTHER']), so pair a pending key with the next elem-type
    marker seen across groups."""

    __slots__ = ("unit", "buf", "pending_key")

    _ELEM_TYPES = {"forename", "family_name", "clan_name", "other"}

    def __init__(self, unit):
        self.unit = unit
        self.buf = []
        self.pending_key = None

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        buf, self.buf = self.buf, []
        loc_key = None
        elem = None
        for v in buf:
            if not isinstance(v, str) or not v:
                continue
            if v in self._ELEM_TYPES:
                elem = v
            elif v.startswith("names_"):
                loc_key = v
        if loc_key is not None:
            self.pending_key = loc_key
        if elem is not None:
            if self.pending_key is not None:
                self.unit.commander[elem] = self.pending_key
                self.pending_key = None


class BundleCollector:
    """CAMPAIGN_EFFECT_BUNDLE v4: [key, duration:int|0] + ADDITIONAL_EFFECTS."""

    __slots__ = ("key", "duration", "effects")

    def __init__(self):
        self.key = None
        self.duration = None
        self.effects = []

    def primitive(self, marker, value):
        if self.key is None:
            if isinstance(value, str) and value:
                self.key = value
            return
        if self.duration is None and isinstance(value, int)                 and not isinstance(value, bool) and value:
            self.duration = value

    def array(self, marker, start, end):
        pass

    def to_dict(self):
        d = {"key": self.key}
        if self.duration:
            d["duration"] = self.duration
        if self.effects:
            d["effects"] = self.effects
        return d


class AdditionalEffectsCollector:
    """ADDITIONAL_EFFECTS: each group = [effect, scope, f32 value, int arg]."""

    __slots__ = ("bundle", "buf")

    def __init__(self, bundle):
        self.bundle = bundle
        self.buf = []

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        group, self.buf = self.buf, []
        strs = [v for v in group if isinstance(v, str) and v]
        if not strs:
            return
        value = next((v for v in group if isinstance(v, float)), None)
        arg = next((v for v in group
                    if isinstance(v, int) and not isinstance(v, bool) and v), None)
        row = {"effect": strs[0]}
        if len(strs) > 1:
            row["scope"] = strs[1]
        if value is not None:
            row["value"] = value
        if arg is not None:
            row["arg"] = arg
        self.bundle.effects.append(row)


class BundlesCollector:
    """CAMPAIGN_EFFECT_BUNDLES / EFFECT_BUNDLE_BLOCK: child bundle records
    append BundleCollectors into .out."""

    __slots__ = ("out",)

    def __init__(self, out):
        self.out = out

    def primitive(self, marker, value):
        pass

    def array(self, marker, start, end):
        pass


class StatsBlockCollector:
    """STATS_BLOCK inside UNIT_STATISTICS_BONUSES: raw per-group primitives."""

    __slots__ = ("unit", "buf")

    def __init__(self, unit):
        self.unit = unit
        self.buf = []

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        if self.buf:
            self.unit.stat_blocks.append(list(self.buf))
        self.buf = []


class AgentContainerCollector:
    """AGENT_CONTAINER: u32/u64 array of embedded-agent cqis."""

    __slots__ = ("ext", "force")

    def __init__(self, ext, force):
        self.ext = ext
        self.force = force

    def primitive(self, marker, value):
        pass

    def array(self, marker, start, end):
        vals = decode_int_array(marker, self.ext.inner, start, end)
        if vals:
            self.force.agent_cqis.extend(vals)


class TraitsCollector:
    """TRAIT record (N groups): each group = [trait_key, points, stage_key]."""

    __slots__ = ("char", "buf")

    def __init__(self, char):
        self.char = char
        self.buf = []

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        g, self.buf = self.buf, []
        key = next((v for v in g if isinstance(v, str) and v), None)
        if key:
            pts = next((v for v in g if isinstance(v, int)
                        and not isinstance(v, bool)), None)
            strs = [v for v in g if isinstance(v, str) and v]
            stage = strs[1] if len(strs) > 1 else None
            self.char.traits.append({"key": key, "points": pts, "stage": stage})


class DetailsNameCollector:
    """CHARACTER_NAME inside CHARACTER_DETAILS. The localisation text and the
    element-type string land in *adjacent* groups ([loc text] then
    ['forename','OTHER']), so pair a pending text with the next elem type."""

    __slots__ = ("char", "buf", "pending")

    _ELEM_TYPES = NameElementCollector._ELEM_TYPES

    def __init__(self, char):
        self.char = char
        self.buf = []
        self.pending = None

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        g, self.buf = self.buf, []
        elem = None
        text = None
        for v in g:
            if not isinstance(v, str) or not v:
                continue
            if v in self._ELEM_TYPES:
                elem = v
            elif v != "OTHER" and text is None:
                text = v
        if text is not None:
            self.pending = text
        if elem is not None:
            if self.pending is not None:
                self.char.name.setdefault(elem, self.pending)
                self.pending = None


class AncillaryItemCollector:
    """ANCILLARY under ANCILLARY_MANAGER (character): [uid, key, DATE, ...]."""

    __slots__ = ("char", "key")

    def __init__(self, char):
        self.char = char
        self.key = None

    def primitive(self, marker, value):
        if self.key is None and isinstance(value, str) and value:
            self.key = value
            self.char.ancillaries.append(value)

    def array(self, marker, start, end):
        pass


class SkillsBlockCollector:
    """CAMPAIGN_SKILLS_BLOCK: each group = [skill_key, level(int, 1 via U32_ONE)]."""

    __slots__ = ("char", "buf")

    def __init__(self, char):
        self.char = char
        self.buf = []

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        g, self.buf = self.buf, []
        key = next((v for v in g if isinstance(v, str) and v), None)
        if key:
            lvl = next((v for v in g if isinstance(v, int)
                        and not isinstance(v, bool) and v > 0), 1)
            self.char.skills.append({"key": key, "level": lvl})


class SkillsMetaCollector:
    """CAMPAIGN_SKILLS (inside CHARACTER_DETAILS): trailing u32 triple =
    [unspent_skill_points, rank, total_xp] (WH3SaveEditor-verified)."""

    __slots__ = ("char", "u32s")

    def __init__(self, char):
        self.char = char
        self.u32s = []
        char.skill_u32s = self.u32s

    def primitive(self, marker, value):
        if marker in _U32 and isinstance(value, int) \
                and not isinstance(value, bool):
            self.u32s.append(value)

    def array(self, marker, start, end):
        pass


class ArtSetInfoCollector:
    """CHARACTER_DETAILS_ART_SET_INFO: [faction, culture, subculture, type,
    subtype, art_set] strings."""

    __slots__ = ("char",)

    def __init__(self, char):
        self.char = char

    def primitive(self, marker, value):
        if isinstance(value, str) and value:
            self.char.art.append(value)

    def array(self, marker, start, end):
        pass


class FamilyMemberCollector:
    """FAMILY_MEMBER: [member_id, faction_key, ...] head scalars. The nested
    CHARACTER_DETAILS collector is only attached for the player faction."""

    __slots__ = ("ext", "member_id", "faction", "details")

    def __init__(self, ext):
        self.ext = ext
        self.member_id = None
        self.faction = None
        self.details = None
        ext.family_members.append(self)

    def primitive(self, marker, value):
        if self.member_id is None and isinstance(value, int)                 and not isinstance(value, bool):
            self.member_id = value
        elif self.faction is None and isinstance(value, str) and value:
            self.faction = value

    def array(self, marker, start, end):
        pass


class CharDetailsCollector:
    """CHARACTER_DETAILS under FAMILY_MEMBER. Nested TRAIT / CHARACTER_NAME /
    ANCILLARY / CAMPAIGN_SKILLS_BLOCK / CAMPAIGN_EFFECT_BUNDLES /
    CHARACTER_DETAILS_ART_SET_INFO get their own collectors; everything else
    inherits this one so scalars (faction key, cqi) keep flowing."""

    __slots__ = ("scalars", "traits", "name", "ancillaries", "skills",
                 "bundles", "art", "cqis", "member_id", "skill_u32s")

    def __init__(self):
        self.member_id = None
        self.scalars = []
        self.traits = []
        self.name = {}
        self.ancillaries = []
        self.skills = []
        self.bundles = []
        self.art = []
        self.cqis = []
        self.skill_u32s = []

    def primitive(self, marker, value):
        self.scalars.append(value)
        # cqi: first plain U32 value (0x08) after the bundle block
        if marker == 0x08 and isinstance(value, int) and not self.cqis:
            self.cqis.append(value)

    def array(self, marker, start, end):
        pass


class DiplomacyCollector:
    """Player OLD_DIPLOMACY_RELATIONSHIP: one nested group per other faction.
    Group primitives: [0] other faction index, [2] stance string
    ('neutral'/'war'/'master'...), [8]/[9] attitude-ish ints."""

    __slots__ = ("ext", "fc", "buf", "rows")

    def __init__(self, ext, fc):
        self.ext = ext
        self.fc = fc
        self.buf = []
        self.rows = []

    def primitive(self, marker, value):
        self.buf.append(value)

    def array(self, marker, start, end):
        pass

    def end_group(self):
        buf = self.buf
        self.buf = []
        if not buf:
            return
        stance = None
        for v in buf[:6]:
            if isinstance(v, str):
                stance = v
                break
        other = buf[0] if isinstance(buf[0], int) else None
        v8 = buf[8] if len(buf) > 8 and isinstance(buf[8], int) else None
        attitude = buf[9] if len(buf) > 9 and isinstance(buf[9], int) else None
        self.rows.append({"index": other, "stance": stance, "v8": v8, "attitude": attitude})


class SettlementCollector:
    """REGION/SETTLEMENT: first COORD_2D = map position; 'settlement:<region>'
    string marks the settlement key; a preceding small int is the tier."""

    __slots__ = ("region", "scalars")

    def __init__(self, region):
        self.region = region
        self.scalars = []
        region.settlement_scalars = self.scalars

    def primitive(self, marker, value):
        self.scalars.append((marker, value))
        if marker == COORD_2D and self.region.x is None:
            self.region.x, self.region.y = value

    def array(self, marker, start, end):
        pass


class GarrisonCollector:
    """SETTLEMENT/GARRISON_RESIDENCE: u32 children; [8] = garrisoned
    force_id (WH3SaveEditor-verified; links the force to this region)."""

    __slots__ = ("region", "u32s")

    def __init__(self, region):
        self.region = region
        self.u32s = []
        region.garrison_u32s = self.u32s

    def primitive(self, marker, value):
        if marker in _U32 and isinstance(value, int) \
                and not isinstance(value, bool):
            self.u32s.append(value)

    def array(self, marker, start, end):
        pass


class EconDataCollector:
    """FACTION_ECONOMICS/history/ECONOMICS_DATA: fixed-width int arrays
    (income/expense breakdown history, category order engine-internal)."""

    __slots__ = ("fc", "arrays", "ext")

    def __init__(self, ext, fc):
        self.ext = ext
        self.fc = fc
        self.arrays = []
        fc.econ_data = self.arrays

    def primitive(self, marker, value):
        pass

    def array(self, marker, start, end):
        vals = decode_int_array(marker, self.ext.inner, start, end)
        if vals:
            self.arrays.append(vals)


class RegionCollector:
    """One REGION record: scalars[1] = region key; building keys collected
    from descendant BUILDING_BASE records (first string = building key)."""

    __slots__ = ("ext", "scalars", "buildings", "x", "y", "settlement_scalars",
                 "owner_key", "bundles", "province", "garrison_u32s")

    def __init__(self, ext):
        self.ext = ext
        self.scalars = []
        self.buildings = []
        self.x = None
        self.y = None
        self.settlement_scalars = None
        self.owner_key = None
        self.bundles = []
        self.province = None
        self.garrison_u32s = []
        ext.regions.append(self)
        ext.cur_region = self

    @property
    def key(self):
        for v in self.scalars[:4]:
            if isinstance(v, str) and v:
                return v
        return None

    def primitive(self, marker, value):
        self.scalars.append(value)

    def array(self, marker, start, end):
        pass


class BuildingKeyCollector:
    __slots__ = ("region", "key")

    def __init__(self, region):
        self.region = region
        self.key = None

    def primitive(self, marker, value):
        if self.key is None and isinstance(value, str) and value:
            self.key = value
            if self.region is not None:
                self.region.buildings.append(value)

    def array(self, marker, start, end):
        pass


class MissionCollector:
    """Player CAMPAIGN_MISSION: mission-level primitives after the definition
    record; first string is the status ('SUCCEEDED'/'ACTIVE'/...)."""

    __slots__ = ("ext", "values", "def_values")

    def __init__(self, ext):
        self.ext = ext
        self.values = []
        self.def_values = []
        ext.player_missions.append(self)

    @property
    def status(self):
        for v in self.values:
            if isinstance(v, str) and v:
                return v
        return None

    @property
    def mission_id(self):
        for v in self.def_values:
            if isinstance(v, str) and v:
                return v
        return None

    @property
    def title_loc(self):
        for v in self.def_values:
            if isinstance(v, str) and "title" in v:
                return v
        return None

    @property
    def desc_loc(self):
        for v in self.def_values:
            if isinstance(v, str) and ("description" in v or "objective" in v):
                return v
        return None

    def primitive(self, marker, value):
        self.values.append(value)

    def array(self, marker, start, end):
        pass


class MissionDefCollector:
    def primitive(self, marker, value):
        self.mission.def_values.append(value)

    def array(self, marker, start, end):
        pass

    __slots__ = ("mission",)

    def __init__(self, mission):
        self.mission = mission


class AncillaryKeyCollector:
    __slots__ = ("ext", "key")

    def __init__(self, ext):
        self.ext = ext
        self.key = None

    def primitive(self, marker, value):
        if self.key is None and isinstance(value, str) and value:
            self.key = value
            self.ext.player_ancillaries.append(value)

    def array(self, marker, start, end):
        pass


class ResourceCollector:
    """Player FACTION_POOLED_RESOURCE: [key string, value int, factors...]."""

    __slots__ = ("ext", "key", "value")

    def __init__(self, ext):
        self.ext = ext
        self.key = None
        self.value = None

    def primitive(self, marker, value):
        if self.key is None and isinstance(value, str) and value:
            self.key = value
        elif self.key is not None and self.value is None and isinstance(value, int):
            self.value = value
            self.ext.player_resources[self.key] = value

    def array(self, marker, start, end):
        pass


class StormCollector:
    __slots__ = ("ext", "stype")

    def __init__(self, ext):
        self.ext = ext
        self.stype = None

    def primitive(self, marker, value):
        if self.stype is None and isinstance(value, str) and value:
            self.stype = value
            self.ext.storms.append(value)

    def array(self, marker, start, end):
        pass


class CrisisCollector:
    __slots__ = ("ext",)

    def __init__(self, ext):
        self.ext = ext

    def primitive(self, marker, value):
        if value in (True, 1):
            self.ext.crisis_triggered = True

    def array(self, marker, start, end):
        pass


class CampaignExtractor:
    def __init__(self):
        self.header = None
        self.mods = []
        self.factions = []
        self.cur_faction = None
        self.cur_force = None
        self.player_key = None
        self.player_characters = []
        self.player_forces = []
        self.player_diplomacy = None
        self.player_missions = []
        self.player_ancillaries = []
        self.player_resources = {}
        self.regions = []
        self.cur_region = None
        self.storms = []
        self.crisis_triggered = False
        self.region_count = 0
        self.cur_unit = None
        self.inner = None
        self.char_details = []
        self.family_members = []

    def on_record(self, path, name, version, parent):
        n = len(path)
        if n == 2 and name == "SAVE_GAME_HEADER":
            self.header = HeaderCollector(self)
            return self.header
        if name == "mod_history_block_name" and isinstance(parent, HeaderCollector):
            return ModCollector(self)
        if n == 6 and name == "FACTION" and path[3] == "WORLD" and path[4] == "FACTION_ARRAY":
            return FactionCollector(self)
        fc = self.cur_faction
        if name == "FACTION_ECONOMICS" and isinstance(parent, FactionCollector):
            return EconCollector(fc)
        if name == "ECONOMICS_DATA" and fc is not None:
            return EconDataCollector(self, fc)
        if name == "CHARACTER" and n == 8 and path[6] == "CHARACTER_ARRAY" \
                and path[4] == "FACTION_ARRAY":
            if fc is not None:
                fc.characters += 1
                if fc.is_player:
                    return CharCollector(self)
            return NULL
        if name == "LOCOMOTABLE" and isinstance(parent, CharCollector):
            return LocoCollector(parent)
        if name == "OLD_DIPLOMACY_RELATIONSHIP" and n == 8 \
                and path[6] == "OLD_DIPLOMACY_MANAGER" and path[4] == "FACTION_ARRAY":
            if fc is not None:
                diplo = DiplomacyCollector(self, fc)
                fc.diplo_rows = diplo.rows
                if fc.is_player:
                    self.player_diplomacy = diplo
                return diplo
            return NULL
        if name == "MILITARY_FORCE" and n == 8 and path[6] == "ARMY_ARRAY" \
                and path[4] == "FACTION_ARRAY":
            if fc is not None:
                fc.forces += 1
                if fc.is_player:
                    force = ForceCollector(self)
                    self.cur_force = force
                    self.cur_unit = None
                    return force
            return NULL
        if name == "UNIT" and n == 11 and path[9] == "UNITS_ARRAY":
            if fc is not None:
                fc.units += 1
                if fc.is_player and self.cur_force is not None:
                    return UnitCollector(self, self.cur_force)
            return NULL
        if name == "UNIT_RECORD_KEY" and isinstance(parent, UnitCollector):
            return parent
        if name == "STATS_BLOCK" and isinstance(parent, UnitCollector):
            return StatsBlockCollector(parent)
        if name == "AGENT_CONTAINER" and isinstance(parent, ForceCollector):
            return AgentContainerCollector(self, parent)
        if name == "FAMILY_MEMBER" and n == 6 and path[4] == "FAMILY_TREE":
            return FamilyMemberCollector(self)
        if name == "CHARACTER_DETAILS" and isinstance(parent, FamilyMemberCollector):
            if parent.faction is not None and parent.faction == self.player_key:
                cd = CharDetailsCollector()
                cd.member_id = parent.member_id
                parent.details = cd
                self.char_details.append(cd)
                return cd
            return NULL
        if name == "CAMPAIGN_EFFECT_BUNDLES":
            if isinstance(parent, FactionCollector):
                if parent.is_player:
                    return BundlesCollector(parent.bundles)
                return NULL
            if isinstance(parent, ForceCollector):
                return BundlesCollector(parent.bundles)
            if isinstance(parent, CharDetailsCollector):
                return BundlesCollector(parent.bundles)
            if isinstance(parent, RegionCollector):
                return BundlesCollector(parent.bundles)
            return NULL
        if name == "EFFECT_BUNDLE_BLOCK" and isinstance(parent, BundlesCollector):
            return parent
        if name == "CAMPAIGN_EFFECT_BUNDLE" and isinstance(parent, BundlesCollector):
            bc = BundleCollector()
            parent.out.append(bc)
            return bc
        if name == "ADDITIONAL_EFFECTS" and isinstance(parent, BundleCollector):
            return AdditionalEffectsCollector(parent)
        if isinstance(parent, CharDetailsCollector):
            if name == "TRAIT":
                return TraitsCollector(parent)
            if name == "CHARACTER_NAME":
                return DetailsNameCollector(parent)
            if name == "ANCILLARY":
                return AncillaryItemCollector(parent)
            if name == "CAMPAIGN_SKILLS_BLOCK":
                return SkillsBlockCollector(parent)
            if name == "CAMPAIGN_SKILLS":
                return SkillsMetaCollector(parent)
            if name == "CHARACTER_DETAILS_ART_SET_INFO":
                return ArtSetInfoCollector(parent)
            return parent
        if isinstance(parent, (BundlesCollector, BundleCollector,
                               AdditionalEffectsCollector)):
            return parent
        if name == "CHARACTER_NAME" and self.cur_unit is not None \
                and isinstance(parent, UnitCollector):
            return NameElementCollector(self.cur_unit)
        if name == "REGION" and n == 7 and path[4] == "REGION_MANAGER" \
                and path[5] == "REGIONS_ARRAY":
            self.region_count += 1
            return RegionCollector(self)
        if isinstance(parent, RegionCollector):
            if name == "SETTLEMENT":
                return SettlementCollector(parent)
            return NULL
        if name == "BUILDING_BASE" and n >= 12 and path[10] == "REGION_BUILDING_MANAGER" \
                and path[6] == "REGION":
            return BuildingKeyCollector(self.cur_region)
        if name == "CAMPAIGN_MISSION" and n == 9 and path[7] == "ALL_MISSIONS" \
                and path[6] == "CAMPAIGN_MISSION_MANAGER" and path[4] == "FACTION_ARRAY":
            if fc is not None and fc.is_player:
                return MissionCollector(self)
            return NULL
        if name == "CAMPAIGN_MISSION_DEFINITION" and isinstance(parent, MissionCollector):
            return MissionDefCollector(parent)
        if name == "CAMPAIGN_LOCALISATION" and isinstance(parent, MissionDefCollector):
            return parent
        if name == "ANCILLARY" and n == 9 and path[6] == "ANCILLARY_POOL" \
                and path[4] == "FACTION_ARRAY":
            if fc is not None and fc.is_player:
                return AncillaryKeyCollector(self)
            return NULL
        if name == "POOLED_RESOURCE" and len(path) >= 8 \
                and path[6] == "FACTION_POOLED_RESOURCE_MANAGER" and path[4] == "FACTION_ARRAY":
            if fc is not None and fc.is_player:
                return ResourceCollector(self)
            return NULL
        if name == "STORM" and n == 6 and path[4] == "STORM_MANAGER":
            return StormCollector(self)
        if name == "crisis.triggered" and n == 6 and path[4] == "SCRIPT_VARIABLES":
            return CrisisCollector(self)
        # Nested records inside a collected subtree inherit the collector so
        # their primitives keep flowing (army name/province, unit commander
        # name blocks, unit stats, settlement coords all live in sub-records).
        if name == "GARRISON_RESIDENCE" and isinstance(parent, SettlementCollector):
            return GarrisonCollector(parent.region)
        if isinstance(parent, (UnitCollector, NameElementCollector,
                               StatsBlockCollector, TraitsCollector,
                               DetailsNameCollector, AncillaryItemCollector,
                               SkillsBlockCollector, SkillsMetaCollector,
                               ArtSetInfoCollector, AgentContainerCollector,
                               GarrisonCollector)):
            return parent
        if isinstance(parent, ForceCollector):
            return parent
        if isinstance(parent, SettlementCollector):
            return parent
        return NULL


def _header_slot(header, idx):
    if header is None or idx >= len(header.values):
        return None
    return header.values[idx]


def _char_to_dict(char):
    v = char.values
    u = char.u32s
    ctype = None
    for x in v[:3]:
        if isinstance(x, str):
            ctype = x
            break
    coord = char.coord
    # direct u32 children: [character_id, family_member_id, force_id, unit_id]
    char_id = u[0] if len(u) > 0 else None
    member_id = u[1] if len(u) > 1 else None
    force_id = u[2] if len(u) > 2 else None
    unit_id = u[3] if len(u) > 3 else None
    tpos = v.index(ctype) if ctype in v else -1
    if member_id is None and tpos >= 0:
        for x in v[tpos + 1:tpos + 4]:
            if isinstance(x, int) and not isinstance(x, bool):
                member_id = x
                break
    rank = None
    if tpos >= 0:
        for x in v[tpos + 1:tpos + 9]:
            if isinstance(x, int) and not isinstance(x, bool) and 0 < x < 100:
                if member_id is not None and x == member_id:
                    continue
                rank = x
                break
    return {
        "type": ctype,
        "rank": rank,
        "id": char_id,
        "member_id": member_id,
        "force_id": force_id,
        "unit_id": unit_id,
        "x": coord[0] if coord else None,
        "y": coord[1] if coord else None,
    }


def _settlement_info(scalars):
    if not scalars:
        return None, None
    skey = None
    level = None
    prev_int = None
    for marker, v in scalars:
        if skey is None:
            if isinstance(v, str) and v.startswith("settlement:"):
                skey = v.split(":", 1)[1]
                level = prev_int
            elif isinstance(v, int) and not isinstance(v, bool):
                prev_int = v
        else:
            break
    return skey, level


def _unit_to_dict(uc, faction_key):
    """UNIT primitives -> {key, uid, strength:[cur,max], hp, rank, commander}."""
    prims = uc.prims
    key = uc.key
    uid = None
    for m, v in prims[:3]:
        if isinstance(v, int) and not isinstance(v, bool):
            uid = v
            break
    strength = None
    hp = None
    rank = None
    xp_frac = None
    extra = None
    fidx = None
    if faction_key:
        for i, (m, v) in enumerate(prims):
            if v == faction_key:
                fidx = i
                break
    # Fixed slot window right after COMMANDER_DETAILS' faction key; aligns
    # with UNIT direct children uk[4..9] (WH3SaveEditor-verified):
    # [hp, hp_max, commander char u32, ?, rank, xp_f32]
    slots = []
    if fidx is not None:
        for m, v in prims[fidx + 1:]:
            if isinstance(v, bool):
                continue
            if isinstance(v, (int, float)) or v is None:
                slots.append(v)
            elif isinstance(v, str):
                break
            if len(slots) >= 6:
                break
    pool = None
    if fidx is not None:
        for m, v in prims[1:fidx]:
            if isinstance(v, str) and v and v != key:
                pool = v
                break
    if len(slots) >= 2:
        strength = [slots[0], slots[1]]
    if len(slots) >= 4 and isinstance(slots[3], int) and slots[3] > 0:
        hp = slots[3]
    rank = slots[4] if len(slots) >= 5 and isinstance(slots[4], int) else rank
    xp_frac = slots[5] if len(slots) >= 6 and isinstance(slots[5], float) else None
    extra = slots[2] if len(slots) >= 3 and isinstance(slots[2], int) else None
    return {
        "key": key,
        "uid": uid,
        "strength": strength,
        "hp": hp,
        "extra": extra,          # == uk[6], commanding character id
        "commander_id": extra,
        "rank": rank,
        "xp": xp_frac,
        "pool": pool,
        "stats_blocks": list(uc.stat_blocks),
        "commander": dict(uc.commander),
    }


def _force_to_dict(fc, garrison_map=None):
    fk = getattr(fc.ext, "player_key", None)
    force_id = fc.refs[0] if fc.refs else None
    commander_id = fc.refs[1] if len(fc.refs) >= 2 else None
    return {
        "name": fc.name,
        "ref": commander_id,
        "force_id": force_id,
        "commander_id": commander_id,
        "garrison_of": (garrison_map or {}).get(force_id),
        "province": fc.province,
        "settlement_loc": fc.settlement_loc,
        "x": fc.x,
        "y": fc.y,
        "commander_keys": list(fc.name_keys),
        "agent_cqis": list(fc.agent_cqis),
        "bundles": [b.to_dict() for b in fc.bundles],
        "units": [_unit_to_dict(u, fk) for u in fc.units],
    }


def _member_to_dict(cd, faction_keys):
    """CHARACTER_DETAILS -> member record; faction/type/subtype prefer the
    ART_SET_INFO strings, falling back to scalar scan."""
    art = list(cd.art)
    faction = art[0] if art else None
    fidx = None
    for i, v in enumerate(cd.scalars):
        if isinstance(v, str) and v in faction_keys:
            if faction is None:
                faction = v
            fidx = i
            break
    member_id = cd.member_id
    if member_id is None and fidx is not None:
        for v in cd.scalars[fidx + 1:fidx + 4]:
            if isinstance(v, int) and not isinstance(v, bool):
                member_id = v
                break
    ctype = art[3] if len(art) > 3 else None
    if ctype is None:
        for v in cd.scalars:
            if isinstance(v, str) and v in _AGENT_TYPES:
                ctype = v
                break
    subtype = art[4] if len(art) > 4 else None
    # CAMPAIGN_SKILLS trailing u32s: [unspent points, rank, xp]
    sp = rank = xp = None
    u = cd.skill_u32s
    if len(u) >= 3 and isinstance(u[-2], int) and 0 <= u[-2] <= 500:
        sp, rank, xp = u[-3], u[-2], u[-1]
    return {
        "member_id": member_id,
        "cqi": cd.cqis[0] if cd.cqis else None,
        "faction": faction,
        "type": ctype,
        "subtype": subtype,
        "rank": rank,
        "xp": xp,
        "skill_points": sp,
        "name": dict(cd.name),
        "traits": cd.traits,
        "ancillaries": cd.ancillaries,
        "skills": cd.skills,
        "bundles": [b.to_dict() for b in cd.bundles],
    }


def extract_summary(inner_bytes):
    """Parse inner ESF bytes into a campaign summary dict."""
    esf = EsfFile(inner_bytes)
    ext = CampaignExtractor()
    ext.inner = inner_bytes
    walk_esf(inner_bytes, esf, on_record=ext.on_record)

    header = ext.header
    player_key = _header_slot(header, 0)
    ext.player_key = player_key
    turn = _header_slot(header, 2)
    season = _header_slot(header, 4)
    player_name = _header_slot(header, 6)
    save_name = _header_slot(header, 8)
    campaign = _header_slot(header, 9)
    version = _header_slot(header, 11)

    player_fc = None
    for fc in ext.factions:
        if fc.is_player:
            player_fc = fc
            break

    mods = []
    for mc in ext.mods:
        vals = mc.values
        for i in range(0, len(vals) - 1, 4):
            mods.append({"pack": vals[i], "id": vals[i + 1] if i + 1 < len(vals) else ""})

    # ---- post pass: region ownership + per-faction war graph ----
    faction_keys = set()
    for fc in ext.factions:
        if fc.key:
            faction_keys.add(fc.key)
    faction_index = {}
    for fc in ext.factions:
        if fc.key:
            faction_index[fc.key] = fc

    region_rows = []
    region_xy = {}
    garrison_map = {}  # force_id -> region_key
    for rc in ext.regions:
        k = rc.key
        if not k:
            continue
        owner = None
        for v in rc.scalars[:8]:
            if isinstance(v, str) and v in faction_keys and v != k:
                owner = v
                break
        if owner is None:
            for v in rc.scalars:
                if isinstance(v, str) and v in faction_keys and v != k:
                    owner = v
                    break
        rc.owner_key = owner
        skey, level = _settlement_info(rc.settlement_scalars)
        if rc.province is None:
            for v in rc.scalars:
                if isinstance(v, str) and "_province_" in v:
                    rc.province = v
                    break
        row = {
            "key": k,
            "owner": owner,
            "province": rc.province,
            "bundles": [b.to_dict() for b in rc.bundles],
            "settlement": skey,
            "level": level,
            "x": rc.x,
            "y": rc.y,
            "buildings": list(rc.buildings),
        }
        if len(rc.garrison_u32s) > 8 and rc.garrison_u32s[8]:
            garrison_map[rc.garrison_u32s[8]] = k
        region_rows.append(row)
        if rc.x is not None:
            region_xy[k] = [rc.x, rc.y]
        if owner in faction_index:
            faction_index[owner].region_keys.append(k)

    # Diplomacy rows reference the target faction's numeric id
    # (FACTION children[0]); fall back to array index for old fields.
    fnum_to_key = {fc.fnum: fc.key for fc in ext.factions
                   if fc.fnum is not None and fc.key}

    def _diplo_key(idx):
        if not isinstance(idx, int):
            return None
        key = fnum_to_key.get(idx)
        if key is None and 0 <= idx < len(ext.factions):
            key = ext.factions[idx].key
        return key

    wars = set()
    for fc in ext.factions:
        rows = fc.diplo_rows or []
        for row in rows:
            if row["stance"] != "war":
                continue
            a = fc.key
            b = _diplo_key(row["index"])
            if a and b:
                wars.add((a, b) if a < b else (b, a))

    player_payload = None
    if player_fc is not None:
        diplomacy = []
        diplo = ext.player_diplomacy
        if diplo is not None:
            for row in diplo.rows:
                diplomacy.append({
                    "key": _diplo_key(row["index"]),
                    "stance": row["stance"],
                    "war_metric": row["v8"],
                    "attitude": row["attitude"],
                })
        char_rows = [_char_to_dict(c) for c in ext.player_characters]
        armies = [_force_to_dict(f, garrison_map) for f in ext.player_forces]
        # join: force.commander_id -> CHARACTER u32[0]; char.member_id ->
        # FAMILY_MEMBER; char.force_id -> MILITARY_FORCE u32[0]
        char_by_id = {c["id"]: c for c in char_rows if c.get("id") is not None}
        char_by_member = {c["member_id"]: c for c in char_rows
                          if c.get("member_id") is not None}
        force_by_id = {}
        for a in armies:
            if a.get("force_id") is not None:
                force_by_id[a["force_id"]] = a
            ch = char_by_id.get(a.get("commander_id"))
            if ch is not None:
                a["commander_member_id"] = ch.get("member_id")
            for u in a.get("units") or []:
                ch = char_by_id.get(u.get("commander_id"))
                if ch is not None:
                    u["commander_member_id"] = ch.get("member_id")
        members = []
        for cd in ext.char_details:
            m = _member_to_dict(cd, faction_keys)
            if m["faction"] not in (player_fc.key, None):
                continue
            ch = char_by_member.get(m["member_id"])
            if ch:
                m["x"] = ch.get("x")
                m["y"] = ch.get("y")
                m["force_id"] = ch.get("force_id")
                fr = force_by_id.get(m["force_id"])
                if fr is not None:
                    m["army"] = fr.get("name")
            members.append(m)
        player_payload = {
            "key": player_fc.key,
            "name": player_name,
            "treasury": player_fc.treasury,
            "forces": player_fc.forces,
            "units": player_fc.units,
            "characters": char_rows,
            "force_units": [f.unit_keys for f in ext.player_forces],
            "diplomacy": diplomacy,
            "ancillaries": list(ext.player_ancillaries),
            "missions": [
                {
                    "id": m.mission_id,
                    "title_loc": m.title_loc,
                    "desc_loc": m.desc_loc,
                    "status": m.status,
                }
                for m in ext.player_missions
            ],
            "resources": dict(ext.player_resources),
            "econ_extra": list(player_fc.econ_extra),
            "econ_data": player_fc.econ_data or [],
            "armies": armies,
            "faction_bundles": [b.to_dict() for b in player_fc.bundles],
            "members": members,
            "regions": [r for r in region_rows if r["owner"] == player_fc.key],
        }

    region_buildings = {}
    region_keys = []
    for rc in ext.regions:
        k = rc.key
        if k:
            region_keys.append(k)
            if rc.buildings:
                region_buildings[k] = list(rc.buildings)

    return {
        "schema": SCHEMA,
        "save": {
            "name": save_name,
            "campaign": campaign,
            "version": version,
            "turn": turn if isinstance(turn, int) else None,
            "season": season,
            "player_faction_key": player_key,
            "player_faction_name": player_name,
            "portrait": _header_slot(header, 1),
            "flag": _header_slot(header, 5),
            "mods": mods,
        },
        "world": {
            "faction_count": len(ext.factions),
            "region_count": ext.region_count,
            "region_keys": region_keys,
            "region_buildings": region_buildings,
            "regions": region_rows,
            "region_xy": region_xy,
            "wars": sorted(wars),
            "storms": list(ext.storms),
            "crisis_triggered": ext.crisis_triggered,
        },
        "player": player_payload,
        "factions": [
            {
                "key": fc.key,
                "id": fc.fnum,
                "treasury": fc.treasury,
                "forces": fc.forces,
                "units": fc.units,
                "characters": fc.characters,
                "regions": len(fc.region_keys),
            }
            for fc in ext.factions
        ],
    }


def summarize_save(save_path):
    """Full pipeline: .save path -> summary dict."""
    from .esf import load_save
    _, inner = load_save(save_path)
    return extract_summary(inner)
