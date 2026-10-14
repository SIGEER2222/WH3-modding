# -*- coding: utf-8 -*-
"""Effective game DB for the current Mod Manager playset.

Builds the same merged view the game sees (vanilla + active playset packs +
saved unit-data edits) by reusing wyccc-warhammer-mod-manager's backend:
  - unit_encyclopedia.build_catalogue -> per-unit card panel values
  - game_data._collect_effective_rows -> bonus/effect/junction tables
  - encyclopedia_localization.collect_catalogue_loc -> zh-CN texts
  - encyclopedia_assets.EncyclopediaAssets -> unit-card / icon PNG lookup

Requires Windows Python (backend needs Pillow/zstandard). Everything here is
read-only. The merged result is cached as JSON under cache/gamedb_<hash>.json,
keyed by backend.catalogue_fingerprint (playset ids + file stamps), so a
playset or mod-content change rebuilds it automatically while a plain
server restart reuses the cache.
"""

import hashlib
import json
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
WORKSPACE = os.path.dirname(ROOT)
CACHE_DIR = os.path.join(ROOT, "cache")

WMM_ROOT = r"E:\Code\wyccc-warhammer-mod-manager"
GAME_ROOT = r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III"

# Tables needed for effect/bonus resolution, beyond the catalogue's own set.
BONUS_TABLES = (
    "effects_tables",
    "effect_bundles_tables",
    "effect_bundles_to_effects_junctions_tables",
    "effect_bonus_value_basic_junction_tables",
    "effect_bonus_value_unit_record_junctions_tables",
    "effect_bonus_value_ids_unit_sets_tables",
    "effect_bonus_value_unit_list_junctions_tables",
    "effect_bonus_value_unit_class_junction_tables",
    "effect_bonus_value_unit_class_stat_modifiers_junctions_tables",
    "effect_bonus_value_unit_ability_junctions_tables",
    "effect_bonus_value_unit_attribute_junctions_tables",
    "effect_bonus_value_special_ability_phase_record_junctions_tables",
    "effect_bonus_value_military_force_ability_junctions_tables",
    "effect_bonus_value_agent_subtype_junctions_tables",
    "trait_level_effects_tables",
    "character_trait_levels_tables",
    "ancillary_to_effects_tables",
    "ancillaries_tables",
    "character_skill_level_to_effects_junctions_tables",
    "character_skills_tables",
    "campaign_effect_scopes_tables",
    "unit_stat_modifiers_tables",
    "unit_experience_bonuses_tables",
    "unit_sets_tables",
    "unit_set_to_unit_junctions_tables",
    "unit_to_unit_list_junctions_tables",
    "unit_lists_tables",
    "agent_subtypes_tables",
    "unit_stat_localisations_tables",
    "land_units_tables",
    "main_units_tables",
    "technologies_tables",
    "technology_effects_junction_tables",
    "pooled_resources_tables",
    "special_ability_phases_tables",
    "unit_abilities_tables",
    "unit_attributes_tables",
    "unit_attributes_groups_tables",
    "unit_attributes_to_groups_junctions_tables",
)

_state = {
    "loaded": False,
    "error": None,
    "db": None,          # compact JSON-able payload (cached)
    "assets": None,      # EncyclopediaAssets (not serialisable; rebuilt live)
}


def _win_import():
    """Import the Mod Manager backend; returns module bundle or raises."""
    if WMM_ROOT not in sys.path:
        sys.path.insert(0, WMM_ROOT)
    from backend import game_data, start_options, unit_data  # noqa: F401
    from backend.constants import (INTERNAL_FEATURE_PACK_NAMES,
                                   INTERNAL_RUNTIME_PACK_NAMES)
    from backend.models import ModAsset
    from backend.start_options import (UNIT_DATA_PATCH_NAME,
                                       collect_game_data_source_snapshot)
    from backend.unit_data_state import load_unit_data_edits
    from backend.unit_encyclopedia import (CATALOGUE_PREFIXES, build_catalogue,
                                           catalogue_fingerprint)
    from backend.encyclopedia_localization import collect_catalogue_loc
    from backend.encyclopedia_assets import EncyclopediaAssets
    return {
        "game_data": game_data,
        "start_options": start_options,
        "INTERNAL_FEATURE_PACK_NAMES": INTERNAL_FEATURE_PACK_NAMES,
        "INTERNAL_RUNTIME_PACK_NAMES": INTERNAL_RUNTIME_PACK_NAMES,
        "ModAsset": ModAsset,
        "UNIT_DATA_PATCH_NAME": UNIT_DATA_PATCH_NAME,
        "collect_game_data_source_snapshot": collect_game_data_source_snapshot,
        "load_unit_data_edits": load_unit_data_edits,
        "CATALOGUE_PREFIXES": CATALOGUE_PREFIXES,
        "build_catalogue": build_catalogue,
        "catalogue_fingerprint": catalogue_fingerprint,
        "collect_catalogue_loc": collect_catalogue_loc,
        "EncyclopediaAssets": EncyclopediaAssets,
    }


def _appdata_dir():
    ad = os.environ.get("APPDATA")
    if ad:
        p = os.path.join(ad, "WycccModManager")
        if os.path.isdir(p):
            return p
    return None


def _local_pack_id(path):
    s = os.path.abspath(path).replace("\\", "/").lower()
    return "local:data:" + hashlib.sha256(s.encode()).hexdigest()[:18]


def _build_mods(be):
    """All candidate packs: data/*.pack + workshop content/*/*.pack."""
    mods = {}
    data_dir = os.path.join(GAME_ROOT, "data")
    ws_root = os.path.join(os.path.dirname(os.path.dirname(GAME_ROOT)),
                           "workshop", "content", "1142710")
    for p in sorted(os.listdir(data_dir)):
        if not p.lower().endswith(".pack"):
            continue
        fp = os.path.join(data_dir, p)
        aid = _local_pack_id(fp)
        mods[aid] = be["ModAsset"](id=aid, pack_name=p, display_name=p[:-5],
                                   path=fp, directory=data_dir, source="data")
    if os.path.isdir(ws_root):
        for wsid in sorted(os.listdir(ws_root)):
            d = os.path.join(ws_root, wsid)
            if not os.path.isdir(d):
                continue
            for p in sorted(os.listdir(d)):
                if not p.lower().endswith(".pack"):
                    continue
                fp = os.path.join(d, p)
                aid = "steam:%s:%s" % (wsid, p)
                mods[aid] = be["ModAsset"](id=aid, pack_name=p,
                                           display_name=p[:-5], path=fp,
                                           directory=d, source="steam")
    return mods


def _active_ids(be, mods):
    ad = _appdata_dir()
    con = sqlite3.connect(os.path.join(ad, "state.db"))
    try:
        playset_id = con.execute(
            "SELECT value FROM app_state WHERE key='current_playset_id:warhammer3'"
        ).fetchone()[0]
        playset_name = (con.execute(
            "SELECT name FROM playsets WHERE id=?", (playset_id,)
        ).fetchone() or ["?"])[0]
        wanted = [r[0] for r in con.execute(
            "SELECT mod_id FROM playset_items WHERE playset_id=? ORDER BY position",
            (playset_id,)).fetchall()]
    finally:
        con.close()

    excluded = {n.casefold() for n in be["INTERNAL_FEATURE_PACK_NAMES"]}
    excluded |= {n.casefold() for n in be["INTERNAL_RUNTIME_PACK_NAMES"]}
    excluded.add(be["UNIT_DATA_PATCH_NAME"].casefold())

    ws_root = os.path.join(os.path.dirname(os.path.dirname(GAME_ROOT)),
                           "workshop", "content", "1142710")
    active, missing = [], []
    for mod_id in wanted:
        asset = mods.get(mod_id)
        if asset is None and mod_id.startswith("steam:"):
            _, wsid, pack_name = mod_id.split(":", 2)
            path = os.path.join(ws_root, wsid, pack_name)
            if os.path.isfile(path):
                asset = be["ModAsset"](id=mod_id, pack_name=pack_name,
                                       display_name=pack_name[:-5], path=path,
                                       directory=os.path.dirname(path),
                                       source="steam")
                mods[mod_id] = asset
        if asset is None or not os.path.isfile(asset.path):
            missing.append(mod_id)
            continue
        if os.path.basename(asset.path).casefold() in excluded:
            continue
        active.append(mod_id)
    return playset_id, playset_name, active, missing


def _dump_cache(db):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        tmp = db["cache_path"] + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({k: v for k, v in db.items() if k != "cache_path"},
                      f, ensure_ascii=False)
        os.replace(tmp, db["cache_path"])
    except OSError:
        pass


def load(force=False):
    """Return the merged game-DB dict (or None when the backend is missing)."""
    if _state["loaded"] and not force:
        return _state["db"]
    _state["loaded"] = True
    try:
        be = _win_import()
        mods = _build_mods(be)
        playset_id, playset_name, active, missing = _active_ids(be, mods)
        fp = be["catalogue_fingerprint"](
            os.path.join(GAME_ROOT, "data"), mods, active, "zh-CN")
        digest = hashlib.sha1(repr(fp).encode()).hexdigest()[:16]
        cache_path = os.path.join(CACHE_DIR, "gamedb_%s.json" % digest)
        if not force and os.path.isfile(cache_path):
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    db = json.load(f)
                db["cache_path"] = cache_path
                _attach_assets(be, mods, active, db)
                _state["db"] = db
                return db
            except (OSError, ValueError):
                pass

        prefixes = tuple(dict.fromkeys(
            list(be["CATALOGUE_PREFIXES"]) +
            ["db" + chr(92) + t + chr(92) for t in BONUS_TABLES]))
        snap = be["collect_game_data_source_snapshot"](
            os.path.join(GAME_ROOT, "data"), mods, active, prefixes=prefixes)
        mod_paths = [e.spec.path for e in snap.entries if e.spec.role != "vanilla"]

        # merged loc (vanilla language packs + mod loc packs)
        loc = be["collect_catalogue_loc"](
            __import__("pathlib").Path(os.path.join(GAME_ROOT, "data")),
            [__import__("pathlib").Path(p) for p in mod_paths], "zh-CN")
        loc = {k: v for k, v in loc.items()}

        # unit catalogue (panel values, merged incl. saved edits)
        ad = _appdata_dir()
        edits = be["load_unit_data_edits"](
            __import__("pathlib").Path(ad) / "runtime", "warhammer3")
        assets = be["EncyclopediaAssets"](
            [__import__("pathlib").Path(p) for p in mod_paths] +
            [__import__("pathlib").Path(os.path.join(GAME_ROOT, "data", n))
             for n in ("ui.pack", "ui2.pack", "ui3.pack")
             if os.path.isfile(os.path.join(GAME_ROOT, "data", n))])
        cat = be["build_catalogue"](snap.sources, edits, loc, assets)

        rows = _merge_bonus_tables(be, snap, set(BONUS_TABLES))

        db = {
            "playset_id": playset_id,
            "playset_name": playset_name,
            "active_ids": active,
            "missing": missing,
            "cache_path": cache_path,
            "units": {u["key"]: u for u in cat.get("units", [])},
            "loc": loc,
            "rows": rows,
            "source_pack_names": [e.spec.path.name for e in snap.entries],
        }
        _state["assets"] = assets
        _state["db"] = db
        _dump_cache(db)
        return db
    except Exception as exc:  # noqa: BLE001 - degrade to no-DB mode
        import traceback
        _state["error"] = "%s: %s" % (type(exc).__name__, exc)
        traceback.print_exc()
        _state["db"] = None
        return None


def _merge_bonus_tables(be, snap, wanted):
    """Merge junction/effect tables across all sources (later wins per
    composite key) using the full vendored schema — _collect_effective_rows
    collapses by single-column key and drops junction rows, so merge here."""
    from backend.conflict_scan import _load_full_schema
    from backend.game_data import parse_db_table

    full = _load_full_schema()          # {table: {ver: {"fields","keys"}}}
    schema_map = {
        t: {v: list(e["fields"]) for v, e in vers.items()}
        for t, vers in full.items()
    }
    merged = {t: {} for t in wanted}
    for source in snap.sources:
        for entry in source.entries:
            parts = entry.name.replace("/", chr(92)).split(chr(92))
            if len(parts) != 3 or parts[0].casefold() != "db":
                continue
            table = parts[1]
            if table not in wanted:
                continue
            try:
                parsed = parse_db_table(table, entry.payload, schema_map=schema_map)
            except ValueError:
                continue
            vers = full.get(table) or {}
            key_fields = (vers.get(parsed.version) or
                          vers.get(max(vers)) or {}).get("keys") or ("key",)
            bucket = merged[table]
            for row in parsed.rows:
                vals = row.values
                key = "".join(str(vals.get(f) or "") for f in key_fields)
                bucket[key] = vals
    return merged


def _attach_assets(be, mods, active, db):
    """Rebuild the asset index when loading from cache (image paths only)."""
    try:
        data_dir = os.path.join(GAME_ROOT, "data")
        mod_paths = [mods[i].path for i in active if i in mods]
        vanilla_ui = [os.path.join(data_dir, n)
                      for n in ("ui.pack", "ui2.pack", "ui3.pack")
                      if os.path.isfile(os.path.join(data_dir, n))]
        _state["assets"] = be["EncyclopediaAssets"](
            [__import__("pathlib").Path(p) for p in [*mod_paths, *vanilla_ui]])
    except Exception:  # noqa: BLE001
        _state["assets"] = None


def error():
    return _state["error"]


def read_image(name):
    """Serve one pack UI image as (bytes, ext) for the icon endpoint."""
    assets = _state.get("assets")
    if assets is None:
        return None
    res = assets.read([name]).get(name)
    if not res:
        return None
    if res.startswith("data:"):
        import base64
        head, _, b64 = res.partition(",")
        ext = "png" if "png" in head else "octet-stream"
        return base64.b64decode(b64), ext
    return None
