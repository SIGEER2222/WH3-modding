# -*- coding: utf-8 -*-
"""Convert the 7 new skinned Zerg GLBs into WH3 pack resources for
zzz_czx_swarm_units. Same flow as convert_zerg_assets.py with per-kind
texture size caps for smaller pack footprint.
"""
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, r"E:\Code\WH3-modding\tools")
from rmv2_convert import (parse_rmv2, read_glb, read_accessor, glb_mesh,
                          write_rmv2_v8)
from convert_zerg_assets import MAT_TEMPLATE, WSMODEL, VMD

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "zzz_czx_swarm_units"
if '--mod' in sys.argv:
    MOD = ROOT / "mod_files" / sys.argv[sys.argv.index('--mod') + 1]
OUT = Path(r"E:\Code\WH3-modding\tools\_out")
DONOR = Path(r"E:\Code\WH3-modding\tools\_donor\files")
TEXCONV = Path(r"E:\Code\WH3-modding\tools\texconv.exe")

# texture caps: base colour keeps 2048, the rest 1024
TEX_MAX = {'base': 2048, 'mr': 1024, 'normal': 1024}

UNITS = [
    dict(key="czx_jibian", glb="jibian_skinned.glb",
         src_glb=r"E:\Download\畸变体.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid06.json",
         donor_rmv2="bst_beastlord_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu6\czx\czx_jibian",
         model_name="czx_jibian_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_hd_green", glb="hd_green_skinned.glb",
         src_glb=r"E:\Download\混合体-大绿.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid06.json",
         donor_rmv2="bst_beastlord_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu6\czx\czx_hd_green",
         model_name="czx_hd_green_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_hd_white", glb="hd_white_skinned.glb",
         src_glb=r"E:\Download\混合体-小白.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid01b.json",
         donor_rmv2="def_sorceress_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu1b\czx\czx_hd_white",
         model_name="czx_hd_white_01",
         audio_entity="wh2_def_sorceress", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_hd_black", glb="hd_black_skinned.glb",
         src_glb=r"E:\Download\混合体-小黑.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid01b.json",
         donor_rmv2="def_sorceress_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu1b\czx\czx_hd_black",
         model_name="czx_hd_black_01",
         audio_entity="wh2_def_sorceress", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_hd_dblack", glb="hd_dblack_skinned.glb",
         src_glb=r"E:\Download\混合体-大黑.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid11b.json",
         donor_rmv2="bst_ghorgon_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu11b\czx\czx_hd_dblack",
         model_name="czx_hd_dblack_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_baochong", glb="baochong_skinned.glb",
         src_glb=r"E:\Download\爆虫.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\spider01.json",
         donor_rmv2="grn_giant_spider_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\sp1\czx\czx_baochong",
         model_name="czx_baochong_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_mangshou", glb="mangshou_czx_bound.glb",
         src_glb=r"E:\Download\莽兽.glb",
         skel=r"E:\Code\WH3-modding\scratch\skel_czx_mangshou.json",
         donor_rmv2="cst_promethean_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\cr1\czx\czx_mangshou",
         model_name="czx_mangshou_01",
         rmv2_skel_name="czx_ms",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_baolongshou", glb="baolongshou_skinned.glb",
         src_glb=r"E:\Download\暴龙兽.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\heavyquadruped01.json",
         donor_rmv2="lzd_stegadon_02.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hq1\czx\czx_baolongshou",
         model_name="czx_baolongshou_01",
         audio_entity="wh2_lzd_stegadon", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_inf_tank", glb="inf_tank_skinned.glb",
         src_glb=r"E:\Download\被感染的坦克.glb",
         skel=r"E:\Code\WH3-modding\scratch\skel_czx_inf_tank.json",
         donor_rmv2="emp_steam_tank_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\st1\czx\czx_inf_tank",
         model_name="czx_inf_tank_01",
         rmv2_skel_name="czx_stank01",
         audio_entity="wh_war_machine_steamtank", audio_armour="heavy_metal",
         vmd_slots_extra=""),
    dict(key="czx_dehaka", glb="dehaka_czx_bound.glb",
         src_glb=r"E:\Download\德哈卡.glb",
         skel=r"E:\Code\WH3-modding\scratch\skel_czx_dehaka.json",
         donor_rmv2="bst_ghorgon_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu11b\czx\czx_dehaka",
         model_name="czx_dehaka_01",
         rmv2_skel_name="czx_dehaka1",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_inf_diamondback", glb="inf_diamondback_skinned.glb",
         src_glb=r"E:\Download\被感染的响尾蛇.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\spider01.json",
         donor_rmv2="grn_giant_spider_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\sp1\czx\czx_inf_diamondback",
         model_name="czx_inf_diamondback_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_dgm_wargreymon", glb="wargreymon_wgm001_bound.glb",
         src_glb=r"E:\Code\WH3-modding\scratch\wargreymon.glb",
         skel=r"E:\Code\WH3-modding\scratch\salzaar_digimon\skel_czx_wgm001.json",
         donor_rmv2="emp_greatswords_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu1\czx\czx_dgm_wargreymon",
         model_name="czx_dgm_wargreymon_01",
         rmv2_skel_name="czx_wgm001",
         audio_entity="wh2_tmb_scorpion", audio_armour="heavy_metal",
         vmd_slots_extra=""),
    dict(key="czx_inf_marine", glb="marine_czx_bound.glb",
         src_glb=r"E:\Download\被感染的枪兵.glb",
         skel=r"E:\Code\WH3-modding\scratch\skel_czx_inf_marine.json",
         donor_rmv2="emp_volkmar_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu1\czx\czx_inf_marine",
         model_name="czx_inf_marine_01",
         rmv2_skel_name="czx_marine",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
]


def extract_glb_textures(glb_path):
    js, binbuf = read_glb(glb_path)
    out = {}
    mat = js['materials'][0]
    pbr = mat.get('pbrMetallicRoughness', {})
    for kind, texref in (('base', pbr.get('baseColorTexture')),
                         ('mr', pbr.get('metallicRoughnessTexture')),
                         ('normal', mat.get('normalTexture'))):
        if not texref:
            continue
        img_idx = js['textures'][texref['index']]['source']
        img = js['images'][img_idx]
        bv = js['bufferViews'][img['bufferView']]
        data = binbuf[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
        im = Image.open(io.BytesIO(data)).convert('RGBA')
        cap = TEX_MAX[kind]
        if im.size[0] > cap:
            im = im.resize((cap, cap), Image.LANCZOS)
        out[kind] = im
    return out


def convert_unit(u):
    import subprocess
    print('=' * 20, u['key'])
    donor = parse_rmv2(DONOR / u['donor_rmv2'])
    donor_model = donor['models'][0][0]

    pos, nrm, uv, tan, idx, bone_idx, weights = glb_mesh(
        Path(u.get('glb_path', OUT / u['glb'])), u['skel'])

    pos_r = pos.copy(); pos_r[:, 0] *= -1
    nrm_r = nrm.copy(); nrm_r[:, 0] *= -1
    tan_r = tan.copy() if tan is not None else None
    if tan_r is not None:
        tan_r[:, 0] *= -1

    d = donor_model['material']
    d['textures'] = [(t, p) for t, p in d['textures']]
    texdir = u['pack_dir'].replace('\\', '/') + '/tex'
    new_tex = []
    texbase = u['model_name']
    for ttype, _ in d['textures']:
        if ttype == 27:
            new_tex.append((ttype, f"{texdir}/{texbase}_base_colour.dds"))
        elif ttype == 1:
            new_tex.append((ttype, f"{texdir}/{texbase}_normal.dds"))
        elif ttype == 29:
            new_tex.append((ttype, f"{texdir}/{texbase}_material_map.dds"))
        elif ttype == 11:
            new_tex.append((ttype, f"{texdir}/{texbase}_specular.dds"))
        elif ttype == 3:
            new_tex.append((ttype, f"{texdir}/{texbase}_mask.dds"))
        else:
            new_tex.append((ttype, f"{texdir}/{texbase}_base_colour.dds"))
    d['tex_dir'] = texdir
    d['textures'] = new_tex
    d['model_name'] = u['model_name']

    out_dir = MOD / u['pack_dir']
    out_dir.mkdir(parents=True, exist_ok=True)
    rmv2_path = out_dir / (u['model_name'] + '.rigid_model_v2')
    write_rmv2_v8(rmv2_path, u.get('rmv2_skel_name', donor['skeleton']),
                  (pos_r, nrm_r, uv, tan_r, idx, bone_idx, weights),
                  donor_model, lod_levels=1)

    tex_dir = out_dir / 'tex'
    tex_dir.mkdir(exist_ok=True)
    imgs = extract_glb_textures(u['src_glb'])
    if u.get('tex_override'):
        imgs['base'] = Image.open(u['tex_override']).convert('RGBA')
    pngs = {
        f"{texbase}_base_colour": imgs.get('base', Image.new('RGBA', (16, 16), (255, 0, 255, 255))),
        f"{texbase}_normal": imgs.get('normal', Image.new('RGBA', (16, 16), (128, 128, 255, 255))),
        f"{texbase}_material_map": imgs.get('mr', Image.new('RGBA', (16, 16), (128, 128, 128, 255))),
        f"{texbase}_mask": Image.new('RGBA', (16, 16), (0, 0, 0, 255)),
        f"{texbase}_specular": Image.new('RGBA', (16, 16), (64, 64, 64, 255)),
    }
    # stage the intermediate pngs in the OS temp dir: texconv only needs
    # them as input, and leaving them inside the mod source dir forced a
    # per-unit cleanup pass (50+ unlinks per batch run).
    import tempfile
    stage_dir = Path(tempfile.mkdtemp(prefix="wh3_tex_"))
    for name, im in pngs.items():
        im.save(stage_dir / (name + '.png'))
    for name in pngs:
        subprocess.run(
            [str(TEXCONV), '-f', 'BC7_UNORM', '-y', '-o', str(tex_dir),
             str(stage_dir / (name + '.png'))], check=True, capture_output=True)

    mat_dir = out_dir / 'materials'
    mat_dir.mkdir(exist_ok=True)
    mat_name = f"{texbase}_weighted4_alpha_off.xml.material"
    (mat_dir / mat_name).write_text(
        MAT_TEMPLATE.format(name=mat_name[:-len('.material')],
                            texdir=u['pack_dir'] + r'\tex', base=texbase),
        encoding='utf-8')
    (out_dir / (u['model_name'] + '.wsmodel')).write_text(
        WSMODEL.format(geom=u['pack_dir'] + '\\' + u['model_name'] + '.rigid_model_v2',
                       mat=u['pack_dir'] + '\\materials\\' + mat_name),
        encoding='utf-8')
    vmd_dir = MOD / 'variantmeshes' / 'variantmeshdefinitions'
    vmd_dir.mkdir(parents=True, exist_ok=True)
    (vmd_dir / (u['key'] + '.variantmeshdefinition')).write_text(
        VMD.format(wsmodel=u['pack_dir'] + '\\' + u['model_name'] + '.wsmodel',
                   aent=u['audio_entity'], aarm=u['audio_armour'],
                   extra=u['vmd_slots_extra']),
        encoding='utf-8')
    print('wrote resources under', out_dir)


def convert():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--mod' in sys.argv:
        args.remove(sys.argv[sys.argv.index('--mod') + 1])
    only = set(args)
    for u in UNITS:
        if only and u['key'] not in only:
            continue
        convert_unit(u)


if __name__ == '__main__':
    convert()
