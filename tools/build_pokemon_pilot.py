# -*- coding: utf-8 -*-
"""Pokemon HOME GLB -> WH3 pack resources (native skeleton + native anims).

Per unit produces in the MOD dir:
  variantmeshes/wh_variantmodels/<grp>/<key>/<key>.rigid_model_v2
  variantmeshes/wh_variantmodels/<grp>/<key>/<key>.wsmodel
  variantmeshes/wh_variantmodels/<grp>/<key>/<key>.xml.material
  variantmeshes/wh_variantmodels/<grp>/<key>/textures/*.dds
  variantmeshes/wh_variantmodels/<grp>/<key>/<key>.variantmeshdefinition
  animations/battle/<skel>/*.anim          (idle/move/attack01/attack02/win/damage/down/getup/guard)

Run with Windows Python313.
"""
import io, json, struct, sys, subprocess
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, r"E:\Code\WH3-modding\tools")
from rmv2_convert import parse_rmv2, read_glb, read_accessor, glb_mesh, write_rmv2_v8
import anim_rw

ROOT = Path(r"E:\Code\WH3-modding")
SRC = ROOT / "scratch" / "pokemon"          # <pmid>.glb
MOD = ROOT / "mod_files" / "zzz_czx_pokemon"
DONOR = ROOT / "tools" / "_donor" / "files"
TEXCONV = ROOT / "tools" / "texconv.exe"

# ---- unit table: key, glb, skeleton key, group, cn name, tier, audio ----
UNITS = [
    dict(key="pkm_001_bulbasaur", pmid="pm0001", skel="pm001", grp="pk1",
         cn="妙蛙种子", en="Bulbasaur", tier=1,
         aent="wh2_lzd_skink", aarm="skin"),
    dict(key="pkm_003_venusaur", pmid="pm0003", skel="pm003", grp="pk1",
         cn="妙蛙花", en="Venusaur", tier=2,
         aent="wh2_lzd_stegadon", aarm="chitin"),
    dict(key="pkm_004_charmander", pmid="pm0004", skel="pm004", grp="pk1",
         cn="小火龙", en="Charmander", tier=1,
         aent="wh2_lzd_skink", aarm="skin"),
    dict(key="pkm_006_charizard", pmid="pm0006", skel="pm006", grp="pk1",
         cn="喷火龙", en="Charizard", tier=3,
         aent="wh2_main_hef_dragon", aarm="chitin"),
    dict(key="pkm_007_squirtle", pmid="pm0007", skel="pm007", grp="pk1",
         cn="杰尼龟", en="Squirtle", tier=1,
         aent="wh2_lzd_skink", aarm="chitin"),
    dict(key="pkm_009_blastoise", pmid="pm0009", skel="pm009", grp="pk1",
         cn="水箭龟", en="Blastoise", tier=3,
         aent="wh2_lzd_stegadon", aarm="chitin"),
    dict(key="pkm_025_pikachu", pmid="pm0025", skel="pm025", grp="pk1",
         cn="皮卡丘", en="Pikachu", tier=1,
         aent="wh2_lzd_skink", aarm="skin"),
]

# GLB anim name -> WH3 anim filename (states the engine picks by filename)
ANIM_MAP = [
    ("waitA01",   ["idle", "move", "guard", "getup"]),
    ("buturi01",  ["attack01", "damage"]),
    ("tokusyu01", ["attack02"]),
    ("roar01",    ["win", "down"]),
    ("mouth01",   ["eat"]),
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
	</SLOT>
</VARIANT_MESH>
"""


def dds(img: Image.Image, out: Path, fmt="BC7_UNORM"):
    tmp = out.with_suffix(".png")
    img.save(tmp)
    subprocess.run([str(TEXCONV), "-f", fmt, "-y", "-o", str(out.parent),
                    str(tmp)], check=True, capture_output=True)
    tmp.unlink()
    gen = tmp.with_suffix(".dds")
    if gen != out and gen.exists():
        gen.rename(out)


def skeleton_from_glb(glb_path):
    """-> {'bones':[{'name','parent'}]}, ordered parent-first (mesh nodes excluded)."""
    js, _ = read_glb(glb_path)
    parents = {}
    for i, n in enumerate(js["nodes"]):
        for c in n.get("children", []):
            parents[c] = i
    bone_nodes = [i for i, n in enumerate(js["nodes"]) if "mesh" not in n]
    idx = {ni: k for k, ni in enumerate(bone_nodes)}
    bones = []
    for ni in bone_nodes:
        p = parents.get(ni)
        bones.append({"name": js["nodes"][ni].get("name", f"b{ni}"),
                      "parent": idx.get(p, -1)})
    return bones


def glb_anim_to_wh3(glb_path, anim_name, bones, out_path, rate=30):
    js, binbuf = read_glb(glb_path)
    anim = next((a for a in js.get("animations", []) if anim_name in a["name"]), None)
    if anim is None:
        return False
    bone_nodes = [i for i, n in enumerate(js["nodes"]) if "mesh" not in n]
    n2b = {ni: k for k, ni in enumerate(bone_nodes)}
    bc = len(bones)
    # per bone: sampled times/vals per channel
    tr = {bi: {} for bi in range(bc)}
    for ch in anim["channels"]:
        ni = ch["target"]["node"]
        if ni not in n2b:
            continue
        bi = n2b[ni]
        smp = anim["samplers"][ch["sampler"]]
        t = read_accessor(js, binbuf, smp["input"]).reshape(-1)
        v = read_accessor(js, binbuf, smp["output"])
        tr[bi][ch["target"]["path"]] = (t, v)
    # frame count = max keys
    nf = max((len(tv[0]) for b in tr.values() for tv in b.values()), default=0)
    if nf == 0:
        return False
    # node rest pose fallback
    def rest(ni, path):
        n = js["nodes"][ni]
        if path == "translation":
            return n.get("translation", [0, 0, 0])
        if path == "rotation":
            return n.get("rotation", [0, 0, 0, 1])
        return n.get("scale", [1, 1, 1])
    frames = []
    for f in range(nf):
        trans, quats = [], []
        for bi, ni in enumerate(bone_nodes):
            chs = tr[bi]
            if "translation" in chs:
                t, v = chs["translation"]
                trans.append(v[min(f, len(t) - 1)][:3].tolist())
            else:
                trans.append(rest(ni, "translation"))
            if "rotation" in chs:
                t, v = chs["rotation"]
                q = np.asarray(v[min(f, len(t) - 1)][:4], dtype=np.float64)
                quats.append((q / (np.linalg.norm(q) or 1)).tolist())
            else:
                quats.append(rest(ni, "rotation"))
        frames.append({"transforms": trans, "quaternions": quats})
    anim8 = {
        "version": 8, "unk0": 1, "frame_rate": float(rate),
        "skeleton_name": bones_skel_name, "flags": [],
        "play_time": nf / rate, "bones": bones, "unk_v8": 6,
        "parts": [{"tb": [12] * bc, "rb": [8] * bc,
                   "rt": [([0.0] * 3, [1.0] * 3)] * 0, "rq": [],
                   "stc": 0, "sqc": 0, "static": None,
                   "ftc": 1, "fqc": 1, "frames": frames}],
    }
    anim_rw.write_file(anim8, out_path, zstd_compress=False)
    return True


bones_skel_name = ""


def convert_unit(u):
    glb = SRC / f"{u['pmid']}_00_00.glb"
    key, skel, grp = u["key"], u["skel"], u["grp"]
    texdir_rel = f"variantmeshes/wh_variantmodels/{grp}/{key}/textures"
    pack_dir = MOD / "variantmeshes" / "wh_variantmodels" / grp / key
    texdir = pack_dir / "textures"
    texdir.mkdir(parents=True, exist_ok=True)

    # skeleton json
    bones = skeleton_from_glb(glb)
    skel_json = ROOT / "scratch" / "pokemon" / f"{key}_skel.json"
    skel_json.write_text(json.dumps({"bones": bones}), encoding="utf-8")

    # rmv2
    donor = parse_rmv2(DONOR / "def_sorceress_body_01.rigid_model_v2")
    donor_model = donor["models"][0][0]
    mesh = glb_mesh(str(glb), str(skel_json))
    write_rmv2_v8(str(pack_dir / f"{key}.rigid_model_v2"), skel, mesh, donor_model,
                  lod_levels=1)

    # wsmodel / material / vmd
    (pack_dir / f"{key}.wsmodel").write_text(WSMODEL.format(
        geom=f"{key}.rigid_model_v2", mat=f"{key}.xml.material"), encoding="utf-8")
    (pack_dir / f"{key}.xml.material").write_text(MAT_TEMPLATE.format(
        name=key, texdir=texdir_rel.replace("/", "\\"), base=u["pmid"]),
        encoding="utf-8")
    (pack_dir / f"{key}.variantmeshdefinition").write_text(VMD.format(
        wsmodel=f"variantmeshes/wh_variantmodels/{grp}/{key}/{key}.wsmodel",
        aent=u["aent"], aarm=u["aarm"]), encoding="utf-8")

    # textures: base_colour from glb png + flat normal/mask/material_map
    js, binbuf = read_glb(str(glb))
    base_img = None
    for img in js.get("images", []):
        nm = img.get("name", "")
        if nm.endswith("_col") and "rare" not in nm and base_img is None:
            bv = js["bufferViews"][img["bufferView"]]
            data = binbuf[bv.get("byteOffset", 0):bv["byteOffset"] + bv["byteLength"]]
            base_img = Image.open(io.BytesIO(data)).convert("RGBA")
    if base_img is None:
        base_img = Image.new("RGBA", (512, 512), (200, 160, 120, 255))
    if base_img.size[0] > 1024:
        base_img = base_img.resize((1024, 1024), Image.LANCZOS)
    w = base_img.size[0]
    dds(base_img, texdir / f"{u['pmid']}_base_colour.dds", "BC7_UNORM")
    dds(Image.new("RGBA", (w, w), (128, 128, 255, 255)),
        texdir / f"{u['pmid']}_normal.dds", "BC5_UNORM")
    dds(Image.new("RGBA", (w, w), (0, 0, 0, 255)),
        texdir / f"{u['pmid']}_mask.dds", "BC1_UNORM")
    dds(Image.new("RGBA", (w, w), (128, 128, 128, 255)),
        texdir / f"{u['pmid']}_material_map.dds", "BC1_UNORM")

    # anims
    global bones_skel_name
    bones_skel_name = skel
    adir = MOD / "animations" / "battle" / skel
    adir.mkdir(parents=True, exist_ok=True)
    done = set()
    for glb_name, states in ANIM_MAP:
        for st in states:
            if st in done:
                continue
            if glb_anim_to_wh3(str(glb), glb_name, bones, adir / f"{st}.anim"):
                done.add(st)
    print(f"{key}: bones={len(bones)} anims={sorted(done)}")


if __name__ == "__main__":
    for u in UNITS:
        try:
            convert_unit(u)
        except Exception as e:
            import traceback; traceback.print_exc()
            print(u["key"], "FAIL", e)
