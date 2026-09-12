# -*- coding: utf-8 -*-
"""Convert the three skinned Zerg GLBs into WH3 pack resources.

For each unit:
- skinned GLB -> RMV2 v8 (donor material template, same skeleton)
- GLB textures -> DDS (2048px, base_colour + normal; mask/specular generated)
- write .wsmodel, .xml.material, .variantmeshdefinition (plain XML)
Output lands under mod_files/czx_swarm_expansion/variantmeshes/
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

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "czx_swarm_expansion"
OUT = Path(r"E:\Code\WH3-modding\tools\_out")
DONOR = Path(r"E:\Code\WH3-modding\tools\_donor\files")
TEXCONV = Path(r"E:\Code\WH3-modding\tools\texconv.exe")

UNITS = [
    dict(key="czx_kerrigan", glb="kerrigan_skinned.glb",
         src_glb=r"E:\Download\3893757fdac8be1a46601d2fb5c5e2c6-凯瑞甘.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\humanoid01b.json",
         donor_rmv2="def_sorceress_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\hu1b\czx\czx_kerrigan",
         model_name="czx_kerrigan_01",
         audio_entity="wh2_def_sorceress", audio_armour="plate",
         vmd_slots_extra="""
	<SLOT name="weapon_1" attach_point="be_prop_0" />
	<SLOT name="weapon_2" attach_point="be_prop_1" />
	<SLOT name="shield" attach_point="be_prop_2" />"""),
    dict(key="czx_zhanglang", glb="roach_skinned.glb",
         src_glb=r"E:\Download\9d11b3ce5add0f33bcaac547aa78d576-蟑螂.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\scorpion01.json",
         donor_rmv2="tmb_tomb_scorpion_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\sc1\czx\czx_zhanglang",
         model_name="czx_zhanglang_01",
         audio_entity="wh2_tmb_scorpion", audio_armour="chitin",
         vmd_slots_extra=""),
    dict(key="czx_feilong", glb="feilong_skinned.glb",
         src_glb=r"E:\Download\8497fafe5e299eb8faf25068a7713685-飞龙.glb",
         skel=r"E:\Code\WH3-modding\tools\_skel\bird01b.json",
         donor_rmv2="tmb_carrion_body_01.rigid_model_v2",
         pack_dir=r"variantmeshes\wh_variantmodels\bi1b\czx\czx_feilong",
         model_name="czx_feilong_01",
         audio_entity="wh2_dlc09_tmb_carrion", audio_armour="chitin",
         vmd_slots_extra=""),
]

MAT_TEMPLATE = """<material>
  <name>{name}.xml</name>
  <shader>shaders/weighted4_character_alpha.xml.shader</shader>
  <sort_override>255</sort_override>
 <textures>
  <texture>
   <slot version="2">t_xml_base_colour</slot>
   <source>{texdir}\\{base}_base_colour.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_blood_map</slot>
   <source>commontextures/bloodmap.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_dither</slot>
   <source>commontextures/dither.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_mask</slot>
   <source>{texdir}\\{base}_mask.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_material_map</slot>
   <source>{texdir}\\{base}_material_map.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_normal</slot>
   <source>{texdir}\\{base}_normal.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_distortion_noise</slot>
   <source>commontextures/winds_of_magic_noise.dds</source>
  </texture>
  <texture>
   <slot version="2">t_xml_distortion</slot>
   <source>commontextures/winds_of_magic_specular.dds</source>
  </texture>
 </textures>
  <params>
  <param>
   <name>blood_uv_scale</name>
   <type>float2</type>
   <value>1,1</value>
  </param>
  <param>
   <name>diffuse_tint_colour</name>
   <type>float3</type>
   <value>0,0,0</value>
  </param>
  <param>
   <name>diffuse_tint_mask</name>
   <type>float4</type>
   <value>0,0,0,0</value>
  </param>
  <param>
   <name>diffuse_tint_variation</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>faction1_tint_variation</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>faction2_tint_variation</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>faction3_mask_channel</name>
   <type>float4</type>
   <value>0,0,0,0</value>
  </param>
  <param>
   <name>faction3_tint_variation</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>faction_colours_use_overlay</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>fuzz_amount</name>
   <type>float</type>
   <value>0</value>
  </param>
  <param>
   <name>receives_blood</name>
   <type>float</type>
   <value>1</value>
  </param>
 </params>
</material>
"""

WSMODEL = """<model version="1">
	<geometry>{geom}</geometry>
		<materials>
			<material lod_index="0" part_index="0">{mat}</material>
		</materials>
</model>
"""

VMD = """<VARIANT_MESH>
	<SLOT name="body" >
		<VARIANT_MESH model="{wsmodel}" >
			<META_DATA>audio_entity_type:{aent}</META_DATA>			<META_DATA>audio_armour_type:{aarm}</META_DATA></VARIANT_MESH>
	</SLOT>{extra}
</VARIANT_MESH>
"""


def extract_glb_textures(glb_path):
    """Return dict image name -> PIL Image (downscaled to 2048)."""
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
        if im.size[0] > 2048:
            im = im.resize((2048, 2048), Image.LANCZOS)
        out[kind] = im
    return out


def convert():
    for u in UNITS:
        print('=' * 20, u['key'])
        donor = parse_rmv2(DONOR / u['donor_rmv2'])
        donor_model = donor['models'][0][0]

        pos, nrm, uv, tan, idx, bone_idx, weights = glb_mesh(OUT / u['glb'], u['skel'])

        # flip X (gltf -> rmv2 convention used by AssetEditor)
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
        write_rmv2_v8(rmv2_path, donor['skeleton'],
                      (pos_r, nrm_r, uv, tan_r, idx, bone_idx, weights),
                      donor_model)

        # textures
        tex_dir = out_dir / 'tex'
        tex_dir.mkdir(exist_ok=True)
        imgs = extract_glb_textures(u['src_glb'])
        pngs = {
            f"{texbase}_base_colour": imgs.get('base', Image.new('RGBA', (16, 16), (255, 0, 255, 255))),
            f"{texbase}_normal": imgs.get('normal', Image.new('RGBA', (16, 16), (128, 128, 255, 255))),
            f"{texbase}_material_map": imgs.get('mr', Image.new('RGBA', (16, 16), (128, 128, 128, 255))),
            f"{texbase}_mask": Image.new('RGBA', (16, 16), (0, 0, 0, 255)),
            f"{texbase}_specular": Image.new('RGBA', (16, 16), (64, 64, 64, 255)),
        }
        for name, im in pngs.items():
            im.save(tex_dir / (name + '.png'))
        # compress to BC7 DDS via texconv
        import subprocess
        for name in pngs:
            subprocess.run(
                [str(TEXCONV), '-f', 'BC7_UNORM', '-y', '-o', str(tex_dir),
                 str(tex_dir / (name + '.png'))], check=True, capture_output=True)
            (tex_dir / (name + '.png')).unlink()

        # wsmodel + material + vmd
        mat_dir = out_dir / 'materials'
        mat_dir.mkdir(exist_ok=True)
        mat_name = f"{texbase}_weighted4_alpha_off.xml.material"
        (mat_dir / mat_name).write_text(
            MAT_TEMPLATE.format(name=mat_name[:-len('.material')],
                                texdir=u['pack_dir'] + r'\tex', base=texbase),
            encoding='utf-8')
        (out_dir / (u['model_name'] + '.wsmodel')).write_text(
            WSMODEL.format(geom=u['pack_dir'] + '\\' + u['model_name'] + '.rigid_model_v2',
                           mat=u['pack_dir'] + r'\materials\\' + mat_name),
            encoding='utf-8')
        vmd_dir = MOD / 'variantmeshes' / 'variantmeshdefinitions'
        vmd_dir.mkdir(parents=True, exist_ok=True)
        (vmd_dir / (u['key'] + '.variantmeshdefinition')).write_text(
            VMD.format(wsmodel=u['pack_dir'] + '\\' + u['model_name'] + '.wsmodel',
                       aent=u['audio_entity'], aarm=u['audio_armour'],
                       extra=u['vmd_slots_extra']),
            encoding='utf-8')
        print('wrote resources under', out_dir)


if __name__ == '__main__':
    convert()
