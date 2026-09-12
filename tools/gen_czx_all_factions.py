# -*- coding: utf-8 -*-
"""Generate all-faction availability TSVs for czx units, mirroring the
companion pack `!!ia_all_factions.pack` that already does this for
gou/leishou/cishe.

Outputs (into mod_files/czx_swarm_expansion/db/...):
- units_custom_battle_permissions_tables/!!czx_all_factions.tsv
- units_to_groupings_military_permissions_tables/!!czx_all_factions.tsv
- building_units_allowed_tables/!!czx_all_factions.tsv
"""
import sys
from pathlib import Path

sys.path.insert(0, r"E:\Code\WH3-modding\tools")
from export_gamedata import iter_pack_entries, decode_db_table, load_schema, SCHEMA_RON

MOD = Path(r"E:\Code\WH3-modding\mod_files\czx_swarm_expansion")
IA = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data\!!ia_all_factions.pack")

schemas = load_schema(SCHEMA_RON)

# unit -> (general_unit, siege_att, siege_def, portrait)
CB_UNITS = {
    "czx_feilong": ("false", "true", "true", ""),
    "czx_zhanglang": ("false", "true", "true", ""),
    "czx_kerrigan": ("true", "true", "true", r"ui/portraits/units/no_culture/czx_kerrigan.png"),
    "czx_kerrigan_lord": ("true", "true", "true", r"ui/portraits/units/no_culture/czx_kerrigan_lord.png"),
}
GROUP_UNITS = ["czx_feilong", "czx_zhanglang"]          # lords not in mp groupings
BUILDING_UNITS = ["czx_feilong", "czx_zhanglang"]        # lords not recruited from buildings
KEY_BASE = 780500000                                   # key int range for building rows

tables = {}
for e in iter_pack_entries(IA):
    n = e.name.replace(chr(92), '/')
    tbl = n.split('/')[-2]
    ver, fields, rows = decode_db_table(tbl, e.payload, schemas[tbl])
    tables[tbl] = (fields, rows)

# --- 1. custom battle permissions ---
cb_fields, cb_rows = tables['units_custom_battle_permissions_tables']
fi = cb_fields.index('faction')
factions = sorted({r[fi] for r in cb_rows})
out = ["faction\tgeneral_unit\tunit\tsiege_unit_attacker\tsiege_unit_defender\tgeneral_portrait\tgeneral_uniform\tset_piece_character\tcampaign_exclusive\tarmory_item_set\tsupports_upgrades",
       "#units_custom_battle_permissions_tables;11;db/units_custom_battle_permissions_tables/!!czx_all_factions"]
for f in factions:
    if f == 'wh_main_emp_empire':
        continue  # already covered by base patch rows
    for u, (gen, sa, sd, portrait) in CB_UNITS.items():
        out.append(f"{f}\t{gen}\t{u}\t{sa}\t{sd}\t{portrait}\t\t\tfalse\t\tfalse")
p = MOD / "db/units_custom_battle_permissions_tables/!!czx_all_factions.tsv"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("cb perms:", len(out) - 2, "rows ->", p)

# --- 2. military groupings ---
gr_fields, gr_rows = tables['units_to_groupings_military_permissions_tables']
gi = gr_fields.index('military_group')
groups = sorted({r[gi] for r in gr_rows})
out = ["unit\tmilitary_group",
       "#units_to_groupings_military_permissions_tables;0;db/units_to_groupings_military_permissions_tables/!!czx_all_factions"]
for g in groups:
    if g in ("wh_main_group_empire", "wh_main_group_empire_reikland"):
        continue  # covered by base patch rows
    for u in GROUP_UNITS:
        out.append(f"{u}\t{g}")
p = MOD / "db/units_to_groupings_military_permissions_tables/!!czx_all_factions.tsv"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("groupings:", len(out) - 2, "rows ->", p)

# --- 3. building units allowed ---
bu_fields, bu_rows = tables['building_units_allowed_tables']
bi = bu_fields.index('building')
buildings = sorted({r[bi] for r in bu_rows})
out = ["building\tunit\tXP\tkey\tconditions\tfaction\tenabled",
       "#building_units_allowed_tables;4;db/building_units_allowed_tables/!!czx_all_factions"]
key = KEY_BASE
for b in buildings:
    for u in BUILDING_UNITS:
        out.append(f"{b}\t{u}\t0\t{key}\t0\t\tfalse")
        key += 1
p = MOD / "db/building_units_allowed_tables/!!czx_all_factions.tsv"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("buildings:", len(out) - 2, "rows ->", p)
