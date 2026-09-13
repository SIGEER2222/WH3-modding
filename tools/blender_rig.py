# Blender 4.x headless script: build WH3 armature from parsed .anim JSON,
# import a GLB mesh, fit it to the skeleton, auto-weight bind, export skinned GLB.
#
# Usage:
#   blender -b -P blender_rig.py -- <skel.json> <in.glb> <out.glb> <fit_axis> [exclude_regex]
# fit_axis: "z" (height), "x" (width), "y" (depth), or "auto" (largest dim)
# exclude_regex: optional bone-name regex excluded from WEIGHT BINDING
#   (bones still exist in the armature; they just receive no vertex weights,
#   so decoration bones like platform_*/skulls_*/cape_* can't grab mesh)
import bpy
import json
import sys
import re
from mathutils import Vector, Quaternion

argv = sys.argv[sys.argv.index('--') + 1:]
SKEL_JSON, IN_GLB, OUT_GLB = argv[0], argv[1], argv[2]
FIT_AXIS = argv[3] if len(argv) > 3 else 'auto'
EXCLUDE_RE = re.compile(argv[4]) if len(argv) > 4 and argv[4] else None

data = json.load(open(SKEL_JSON, encoding='utf-8'))
bones = data['bones']
wpos = data['world_pos_frame0']

# --- reset scene ---
bpy.ops.wm.read_factory_settings(use_empty=True)

# --- build armature ---
# game coords are Y-up; Blender is Z-up. glTF importer maps (x,y,z)->(x,-z,y).
def to_blender(v):
    return Vector((v[0], -v[2], v[1]))

arm_data = bpy.data.armatures.new('armature')
arm_obj = bpy.data.objects.new('armature', arm_data)
bpy.context.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
arm_obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')

ebs = []
for i, b in enumerate(bones):
    eb = arm_data.edit_bones.new(b['name'])
    head = to_blender(wpos[i])
    # tail: point to first child head, else small offset along Z
    tail = None
    for j, c in enumerate(bones):
        if c['parent'] == i:
            tail = to_blender(wpos[j])
            break
    if tail is None or (tail - head).length < 0.01:
        tail = head + Vector((0, 0, 0.03))
    eb.head = head
    eb.tail = tail
    ebs.append(eb)

for i, b in enumerate(bones):
    if b['parent'] >= 0:
        ebs[i].parent = ebs[b['parent']]

bpy.ops.object.mode_set(mode='OBJECT')

# --- import mesh ---
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- fit mesh to skeleton ---
sk_pts = [to_blender(p) for p in wpos]
sk_min = Vector((min(p.x for p in sk_pts), min(p.y for p in sk_pts), min(p.z for p in sk_pts)))
sk_max = Vector((max(p.x for p in sk_pts), max(p.y for p in sk_pts), max(p.z for p in sk_pts)))
sk_size = sk_max - sk_min

bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
m_size = m_max - m_min

axis_idx = {'x': 0, 'y': 1, 'z': 2}[FIT_AXIS] if FIT_AXIS != 'auto' else \
    max(range(3), key=lambda i: sk_size[i])
scale = sk_size[axis_idx] / m_size[axis_idx]
mesh.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# recompute bounds after scaling, then align centers + ground level
bb = [Vector(c) for c in mesh.bound_box]
m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
m_ctr = (m_min + m_max) / 2
sk_ctr = (sk_min + sk_max) / 2
mesh.location = Vector((sk_ctr.x - m_ctr.x, sk_ctr.y - m_ctr.y, sk_min.z - m_min.z))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- bind: nearest-bone-segment weights (deterministic, no bone heat) ---
import numpy as np
import re

# decorative/attachment bones flap wildly in clips and shred nearby mesh
# (observed: skirt/cape/belt/platform bones tearing blade arms and shells).
EXCLUDE = re.compile(
    r'prop|cape|skirt|belt|sleeve|cloth|loincloth|flag|tabard|fx|icon|camera'
    r'|weapon|shield|quiver|scabbard|plume|tassel|feather|wing|hair|beard'
    r'|finger|thumb|attach|slot|mount|platform|antenna|eyestalk|banner|be_',
    re.I)
allowed_idx = [i for i, b in enumerate(bones)
               if not EXCLUDE.search(b['name'])
               and not (EXCLUDE_RE and EXCLUDE_RE.search(b['name']))]
print('weightable bones:', len(allowed_idx), '/', len(bones))
if EXCLUDE_RE:
    print('user-excluded:', [b['name'] for b in bones if EXCLUDE_RE.search(b['name'])])

mesh_bb = [Vector(c) for c in mesh.bound_box]
print('MESH bounds after fit:',
      tuple(round(v, 2) for v in Vector((min(v.x for v in mesh_bb), min(v.y for v in mesh_bb), min(v.z for v in mesh_bb)))),
      tuple(round(v, 2) for v in Vector((max(v.x for v in mesh_bb), max(v.y for v in mesh_bb), max(v.z for v in mesh_bb)))))
print('SKEL bounds:', tuple(round(v, 2) for v in sk_min), tuple(round(v, 2) for v in sk_max))

# bone segments in armature space
segs = []
for i, b in enumerate(bones):
    h = to_blender(wpos[i])
    par = b['parent']
    t = None
    for j, c in enumerate(bones):
        if c['parent'] == i:
            t = to_blender(wpos[j])
            break
    if t is None or (t - h).length < 0.01:
        t = h + Vector((0, 0, 0.03))
    segs.append((h, t))

H = np.array([s[0] for s in segs])          # (B,3)
T = np.array([s[1] for s in segs])          # (B,3)
D = T - H                                    # (B,3)
dd = np.maximum((D * D).sum(1), 1e-12)      # |seg|^2

n = len(mesh.data.vertices)
co = np.empty(n * 3)
mesh.data.vertices.foreach_get('co', co)
V = co.reshape(n, 3)

# distance from each vertex to each bone segment -> (n, B)
ap = V[:, None, :] - H[None, :, :]          # (n,B,3)
tpar = np.clip((ap * D[None, :, :]).sum(2) / dd[None, :], 0.0, 1.0)
closest = H[None, :, :] + tpar[:, :, None] * D[None, :, :]
dist = np.sqrt(((V[:, None, :] - closest) ** 2).sum(2))  # (n,B)
dist[:, [i for i in range(len(bones)) if i not in allowed_idx]] = np.inf

K = 4
top = np.argpartition(dist, K, axis=1)[:, :K]            # (n,K)
topd = np.take_along_axis(dist, top, 1)
w = 1.0 / np.maximum(topd, 0.005) ** 2                   # sharp falloff
w /= w.sum(1, keepdims=True)

# create vertex groups and fill weights
vgs = [mesh.vertex_groups.new(name=b['name']) for b in bones]
for vi in range(n):
    for k in range(K):
        wt = float(w[vi, k])
        if wt > 0.001:
            vgs[top[vi, k]].add([vi], wt, 'REPLACE')

mod = mesh.modifiers.new('Armature', 'ARMATURE')
mod.object = arm_obj
mesh.parent = arm_obj
mesh.parent_type = 'ARMATURE'
n_w = sum(1 for v in mesh.data.vertices if len(v.groups) > 0)
print('weighted verts:', n_w, '/', n)

# --- export skinned glb ---
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB',
                          export_skins=True, export_yup=True,
                          export_tangents=True)
print('DONE: exported', OUT_GLB)
