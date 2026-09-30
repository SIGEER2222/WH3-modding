# -*- coding: utf-8 -*-
"""Blender headless: FBX/DAE -> GLB for the digimon/pkmn model pipeline.

Usage:
  blender -b --factory-startup -P tools/fbx_to_glb.py -- <in.fbx> <out.glb> [--no-anim]

- imports the first armature+meshes as-is (keep bone names! pipeline jmaps
  rely on J_* names)
- packs external images into the .blend so GLB embeds them
- exports GLB (Y-up, skin weights, animations unless --no-anim)
- prints a JSON line SRCINFO={...} with bone/vert/action counts
"""
import json
import sys

import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
keep_anim = "--no-anim" not in argv

bpy.ops.wm.read_factory_settings(use_empty=True)

low = src.lower()
if low.endswith(".fbx"):
    bpy.ops.import_scene.fbx(
        filepath=src,
        use_anim=keep_anim,
        ignore_leaf_bones=False,   # J_weapon/J_toe leaf bones are real skin
        automatic_bone_orientation=False,
    )
elif low.endswith(".dae"):
    bpy.ops.wm.collada_import(filepath=src)
    # NOTE: do NOT manually flip UVs here. Blender's collada importer keeps
    # v-bottom-origin in Blender space, and the glTF exporter already flips
    # v on export. An extra manual flip cancels it out (glb v == dae v) and
    # produced upside-down textures (missing eyes) across the whole batch.
else:
    raise SystemExit(f"unsupported source: {src}")

# normalize: bake every object's world transform into its data so mesh
# verts and bone rest matrices share ONE frame. glTF ignores the skinned
# mesh node's transform, so if a DAE/FBX import gives the mesh object a
# different transform than its armature, the exported POSITION accessors
# and inverse bind matrices end up in different frames (verts -Z-up vs
# joints +Z-up) and downstream orientation handling breaks.
for o in list(bpy.data.objects):
    if o.parent:
        W = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = W
for o in bpy.data.objects:
    M = o.matrix_world.copy()
    if o.type == "MESH":
        o.data.transform(M)
    elif o.type == "ARMATURE":
        o.data.transform(M)
    o.matrix_world = Matrix.Identity(4)

# pack external textures so they embed in the glb
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

kw = dict(
    filepath=dst,
    export_format="GLB",
    export_yup=True,
    export_apply=False,          # keep skinning intact
    export_animations=keep_anim,
    export_skins=True,
    export_morph=True,
    export_image_format="AUTO",
)
if keep_anim:
    kw.update(export_animation_mode="ACTIONS",
              export_bake_animation=False)
bpy.ops.export_scene.gltf(**kw)
print("WROTE", dst)
