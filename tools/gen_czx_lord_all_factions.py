# -*- coding: utf-8 -*-
"""Generate all-faction campaign agent permissions for czx_kerrigan (hero)
and czx_kerrigan_lord (lord), plus all-culture agent_culture_details rows.

Sources faction list + culture list from vanilla game db.
"""
import sys
from pathlib import Path

sys.path.insert(0, r"E:\Code\WH3-modding\tools")
from export_gamedata import iter_pack_entries, decode_db_table, load_schema, SCHEMA_RON

MOD = Path(r"E:\Code\WH3-modding\mod_files\czx_swarm_expansion")
DATA = Path(r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data")
schemas = load_schema(SCHEMA_RON)


def decode_from_game(table):
    """Return (fields, rows) of the data__ table for `table` from db/data packs."""
    best = None
    for pname in ("db.pack", "data.pack"):
        for e in iter_pack_entries(DATA / pname):
            n = e.name.replace(chr(92), '/')
            if n == f"db/{table}/data__":
                ver, fields, rows = decode_db_table(table, e.payload, schemas[table])
                best = (fields, rows)
    return best


fields_f, rows_f = decode_from_game('factions_tables')
fi = fields_f.index('key')
factions = sorted({r[fi] for r in rows_f if r[fi].strip()})
print('factions:', len(factions))

fields_c, rows_c = decode_from_game('cultures_tables')
ci = fields_c.index('key')
cultures = sorted({r[ci] for r in rows_c if r[ci].strip()})
print('cultures:', len(cultures))

# --- faction_agent_permitted_subtypes: every faction x both agents ---
out = ["agent\tfaction\tsubtype\tmod_disabled",
       "#faction_agent_permitted_subtypes_tables;1;db/faction_agent_permitted_subtypes_tables/!!czx_all_factions"]
emp_facs = {"wh_main_emp_empire", "wh2_dlc13_emp_golden_order",
            "wh2_dlc13_emp_the_huntmarshals_expedition",
            "wh3_main_emp_cult_of_sigmar", "wh3_dlc27_emp_empire_dm"}
for f in factions:
    if f in emp_facs:
        continue  # covered by base patch rows
    out.append(f"general\t{f}\tczx_kerrigan_lord\tfalse")
    out.append(f"wizard\t{f}\tczx_kerrigan\tfalse")
p = MOD / "db/faction_agent_permitted_subtypes_tables/!!czx_all_factions.tsv"
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("agent perms:", len(out) - 2, "rows ->", p)

# --- agent_culture_details: every culture x both agents ---
# fields: agent culture associated_unit key season level agent_recruited_movie gender icon small_icon recruitable_in_ui
out = ["agent\tculture\tassociated_unit\tkey\tseason\tlevel\tagent_recruited_movie\tgender\ticon\tsmall_icon\trecruitable_in_ui",
       "#agent_culture_details_tables;9;db/agent_culture_details_tables/!!czx_all_factions"]
key = 789900100
for c in cultures:
    if c == "wh_main_emp_empire":
        continue
    out.append(f"general\t{c}\tczx_kerrigan_lord\t{key}\t\t0\t\tf\t\tui/campaign ui/agents/wh_main_wizard.png\ttrue")
    key += 1
    out.append(f"wizard\t{c}\tczx_kerrigan\t{key}\t\t0\t\tf\t\tui/campaign ui/agents/wh_main_wizard.png\ttrue")
    key += 1
p = MOD / "db/agent_culture_details_tables/!!czx_all_factions.tsv"
p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("culture details:", len(out) - 2, "rows ->", p)
