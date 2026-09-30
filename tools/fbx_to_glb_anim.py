# -*- coding: utf-8 -*-
"""Blender headless: FBX/DAE -> GLB keeping animations, for the DGM viewer.

Same as fbx_to_glb.py but WITHOUT baking object transforms into mesh/armature
data — that bake scales bone rest positions while leaving action fcurve
translations untouched, which explodes the skeleton during clip playback
(bone worlds ~100x off). For viewer GLBs we keep node transforms as authored
and let the glTF exporter handle the fcurve->node translation mapping.

Usage:
  blender -b --factory-startup -P tools/fbx_to_glb_anim.py -- <in> <out.glb>
"""
import json
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)

low = src.lower()
if low.endswith(".fbx"):
    bpy.ops.import_scene.fbx(
        filepath=src,
        use_anim=True,
        ignore_leaf_bones=False,
        automatic_bone_orientation=False,
    )
elif low.endswith(".dae"):
    bpy.ops.wm.collada_import(filepath=src)
else:
    raise SystemExit(f"unsupported source: {src}")

try:
    bpy.ops.file.pack_all()
except Exception as e:
    print("pack_all warn:", e)

arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
info = {
    "armatures": [(a.name, len(a.data.bones)) for a in arms],
    "meshes": [(m.name, len(m.data.vertices),
                len(m.vertex_groups)) for m in meshes],
    "actions": [a.name for a in bpy.data.actions],
    "images": [i.name for i in bpy.data.images
               if i.name not in ("Render Result", "Viewer Node")],
}
print("SRCINFO=" + json.dumps(info, ensure_ascii=False))

bpy.ops.export_scene.gltf(
    filepath=dst,
    export_format="GLB",
    export_yup=True,
    export_apply=False,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_bake_animation=False,
    export_skins=True,
    export_morph=True,
    export_image_format="AUTO",
)
print("WROTE", dst)
