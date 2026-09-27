# -*- coding: utf-8 -*-
"""Batch-port digimon units from the Salzaar GLB dump into zzz_czx_digimon.

Pipeline per unit (subcommand-driven, resumable):
  scan   roster -> pick GLB -> dump joints + bounds -> auto landmarks -> report
  fit    landmarks -> skel_czx_<u>.json via fit_skeleton (form template)
  bind   blender rig2 nofit bind -> bound glb + overlay png QA
  anim   skeleton .anim + invmats + meta + retargeted clips + cloned bin
  rmv2   rmv2/dds/wsmodel/vmd via convert machinery
  db     gen_digimon_db rows (reads PORTED.tsv overrides)

State lives in scratch/digimon_batch/ (report.json, per-unit artifacts).

Usage:
  python tools/digimon_batch.py scan [--form biped] [--units k1,k2]
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "zzz_czx_digimon"
GLB_DIR = ROOT / "scratch" / "salzaar_digimon" / "glb"
WORK = ROOT / "scratch" / "digimon_batch"
ROSTER = MOD / "ROSTER.tsv"
PORTED = MOD / "PORTED.tsv"
TOOLS = ROOT / "tools"

sys.path.insert(0, str(TOOLS))
from rmv2_convert import read_accessor  # noqa: E402

# ------------------------------------------------------------- GLB helpers

def read_glb(path):
    d = Path(path).read_bytes()
    jl = struct.unpack("<I", d[12:16])[0]
    js = json.loads(d[20:20 + jl])
    return js, d[20 + jl + 8:]


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
    M = np.eye(4)
    M[:3, :3] = R @ np.diag(s)
    M[:3, 3] = t
    return M


def glb_scene(path):
    """(joints{name:worldpos}, parents{name:parentname|None},
        (lo,hi) world bbox, n_images, n_verts)."""
    js, binbuf = read_glb(path)
    nodes = js["nodes"]
    world = {}
    par_idx = {}

    def walk(i, P, par):
        M = P @ node_mat(nodes[i])
        world[i] = M
        par_idx[i] = par
        for c in nodes[i].get("children", []):
            walk(c, M, i)

    children = {c for n in nodes for c in n.get("children", [])}
    for r in set(range(len(nodes))) - children:
        walk(r, np.eye(4), None)

    joints = {}
    parents = {}
    skins = js.get("skins", [])
    # bind-space joint anchors: inv(IBM_j)[:3,3] — the joint's position in
    # raw mesh space. Equals world pos when rest==bind, but stays correct
    # for rest!=bind sources (shinegreymon rest pose lies along -Z etc.)
    skin_bind = {}
    for sk in skins:
        if "inverseBindMatrices" not in sk:
            continue
        ibm = read_accessor(js, binbuf, sk["inverseBindMatrices"])
        ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1)
        ibm_inv = np.linalg.inv(ibm)
        for i, j in enumerate(sk.get("joints", [])):
            skin_bind[j] = ibm_inv[i][:3, 3]
    if skins:
        # union of ALL skins' joints — some sources split the body into
        # several skinned meshes (jesmonx: backpack/body/scarf skins); the
        # first skin alone may lack whole limb chains
        jset = set()
        for sk in skins:
            jset.update(sk.get("joints", []))
        for j in jset:
            nm = nodes[j].get("name", f"n{j}")
            joints[nm] = np.asarray(
                skin_bind.get(j, world[j][:3, 3])).tolist()
            p = par_idx.get(j)
            while p is not None and p not in jset:
                p = par_idx.get(p)          # skip non-skin ancestors
            parents[nm] = nodes[p].get("name") if p is not None else None

    lo = np.array([1e9] * 3)
    hi = np.array([-1e9] * 3)
    nv = 0
    node_skin = {i: n.get("skin") for i, n in enumerate(nodes)}
    for i, n in enumerate(nodes):
        if "mesh" not in n or i not in world:
            continue
        for pr in js["meshes"][n["mesh"]].get("primitives", []):
            a = js["accessors"][pr["attributes"]["POSITION"]]
            bv = js["bufferViews"][a["bufferView"]]
            pos = np.frombuffer(
                binbuf, dtype="<f4", count=a["count"] * 3,
                offset=bv.get("byteOffset", 0) + a.get("byteOffset", 0)
            ).reshape(-1, 3).astype(np.float64)
            nv += a["count"]
            if node_skin[i] is not None:
                wp = pos        # skinned: POSITION is already bind space
            else:
                wp = (world[i][:3, :3] @ pos.T).T + world[i][:3, 3]
            lo = np.minimum(lo, wp.min(0))
            hi = np.maximum(hi, wp.max(0))
    return joints, parents, (lo.tolist(), hi.tolist()), \
        len(js.get("images", [])), nv


# ------------------------------------------------------------ GLB selection

# unit_key -> forced GLB filename (for multi-form series / mismatched names)
GLB_OVERRIDE = {
    "czx_dgm_imperialfm": "帝皇龙甲兽系列_chr419_2.glb",
    "czx_dgm_imperialpm": "帝皇龙甲兽系列_chr420_2.glb",
    # zhansunskill3.glb has a broken skin (refs missing J_Weapon02_R)
    "czx_dgm_omegamond": "奥米加兽兹瓦特战损_g008_master.glb",
    # the _2 variants of these are degenerate (collapsed pose / no images);
    # use the base files which have sane meshes + textures
    "czx_dgm_rosemon": "蔷薇兽_chr057.glb",
    "czx_dgm_rosemonbm": "蔷薇兽_chr779.glb",
    "czx_dgm_metalgarurumon": "钢铁加鲁鲁_chr135.glb",
    # 2026-09 batch triage (renders in scratch/digimon_batch/_cands):
    # these picks had exploded/lying/empty meshes in Blender; replaced with
    # the candidate that renders a coherent upright model.
    "czx_dgm_alphamon": "阿尔法兽_chr416.glb",
    "czx_dgm_gabumon": "加布兽_chr151 with animations.glb",
    "czx_dgm_gatomon": "迪路兽_chr092.glb",
    "czx_dgm_growlmon": "古拉兽_chr078 with animations.glb",
    "czx_dgm_jesmonx": "杰斯兽x_chr468 with animations.glb",
    "czx_dgm_megakabuterimon": "超比多兽_chr305 With Animations.glb",
    "czx_dgm_metalgreymon": "机械暴龙兽_chr302.glb",
    "czx_dgm_metalseadramon": "钢铁海龙兽_chr434 with animations.glb",
    "czx_dgm_omegamonm": "奥米加兽慈悲形态_chr448 With Animations.glb",
    "czx_dgm_omegamonx": "奥米加兽x_奥米加兽X.glb",
    "czx_dgm_seraphimon": "炽天使兽_chr315.glb",
    "czx_dgm_shinegreymon": "闪光暴龙兽_chr094 With Animations.glb",
    "czx_dgm_shinegreymonbm": "闪光暴龙兽_闪光暴龙兽爆裂.glb",
    "czx_dgm_skullgreymon": "丧尸暴龙兽_chr404 with animations.glb",
    "czx_dgm_taomon": "祭祀兽_chr405 with animations.glb",
    "czx_dgm_veemon": "v仔兽_chr114_s100.glb",
    "czx_dgm_weregarurumon": "兽人加鲁鲁兽_chr140.glb",
    "czx_dgm_zeedmillennium": "最终千年兽_chr230 with animations.glb",
    "czx_dgm_aerovdramon": "天翔v龙兽_chr400 with animations.glb",
}

# external base-colour PNG for GLBs that ship no embedded texture
TEX_OVERRIDE = {
    "czx_dgm_lilimon": ROOT / "scratch" / "salzaar_digimon" / "extracted"
                       / "textures" / "Lillymon.png",
    "czx_dgm_veemon": ROOT / "scratch" / "salzaar_digimon" / "extracted"
                      / "textures" / "chr114a01.png",
}

# roster cn -> index digimon name when they differ
CN_ALIAS = {
    "祭师兽": "祭祀兽",
    "喷射西尔芙兽": "喷射风灵兽",
}

# ------------------------------------------------------- animation families
# Per-family vanilla resources under scratch/salzaar_digimon/<vdir>/:
#   <bin>                    animation-library bin to clone+patch
#   <tmpl>.anim              template skeleton anim (fit_skeleton source)
#   clips/ + clip_list.txt   vanilla clips to retarget (paths under
#                            animations/battle/<tmpl>/)
# Skeleton names MUST keep len(tmpl) chars for the bin byte patch.
VANILLA = ROOT / "scratch" / "salzaar_digimon"
FAMILY = {
    "biped": dict(tmpl="humanoid01", vdir="vanilla_hu1_sws",
                  bin="hu1_empire_sword_and_shield.bin",
                  suffix="emp_sws1", slot="hu1",
                  donor="emp_greatswords_body_01.rigid_model_v2",
                  entity="wh_dlc03_bst_mon_minotaur_blood",
                  weapon="", meta=True,
                  exclude=r"^(be_prop_|finger_|slot_|fx_)"),
    "quad": dict(tmpl="wolf01", vdir="vanilla_wf1_wolf",
                 bin="wf1_giant_wolf.bin", suffix="wf1_wolf",
                 slot="wf1", donor="lzd_stegadon_02.rigid_model_v2",
                 entity="wh_main_monster_wolf_hound_blood",
                 weapon="wh2_dlc16_wef_wolf_fangs", meta=False,
                 exclude=r"^(be_prop_|slot_|fx_|eye_lid_|ear_)"),
    "bird": dict(tmpl="bird01", vdir="vanilla_bi1_eagle",
                 bin="bi1_eagle.bin", suffix="bi1_eagl",
                 slot="bi1", donor="tmb_carrion_body_01.rigid_model_v2",
                 entity="wh_dlc05_wef_mon_great_eagle_blood",
                 weapon="wh_dlc05_wef_great_eagle", meta=False,
                 exclude=r"^(be_prop_|slot_|fx_|eyelid_|saddle_)"),
    "snake": dict(tmpl="snake01", vdir="vanilla_sn1_serpent",
                  bin="sn1_serpent.bin", suffix="sn1_serp",
                  slot="sn1", donor="lzd_stegadon_02.rigid_model_v2",
                  entity="wh2_dlc09_tmb_mon_sepulchral_stalker",
                  weapon="wh2_dlc09_tmb_halberd_stalker", meta=False,
                  exclude=(r"^(be_prop_|finger_|thumb_|slot_|fx_|"
                           r"shoulderpad_|lowerarm_roll_|upperarm_roll_)")),
    "spider": dict(tmpl="spider01", vdir="vanilla_sp1_spider",
                   bin="sp1_giant_spider.bin", suffix="sp1_spid",
                   slot="sp1",
                   donor="grn_giant_spider_body_01.rigid_model_v2",
                   entity="wh_main_monster_spider_giant_blood",
                   weapon="wh2_dlc16_wef_spider_fangs_0", meta=False,
                   exclude=r"^(be_prop_|slot_|fx_|platform_)"),
    "dragon": dict(tmpl="dragon01b", vdir="vanilla_dr1b_dragon",
                   bin="dr1b_chaos_dragon.bin", suffix="dr1b_drg",
                   slot="dr1b",
                   donor="lzd_ancient_stegadon_01.rigid_model_v2",
                   entity="wh_dlc08_flying_chaos_frost_dragon_blood",
                   weapon="wh_dlc08_nor_wyrm", meta=False,
                   exclude=(r"^(be_prop_|slot_|fx_|nostril_|eyelid_|"
                            r"saddle_|feather_secondary_|feather_tertiary_)")),
}

# per-unit family override (roster `form` alone is unreliable for monsters)
FAMILY_OF = {
    # roster "flyer" but actually bird/quadruped rigs (verified by renders)
    "czx_dgm_biyomon": "bird",
    "czx_dgm_birdramon": "bird",
    "czx_dgm_hououmon": "bird",
    "czx_dgm_patamon": "quad",
    "czx_dgm_zubaeagermon": "quad",
    # roster "quadruped" but upright bipeds (render-verified)
    "czx_dgm_dorugamon": "biped",
    "czx_dgm_dorumon": "biped",
    "czx_dgm_cresgarurumon": "biped",
    # imperialdm: bipedal dragon stance (2 legs + arms + wings) -> humanoid
    "czx_dgm_imperialdm": "biped",
    # dorugoramon: T-rex stance biped (forelimbs don't reach ground)
    "czx_dgm_dorugoramon": "biped",
    # apocalymon: polyhedron + tentacle arms + bottom spike -> naga
    "czx_dgm_apocalymon": "snake",
}

# _fbx-style GLBs store bind space z-up (x=lat, y=fwd, z=up);
# rotate joints+baked mesh into the game frame: (x,y,z) -> (x, z, -y)
def _zup_of(joints):
    """True when bind-space joints sit on a z=0 ground plane (z-up file)."""
    if not joints:
        return False
    a = np.array(list(joints.values()), dtype=float)
    ys, zs = a[:, 1], a[:, 2]
    sy = max(np.ptp(ys), 1e-6)
    sz = max(np.ptp(zs), 1e-6)
    return bool(zs.min() > -0.08 * sz
                and (sz > 1.1 * sy
                     or abs((ys.min() + ys.max()) / 2) < 0.3 * sy))


# prop-ish bones that may dangle below the ground plane and skew bbox
PROP_RE = re.compile(r"freezer|tomahawk|missile|open|weapon|prop|gun|cannon",
                     re.I)

# units whose bind pose resembles the donor's combat stance rather than its
# T-pose -> retarget deltas must be measured against clip frame0
RETARGET_REF = {
    "czx_dgm_imperialdm": "frame0",
}

# per-unit {bone-name-regex: damp} for retarget_delta(damp=...) — tames
# donor swings on chains/wings far longer than the donor's (QA 'bad' flags:
# birdramon/hououmon wingtips whipped to a pillar, plesiomon's coiled
# tail/arm chains overshot ~9 units on the serpent lunge)
RETARGET_DAMP = {
    "czx_dgm_birdramon": {r"^root$": 0.3, r"^spine_|^neck_": 0.25,
                          r"^wing_|^feather_": 0.1},
    "czx_dgm_hououmon": {r"^root$": 0.3, r"^spine_|^neck_": 0.25,
                         r"^wing_|^feather_": 0.1},
    "czx_dgm_plesiomon": {r"^tail_": 0.25, r"^neck_|^spine_": 0.4,
                          r"^clav_|^upperarm_|^lowerarm_|^hand_|"
                          r"^finger_|^thumb_|^fin_": 0.3},
}

# per-unit {bone-name-regex: factor} scaling the donor root-motion delta —
# the eagle donor leaps ~9m on fly_attack; on a 0.56m-high bird skeleton even
# height-ratio scaling leaves a +3m pop that dwarfs the unit. Reins it in.
RETARGET_POS_DAMP = {
    "czx_dgm_birdramon": {r"^(root|animroot)$": 0.4},
    "czx_dgm_hououmon": {r"^(root|animroot)$": 0.4},
}


def _ground_y(joints, lo_y, hi_y):
    """Ground line from the joint cloud: prop bones excluded, then a low
    percentile + margin. Robust to accessory bones hanging under the mesh."""
    ys = sorted(p[1] for n, p in joints.items()
                if not PROP_RE.search(n))
    if not ys:
        return lo_y + 0.18 * (hi_y - lo_y)
    g = ys[max(0, int(len(ys) * 0.05) - 1)]
    return g + 0.18 * (ys[-1] - g)


def _rotx(v):
    """bind z-up -> game y-up: (x,y,z) -> (x, z, -y)."""
    return [v[0], v[2], -v[1]]
FORM_FAMILY = {"biped": "biped", "quadruped": "quad", "serpent": "snake",
               "insect": "spider", "flyer": "biped"}


def family_of(u):
    return FAMILY_OF.get(u["key"],
                         FORM_FAMILY.get(u.get("form", ""), "biped"))


# hand-authored landmark maps for degenerate rigs (J_jointNN stubs etc.)
# value = source joint name or literal [x,y,z]
MANUAL_LM = {
    # lalamon: 17-joint plant ball; arms/legs are stubs off J_center
    "czx_dgm_lalamon": {
        "root": "J_center",
        "spine_0": "J_center", "spine_1": "J_joint6", "spine_2": "J_joint17",
        "neck_0": "J_joint17", "head": "J_joint7",
        "clav_left": "J_joint9", "upperarm_left": "J_joint9",
        "lowerarm_left": "J_joint9", "hand_left": "J_joint9",
        "clav_right": "J_joint13", "upperarm_right": "J_joint13",
        "lowerarm_right": "J_joint13", "hand_right": "J_joint13",
        "upperleg_left": "J_joint11", "lowerleg_left": "J_joint11",
        "foot_left": [0.09, 0.05, 0.02], "toe_left_0": [0.09, 0.02, 0.10],
        "upperleg_right": "J_joint15", "lowerleg_right": "J_joint15",
        "foot_right": [-0.09, 0.05, 0.02], "toe_right_0": [-0.09, 0.02, 0.10],
    },
    # apocalymon: polyhedron + folded humanoid lump + tentacle chains.
    # naga layout: head=lump top, spine along torso, tail = bottom spike,
    # arms = the two big upper tentacle chains.
    "czx_dgm_apocalymon": {
        "root": "J_root_core",
        "spine_0": "J_center", "spine_1": "J_spine01",
        "spine_2": "J_spine02", "spine_3": "J_spine03",
        "neck_0": "J_neck", "neck_1": "J_neck", "head_0": "J_head",
        "clav_left": "J_shoulder_l", "upperarm_left": "J_arm_l",
        "lowerarm_left": "J_elbow_l", "hand_left": "J_hand_l",
        "clav_right": "J_shoulder_r", "upperarm_right": "J_arm_r",
        "lowerarm_right": "J_elbow_r", "hand_right": "J_hand_r",
        # tail = undersurface spike then bottom tentacle
        "tail_0": "J_undersurface01", "tail_1": "J_undersurface02",
        "tail_2": "J_undersurface03",
        "tail_3": "J_underchain01_f", "tail_5": "J_underchain03_f",
        "tail_7": "J_underchain05_f", "tail_9": "J_underchain07_f",
        "tail_11": "J_underhand_f",
        # big side tentacles ride the arm chains via fit interpolation
        "fin_0_left_0": "J_topchain03_s_l", "fin_0_right_0": "J_topchain03_s_r",
        "fin_2_left_0": "J_underchain03_s_l",
        "fin_2_right_0": "J_underchain03_b_r",
    },
}


def pick_glb(cn, index_entries):
    """Best GLB for digimon cn. Rank: _2 > plain > WithAnim; require sane
    bounds (h>0.25) and images>0 when possible."""
    cands = [e["file"] for e in index_entries if e.get("digimon") == cn]
    if not cands:  # case-insensitive / substring fallback
        cl = cn.lower()
        cands = [e["file"] for e in index_entries
                 if e.get("digimon") and e["digimon"].lower() == cl]
    if not cands:
        cands = [e["file"] for e in index_entries
                 if e.get("digimon") and (e["digimon"].lower() in cn.lower()
                                          or cn.lower() in e["digimon"].lower())]
    if not cands:
        return None, [], {}

    def rank(f):
        fl = f.lower()
        if "with animation" in fl:
            return 2
        if re.search(r"_\d+\.glb$", fl):
            return 0
        return 1

    best = None
    best_info = None
    for f in sorted(cands, key=rank):
        try:
            joints, _p, (lo, hi), nimg, nv = glb_scene(GLB_DIR / f)
        except Exception:
            continue
        h = hi[1] - lo[1]
        sane = h > 0.25 and nimg > 0 and nv > 100 and joints
        info = dict(h=h, img=nimg, nv=nv, nj=len(joints), sane=bool(sane))
        if sane:
            return f, cands, info
        if best is None:
            best, best_info = f, info
    return best, cands, (best_info or {}) | {"sane": False}


# ------------------------------------------------------- bone classification

HELPER_RE = re.compile(r"target|hud|grp_|loc_|^chr\d|camera|dummy", re.I)

LIMB_WORDS = (r"arm|ude|hiji|te\d*|wrist|hand|elbow|ancon|shoulder|collar|"
              r"kata|clavicle|leg|momo|knee|hiza|foot|ashi|asi|unkle|ankle|"
              r"kakato|toe|tuma|finger|yubi|wing|mimi|ear|thigh|calf|upleg|"
              r"bone0")

# exact core names allowed to carry a bare trailing l/r side marker
# (guards J_center/J_root which end in r/t naturally)
LIMB_CORES = {
    "arm", "ude", "elbow", "ancon", "hiji", "forearm", "tekubu", "wrist",
    "hand", "te", "palm", "weapon", "shoulder", "collar", "kata",
    "clavicle", "joudai", "leg", "momo", "thigh", "upleg", "legb",
    "ashiu", "knee", "hiza", "calf", "sune", "foot", "ashi", "asi",
    "unkle", "ankle", "ashikubi", "kakato", "toe", "tuma", "tumasaki",
    "tsumasaki", "finger", "yubi", "nail", "finge", "wing", "hane",
    "tsubasa", "mimi", "ear", "bone",
}


def split_side(name):
    """Return (side 'l'/'r'/'', core). Side is only real when the remaining
    core still looks like a limb word (protects J_center/J_root)."""
    n = name.lower()
    m = re.match(r"^(bip\d+)\s+([lr])\s+(.+)$", n)          # Bip001 L Thigh
    if m:
        return m.group(2), m.group(3)
    m = re.match(r"^j_([lr])_?([a-z].*)$", n)              # J_Lude / J_L_ude
    if m and re.search(LIMB_WORDS, m.group(2)):
        return m.group(1), m.group(2)
    # QuickRig Left/Right word sides: quickrigcharacter_leftarm
    m = re.search(r"_(left|right)_?([a-z].*)$", n)
    if m:
        return ("l" if m.group(1) == "left" else "r"), m.group(2)
    n2 = re.sub(r"^(?:j_|bip\d+\s*|quickrigcharacter_)", "", n)
    m = re.match(r"^(.+?)[_ ](left|right|l|r)(\d*)$", n2)  # *_l / *_left
    if m:
        return ("l" if m.group(2).startswith("l") else "r"), m.group(1)
    m = re.match(r"^(.+?)(l|r)(\d*)$", n2)                 # J_elbowL
    if m and m.group(1) in LIMB_CORES:
        return m.group(2), m.group(1)
    return "", n2


def side_of(name):
    return split_side(name)[0]


def core_name(name):
    return split_side(name)[1]


# (slot -> ordered regex list on core name; earlier = preferred)
SLOT_PATTERNS = {
    "pelvis":   [r"^center", r"^kosi", r"^koshi", r"^pelvis", r"^hips?$",
                 r"^karama", r"^waist"],
    "spine":    [r"^spine", r"^mune", r"^chest", r"^hara", r"^torso",
                 r"^upperbody", r"^sebone", r"^body\d*$"],
    "neck":     [r"^neck", r"^kubi"],
    "head":     [r"^head[_\d]*$", r"^atama", r"^kao", r"^hed$", r"^haed"],
    "clav":     [r"^collar", r"^clavicle", r"^kata", r"^shoulder",
                 r"^shourder"],
    "upperarm": [r"^arm\d*$", r"^ude\d*$", r"^upperarm", r"^joudai"],
    "lowerarm": [r"^elbow", r"^ancon", r"^hiji", r"^forearm", r"^tekubu"],
    "hand":     [r"^hand\d*$", r"^te\d*$", r"^weapon", r"^wrist", r"^palm",
                 r"^claw"],
    "upperleg": [r"^leg\d*$", r"^momo", r"^thigh", r"^upperleg", r"^upleg",
                 r"^legb", r"^ashiu"],
    "lowerleg": [r"^knee", r"^hiza", r"^calf", r"^sune", r"^lowerleg"],
    "foot":     [r"^foot\d*$", r"^ashi\d*$", r"^asi\d*$", r"^unkle",
                 r"^ankle", r"^ashikubi", r"^kakato", r"^heel"],
    "toe":      [r"^toe", r"^tuma", r"^tumasaki", r"^tsumasaki",
                 r"^foot.*1$", r"^ashi.*1$"],
    "wing":     [r"^wing", r"^hane", r"^tsubasa"],
    "tail":     [r"^tail", r"^shippo", r"^sippo"],
    "jaw":      [r"^jaw", r"^ago", r"^mouth", r"^kuci", r"^chin"],
    "finger":   [r"^yubi", r"^finger", r"^nail", r"^finge"],
}

# chain-order slots filled by parent-walking when name lookup fails
ARM_CHAIN = ["clav", "upperarm", "lowerarm", "hand"]
LEG_CHAIN = ["upperleg", "lowerleg", "foot", "toe"]


def classify_joints(joints, parents=None):
    """semantic map: {slot: {side: (name,pos)}}. Name patterns first, then
    parent-chain completion for missing limb links."""
    parents = parents or {}
    kids = {}
    for n, p in parents.items():
        if p:
            kids.setdefault(p, []).append(n)

    per = {"l": {}, "r": {}, "": {}}
    core = {}
    for name, pos in joints.items():
        if HELPER_RE.search(name):
            continue
        s, c = split_side(name)
        per[s][name] = pos
        core[name] = c
    slots = {}
    used = set()

    def side_ok(n, s):
        return n in per[s] or n in per[""]

    for slot, pats in SLOT_PATTERNS.items():
        for side in ("", "l", "r"):
            if slot in ("clav", "upperarm", "lowerarm", "hand", "upperleg",
                        "lowerleg", "foot", "toe", "wing", "finger") \
                    and not side:
                continue
            if slot in ("pelvis", "spine", "neck", "head") and side:
                continue
            cands = []
            for name, pos in per[side].items():
                if name in used:
                    continue
                cn = core[name]
                for pi, pat in enumerate(pats):
                    if re.search(pat, cn):
                        cands.append((pi, len(cn), name, pos))
                        break
            if not cands:
                continue
            cands.sort(key=lambda t: (t[0], t[1]))
            slots.setdefault(slot, {})[side or "c"] = (cands[0][2],
                                                      cands[0][3])
            used.add(cands[0][2])

    def descend(start, s, max_len=7):
        """walk down the limb chain; prefer same-side then unsided child."""
        seq = [start]
        while len(seq) < max_len:
            ch = [c for c in kids.get(seq[-1], [])
                  if c in joints and not HELPER_RE.search(c)]
            if not ch:
                break
            prefer = [c for c in ch if side_ok(c, s) and c not in per["l" if s == "r" else "r"]] \
                or [c for c in ch if c not in per["l" if s == "r" else "r"]]
            if not prefer:
                break
            seq.append(prefer[0])
        return seq

    def ascend_to_pelvis(start):
        seq = [start]
        while parents.get(seq[-1]) and parents[seq[-1]] in joints:
            seq.append(parents[seq[-1]])
        return seq  # leaf -> root order

    def pelvis_pos():
        return slots.get("pelvis", {}).get("c", (None, None))[1] or \
            joints.get("J_root")

    for s in ("l", "r"):
        S = {k: v.get(s) for k, v in slots.items()}
        # ---- leg chain completion
        if not S.get("upperleg"):
            # find a sided leaf chain that ends near ground and hangs off
            # pelvis/root region
            pv = pelvis_pos()
            best = None
            for n in per[s]:
                ch = ascend_to_pelvis(n)
                if pv and ch and np.linalg.norm(
                        np.subtract(joints[ch[-1]], pv)) > 0.5 * abs(pv[1]):
                    continue          # doesn't hang off pelvis area
                if len(ch) >= 3 and (best is None
                                     or joints[n][1] < joints[best][1]):
                    best = n
            if best is not None:
                ch = ascend_to_pelvis(best)[:-1][::-1]   # top->leaf excl root
                S["upperleg"] = (ch[0], joints[ch[0]])
        if S.get("upperleg"):
            seq = descend(S["upperleg"][0], s)
            body = seq[1:]
            if not S.get("lowerleg") and body:
                i = len(body) - 2 if len(body) >= 3 else 0
                S["lowerleg"] = (body[i], joints[body[i]])
            if not S.get("foot") and body:
                S["foot"] = (body[-1] if len(body) < 3 else body[-2],
                             joints[body[-1] if len(body) < 3 else body[-2]])
            if not S.get("toe") and body:
                S["toe"] = (body[-1], joints[body[-1]])
            if S.get("lowerleg") and S["lowerleg"][0] == S.get("upperleg")[0]:
                S["lowerleg"] = None
        # ---- arm chain completion
        if S.get("hand") and (not S.get("upperarm")
                              or not S.get("lowerarm")):
            # walk up from hand; links between anchor and hand fill the arm
            anchors = {v[s][0] for k, v in slots.items()
                       if k in ("clav", "neck", "spine", "pelvis", "head")
                       and s in v}
            anchors |= {v["c"][0] for k, v in slots.items()
                        if k in ("neck", "spine", "pelvis", "head")
                        and "c" in v}
            ch = ascend_to_pelvis(S["hand"][0])   # hand -> root
            cut = len(ch)
            for i, n in enumerate(ch):
                if n in anchors:
                    cut = i
                    break
            links = ch[:cut][::-1]              # top -> hand order
            if links and links[-1] == S["hand"][0]:
                links = links[:-1]
            if not S.get("upperarm") and links:
                S["upperarm"] = (links[0], joints[links[0]])
            if not S.get("lowerarm") and len(links) >= 2:
                S["lowerarm"] = (links[-1], joints[links[-1]])
        if not S.get("upperarm") and not S.get("hand"):
            # whole arm unknown: descend from clav/neck/spine-top outward
            top = S.get("clav") or slots.get("neck", {}).get("c")
            if not top:
                sp = [v[1] for v in slots.get("spine", {}).values()]
                top = ("synth", max(sp, key=lambda p: p[1])) if sp else None
            if top:
                other = "r" if s == "l" else "l"
                ch = [c for c in kids.get(top[0], [])
                      if c in joints and not HELPER_RE.search(c)
                      and c not in per[other]]
                if ch:
                    pick = max(ch, key=lambda c: abs(joints[c][0]))
                    S["upperarm"] = (pick, joints[pick])
        if S.get("upperarm") and (not S.get("lowerarm")
                                  or not S.get("hand")):
            seq = descend(S["upperarm"][0], s)
            body = seq[1:]
            if not S.get("lowerarm") and len(body) >= 2:
                S["lowerarm"] = (body[-2], joints[body[-2]])
            if not S.get("hand") and body:
                S["hand"] = (body[-1], joints[body[-1]])
        # write back
        for k in ARM_CHAIN + LEG_CHAIN:
            if S.get(k):
                slots.setdefault(k, {})[s] = S[k]
    return slots, per


def lerp(a, b, t):
    return [a[k] + (b[k] - a[k]) * t for k in range(3)]


# ------------------------------------------------- non-biped landmark utils

TRUNK_RE = re.compile(
    r"center|body|spine|mune|hara|kosi|koshi|pelvis|thorax|chest|sebone|"
    r"karami|torso|point\d*$|root|chine|core", re.I)


def _kids_map(parents):
    k = {}
    for n, p in parents.items():
        if p is not None:
            k.setdefault(p, []).append(n)
    return k


def _is_trunk(name, pos, x_half):
    return (TRUNK_RE.search(name) is not None and abs(pos[0]) < 0.3 * x_half) \
        or abs(pos[0]) < 0.05 * x_half


def _leaf_chains(joints, parents):
    """[leaf .. trunk] chains: every skin joint leaf walked up until a
    centred/trunk-named ancestor."""
    kids = _kids_map(parents)
    xh = max(abs(p[0]) for p in joints.values()) or 1.0
    out = []
    for n in joints:
        if HELPER_RE.search(n):
            continue
        if any(c in joints and not HELPER_RE.search(c)
               for c in kids.get(n, [])):
            continue
        seq = [n]
        while True:
            p = parents.get(seq[-1])
            if p is None or p not in joints or len(seq) > 14:
                break
            seq.append(p)
            if _is_trunk(p, joints[p], xh):
                break
        out.append(seq)
    return out


def _trunk_joints(joints):
    xh = max(abs(p[0]) for p in joints.values()) or 1.0
    return sorted(
        (n for n, p in joints.items()
         if not HELPER_RE.search(n) and _is_trunk(n, p, xh)),
        key=lambda n: joints[n][2])


def _poly_sample(pts, frac):
    """arc-length interpolation along a joint polyline."""
    pts = [np.array(p, dtype=float) for p in pts]
    seg = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
    total = sum(seg) or 1.0
    d = frac * total
    acc = 0.0
    for i, s in enumerate(seg):
        if acc + s >= d or i == len(seg) - 1:
            t = (d - acc) / s if s > 1e-9 else 0.0
            return (pts[i] + (pts[i + 1] - pts[i]) * t).tolist()
        acc += s
    return pts[-1].tolist()


def quad_landmarks(joints, parents, bbox):
    """Generic 4-limb rig -> wolf01. Ground-touching chains split front/back
    by z; trunk joints give spine/neck/head/tail."""
    lo, hi = np.array(bbox[0]), np.array(bbox[1])
    H = float(hi[1] - lo[1]); gy = _ground_y(joints, lo[1], hi[1])
    lm, probs = {}, []
    chains = _leaf_chains(joints, parents)
    xh = max(abs(p[0]) for p in joints.values()) or 1.0
    legs = [c for c in chains
            if joints[c[0]][1] < gy and len(c) >= 3
            and abs(joints[c[0]][0]) > 0.03 * xh]
    by = {"l": [], "r": []}
    for c in legs:
        by["l" if joints[c[0]][0] > 0 else "r"].append(c)
    trunk = _trunk_joints(joints)
    for s, suf in (("l", "left"), ("r", "right")):
        cs = sorted(by[s], key=lambda c: joints[c[0]][2])
        if len(cs) < 2:
            probs.append(f"quad: only {len(cs)} leg chains {s}")
            continue
        hind, front = cs[0], cs[-1]          # leaf..trunk order
        hb = [j for j in hind if j != hind[-1]]   # drop trunk node
        fb = [j for j in front if j != front[-1]]
        lm[f"leg_{suf}_0"] = joints[hb[-1]]       # hip
        mid = hb[1:-1]
        lm[f"leg_{suf}_1"] = joints[mid[len(mid) // 2] if mid else hb[-1]]
        lm[f"leg_{suf}_2"] = joints[hb[1] if len(hb) > 2 else hb[0]]
        lm[f"foot_{suf}"] = joints[hb[0]]
        ft = joints[hb[0]]
        lm[f"toe_inner_{suf}_0"] = [ft[0] - 0.03, ft[1], ft[2] + 0.06]
        lm[f"toe_outer_{suf}_0"] = [ft[0] + 0.03, ft[1], ft[2] + 0.06]
        # front limb -> clav/upperarm/lowerarm/hand
        lm[f"upperarm_{suf}"] = joints[fb[-1]]
        fmid = fb[1:-1]
        lm[f"lowerarm_{suf}"] = joints[fmid[len(fmid) // 2]
                                       if fmid else fb[-1]]
        lm[f"hand_{suf}"] = joints[fb[0]]
        hd = joints[fb[0]]
        lm[f"finger_base_{suf}_0"] = [hd[0], hd[1] * 0.5, hd[2] + 0.05]
        lm[f"finger_inner_{suf}_0"] = [hd[0] - 0.03, hd[1] * 0.4,
                                       hd[2] + 0.07]
        lm[f"finger_outer_{suf}_0"] = [hd[0] + 0.03, hd[1] * 0.4,
                                       hd[2] + 0.07]
    if "leg_left_0" in lm:
        pelvis = lerp(lm["leg_left_0"], lm["leg_right_0"], 0.5)
        pelvis[0] = 0.0
        lm["root"] = pelvis
        shoulder = lerp(lm["upperarm_left"], lm["upperarm_right"], 0.5)
        shoulder[0] = 0.0
        # spine: pelvis -> shoulder line, snapped to real trunk joints
        mid_j = [joints[n] for n in trunk
                 if pelvis[2] - 0.05 < joints[n][2] < shoulder[2] + 0.05]
        lm["spine_0"] = pelvis
        lm["spine_2"] = shoulder
        lm["spine_1"] = (mid_j[len(mid_j) // 2] if mid_j
                         else lerp(pelvis, shoulder, 0.5))
        # clav sits on spine_2, offset to upperarm
        for suf in ("left", "right"):
            ua = lm[f"upperarm_{suf}"]
            lm[f"clav_{suf}"] = lerp(shoulder, ua, 0.45)
        # tail: trunk joints behind pelvis
        tail = [joints[n] for n in trunk if joints[n][2] < pelvis[2] - 0.04]
        tail.sort(key=lambda p: -p[2])
        for i in range(3):
            if i < len(tail):
                lm[f"tail_{i}"] = tail[i]
        # head/neck: trunk joints ahead of shoulder
        fwd = [n for n in trunk if joints[n][2] > shoulder[2] + 0.03]
        named_head = next((n for n in joints
                           if re.search(r"head|atama|kao|^hed$", n, re.I)),
                          None)
        named_jaw = next((n for n in joints
                          if re.search(r"jaw|ago|mouth|tooth|chin|kuci", n,
                                       re.I)), None)
        if named_head:
            lm["head_0"] = joints[named_head]
        elif fwd:
            lm["head_0"] = joints[fwd[-1]]
        if named_jaw:
            lm["jaw_0"] = joints[named_jaw]
        neck = next((n for n in fwd
                     if re.search(r"neck|kubi", n, re.I)), None)
        lm["neck_0"] = joints[neck] if neck else lerp(
            lm["spine_2"], lm.get("head_0", shoulder), 0.5)
        if "head_0" in lm:
            lm["snout_0"] = [lm["head_0"][0], lm["head_0"][1],
                             lm["head_0"][2] + 0.3]
    return lm, probs


def bird_landmarks(joints, parents, bbox):
    """True bird rig -> bird01: 2 leg chains, wing chains (max-|x| leaves),
    trunk gives spine/neck/head/tail_middle."""
    lo, hi = np.array(bbox[0]), np.array(bbox[1])
    H = float(hi[1] - lo[1]); gy = _ground_y(joints, lo[1], hi[1])
    lm, probs = {}, []
    chains = _leaf_chains(joints, parents)
    legs = [c for c in chains
            if joints[c[0]][1] < gy and len(c) >= 3
            and abs(joints[c[0]][0]) > 0.02]
    trunk = _trunk_joints(joints)
    for s, suf in (("l", "left"), ("r", "right")):
        cs = [c for c in legs if (joints[c[0]][0] > 0) == (s == "l")]
        if not cs:
            probs.append(f"bird: no leg {s}")
            continue
        c = max(cs, key=len)
        b = [j for j in c if j != c[-1]]            # leaf..top excl trunk
        lm[f"leg_{suf}_0"] = joints[b[-1]]
        mid = b[1:-1]
        lm[f"leg_{suf}_1"] = joints[mid[len(mid) // 2] if mid else b[-1]]
        lm[f"leg_{suf}_2"] = joints[b[1] if len(b) > 2 else b[0]]
        lm[f"foot_{suf}_0"] = joints[b[0]]
        ft = joints[b[0]]
        for k, dx in (("middle", 0.0), ("inner", -0.04), ("outer", 0.04),
                      ("back", 0.0)):
            dz = -0.06 if k == "back" else 0.08
            lm[f"toe_{k}_{suf}_0"] = [ft[0] + dx, ft[1] * 0.6, ft[2] + dz]
            lm[f"toe_{k}_{suf}_1"] = [ft[0] + dx * 1.4, ft[1] * 0.4,
                                       ft[2] + dz * 1.6]
    # wings: sided chains whose leaf has the largest |x| (above leg height)
    kids = _kids_map(parents)
    wleaves = [c for c in chains
               if joints[c[0]][1] > gy and abs(joints[c[0]][0]) > 0.3]
    for s, suf in (("l", "left"), ("r", "right")):
        cs = [c for c in wleaves if (joints[c[0]][0] > 0) == (s == "l")]
        if not cs:
            probs.append(f"bird: no wing {s}")
            continue
        cs.sort(key=lambda c: -abs(joints[c[0]][0]))
        c = cs[0]
        b = [j for j in c if j != c[-1]]            # tip..root excl trunk
        b = b[::-1]                                  # root..tip
        lm[f"wing_{suf}_0"] = joints[b[0]]
        lm[f"wing_{suf}_1"] = joints[b[len(b) // 2]]
        lm[f"wing_{suf}_2"] = joints[b[-1]]
        lm[f"wing_shoulder_{suf}_0"] = lerp(
            [0, joints[b[0]][1], joints[b[0]][2]], joints[b[0]], 0.5)
        # secondary wing chains -> feather rows
        for ci, c2 in enumerate(cs[1:4]):
            b2 = [j for j in c2 if j != c2[-1]][::-1]
            fams = ("feather_primary_middle", "feather_secondary_middle",
                    "feather_primary_outer")
            for j2, nm in enumerate(b2[:3]):
                lm[f"{fams[min(ci,2)]}_{suf}_{j2}"] = joints[nm]
    if "leg_left_0" in lm:
        pelvis = lerp(lm["leg_left_0"], lm["leg_right_0"], 0.5)
        pelvis[0] = 0.0
        lm["root"] = pelvis
    # spine/neck/head along trunk (z asc)
    named_head = next((n for n in joints
                       if re.search(r"head|atama|kao|^hed$", n, re.I)), None)
    named_jaw = next((n for n in joints
                      if re.search(r"jaw|ago|mouth|kuti|chin", n, re.I)),
                     None)
    if named_head:
        lm["head_0"] = joints[named_head]
    if named_jaw:
        lm["jaw_0"] = joints[named_jaw]
    hz = lm.get("head_0", [0, 0, hi[2]])[2]
    fwd = [n for n in trunk if joints[n][2] < hz]
    fwd = [n for n in fwd if joints[n][1] > (lm.get("root", lo)[1])]
    if named_head and len(fwd) >= 2:
        path = [joints[n] for n in fwd] + [joints[named_head]]
        lm["spine_2"] = _poly_sample(path, 0.45)
        lm["neck_0"] = _poly_sample(path, 0.7)
        lm["neck_1"] = _poly_sample(path, 0.88)
    if "root" in lm:
        rear = [n for n in trunk
                if joints[n][2] < lm["root"][2] + 0.3]
        spine_back = [n for n in rear
                      if joints[n][2] > lm["root"][2] - 0.4 * (hi[2] - lo[2])]
        lm["spine_0"] = joints[spine_back[-1]] if spine_back else lm["root"]
        lm["spine_1"] = lerp(lm["spine_0"],
                             lm.get("spine_2", lm["root"]), 0.5)
        tail = [joints[n] for n in trunk
                if joints[n][2] < lm["root"][2] - 0.1]
        tail.sort(key=lambda p: -p[2])
        for i, nm in enumerate(("tail_middle_0", "tail_middle_1",
                                "tail_middle_2", "tail_middle_3")):
            if i < len(tail):
                lm[nm] = tail[i]
            elif tail:
                lm[nm] = [tail[-1][0], tail[-1][1],
                          tail[-1][2] - 0.15 * (i - len(tail) + 1)]
        for side in ("left", "right"):
            sgn = -1 if side == "left" else 1
            for i in range(4):
                tm = lm.get(f"tail_middle_{i}")
                if tm:
                    lm[f"tail_{side}_{i}"] = [tm[0] + sgn * 0.1,
                                              tm[1], tm[2]]
    return lm, probs


def snake_landmarks(joints, parents, bbox):
    """Serpent rig -> snake01 (naga): head end -> neck/spine, rear body ->
    tail_0..19 distributed along the chain polyline."""
    lm, probs = {}, []
    named_head = next((n for n in joints
                       if re.search(r"head|atama|kao", n, re.I)), None)
    named_jaw = next((n for n in joints
                      if re.search(r"jaw|ago|mouth|chin|kuti", n, re.I)),
                     None)
    if not named_head:
        probs.append("snake: no head")
        return lm, probs
    # full polyline head -> tail tip by walking parents
    seq = [named_head]
    while parents.get(seq[-1]) and parents[seq[-1]] in joints \
            and len(seq) < 60:
        seq.append(parents[seq[-1]])
    fwd = seq[1:]                                  # head -> rear
    # find body middle = the joint whose children include BOTH directions
    # (in seadramon rigs J_center is the branching point)
    kids = _kids_map(parents)
    mid_i = next((i for i, n in enumerate(fwd)
                  if len([c for c in kids.get(n, [])
                          if c in joints and c not in fwd
                          and c != seq[max(0, i - 1)]
                          and not HELPER_RE.search(c)]) >= 1), len(fwd) // 2)
    # simpler: center = trunk joint with most children
    center = max((_ for _ in joints if not HELPER_RE.search(_)),
                 key=lambda n: len([c for c in kids.get(n, [])
                                    if c in joints]))
    lm["root"] = joints[center]
    # head->center = front body; center->tip = tail
    try:
        ci = seq.index(center)
    except ValueError:
        ci = mid_i
    front = seq[:ci + 1]                            # head..center
    back = seq[ci:]                                 # center..tip
    lm["head_0"] = joints[named_head]
    if named_jaw:
        lm["jaw_0"] = joints[named_jaw]
    fp = [joints[n] for n in front]
    for i, nm in enumerate(("neck_1", "neck_0", "spine_3", "spine_2",
                            "spine_1", "spine_0")):
        lm[nm] = _poly_sample(fp, (i + 1) / 7.0)
    bp = [joints[n] for n in back]
    for i in range(20):
        lm[f"tail_{i}"] = _poly_sample(bp, (i + 0.5) / 20.0)
    # fins -> fin_0..4 pairs
    fins_l = sorted((n for n in joints
                     if re.search(r"wing_l|fin_l|hane_l|_la_", n, re.I)),
                    key=lambda n: joints[n][2])
    fins_r = sorted((n for n in joints
                     if re.search(r"wing_r|fin_r|hane_r|_ra_", n, re.I)),
                    key=lambda n: joints[n][2])
    for i in range(5):
        if i < len(fins_l):
            lm[f"fin_{i}_left_0"] = joints[fins_l[i]]
        if i < len(fins_r):
            lm[f"fin_{i}_right_0"] = joints[fins_r[i]]
    return lm, probs


def spider_landmarks(joints, parents, bbox):
    """Prone multi-limb rig -> spider01: sided limb chains sorted by attach
    z map onto front/front_mid/back_mid/back leg pairs."""
    lo, hi = np.array(bbox[0]), np.array(bbox[1])
    H = float(hi[1] - lo[1]); gy = _ground_y(joints, lo[1], hi[1]) \
        + 0.04 * H
    lm, probs = {}, []
    chains = _leaf_chains(joints, parents)
    limbs = [c for c in chains if len(c) >= 3
             and abs(joints[c[0]][0]) > 0.05]
    groups = ("front", "front_mid", "back_mid", "back")
    for s, suf in (("l", "left"), ("r", "right")):
        cs = [c for c in limbs if (joints[c[0]][0] > 0) == (s == "l")]
        # attach z = z of chain top (last link before trunk)
        cs.sort(key=lambda c: -joints[c[-1]][2])    # front-most first
        for gi, c in enumerate(cs[:4]):
            b = [j for j in c if j != c[-1]]         # leaf..top excl trunk
            seq = b[::-1]                            # top..leaf
            g = groups[gi]
            for li in range(4):
                t = li / 3.0
                idx = min(len(seq) - 1, int(round(t * (len(seq) - 1))))
                lm[f"leg_{suf}_{g}_{li}"] = joints[seq[idx]]
            lm[f"leg_{suf}_{g}_end"] = joints[seq[-1]]
        if len(cs) < 3:
            probs.append(f"spider: {len(cs)} limb chains {s}")
    trunk = _trunk_joints(joints)
    named_head = next((n for n in joints
                       if re.search(r"head|atama|kao", n, re.I)), None)
    if named_head:
        lm["head_0"] = joints[named_head]
    hz = joints[named_head][2] if named_head else hi[2]
    mid = [joints[n] for n in trunk if joints[n][2] < hz]
    mid.sort(key=lambda p: p[2])
    if mid:
        lm["root"] = mid[len(mid) // 2]
        lm["spine_0"] = mid[len(mid) // 3]
        lm["spine_1"] = mid[len(mid) // 2]
        lm["spine_2"] = mid[-1]
        lm["rear_0"] = mid[0]
        if len(mid) > 1:
            lm["rear_1"] = mid[max(0, len(mid) // 3 - 1)]
    return lm, probs


def dragon_landmarks(joints, parents, bbox):
    """Big quadruped+wings -> dragon01b. Reuses quad detection, then maps to
    the two-neck/7-tail layout (both neck chains share the single head)."""
    lm, probs = quad_landmarks(joints, parents, bbox)
    out = {}
    for k, v in lm.items():
        out[k] = v
    # spine_0..4: extrapolate extra links between spine_2 and neck
    if "neck_0" in out and "spine_2" in out:
        out["spine_3"] = lerp(out["spine_2"], out["neck_0"], 0.4)
        out["spine_4"] = lerp(out["spine_2"], out["neck_0"], 0.8)
        out["chest_0"] = out["spine_4"]
    # tail_0..6: sample along tail polyline further back
    tail = [v for k, v in sorted(out.items()) if k.startswith("tail_")]
    if len(tail) >= 2:
        step = [tail[-1][i] - tail[-2][i] for i in range(3)]
        for i in range(3, 7):
            out[f"tail_{i}"] = [tail[-1][j] + step[j] * (i - 2)
                                for j in range(3)]
    # neck_left/right_0..3 + head_left/right share the single neck/head
    for side in ("left", "right"):
        if "neck_0" in out and "head_0" in out:
            for i in range(4):
                out[f"neck_{side}_{i}"] = lerp(out["neck_0"], out["head_0"],
                                               i / 3.0)
        if "head_0" in out:
            out[f"head_{side}"] = out["head_0"]
        if "jaw_0" in out:
            out[f"jaw_{side}_0"] = out["jaw_0"]
        # extra toe rows
        if f"toe_inner_{side}_0" in out:
            f0 = out[f"toe_inner_{side}_0"]
            out[f"toe_middle_{side}_0"] = [f0[0], f0[1], f0[2] + 0.03]
            for i in range(2):
                for nm in ("inner", "middle", "outer"):
                    p = out[f"toe_{nm}_{side}_0"]
                    out[f"toe_{nm}_{side}_1"] = [p[0], p[1] * 0.7,
                                                 p[2] + 0.06]
    # wings: max-|x| chains
    chains = _leaf_chains(joints, parents)
    lo, hi = np.array(bbox[0]), np.array(bbox[1])
    gy = lo[1] + 0.25 * (hi[1] - lo[1])
    wleaves = [c for c in chains
               if joints[c[0]][1] > gy and abs(joints[c[0]][0]) > 0.3]
    for s, suf in (("l", "left"), ("r", "right")):
        cs = [c for c in wleaves if (joints[c[0]][0] > 0) == (s == "l")]
        if not cs:
            continue
        cs.sort(key=lambda c: -abs(joints[c[0]][0]))
        b = [j for j in cs[0] if j != cs[0][-1]][::-1]   # root..tip
        if len(b) >= 2:
            out[f"wing_shoulder_{suf}_0"] = lerp(
                [0, joints[b[0]][1], joints[b[0]][2]], joints[b[0]], 0.4)
            out[f"wing_{suf}_0"] = joints[b[0]]
            out[f"wing_{suf}_1"] = joints[b[len(b) // 2]]
            # feathers fan toward tip
            tip = joints[b[-1]]
            for i, fam in enumerate(("feather_primary_inner",
                                     "feather_primary_middle",
                                     "feather_primary_outer")):
                p = lerp(joints[b[len(b) // 2]], tip, 0.4 + 0.2 * i)
                for j2 in range(3):
                    out[f"{fam}_{suf}_{j2}"] = [
                        p[0] + (p[0] > 0 and 1 or -1) * 0.05 * j2,
                        p[1], p[2] + 0.04 * j2]
    return out, probs


def topo_biped_landmarks(joints, parents, bbox):
    """Fallback for rigs with non-semantic names (J_jointNN): topology +
    position. Ground leaves -> legs, far-|x| upper leaves -> arms."""
    lo, hi = np.array(bbox[0]), np.array(bbox[1])
    H = float(hi[1] - lo[1])
    gy = lo[1] + 0.15 * H
    chains = _leaf_chains(joints, parents)
    slots = {"pelvis": {}, "spine": {}, "neck": {}, "head": {}, "clav": {},
             "upperarm": {}, "lowerarm": {}, "hand": {}, "upperleg": {},
             "lowerleg": {}, "foot": {}, "toe": {}}
    probs = []
    legs = [c for c in chains if joints[c[0]][1] < gy
            and len(c) >= 3 and abs(joints[c[0]][0]) > 0.02]
    for s in ("l", "r"):
        cs = [c for c in legs if (joints[c[0]][0] > 0) == (s == "l")]
        if not cs:
            continue
        c = max(cs, key=len)
        b = [j for j in c if j != c[-1]]
        slots["upperleg"][s] = (b[-1], joints[b[-1]])
        mid = b[1:-1]
        slots["lowerleg"][s] = ((mid[len(mid) // 2], joints[mid[len(mid) // 2]])
                                if mid else (b[-1], joints[b[-1]]))
        slots["foot"][s] = (b[1] if len(b) > 2 else b[0],
                            joints[b[1] if len(b) > 2 else b[0]])
        slots["toe"][s] = (b[0], joints[b[0]])
    # arms: remaining leaves with big |x| in upper body
    arm_leaves = [c for c in chains
                  if c not in legs and joints[c[0]][1] > gy
                  and abs(joints[c[0]][0]) > 0.15]
    for s in ("l", "r"):
        cs = [c for c in arm_leaves if (joints[c[0]][0] > 0) == (s == "l")]
        if not cs:
            continue
        c = max(cs, key=lambda c2: abs(joints[c2[0]][0]))
        b = [j for j in c if j != c[-1]]
        slots["hand"][s] = (b[0], joints[b[0]])
        slots["upperarm"][s] = (b[-1], joints[b[-1]])
        mid = b[1:-1]
        if mid:
            slots["lowerarm"][s] = (mid[len(mid) // 2],
                                    joints[mid[len(mid) // 2]])
    # trunk: pelvis = leg-top midpoint; head = topmost centered joint
    trunk = _trunk_joints(joints)
    named_head = next((n for n in joints
                       if re.search(r"head|atama|kao", n, re.I)), None)
    if slots["upperleg"]:
        pv = lerp(slots["upperleg"]["l"][1], slots["upperleg"]["r"][1], 0.5)
        pv[0] = 0.0
        slots["pelvis"]["c"] = ("synth", pv)
    if named_head:
        slots["head"]["c"] = (named_head, joints[named_head])
    elif trunk:
        top = max(trunk, key=lambda n: joints[n][1])
        slots["head"]["c"] = (top, joints[top])
        probs.append("synth head")
    neck = next((n for n in trunk if re.search(r"neck|kubi", n, re.I)),
                None)
    if neck:
        slots["neck"]["c"] = (neck, joints[neck])
    sp = [n for n in trunk
          if joints[n][1] > (slots["pelvis"].get("c", (0, [0, -9, 0]))[1] or -9)[1]
          and n != slots["head"].get("c", (None,))[0]
          and n != (neck or "")]
    for i, n in enumerate(sp[:3]):
        slots["spine"][f"c{i}"] = (n, joints[n])
    lm, probs2 = biped_landmarks(slots)
    return lm, probs + probs2


def biped_landmarks(slots):
    """semantic slots -> hu1 landmark dict. Returns (lm, problems)."""
    lm, probs = {}, []
    pelvis = slots.get("pelvis", {}).get("c", (None, None))[1]
    neck = slots.get("neck", {}).get("c", (None, None))[1]
    head = slots.get("head", {}).get("c", (None, None))[1]
    if not pelvis:
        # synth pelvis: midpoint of leg roots, nudged toward spine/head
        ul = slots.get("upperleg", {})
        if "l" in ul and "r" in ul:
            mid = lerp(ul["l"][1], ul["r"][1], 0.5)
            top = head or (sorted(
                (v[1] for v in slots.get("spine", {}).values()),
                key=lambda p: p[1])[-1] if slots.get("spine") else None)
            pelvis = lerp(mid, top, 0.25) if top else mid
            probs.append("synth pelvis")
        else:
            probs.append("no pelvis")
            return lm, probs
    if not neck:
        probs.append("no neck")

    # spine: interpolate pelvis->neck across any real spine joints
    sp = [v[1] for k, v in sorted(slots.get("spine", {}).items())]
    top = neck or head or (sorted(sp, key=lambda p: p[1])[-1] if sp else None)
    if pelvis and top:
        pts = [pelvis] + sorted(sp, key=lambda p: p[1]) + [top]
        for i in range(3):
            t = (i + 1) / 4 * (len(pts) - 1)
            a, b = int(t), min(int(t) + 1, len(pts) - 1)
            lm[f"spine_{i}"] = lerp(pts[a], pts[b], t - a)
    if not neck and head:
        # synth neck: halfway between the top spine link and the head.
        # lerp(pelvis, head, 0.78) landed too low on hunched/quad rigs
        # (gabumon, taomon) and dragged chest verts into the neck group;
        # anchoring on spine_2 also keeps the neck bone non-degenerate.
        base = lm.get("spine_2") or (max(sp, key=lambda p: p[1]) if sp
                                     else pelvis)
        if base is not None:
            neck = lerp(base, head, 0.5)
            probs.append("synth neck")
    lm["root"] = pelvis
    if neck:
        lm["neck_0"] = neck
    if head:
        lm["head"] = head

    for side, suf in (("l", "left"), ("r", "right")):
        ua = slots.get("upperarm", {}).get(side, (None, None))[1]
        la = slots.get("lowerarm", {}).get(side, (None, None))[1]
        ha = slots.get("hand", {}).get(side, (None, None))[1]
        cl = slots.get("clav", {}).get(side, (None, None))[1]
        ul = slots.get("upperleg", {}).get(side, (None, None))[1]
        ll = slots.get("lowerleg", {}).get(side, (None, None))[1]
        fo = slots.get("foot", {}).get(side, (None, None))[1]
        to = slots.get("toe", {}).get(side, (None, None))[1]

        if not ua and cl:
            ua = cl  # shoulder doubles as upperarm
        if ua and not cl:
            # synth clav 30% spine2->upperarm
            base = lm.get("spine_2", neck or pelvis)
            cl = lerp(base, ua, 0.3)
        if la is None and ua and ha:
            la = lerp(ua, ha, 0.55)
        if ha is None and ua and la:
            ha = [la[0] + (la[0] - ua[0]), la[1] - abs(la[1] - ua[1]), la[2]]

        if ul is None and fo:
            ul = lerp(pelvis, fo, 0.35)
        if ll is None and ul and fo:
            ll = lerp(ul, fo, 0.5)
        if fo is None and ll:
            fo = [ll[0], max(0.04, ll[1] * 0.35), ll[2] + 0.06]
            probs.append(f"synth foot {side}")
        if to is None and fo:
            to = [fo[0], max(0.02, fo[1] * 0.4), fo[2] + 0.15]
            probs.append(f"synth toe {side}")

        for slot, p, hu in (("clav", cl, f"clav_{suf}"),
                            ("upperarm", ua, f"upperarm_{suf}"),
                            ("lowerarm", la, f"lowerarm_{suf}"),
                            ("hand", ha, f"hand_{suf}"),
                            ("upperleg", ul, f"upperleg_{suf}"),
                            ("lowerleg", ll, f"lowerleg_{suf}"),
                            ("foot", fo, f"foot_{suf}"),
                            ("toe", to, f"toe_{suf}_0")):
            if p is None:
                probs.append(f"missing {slot} {side}")
            else:
                lm[hu] = p
    return lm, probs


# --------------------------------------------------------------------- scan

def load_roster():
    lines = ROSTER.read_text(encoding="utf-8").splitlines()
    hdr = lines[0].split("\t")
    return [dict(zip(hdr, l.split("\t"))) for l in lines[1:]
            if l and not l.startswith("#")]


def scan(units):
    index = json.loads((GLB_DIR / "index.json").read_text(encoding="utf-8"))
    entries = index if isinstance(index, list) else index.get("entries", index)
    rep_path = WORK / "report.json"
    rep = json.loads(rep_path.read_text(encoding="utf-8")) \
        if rep_path.exists() else {}
    for u in units:
        key, cn, form = u["key"], u["cn"], u["form"]
        fam = family_of(u)
        if key in GLB_OVERRIDE and (GLB_DIR / GLB_OVERRIDE[key]).exists():
            f, cands, info = GLB_OVERRIDE[key], [], {"sane": True}
        else:
            f, cands, info = pick_glb(CN_ALIAS.get(cn, cn), entries)
            # external texture override counts as a valid image source
            if key in TEX_OVERRIDE and info and not info.get("img"):
                info = dict(info, img=1,
                            sane=info.get("h", 0) > 0.25
                            and info.get("nv", 0) > 100
                            and info.get("nj", 0) > 0)
        if not f:
            rep[key] = {"status": "noglb", "cn": cn, "form": form,
                        "family": fam}
            print(f"{key:34s} NO GLB ({cn})")
            continue
        joints, parents, (lo, hi), nimg, nv = glb_scene(GLB_DIR / f)
        zup = _zup_of(joints)
        if zup:   # _fbx-style file: rotate bind space z-up -> game y-up
            joints = {n: _rotx(p) for n, p in joints.items()}
            lo, hi = _rotx(lo), _rotx(hi)
            lo, hi = ([min(a, b) for a, b in zip(lo, hi)],
                      [max(a, b) for a, b in zip(lo, hi)])
        rec = {"status": "ok", "cn": cn, "form": form, "family": fam,
               "glb": f, "zup": zup, "candidates": cands, "joints": joints,
               "bbox": [lo, hi], "images": nimg, "verts": nv,
               "mesh_h": round(hi[1] - lo[1], 3),
               "mesh_len": round(hi[2] - lo[2], 3)}
        slots, per = classify_joints(joints, parents)
        rec["slots"] = {k: {s: v[0] for s, v in d.items()}
                        for k, d in slots.items()}
        if key in MANUAL_LM:
            # hand-authored joint/position map for degenerate rigs
            lm, probs = {}, []
            for lmk, src in MANUAL_LM[key].items():
                if isinstance(src, str):
                    if src in joints:
                        lm[lmk] = joints[src]
                    else:
                        probs.append(f"manual: {src} missing")
                else:
                    lm[lmk] = list(src)
            rec["landmarks"] = lm
            rec["problems"] = probs
            if probs or len(lm) < 12:
                rec["status"] = "manual"
        elif fam == "biped":
            lm, probs = biped_landmarks(slots)
            if len(lm) < 16 or any(
                    not p.startswith("synth") and p != "no neck"
                    for p in probs):
                # topology fallback for J_jointNN-style generic rigs
                lm2, probs2 = topo_biped_landmarks(joints, parents,
                                                   (lo, hi))
                if len(lm2) > len(lm):
                    lm, probs = lm2, probs2
            rec["landmarks"] = lm
            rec["problems"] = probs
            fatal = [p for p in probs
                     if not p.startswith("synth") and p != "no neck"]
            if fatal or len(lm) < 16:
                rec["status"] = "manual"
        else:
            builder = {"quad": quad_landmarks, "bird": bird_landmarks,
                       "snake": snake_landmarks,
                       "spider": spider_landmarks,
                       "dragon": dragon_landmarks}[fam]
            lm, probs = builder(joints, parents, (lo, hi))
            rec["landmarks"] = lm
            rec["problems"] = probs
            if len(lm) < 12:
                rec["status"] = "manual"
        if not info.get("sane", True):
            rec["status"] = "manual"
        # preserve build identity across rescans
        for keep in ("skel", "anim_key"):
            if rep.get(key, {}).get(keep):
                rec[keep] = rep[key][keep]
        rep[key] = rec
        print(f"{key:34s} {rec['status']:7s} fam={fam:6s} "
              f"h={rec['mesh_h']:5.2f} j={len(joints):3d} v={nv:5d} "
              f"img={nimg} {f} {rec.get('problems') or ''}")
    rep_path.parent.mkdir(parents=True, exist_ok=True)
    rep_path.write_text(json.dumps(rep, ensure_ascii=False, indent=1),
                        encoding="utf-8")
    print("report ->", rep_path)


# ============================================================ build phases

BLENDER = r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
# gameplay target height (m) per stage -> variants scale
STAGE_HEIGHT = {"rookie": 1.25, "champion": 2.1, "ultimate": 2.9,
                "mega": 3.9, "boss": 4.6}
# per-unit mesh yaw fix (deg) applied at bind when source faces != -Y
BIND_YAW = {}


def fam_res(fam):
    """Resolved resource paths for an animation family."""
    f = FAMILY[fam]
    vd = VANILLA / f["vdir"]
    return dict(tmpl=f["tmpl"],
                skel_json=TOOLS / "_skel" / f"{f['tmpl']}.json",
                skel_anim=TOOLS / "_skel" / f"{f['tmpl']}.anim",
                meta=vd / f"{f['tmpl']}.anm.meta",
                bin=vd / f["bin"], clips=vd / "clips",
                clip_list=vd / "clip_list.txt",
                skel_len=len(f["tmpl"]), suffix=f["suffix"],
                slot=f["slot"], donor=f["donor"], entity=f["entity"],
                weapon=f["weapon"], meta_ok=f["meta"],
                exclude=f["exclude"])


def skel_name_for(key, rep, fam):
    """Skeleton name must be exactly len(template) chars (bin patch)."""
    rec = rep.get(key, {})
    if rec.get("skel"):
        return rec["skel"]
    L = len(FAMILY[fam]["tmpl"])
    base = key[len("czx_dgm_"):]
    nm = ("czx_" + base)[:L]
    used = {r.get("skel") for r in rep.values()}
    if nm in used:
        for i in range(10):
            alt = ("czx_" + base)[:L - 1] + str(i)
            if alt not in used:
                return alt
    return nm


def unit_dir(key):
    d = WORK / key
    d.mkdir(parents=True, exist_ok=True)
    return d


def phase_fit(units):
    from fit_skeleton import fit
    rep = load_report()
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("status") != "ok" or not rec.get("landmarks"):
            print(f"{key:32s} skip ({rec.get('status')})")
            continue
        if rec.get("phase_fit") == "done":
            print(f"{key:32s} fit done"); continue
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        sk = skel_name_for(key, rep, fam)
        ud = unit_dir(key)
        lm = {k: [-v[0], v[1], v[2]] for k, v in rec["landmarks"].items()}
        (ud / "landmarks.json").write_text(json.dumps(lm, indent=1))
        skel = json.loads(res["skel_json"].read_text(encoding="utf-8"))
        skel["custom_name"] = sk
        wp, wq, lp, lq = fit(skel, lm)
        skel["world_pos_frame0"] = [list(map(float, p)) for p in wp]
        skel["world_quat_frame0"] = [list(map(float, q)) for q in wq]
        skel["local_pos_frame0"] = lp
        skel["local_quat_frame0"] = lq
        skel["skeleton_name"] = sk
        out = ud / f"skel_{sk}.json"
        out.write_text(json.dumps(skel))
        rec["skel"] = sk
        rec["family"] = fam
        rec["phase_fit"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} fit[{fam}] -> {sk} ({len(lm)} landmarks)")


def _remap_prim_weights(js, buf, jmap, bone_names):
    """Per-prim (JOINTS_0, WEIGHTS_0) remapped through jmap into bone_names
    index space. Iterates nodes/prims in the exact order glb_bindspace._bake
    does so the lists stay parallel. Non-skinned prims -> None."""
    import glb_bindspace as gb
    bidx = {n: i for i, n in enumerate(bone_names)}
    out = []
    for n in js.get("nodes", []):
        if "mesh" not in n:
            continue
        skin = js["skins"][n["skin"]] if "skin" in n else None
        if skin is not None:
            src_names = [js["nodes"][j].get("name", "")
                         for j in skin["joints"]]
            lut = np.array([bidx.get(jmap.get(nm, ""), 0)
                            for nm in src_names], dtype=np.int64)
            miss = [nm for nm in src_names if jmap.get(nm) not in bidx]
            if miss:
                print("   weightmap miss:", miss[:8])
        for prim in js["meshes"][n["mesh"]].get("primitives", []):
            at = prim["attributes"]
            if skin is None or "JOINTS_0" not in at:
                out.append(None)
                continue
            jj = gb.read_accessor(js, buf, at["JOINTS_0"]).astype(np.int64)
            ww = gb.read_accessor(js, buf, at["WEIGHTS_0"]).astype(np.float32)
            jj = lut[np.clip(jj, 0, len(lut) - 1)]
            # merge duplicate target bones inside a vert's 4 slots
            for v in range(len(jj)):
                seen = {}
                for k in range(4):
                    t, w = int(jj[v, k]), float(ww[v, k])
                    if w <= 0:
                        continue
                    if t in seen:
                        ww[v, seen[t]] += w
                        ww[v, k] = 0.0
                    else:
                        seen[t] = k
            s = ww.sum(1, keepdims=True)
            ww = np.divide(ww, s, out=np.zeros_like(ww), where=s > 0)
            out.append((jj.astype(np.uint16), ww))
    return out


def phase_bind(units):
    rep = load_report()
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_fit") != "done":
            print(f"{key:32s} skip (no fit)")
            continue
        if rec.get("phase_bind") == "done":
            print(f"{key:32s} bind done")
            continue
        ud = unit_dir(key)
        out = ud / f"{key}_bound.glb"
        world_glb = ud / f"{key}_world.glb"
        jmap_p = ud / "jmap.json"
        # bake skinned source -> static world-space glb (v = Σw·J·IBM·v)
        if not world_glb.exists():
            import glb_bindspace as gb
            _js, _bb = gb.read_glb(str(GLB_DIR / rec["glb"]))
            sjs, prims = gb._bake(_js, _bb)
            # drop VFX effect-sheet prims (eff_*/fx_* materials): they are
            # quads for skill effects, not body geometry — leaving them in
            # produces giant striped planes flapping on limb bones.
            _mats = _js.get("materials", [])
            _drop = {i for i, m in enumerate(_mats)
                     if re.match(r"(eff_|ef_|fx_|effect)", m.get("name", ""),
                                 re.I)}
            keep_idx = ([i for i, p in enumerate(prims)
                         if p["mat"] not in _drop]
                        if _drop else list(range(len(prims))))
            if not keep_idx:
                keep_idx = list(range(len(prims)))
                print(f"{key:34s} !! all prims are eff_* - keeping")
            if rec.get("zup"):
                # bind space is z-up -> rotate to game y-up, same as joints
                for p in prims:
                    p["pos"] = np.stack(
                        [p["pos"][:, 0], p["pos"][:, 2],
                         -p["pos"][:, 1]], 1)
                    if p["nrm"] is not None:
                        p["nrm"] = np.stack(
                            [p["nrm"][:, 0], p["nrm"][:, 2],
                             -p["nrm"][:, 1]], 1)
            weights = bone_names = None
            _ovr = _ovr_p = _orep = None
            # ---- wfix.ovr 装载（jmap 无关——rest_scale_fix 是节点层补丁）
            try:
                import wfix_ovr_replay as _wovr
                _ovr, _ovr_p = _wovr.load_ovr(key)
            except Exception:
                pass
            if _ovr:
                # rest_scale_fix：sjs/源 _js 双侧节点层归一（bind 输出骨架由
                # skel json 重建本无 scale 面，此处防源层污染带入 + 记账）
                _rs = _wovr.apply_rest_scale_fix(sjs, _ovr)
                _rs2 = _wovr.apply_rest_scale_fix(_js, _ovr)
                _orep = {"path": _ovr_p,
                         "rest_scale": {"sjs": _rs, "src": _rs2},
                         "prims": []}
                if _rs["fixed"] or _rs2["fixed"] or _rs["missing"]:
                    print(f"{key:34s} rest_scale_fix "
                          f"sjs={len(_rs['fixed'])} src={len(_rs2['fixed'])} "
                          f"miss={len(_rs['missing'])} "
                          f"maxdv={_rs['rest_world_max_dv']:.2e}")
            if jmap_p.exists():
                # carry source artist weights (remapped to target bones) as a
                # synthetic skin so blender_rig2 'keep' mode preserves them
                jmap = json.loads(jmap_p.read_text(encoding="utf-8"))
                skel = json.loads(
                    (ud / f"skel_{rec['skel']}.json").read_text())
                bone_names = [b["name"] for b in skel["bones"]]
                # ---- wfix.ovr 钩子：jmap_ovr 先于权重移植合并
                if _ovr:
                    jmap, _ovk = _wovr.apply_jmap_ovr(jmap, _ovr)
                weights = _remap_prim_weights(
                    _js, _bb, jmap, bone_names)
                # ---- wfix.ovr 钩子：谓词补丁在骨名空间重放 + nzJ 守卫
                if _ovr and weights is not None:
                    _bpos = {}
                    _wp = skel.get("world_pos_frame0") or []
                    for _bi, _b in enumerate(skel["bones"]):
                        if _bi < len(_wp):
                            _bpos[_b["name"]] = np.array(_wp[_bi])
                    _orep = _orep or {"path": _ovr_p, "prims": []}
                    _pid = []  # per-node prim 下标（rigid_prim 语义键，
                    for _n in _js.get("nodes", []):        #  与
                        if "mesh" not in _n:               #  _remap_prim_weights
                            continue                     #  同序）
                        for _pi2 in range(len(_js["meshes"]
                                              [_n["mesh"]]
                                              .get("primitives", []))):
                            _pid.append(_pi2)
                    for _pi, _pw in enumerate(weights):
                        if _pw is None:
                            continue
                        _jj, _ww = _pw
                        _W = _wovr.slots_to_dense(
                            _jj, _ww, len(bone_names))
                        _W0 = _W.copy()
                        _pr = _wovr.apply_patches(
                            _W, bone_names,
                            np.asarray(prims[_pi]["pos"]), _bpos, _ovr,
                            prim_id=np.full(len(_W), _pid[_pi], np.int32))
                        _pr["guard"] = _wovr.weight_guard(
                            bone_names, _W0, bone_names, _W,
                            dom_exclude={'animroot'})
                        weights[_pi] = _wovr.dense_to_slots(_W)
                        _orep["prims"].append(_pr)
                    _orep["applied"] = sum(x.get("applied", 0)
                                         for x in _orep["prims"])
                    _orep["WEIGHT_FIX_RISK"] = any(
                        x["guard"]["risk"] for x in _orep["prims"])
                    print(f"{key:34s} wfix.ovr replay "
                          f"applied={_orep['applied']} "
                          f"risk={_orep['WEIGHT_FIX_RISK']}")
            if _orep is not None:   # 重放记账落盘（jmap 有无皆然）
                try:
                    (ud / "wfix_replay.json").write_text(
                        json.dumps(_orep, ensure_ascii=False, indent=1),
                        encoding="utf-8")
                except Exception:
                    pass
            prims = [prims[i] for i in keep_idx]
            if weights is not None:
                weights = [weights[i] for i in keep_idx]
            gb.write_glb(str(world_glb), sjs, prims, src_buf=_bb,
                         weights=weights, bone_names=bone_names)
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        yaw = BIND_YAW.get(key, 0.0)
        env = dict(os.environ)
        # birds/dragons need wing+feather bones weightable -> relax builtin
        if fam in ("bird", "dragon"):
            env["RIG_EXCLUDE_BUILTIN"] = (
                r"prop|cape|skirt|belt|cloth|flag|tabard|fx_|icon|camera"
                r"|weapon|shield|quiver|scabbard|attach|slot|mount|platform"
                r"|banner|be_prop")
        cmd = [BLENDER, "-b", "-P", str(TOOLS / "blender_rig2.py"), "--",
               str(ud / f"skel_{rec['skel']}.json"),
               str(world_glb), str(out), "nofit",
               res["exclude"], "", str(yaw), "",
               "keep" if jmap_p.exists() else ""]
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", env=env)
        ok = out.exists() and r.returncode == 0
        (ud / "bind_log.txt").write_text(r.stdout + "\n" + r.stderr)
        if ok:
            # true bound height -> drives variants scale in phase_db
            _js, _bb = read_glb(out)
            _mn = _mx = None
            for _n in _js.get("nodes", []):
                if "mesh" not in _n:
                    continue
                for _p in _js["meshes"][_n["mesh"]]["primitives"]:
                    _ac = _js["accessors"][_p["attributes"]["POSITION"]]
                    _lo, _hi = np.array(_ac["min"]), np.array(_ac["max"])
                    _mn = _lo if _mn is None else np.minimum(_mn, _lo)
                    _mx = _hi if _mx is None else np.maximum(_mx, _hi)
            if _mx is not None:
                rec["mesh_h"] = round(float(_mx[1] - _mn[1]), 3)
            if _ovr and weights is not None:
                rec["wfix_ovr"] = {"applied": _orep["applied"],
                                   "risk": bool(_orep["WEIGHT_FIX_RISK"]),
                                   "stale": sorted({s for x in
                                                    _orep["prims"]
                                                    for s in
                                                    x.get("stale", [])})}
            rec["phase_bind"] = "done"
            save_report(rep, {key})
        print(f"{key:32s} bind {'ok' if ok else 'FAIL (see bind_log.txt)'}")


def phase_skelres(units):
    """skeleton .anim + bone_inv_trans_mats + .anm.meta into mod source."""
    from fit_skeleton import write_skeleton, write_invmats
    rep = load_report()
    skdir = MOD / "animations" / "skeletons"
    skdir.mkdir(parents=True, exist_ok=True)
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_bind") != "done":
            print(f"{key:32s} skip skelres")
            continue
        if rec.get("phase_skelres") == "done":
            print(f"{key:32s} skelres done"); continue
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        ud = unit_dir(key)
        skel = json.loads((ud / f"skel_{rec['skel']}.json").read_text())
        sk = rec["skel"]
        write_skeleton(str(res["skel_anim"]), str(skdir / f"{sk}.anim"),
                       sk, skel["local_pos_frame0"],
                       skel["local_quat_frame0"])
        write_invmats(skel["world_pos_frame0"], skel["world_quat_frame0"],
                      str(skdir / f"{sk}.bone_inv_trans_mats"))
        if res["meta_ok"] and res["meta"].exists():
            (skdir / f"{sk}.anm.meta").write_bytes(res["meta"].read_bytes())
        rec["phase_skelres"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} skeleton res -> {sk}")


_MOD_FILES_CACHE = None


def _mod_files():
    """lower-case posix paths of every file currently in the mod source."""
    global _MOD_FILES_CACHE
    if _MOD_FILES_CACHE is None:
        _MOD_FILES_CACHE = {
            p.relative_to(MOD).as_posix().lower()
            for p in MOD.rglob("*") if p.is_file()
        }
    return _MOD_FILES_CACHE


def patch_animsuite_bin(raw, tmpl_b, sk_b):
    """Selective skeleton-name rewrite inside an animsuite bin.

    Rewrites tmpl -> skel only inside length-prefixed strings that are
    either the bare skeleton name, an 'animations/skeletons/' ref, or an
    '.anim' clip path whose rewritten target actually exists in the mod
    source. All other refs (.anm.meta/.meta/.snd.meta/.xml, matchup
    deaths/face/hands clips we do not ship) keep the donor path so they
    resolve against vanilla files. [实测/需随版本复查]
    """
    import struct
    assert len(tmpl_b) == len(sk_b), (tmpl_b, sk_b)
    n = len(raw)
    toks = []
    i = 0
    while i + 2 <= n:
        L = struct.unpack_from("<H", raw, i)[0]
        if (2 <= L <= 400 and i + 2 + L <= n
                and all(0x20 <= c <= 0x7E for c in raw[i + 2:i + 2 + L])):
            toks.append((i + 2, i + 2 + L))
            i += 2 + L
        else:
            i += 1
    buf = bytearray(raw)
    for s, e in toks:
        content = raw[s:e]
        if tmpl_b not in content:
            continue
        cs = content.decode("ascii")
        if cs == tmpl_b.decode() or cs.startswith("animations/skeletons/"):
            rewrite = True
        elif cs.endswith(".anim"):
            rewrite = (content.replace(tmpl_b, sk_b)
                       .decode("ascii").lower() in _mod_files())
        else:
            rewrite = False
        if rewrite:
            buf[s:e] = content.replace(tmpl_b, sk_b)
    return bytes(buf)


def set_animsuite_name(raw, name_b):
    """Rewrite the bin's first length-prefixed string (the animsuite
    registration name) to `name_b`. The engine registers the suite under
    this internal name, not the filename — if left as the vanilla donor
    name, all cloned bins collide on the donor key, none of the czx_*
    suites (or the skeletons they declare) register, and every unit
    referencing them crashes on spawn. [实测：db_validation 104 条
    BATTLE_SKELETONS bad entry 全由此起]"""
    import struct
    L = struct.unpack_from("<H", raw, 8)[0]
    return raw[:8] + struct.pack("<H", len(name_b)) + name_b + raw[10 + L:]


def phase_anim(units):
    """retarget the family's vanilla clips + clone bin per unit."""
    from retarget_clip import load_clip, retarget_delta
    from anim_rw import write_file
    rep = load_report()
    pathmaps, donors = {}, {}
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_skelres") != "done":
            print(f"{key:32s} skip anim")
            continue
        if rec.get("phase_anim") == "done":
            print(f"{key:32s} anim done")
            continue
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        if fam not in pathmaps:
            pm = {}
            anchor = f"animations/battle/{res['tmpl']}/"
            for line in res["clip_list"].read_text().splitlines():
                line = line.strip()
                if line:
                    pm[Path(line).name] = line.split(anchor)[-1]
            pathmaps[fam] = pm
            donors[fam] = json.loads(
                res["skel_json"].read_text(encoding="utf-8"))
        pathmap = pathmaps[fam]
        donor = donors[fam]
        sk = rec["skel"]
        ud = unit_dir(key)
        skel = json.loads((ud / f"skel_{sk}.json").read_text())
        n_ok = 0
        for src in sorted(res["clips"].glob("*.anim")):
            rel = pathmap.get(src.name)
            if not rel:
                continue
            out = MOD / "animations" / "battle" / sk / rel
            if out.exists():
                n_ok += 1
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            try:
                clip = load_clip(str(src))
                clip, _w = retarget_delta(
                    clip, skel, donor, sk,
                    ref=RETARGET_REF.get(key, "bind"),
                    damp=RETARGET_DAMP.get(key),
                    pos_damp=RETARGET_POS_DAMP.get(key))
                write_file(clip, str(out), zstd_compress=True)
                n_ok += 1
            except Exception as e:
                print(f"   ! {src.name}: {e}")
        # clone bin: existence-aware path rewrite (same length!)
        # 实测教训：禁止裸 raw.replace(tmpl, sk) —— 会把 .anm.meta/.snd.meta
        # 等必须保留原版路径的引用一起改名成不存在的 czx_* 文件。
        anim_key = f"{key}_{res['suffix']}"
        bdir = MOD / "animations" / "database" / "battle" / "bin"
        bdir.mkdir(parents=True, exist_ok=True)
        raw = res["bin"].read_bytes()
        global _MOD_FILES_CACHE
        _MOD_FILES_CACHE = None
        patched = patch_animsuite_bin(raw, res["tmpl"].encode(), sk.encode())
        assert len(patched) == len(raw)
        # suite registration name must be the suite's own key, else every
        # cloned bin claims the donor name and none register
        patched = set_animsuite_name(patched, anim_key.encode())
        (bdir / f"{anim_key}.bin").write_bytes(patched)
        rec["anim_key"] = anim_key
        rec["phase_anim"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} anim[{fam}] ok ({n_ok} clips, "
              f"bin {len(patched)}B)")


def phase_rmv2(units):
    import convert_new_units as cnu
    rep = load_report()
    cnu.MOD = MOD
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_bind") != "done":
            print(f"{key:32s} skip rmv2")
            continue
        if rec.get("phase_rmv2") == "done":
            print(f"{key:32s} rmv2 done"); continue
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        ud = unit_dir(key)
        cnu.convert_unit(dict(
            key=key, glb="",
            glb_path=str(ud / f"{key}_bound.glb"),
            src_glb=str(GLB_DIR / rec["glb"]),
            skel=str(ud / f"skel_{rec['skel']}.json"),
            donor_rmv2=res["donor"],
            pack_dir=f"variantmeshes\\wh_variantmodels\\{res['slot']}"
                     f"\\czx\\{key}",
            model_name=f"{key}_01",
            rmv2_skel_name=rec["skel"],
            audio_entity="wh2_tmb_scorpion", audio_armour="heavy_metal",
            vmd_slots_extra="",
            tex_override=str(TEX_OVERRIDE.get(key, "")) or None))
        rec["phase_rmv2"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} rmv2[{fam}] ok")


def phase_db(units):
    rep = load_report()
    keys = [u["key"] for u in units
            if rep.get(u["key"], {}).get("phase_rmv2") == "done"]
    if not keys:
        print("no rmv2-done units"); return
    byfam = {}
    for u in units:
        k = u["key"]
        if k in keys:
            byfam.setdefault(rep[k].get("family") or family_of(u),
                             []).append(k)
    for fam, ks in byfam.items():
        res = fam_res(fam)
        cmd = [sys.executable, str(TOOLS / "gen_digimon_db.py"),
               "--units", ",".join(ks)]
        if res["entity"]:
            cmd += ["--entity", res["entity"]]
        if res["weapon"]:
            cmd += ["--weapon", res["weapon"]]
        subprocess.run(cmd, check=True)
    # patch man_animation + battle_animations + variants scale
    lu = MOD / "db" / "land_units_tables" / "!!czx_digimon_units.tsv"
    lines = lu.read_text(encoding="utf-8").splitlines()
    hdr = lines[0].split("\t")
    ia = hdr.index("man_animation")
    ba = MOD / "db" / "battle_animations_table_tables" \
        / "!!czx_digimon_units.tsv"
    ba.parent.mkdir(parents=True, exist_ok=True)
    ba_lines = ba.read_text(encoding="utf-8").splitlines() \
        if ba.exists() else ["key\tskeleton",
                             "#battle_animations_table;7;"
                             "db/battle_animations_table_tables/"
                             "!!czx_digimon_units"]
    vt = MOD / "db" / "variants_tables" / "!!czx_digimon_units.tsv"
    vlines = vt.read_text(encoding="utf-8").splitlines()
    vh = vlines[0].split("\t")
    vscale = vh.index("scale") if "scale" in vh else None
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if "anim_key" not in rec:
            continue
        for i, l in enumerate(lines[2:], 2):
            f = l.split("\t")
            if f and key in f:
                while len(f) <= ia:
                    f.append("")
                f[ia] = rec["anim_key"]
                lines[i] = "\t".join(f)
        row = f"{rec['anim_key']}\t{rec['skel']}"
        if not any(l.startswith(rec["anim_key"]) for l in ba_lines[2:]):
            ba_lines.append(row)
        # variants scale -> stage height
        if vscale is not None and rec.get("mesh_h"):
            target = STAGE_HEIGHT.get(u["stage"], 2.0)
            scale = round(min(3.5, max(0.02, target / rec["mesh_h"])), 3)
            for i, l in enumerate(vlines[2:], 2):
                f = l.split("\t")
                if f and f[0].lstrip("﻿") == key:
                    while len(f) <= vscale:
                        f.append("")
                    f[vscale] = str(scale)
                    vlines[i] = "\t".join(f)
            rec["scale"] = scale
    lu.write_text("\n".join(lines) + "\n", encoding="utf-8")
    ba.write_text("\n".join(ba_lines) + "\n", encoding="utf-8")
    vt.write_text("\n".join(vlines) + "\n", encoding="utf-8")
    save_report(rep, keys)
    print("db patched:", ", ".join(keys))


def phase_ui(units):
    from PIL import Image
    rep = load_report()
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_rmv2") != "done":
            continue
        ud = unit_dir(key)
        prev = ud / "prev"
        if not (ud / "prev_front.png").exists():
            subprocess.run([BLENDER, "-b", "-P",
                            str(TOOLS / "blender_preview_glb.py"), "--",
                            str(ud / f"{key}_bound.glb"), str(prev)],
                           capture_output=True)
        src = ud / "prev_front.png"
        if not src.exists():
            print(f"{key:32s} ui FAIL (no render)"); continue
        im = Image.open(src).convert("RGBA")
        w, h = im.size
        cw = min(w, int(h * 60 / 130))
        x0 = (w - cw) // 2
        crop = im.crop((x0, 0, x0 + cw, h))
        for rel, size in (("ui/units/icons", (60, 130)),
                          ("ui/units/infopics", (120, 260)),
                          ("ui/portraits/units/no_culture", (60, 130))):
            d = MOD / rel
            d.mkdir(parents=True, exist_ok=True)
            crop.resize(size, Image.LANCZOS).save(d / f"{key}.png")
        rec["phase_ui"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} ui ok")


VERIFY_CLIPS = ["hu1_sws_combat_idle_01.anim", "hu1_sws_attack_01.anim",
                "hu1_sws_run_01.anim"]


def verify_clips_for(res):
    """pick idle/attack/move clips present in the family's clip dir."""
    names = [p.name for p in res["clips"].glob("*.anim")]
    pick = []
    for pat in (r"combat_idle", r"attack_0?1", r"(run|walk|fly)_0?1"):
        m = sorted(n for n in names if re.search(pat, n))
        if m:
            pick.append(m[0])
    return pick or sorted(names)[:3]


def phase_verify(units):
    rep = load_report()
    for u in units:
        key = u["key"]
        rec = rep.get(key, {})
        if rec.get("phase_bind") != "done":
            print(f"{key:32s} skip verify"); continue
        fam = rec.get("family") or family_of(u)
        res = fam_res(fam)
        ud = unit_dir(key)
        sk = rec["skel"]
        skel_p = ud / f"skel_{sk}.json"
        bound = ud / f"{key}_bound.glb"
        # overlays
        for view in ("front", "side"):
            out = ud / f"overlay_{view}"
            if not Path(str(out) + ".png").exists():
                subprocess.run([BLENDER, "-b", "-P",
                                str(TOOLS / "blender_skel_overlay_json.py"),
                                "--", str(bound), str(skel_p), str(out),
                                f"--{view}"], capture_output=True)
        # pose renders
        donor = json.loads(res["skel_json"].read_text(encoding="utf-8"))
        skel = json.loads(skel_p.read_text())
        from retarget_clip import load_clip, retarget_delta
        for cn in verify_clips_for(res):
            pose_j = ud / f"pose_{cn[:-5]}.json"
            outdir = ud / f"pose_{cn[:-5]}"
            if not pose_j.exists():
                clip = load_clip(str(res["clips"] / cn))
                clip, world = retarget_delta(
                    clip, skel, donor, sk,
                    ref=RETARGET_REF.get(key, "bind"),
                    damp=RETARGET_DAMP.get(key),
                    pos_damp=RETARGET_POS_DAMP.get(key))
                pose_j.write_text(json.dumps(
                    {"skeleton_name": sk, "frame_rate": clip["frame_rate"],
                     "bones": clip["bones"], "world": world}))
            if not outdir.exists():
                subprocess.run(
                    [BLENDER, "-b", "-P",
                     str(TOOLS / "blender_pose_anim.py"), "--",
                     str(bound), str(pose_j), str(skel_p),
                     str(outdir), "15"], capture_output=True)
        rec["phase_verify"] = "done"
        save_report(rep, {key})
        print(f"{key:32s} verify renders done")


def load_report():
    p = WORK / "report.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}


def save_report(rep, keys=None):
    """Merge-on-write: only overwrite records for `keys` (default: all of
    rep's keys). Prevents a stale in-memory rep from clobbering unit state
    written by an earlier phase."""
    p = WORK / "report.json"
    disk = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
    keys = keys or set(rep)
    for k in keys:
        if k in rep:
            disk[k] = rep[k]
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(disk, ensure_ascii=False, indent=1),
                 encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["scan", "fit", "bind", "skelres", "anim",
                                    "rmv2", "db", "ui", "verify", "pack"])
    ap.add_argument("--form", default="")
    ap.add_argument("--units", default="")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--mod", default="zzz_czx_digimon",
                    help="mod source dir under mod_files/ to write into "
                         "(default zzz_czx_digimon). Needs ROSTER.tsv.")
    args = ap.parse_args()

    global MOD, ROSTER, PORTED
    if args.mod != "zzz_czx_digimon":
        MOD = ROOT / "mod_files" / args.mod
        ROSTER = MOD / "ROSTER.tsv"
        PORTED = MOD / "PORTED.tsv"

    roster = load_roster()
    want = set(args.units.split(",")) if args.units else None
    units = [r for r in roster
             if (not want or r["key"] in want)
             and (not args.form or r["form"] == args.form)]
    if args.limit:
        units = units[: args.limit]
    if args.cmd == "scan":
        scan(units)
    elif args.cmd == "pack":
        subprocess.run([sys.executable, str(TOOLS / "build_pack.py"),
                        "zzz_czx_digimon"], check=True)
    else:
        globals()[f"phase_{args.cmd}"](units)


if __name__ == "__main__":
    main()
