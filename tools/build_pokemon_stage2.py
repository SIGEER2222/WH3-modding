# -*- coding: utf-8 -*-
"""Pokemon pilot stage 2: skeleton resources + animsuite bins + DB TSVs + loc.

- animations/skeletons/<skel>.anim          (v8 bind-pose skeleton file)
- animations/skeletons/<skel>.bone_inv_trans_mats
- animations/database/battle/bin/<skel>.bin (rewritten donor bin, slots kept)
- variantmeshdefinitions/<variant>.variantmeshdefinition (direct rmv2 ref)
- rewrites rmv2 material texture paths -> our dds
- db/*.tsv fragments + text/db/loc.tsv

Run with Windows Python313 after build_pokemon_pilot.py.
"""
import io, json, re, struct, sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, r"E:\Code\WH3-modding\tools")
from rmv2_convert import parse_rmv2, read_glb, glb_mesh, write_rmv2_v8
from anim_rw import write_file, decompress
from fit_skeleton import write_invmats, quat_to_mat

ROOT = Path(r"E:\Code\WH3-modding")
SRC = ROOT / "scratch" / "pokemon"
MOD = ROOT / "mod_files" / "zzz_czx_pokemon"
DONOR = ROOT / "tools" / "_donor" / "files"
DGM = ROOT / "mod_files" / "zzz_czx_digimon"
VANILLA = ROOT / "scratch" / "salzaar_digimon"
T = "\t"

# key, glb, skel, donor-bin family, tier, cn/en names
UNITS = [
    dict(key="pkm_001_bulbasaur", pmid="pm0001", skel="pm001", fam="wf1",
         variant="pm001", tier=1, cn="妙蛙种子", en="Bulbasaur",
         ent="wh_main_infantry_standard_blood_dismembers"),
    dict(key="pkm_003_venusaur", pmid="pm0003", skel="pm003", fam="wf1",
         variant="pm003", tier=3, cn="妙蛙花", en="Venusaur",
         ent="wh_dlc03_bst_mon_minotaur_blood"),
    dict(key="pkm_004_charmander", pmid="pm0004", skel="pm004", fam="hu1",
         variant="pm004", tier=1, cn="小火龙", en="Charmander",
         ent="wh_main_infantry_standard_blood_dismembers"),
    dict(key="pkm_006_charizard", pmid="pm0006", skel="pm006", fam="dr1b",
         variant="pm006", tier=3, cn="喷火龙", en="Charizard",
         ent="wh_dlc08_flying_chaos_frost_dragon_blood"),
    dict(key="pkm_007_squirtle", pmid="pm0007", skel="pm007", fam="hu1",
         variant="pm007", tier=1, cn="杰尼龟", en="Squirtle",
         ent="wh_main_infantry_standard_blood_dismembers"),
    dict(key="pkm_009_blastoise", pmid="pm0009", skel="pm009", fam="hu1",
         variant="pm009", tier=3, cn="水箭龟", en="Blastoise",
         ent="wh_dlc03_bst_mon_minotaur_blood"),
    dict(key="pkm_025_pikachu", pmid="pm0025", skel="pm025", fam="hu1",
         variant="pm025", tier=1, cn="皮卡丘", en="Pikachu",
         ent="wh_main_infantry_standard_blood_dismembers"),
]

FAMBINS = {
    "wf1": (VANILLA / "vanilla_wf1_wolf" / "wf1_giant_wolf.bin", "wolf01"),
    "hu1": (VANILLA / "vanilla_hu1_sws" / "hu1_empire_sword_and_shield.bin",
            "humanoid01"),
    "dr1b": (VANILLA / "vanilla_dr1b_dragon" / "dr1b_chaos_dragon.bin",
             "dragon01b"),
}

# ------------------------------------------------------------- bin rewriter

def rd_str(b, o):
    l, = struct.unpack_from("<H", b, o)
    return b[o + 2:o + 2 + l].decode("utf-8"), o + 2 + l


def wr_str(s):
    e = s.encode("utf-8")
    return struct.pack("<H", len(e)) + e


def parse_bin(path):
    """Tokenize bin into (offset,end,string) u16str tokens.
    Byte structure between tokens is kept verbatim on rebuild — only
    string *contents* are rewritten (length-prefixed, so length changes ok)."""
    b = Path(path).read_bytes()
    toks = []
    i = 0
    n = len(b)
    while i + 2 <= n:
        L = struct.unpack_from("<H", b, i)[0]
        if (2 <= L <= 400 and i + 2 + L <= n
                and all(0x20 <= c <= 0x7E for c in b[i + 2:i + 2 + L])):
            toks.append((i, i + 2 + L, b[i + 2:i + 2 + L].decode("ascii")))
            i += 2 + L
        else:
            i += 1
    return b, toks


SEM_RULES = [
    (r"attack2|special|breath|shoot|spell|missile|beam", "attack02"),
    (r"attack|bite|claw|strike|melee|kill|matched|combat_attack|pounce|gore", "attack01"),
    (r"hit|damage|flinch|stagger|knock|impact|pain|recoil", "damage"),
    (r"death|die|down|dead|fall|collapse|corpse", "down"),
    (r"getup|get_up|rise|recover|unstunned", "getup"),
    (r"guard|block|defend|shield", "guard"),
    (r"win|cheer|victor|taunt|roar|spawn|summon|affirmative|celebrat", "win"),
    (r"eat|feed|devour", "eat"),
    (r"walk|run|move|charge|locomot|turn|fly|rout|flee|withdraw|trot|canter|gallop|jump|hop", "move"),
    (r"stand|idle|porthole|wait|taxi|land|sleep|sitting", "idle"),
]


def sem_clip(donor_anim_path):
    fn = Path(donor_anim_path).stem.lower()
    for rx, clip in SEM_RULES:
        if re.search(rx, fn):
            return clip
    return "idle"


def build_bin(donor_path, donor_skel, skel, out_path):
    """Rebuild donor bin replacing every 'animations/battle/<donor_skel>/...'
    .anim token with our mapped clip, skeleton/skeletons/suite-name tokens
    with our skel. All other bytes (slots, blends, meta/snd refs, counts)
    are preserved verbatim."""
    raw, toks = parse_bin(donor_path)
    used = {}
    repl = []
    cursor = 0
    for s, e, content in toks:
        low = content.lower()
        new = None
        if content == donor_path.stem or content == donor_skel:
            new = skel
        elif low.startswith("animations/skeletons/") and donor_skel in content:
            new = content.replace(donor_skel, skel)
        elif low.endswith(".anim") and low.startswith("animations/battle/"):
            clip = sem_clip(content)
            new = f"animations/battle/{skel}/{clip}.anim"
            used[clip] = used.get(clip, 0) + 1
        if new is not None:
            repl.append((s, e, new))
        cursor = e
    out = bytearray()
    prev = 0
    for s, e, new in repl:
        out += raw[prev:s]
        out += wr_str(new)
        prev = e
    out += raw[prev:]
    out_path.write_bytes(bytes(out))
    return used


# ------------------------------------------------------- skeleton resources

def skel_world(glb_path, bones):
    """world pos/quat per bone at GLB rest pose."""
    js, _ = read_glb(str(glb_path))
    nodes = js["nodes"]
    bone_set = {i for i, n in enumerate(nodes) if "mesh" not in n}
    order = [i for i, n in enumerate(nodes) if "mesh" not in n]

    def node_mat(n):
        if "matrix" in n:
            return np.array(n["matrix"]).reshape(4, 4).T
        t = n.get("translation", [0, 0, 0])
        r = n.get("rotation", [0, 0, 0, 1])
        s = n.get("scale", [1, 1, 1])
        x, y, z, w = r
        R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        M = np.eye(4); M[:3, :3] = R @ np.diag(s); M[:3, 3] = t
        return M

    world = {}
    def walk(i, P):
        M = P @ node_mat(nodes[i])
        world[i] = M
        for c in nodes[i].get("children", []):
            walk(c, M)
    children = {c for n in nodes for c in n.get("children", [])}
    for r in set(range(len(nodes))) - children:
        walk(r, np.eye(4))

    wp, wq = [], []
    for ni in order:
        M = world[ni]
        R = M[:3, :3]
        # orthonormalise (strip possible uniform scale)
        sc = np.linalg.norm(R, axis=0)
        Rn = R / np.where(sc == 0, 1, sc)
        # rot mat -> quat
        tr = np.trace(Rn)
        if tr > 0:
            S = np.sqrt(tr + 1) * 2
            q = [(Rn[2, 1] - Rn[1, 2]) / S, (Rn[0, 2] - Rn[2, 0]) / S,
                 (Rn[1, 0] - Rn[0, 1]) / S, S / 4]
        else:
            i = int(np.argmax(np.diag(Rn)))
            j, k = (i + 1) % 3, (i + 2) % 3
            S = np.sqrt(Rn[i, i] - Rn[j, j] - Rn[k, k] + 1) * 2
            q = [0, 0, 0, 0]
            q[i] = S / 4
            q[j] = (Rn[j, i] + Rn[i, j]) / S
            q[k] = (Rn[k, i] + Rn[i, k]) / S
            q[3] = (Rn[k, j] - Rn[j, k]) / S
        n = np.linalg.norm(q) or 1
        wp.append(M[:3, 3].tolist())
        wq.append([c / n for c in q])
    return wp, wq


def write_skel_anim(bones, glb_path, out_path):
    js, _ = read_glb(str(glb_path))
    bone_nodes = [i for i, n in enumerate(js["nodes"]) if "mesh" not in n]
    trans, quats = [], []
    for ni in bone_nodes:
        n = js["nodes"][ni]
        trans.append(list(n.get("translation", [0, 0, 0])))
        quats.append(list(n.get("rotation", [0, 0, 0, 1])))
    bc = len(bones)
    frame = {"transforms": trans, "quaternions": quats}
    anim = {"version": 8, "unk0": 1, "frame_rate": 20.0,
            "skeleton_name": out_path.stem, "flags": [],
            "play_time": 0.1, "bones": bones, "unk_v8": 6,
            "parts": [{"tb": [12] * bc, "rb": [8] * bc, "rt": [], "rq": [],
                       "stc": 0, "sqc": 0, "static": None,
                       "ftc": bc, "fqc": bc,
                       "frames": [frame, dict(frame), dict(frame)]}]}
    write_file(anim, str(out_path), zstd_compress=True)


# ---------------------------------------------------------- rmv2 mat fix

def fix_rmv2(u):
    """rewrite rmv2 embedding our texture paths in the material block."""
    key, skel, grp = u["key"], u["skel"], "pk1"
    pack_dir = MOD / "variantmeshes" / "wh_variantmodels" / grp / key
    texdir = f"variantmeshes/wh_variantmodels/{grp}/{key}/textures"
    donor = parse_rmv2(DONOR / "def_sorceress_body_01.rigid_model_v2")
    donor_model = donor["models"][0][0]
    d = donor_model["material"]
    d["textures"] = [(t, p) for t, p in d["textures"]]
    texbase = u["pmid"]
    new_tex = []
    for ttype, _ in d["textures"]:
        if ttype == 27:
            new_tex.append((ttype, f"{texdir}/{texbase}_base_colour.dds"))
        elif ttype == 1:
            new_tex.append((ttype, f"{texdir}/{texbase}_normal.dds"))
        elif ttype == 29:
            new_tex.append((ttype, f"{texdir}/{texbase}_material_map.dds"))
        elif ttype == 3:
            new_tex.append((ttype, f"{texdir}/{texbase}_mask.dds"))
        else:
            new_tex.append((ttype, f"{texdir}/{texbase}_base_colour.dds"))
    d["textures"] = new_tex
    skel_json = SRC / f"{key}_skel.json"
    mesh = glb_mesh(str(SRC / f"{u['pmid']}_00_00.glb"), str(skel_json))
    write_rmv2_v8(str(pack_dir / f"{key}.rigid_model_v2"), skel, mesh,
                  donor_model, lod_levels=1)


# ------------------------------------------------------------------ DB TSV

# table -> schema version (digimon meta values, proven encodable)
TABLE_VER = {
    "battle_animations_table_tables": 0,
    "battle_currency_units_cost_values_tables": 0,
    "battle_skeletons_tables": 17,
    "building_units_allowed_tables": 4,
    "cdir_military_generator_unit_qualities_tables": 2,
    "culture_to_battle_animation_tables_tables": 0,
    "land_units_tables": 54,
    "main_units_tables": 7,
    "melee_weapons_tables": 25,
    "unit_attributes_groups_tables": 0,
    "unit_attributes_to_groups_junctions_tables": 2,
    "unit_description_historical_texts_tables": 0,
    "unit_description_short_texts_tables": 0,
    "unit_set_to_unit_junctions_tables": 1,
    "unit_sets_tables": 2,
    "unit_variants_tables": 5,
    "units_custom_battle_permissions_tables": 11,
    "units_to_groupings_military_permissions_tables": 0,
    "variants_tables": 6,
}


def tsv_write(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    ver = TABLE_VER.get(path.parent.name, 0)
    meta = f"#{path.parent.name};{ver};db/{path.parent.name}/{path.stem}"
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        f.write(T.join(header) + "\n" + meta + "\n")
        for r in rows:
            f.write(T.join(str(c) for c in r) + "\n")


TIER = {
    1: dict(hp=2400, atk=32, dfn=28, morale=45, charge=20, dmg=60, ap=28,
            splash="medium", spl_n=2, recruit=700, upkeep=175, mp=700,
            supplies="500.0", quality="tier_2_step_3_units",
            armour="wh2_main_body_95", attrs=["strider"]),
    3: dict(hp=8500, atk=42, dfn=36, morale=60, charge=35, dmg=95, ap=42,
            splash="large", spl_n=3, recruit=1600, upkeep=400, mp=1500,
            supplies="1500.0", quality="tier_4_step_1_units",
            armour="wh2_main_body_110", attrs=["strider", "fear", "terror"]),
}

# buildings per tier (reuse digimon building list)
BLDG = Path(DGM / "db" / "building_units_allowed_tables" / "!!dgm_digimon.tsv")


def digi_rows(table, col, value):
    f = DGM / "db" / table / "!!dgm_digimon.tsv"
    lines = f.read_text(encoding="utf-8-sig").splitlines()
    hdr = lines[0].split(T)
    ci = hdr.index(col)
    return sorted({l.split(T)[ci] for l in lines[2:]
                   if l.split(T)[ci] == value or value is None})


def gen_db():
    db = MOD / "db"
    # ---- land_units (clone chr050 template layout)
    hdr_lu = (DGM / "db" / "land_units_tables" / "!!dgm_digimon.tsv")\
        .read_text(encoding="utf-8-sig").splitlines()[0].split(T)
    tmpl = None
    for l in (DGM / "db" / "land_units_tables" / "!!dgm_digimon.tsv")\
            .read_text(encoding="utf-8-sig").splitlines()[2:]:
        if "chr050" in l:
            tmpl = l.split(T); break
    idx = {c: i for i, c in enumerate(hdr_lu)}
    lu_rows = []
    for u in UNITS:
        t = TIER[u["tier"]]
        r = list(tmpl)
        def setc(name, val):
            if name in idx:
                r[idx[name]] = val
        setc("key", u["key"])
        setc("man_animation", u["skel"])          # bin stem = skeleton
        setc("man_entity", u["ent"])
        setc("primary_melee_weapon", f"{u['key']}_strike")
        setc("primary_missile_weapon", "")
        setc("armour", t["armour"])
        setc("melee_attack", t["atk"])
        setc("melee_defence", t["dfn"])
        setc("morale", t["morale"])
        setc("charge_bonus", t["charge"])
        setc("bonus_hit_points", t["hp"])
        setc("historical_description_text", f"pkm_long_{u['variant']}")
        setc("short_description_text", f"pkm_short_{u['variant']}")
        setc("attribute_group", f"{u['key']}_attrs")
        setc("spacing", "wh_main_monster")
        lu_rows.append(r)
    tsv_write(db / "land_units_tables" / "!!pkm_pokemon.tsv", hdr_lu, lu_rows)

    # ---- main_units
    hdr_mu = (DGM / "db" / "main_units_tables" / "!!dgm_digimon.tsv")\
        .read_text(encoding="utf-8-sig").splitlines()[0].split(T)
    tmpl_mu = None
    for l in (DGM / "db" / "main_units_tables" / "!!dgm_digimon.tsv")\
            .read_text(encoding="utf-8-sig").splitlines()[2:]:
        if "chr050" in l:
            tmpl_mu = l.split(T); break
    im = {c: i for i, c in enumerate(hdr_mu)}
    mu_rows = []
    for u in UNITS:
        t = TIER[u["tier"]]
        r = list(tmpl_mu)
        def setm(name, val):
            if name in im:
                r[im[name]] = val
        setm("unit", u["key"])
        setm("land_unit", u["key"])
        setm("recruitment_cost", t["recruit"])
        setm("upkeep_cost", t["upkeep"])
        setm("multiplayer_cost", t["mp"])
        setm("create_time", 1 if u["tier"] == 1 else 2)
        mu_rows.append(r)
    tsv_write(db / "main_units_tables" / "!!pkm_pokemon.tsv", hdr_mu, mu_rows)

    # ---- melee_weapons
    hdr_mw = (DGM / "db" / "melee_weapons_tables" / "!!dgm_digimon.tsv")\
        .read_text(encoding="utf-8-sig").splitlines()[0].split(T)
    tmpl_mw = None
    for l in (DGM / "db" / "melee_weapons_tables" / "!!dgm_digimon.tsv")\
            .read_text(encoding="utf-8-sig").splitlines()[2:]:
        if "chr050" in l:
            tmpl_mw = l.split(T); break
    iw = {c: i for i, c in enumerate(hdr_mw)}
    mw_rows = []
    for u in UNITS:
        t = TIER[u["tier"]]
        r = list(tmpl_mw)
        def setw(name, val):
            if name in iw:
                r[iw[name]] = val
        setw("key", f"{u['key']}_strike")
        setw("damage", t["dmg"])
        setw("ap_damage", t["ap"])
        setw("splash_attack_target_size", t["splash"])
        setw("splash_attack_max_attacks", t["spl_n"])
        mw_rows.append(r)
    tsv_write(db / "melee_weapons_tables" / "!!pkm_pokemon.tsv", hdr_mw, mw_rows)

    # ---- battle_animations + battle_skeletons + culture map
    tsv_write(db / "battle_animations_table_tables" / "!!pkm_pokemon.tsv",
              ["key", "skeleton"],
              [[u["skel"], u["skel"]] for u in UNITS])

    skel_hdr = (DGM / "db" / "battle_skeletons_tables" / "!!dgm_digimon.tsv")\
        .read_text(encoding="utf-8-sig").splitlines()[0].split(T)
    tmpl_sk = None
    for l in (DGM / "db" / "battle_skeletons_tables" / "!!dgm_digimon.tsv")\
            .read_text(encoding="utf-8-sig").splitlines()[2:]:
        if "chr050" in l:
            tmpl_sk = l.split(T); break
    isk = {c: i for i, c in enumerate(skel_hdr)}

    def bone_map(names):
        """semantic role -> actual bone name for a pokemon skeleton."""
        def pick(*cands):
            for c in cands:
                if c in names:
                    return c
            for c in cands:
                for n in names:
                    if n.lower() == c.lower():
                        return n
            return ""
        return {
            "head_node": pick("Head"),
            "hips_node": pick("Hips", "Waist"),
            "neck_node": pick("Neck1", "Neck"),
            "spine_node": pick("Spine1", "Waist"),
            "root": pick("Origin", names[0]),
            "back_node": pick("Tail1"),
            "leftarm_node": pick("LArm"),
            "leftshoulder_node": pick("LShoulder"),
            "lefthand_node": pick("LHand"),
            "leftfinger_node": pick("LFinger", "LFingerA", "LFinger1", "LFingerA1"),
            "leftupleg_node": pick("LThigh"),
            "leftleg_node": pick("LLeg"),
            "leftfoot_node": pick("LFoot"),
            "lefttoe_node": pick("LToe", "LToeA"),
            "rightarm_node": pick("RArm"),
            "rightshoulder_node": pick("RShoulder"),
            "righthand_node": pick("RHand"),
            "rightfinger_node": pick("RFinger", "RFingerA", "RFinger1", "RFingerA1"),
            "rightupleg_node": pick("RThigh"),
            "rightleg_node": pick("RLeg"),
            "rightfoot_node": pick("RFoot"),
            "righttoe_node": pick("RToe", "RToeA"),
            "leftwingbase_node": pick("LFeeler1", "LWing1"),
            "rightwingbase_node": pick("RFeeler1", "RWing1"),
            "footstep_nodes": ";".join(x for x in
                                       [pick("LFoot"), pick("RFoot"),
                                        pick("LToe", "LToeA"), pick("RToe", "RToeA")] if x),
        }

    sk_rows = []
    for u in UNITS:
        names = [b["name"] for b in json.loads(
            (SRC / f"{u['key']}_skel.json").read_text())["bones"]]
        bm = bone_map(names)
        r = list(tmpl_sk)
        for cname, val in bm.items():
            if cname in isk:
                r[isk[cname]] = val
        r[isk["name"]] = u["skel"]
        r[isk["scale"]] = "1.0"
        sk_rows.append(r)
    tsv_write(db / "battle_skeletons_tables" / "!!pkm_pokemon.tsv",
              skel_hdr, sk_rows)

    cultures = digi_rows("culture_to_battle_animation_tables_tables",
                         "culture_pack", None)
    tsv_write(db / "culture_to_battle_animation_tables_tables" / "!!pkm_pokemon.tsv",
              ["battle_animations_table", "culture_pack"],
              [[u["skel"], c] for u in UNITS for c in cultures])

    # ---- variants / unit_variants
    tsv_write(db / "variants_tables" / "!!pkm_pokemon.tsv",
              ["variant_name", "tech_folder", "variant_filename",
               "low_poly_filename", "mount_scale", "scale", "scale_variation",
               "super_low_poly_filename"],
              [[u["variant"], "", u["variant"], "", "1.0", "1.0", "0.0", ""]
               for u in UNITS])
    tsv_write(db / "unit_variants_tables" / "!!pkm_pokemon.tsv",
              ["faction", "name", "unit", "variant", "unit_card"],
              [["", u["key"], u["key"], u["variant"], u["variant"]]
               for u in UNITS])

    # ---- attribute groups
    tsv_write(db / "unit_attributes_groups_tables" / "!!pkm_pokemon.tsv",
              ["group_name"], [[f"{u['key']}_attrs"] for u in UNITS])
    tsv_write(db / "unit_attributes_to_groups_junctions_tables" / "!!pkm_pokemon.tsv",
              ["attribute", "attribute_group"],
              [[a, f"{u['key']}_attrs"] for u in UNITS for a in TIER[u["tier"]]["attrs"]])

    # ---- unit sets
    tsv_write(db / "unit_sets_tables" / "!!pkm_pokemon.tsv",
              ["key", "use_unit_exp_level_range", "min_unit_exp_level_inclusive",
               "max_unit_exp_level_inclusive", "special_category"],
              [["pkm_pokemon_all", "false", "0", "9", ""]])
    tsv_write(db / "unit_set_to_unit_junctions_tables" / "!!pkm_pokemon.tsv",
              ["exclude", "unit_caste", "unit_category", "unit_class",
               "unit_record", "unit_set"],
              [["false", "", "", "", u["key"], "pkm_pokemon_all"] for u in UNITS])

    # ---- permissions
    factions = digi_rows("units_custom_battle_permissions_tables", "faction", None)
    tsv_write(db / "units_custom_battle_permissions_tables" / "!!pkm_pokemon.tsv",
              ["faction", "general_unit", "unit", "siege_unit_attacker",
               "siege_unit_defender", "general_portrait", "general_uniform",
               "set_piece_character", "campaign_exclusive", "armory_item_set",
               "supports_upgrades"],
              [[f, "false", u["key"], "true", "true", "", "", "", "false", "", ""]
               for u in UNITS for f in factions])

    groups = digi_rows("units_to_groupings_military_permissions_tables",
                     "military_group", None)
    tsv_write(db / "units_to_groupings_military_permissions_tables" / "!!pkm_pokemon.tsv",
              ["unit", "military_group"],
              [[u["key"], g] for u in UNITS for g in groups])

    # ---- buildings (tier gated, reuse digimon building list+level filter)
    bldg_levels = {}
    for l in BLDG.read_text(encoding="utf-8-sig").splitlines()[2:]:
        f = l.split(T)
        if len(f) > 1:
            bldg_levels[f[0]] = True
    lvl_re = re.compile(r"_([1-5])(?:[a-zA-Z_].*)?$")

    def bldg_level(b):
        m = lvl_re.search(b)
        return int(m.group(1)) if m else 0

    allowed = {1: {1, 2}, 3: {3, 4, 5}}
    b_rows = []
    keyseq = 2147300000
    for u in UNITS:
        for b in sorted(bldg_levels):
            if bldg_level(b) in allowed[u["tier"]]:
                b_rows.append([b, u["key"], "0", str(keyseq), "0", "", "true"])
                keyseq += 1
    tsv_write(db / "building_units_allowed_tables" / "!!pkm_pokemon.tsv",
              ["building", "unit", "XP", "key", "conditions", "faction", "enabled"],
              b_rows)

    # ---- cdir + currency + descriptions
    tsv_write(db / "cdir_military_generator_unit_qualities_tables" / "!!pkm_pokemon.tsv",
              ["group_key", "unit_key", "quality"],
              [["wh3_default_land_monsters_heavy", u["key"],
                TIER[u["tier"]]["quality"]] for u in UNITS])
    tsv_write(db / "battle_currency_units_cost_values_tables" / "!!pkm_pokemon.tsv",
              ["cost_value", "currency_type", "item_type"],
              [[TIER[u["tier"]]["supplies"], "supplies_currency", u["key"]]
               for u in UNITS])
    tsv_write(db / "unit_description_short_texts_tables" / "!!pkm_pokemon.tsv",
              ["key"], [[f"pkm_short_{u['variant']}"] for u in UNITS])
    tsv_write(db / "unit_description_historical_texts_tables" / "!!pkm_pokemon.tsv",
              ["key"], [[f"pkm_long_{u['variant']}"] for u in UNITS])

    # ---- loc.tsv
    loc = MOD / "text" / "db" / "loc.tsv"
    loc.parent.mkdir(parents=True, exist_ok=True)
    rows = ["key\ttext\ttooltip",
            "#loc_tables;3;text/db/loc"]
    for u in UNITS:
        rows += [
            f"units_onscreen_name_{u['key']}\t{u['cn']}\ttrue",
            f"land_units_onscreen_name_{u['key']}\t{u['cn']}\ttrue",
            f"unit_description_short_texts_text_pkm_short_{u['variant']}\t{u['cn']}（{u['en']}）\ttrue",
            f"unit_description_historical_texts_text_pkm_long_{u['variant']}\t{u['cn']}，宝可梦。\ttrue",
        ]
    loc.write_text("\n".join(rows) + "\n", encoding="utf-8-sig")


# ---------------------------------------------------------------------- main

def main():
    # 1. fix rmv2 material texture paths
    for u in UNITS:
        fix_rmv2(u)
        print("rmv2 fixed", u["key"])

    # 2. skeleton anim + invmats + bins + vmd
    skdir = MOD / "animations" / "skeletons"
    skdir.mkdir(parents=True, exist_ok=True)
    bindir = MOD / "animations" / "database" / "battle" / "bin"
    bindir.mkdir(parents=True, exist_ok=True)
    vmddir = MOD / "variantmeshes" / "variantmeshdefinitions"
    vmddir.mkdir(parents=True, exist_ok=True)
    for u in UNITS:
        glb = SRC / f"{u['pmid']}_00_00.glb"
        skel_json = json.loads((SRC / f"{u['key']}_skel.json").read_text())
        bones = skel_json["bones"]
        write_skel_anim(bones, glb, skdir / f"{u['skel']}.anim")
        wp, wq = skel_world(glb, bones)
        write_invmats(wp, wq, str(skdir / f"{u['skel']}.bone_inv_trans_mats"))
        bin_path, dskel = FAMBINS[u["fam"]]
        used = build_bin(bin_path, dskel, u["skel"],
                         bindir / f"{u['skel']}.bin")
        vmd = (f'<VARIANT_MESH>\n\t<SLOT name="body" >\n'
               f'\t\t<VARIANT_MESH model="variantmeshes/wh_variantmodels/pk1/'
               f'{u["key"]}/{u["key"]}.rigid_model_v2" '
               f' imposter_model="variantmeshes/wh_variantmodels/pk1/'
               f'{u["key"]}/{u["key"]}.rigid_model_v2" />\n\t</SLOT>\n'
               f'</VARIANT_MESH>\n')
        (vmddir / f"{u['variant']}.variantmeshdefinition").write_text(
            vmd, encoding="utf-8")
        print(f"{u['skel']}: skel+invmats+bin({len(used)} clips->{sorted(used)})")

    # 3. drop the stray in-dir vmd/wsmodel/material files from stage 1
    for u in UNITS:
        d = MOD / "variantmeshes" / "wh_variantmodels" / "pk1" / u["key"]
        for junk in [f"{u['key']}.variantmeshdefinition",
                     f"{u['key']}.wsmodel", f"{u['key']}.xml.material"]:
            p = d / junk
            if p.exists():
                p.unlink()

    # 4. DB
    gen_db()
    print("DB+loc done")


if __name__ == "__main__":
    main()
