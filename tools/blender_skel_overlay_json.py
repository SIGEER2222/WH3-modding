# Blender 4.x headless: render a static/skinned GLB with a skeleton overlay
# built from a _skel/*.json (world_pos_frame0 + parents). For checking whether
# a CANDIDATE skeleton's bind pose fits inside a mesh.
#
# usage: blender -b -P blender_skel_overlay_json.py -- <glb> <skel.json> <out.png>
import bpy
import sys
import json
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, SKEL, OUT = argv[0], argv[1], argv[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

mat = bpy.data.materials.new('meshmat')
mat.use_nodes = True
bs = mat.node_tree.nodes['Principled BSDF']
bs.inputs['Base Color'].default_value = (0.45, 0.38, 0.5, 1)
bs.inputs['Roughness'].default_value = 0.85
bs.inputs['Alpha'].default_value = 0.55
mat.surface_render_method = 'DITHERED'
for m in meshes:
    m.data.materials.clear()
    m.data.materials.append(mat)

skel = json.load(open(SKEL))
bones = skel['bones']
# glTF y-up -> Blender z-up: (x,y,z)_gltf -> (x,-z,y)_blender
wp = [Vector((p[0], -p[2], p[1])) for p in skel['world_pos_frame0']]

CHAIN = [
    ('leg|foot|ankle|toe|upleg|shin|calf|thigh|knee', (0.15, 0.7, 0.2, 1)),
    ('arm|hand|clav|thumb|finger|wrist|elbow|shoulder|upperarm|forearm', (0.15, 0.4, 0.9, 1)),
    ('spine|neck|head|jaw|snout|mouth|mandible|chest|pelvis|hips|root|torso', (0.9, 0.2, 0.15, 1)),
    ('rear|tail|shell|abdomen', (0.9, 0.6, 0.1, 1)),
    ('claw|pincer|wing', (0.6, 0.15, 0.8, 1)),
]
import re
def color_for(name):
    n = name.lower()
    for pat, c in CHAIN:
        if re.search(pat, n):
            return c
    return (0.95, 0.95, 0.9, 1)

mats = {}
def bone_mat(c):
    key = tuple(c)
    if key not in mats:
        m = bpy.data.materials.new('bmat')
        m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = c
        b.inputs['Roughness'].default_value = 0.5
        em = b.inputs.get('Emission Color') or b.inputs.get('Emission')
        if em:
            em.default_value = c
            st = b.inputs.get('Emission Strength')
            if st:
                st.default_value = 0.6
        mats[key] = m
    return mats[key]

def cyl(a, b, r, mat):
    d = b - a
    L = d.length
    if L < 1e-4:
        return
    mid = (a + b) / 2
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=L, location=mid)
    o = bpy.context.object
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = d.to_track_quat('Z', 'Y')
    o.data.materials.append(mat)

drawn = 0
for i, b in enumerate(bones):
    p = b.get('parent', -1)
    if p < 0 or p >= len(bones):
        continue
    a, bb = wp[p], wp[i]
    if (bb - a).length < 1e-4:
        continue
    cyl(a, bb, 0.025, bone_mat(color_for(b['name'])))
    drawn += 1
# joint balls
for i, b in enumerate(bones):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, radius=0.03, location=wp[i])
    bpy.context.object.data.materials.append(bone_mat(color_for(b['name'])))
print('bones drawn:', drawn)

# camera: frame mesh bbox
allv = []
for m in meshes:
    for v in m.data.vertices:
        allv.append(m.matrix_world @ v.co)
mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
mx = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
c = (mn + mx) / 2
size = max((mx - mn).length, 0.5)

# glTF Y-up -> Blender Z-up already handled by importer; use bbox
cam_data = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', cam_data)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam
cam_pos = c + Vector((size * 0.9, -size * 1.1, size * 0.45))
if '--side' in argv:
    cam_pos = c + Vector((size * 1.3, 0, size * 0.35))
elif '--front' in argv:
    cam_pos = c + Vector((0, -size * 1.3, size * 0.3))
cam.location = cam_pos
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam_data.clip_end = size * 10

sun = bpy.data.lights.new('sun', 'SUN')
sun.energy = 4
so = bpy.data.objects.new('sun', sun)
bpy.context.collection.objects.link(so)
so.rotation_euler = (0.6, 0.2, 0.8)
w = bpy.data.worlds.new('w')
w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.75, 0.78, 0.82, 1)
w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
bpy.context.scene.world = w

# ground
bpy.ops.mesh.primitive_plane_add(size=size * 4, location=(c.x, c.y, mn.z))
pl = bpy.context.object
pm = bpy.data.materials.new('pmat')
pm.use_nodes = True
pm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.85, 0.85, 0.88, 1)
pl.data.materials.append(pm)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x = 640
sc.render.resolution_y = 640
sc.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('saved', OUT)
