# Blender 4.x headless: re-rig a skinned GLB to the WH3 bird01b skeleton,
# filtering out feather bones so the mesh binds only to structural bones.
#
# Usage: blender -b -P blender_rig_filtered.py -- <skel.json> <in.glb> <out.glb>
import bpy
import json
import sys
import re
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
SKEL_JSON, IN_GLB, OUT_GLB = argv[0], argv[1], argv[2]

data = json.load(open(SKEL_JSON, encoding='utf-8'))
bones = data['bones']
wpos = data['world_pos_frame0']

# --- bones to EXCLUDE from binding (feather bones, detailed toes) ---
EXCLUDE_RE = re.compile(
    r'^(feather_|toe_back_|toe_inner_|toe_middle_|toe_outer_|eyelid_)'
)
# Keep: animroot, root, spine_*, neck_*, head_0, jaw_0, tail_*, 
#       wing_shoulder_*, wing_left_*, wing_right_*, leg_*, foot_*, collar_0
include_idx = [i for i, b in enumerate(bones) if not EXCLUDE_RE.match(b['name'])]
print(f'Bone filter: {len(bones)} total -> {len(include_idx)} included (excluded {len(bones)-len(include_idx)} feather/toe/eyelid bones)')
print('Excluded:', [bones[i]['name'] for i in range(len(bones)) if i not in set(include_idx)][:10], '...')

# --- reset scene ---
bpy.ops.wm.read_factory_settings(use_empty=True)

# --- import skinned GLB FIRST ---
bpy.ops.import_scene.gltf(filepath=IN_GLB)

# Find imported mesh and armature objects
imported_meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
imported_arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']

# Unparent meshes from imported armatures before removing them
for m in imported_meshes:
    if m.parent and m.parent.type == 'ARMATURE':
        m.parent = None
    # Remove armature modifiers pointing to imported arms
    for mod in list(m.modifiers):
        if mod.type == 'ARMATURE':
            m.modifiers.remove(mod)

# Remove imported armatures (we'll build our own)
for arm in imported_arms:
    bpy.data.objects.remove(arm, do_unlink=True)

# Deselect all, then select meshes
bpy.ops.object.select_all(action='DESELECT')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not meshes:
    raise RuntimeError('No mesh found after import')

for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active

# Clear all existing vertex groups
mesh.vertex_groups.clear()

bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- NOW build armature (only included bones) ---
def to_blender(v):
    return Vector((v[0], -v[2], v[1]))

arm_data = bpy.data.armatures.new('czx_armature')
arm_obj = bpy.data.objects.new('czx_armature', arm_data)
bpy.context.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
arm_obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')

ebs = []
for i in range(len(bones)):
    if i not in set(include_idx):
        ebs.append(None)
        continue
    b = bones[i]
    eb = arm_data.edit_bones.new(b['name'])
    head = to_blender(wpos[i])
    # tail: point to first included child head
    tail = None
    for j in include_idx:
        if bones[j]['parent'] == i:
            tail = to_blender(wpos[j])
            break
    if tail is None or (tail - head).length < 0.01:
        tail = head + Vector((0, 0, 0.03))
    eb.head = head
    eb.tail = tail
    ebs.append(eb)

for i in include_idx:
    b = bones[i]
    # find parent in included set
    par = b['parent']
    while par >= 0 and par not in set(include_idx):
        par = bones[par]['parent']
    if par >= 0 and ebs[par] is not None:
        ebs[i].parent = ebs[par]

bpy.ops.object.mode_set(mode='OBJECT')

# --- fit mesh to skeleton (only included bones) ---
sk_pts = [to_blender(wpos[i]) for i in include_idx]
sk_min = Vector((min(p.x for p in sk_pts), min(p.y for p in sk_pts), min(p.z for p in sk_pts)))
sk_max = Vector((max(p.x for p in sk_pts), max(p.y for p in sk_pts), max(p.z for p in sk_pts)))
sk_size = sk_max - sk_min
sk_ctr = (sk_min + sk_max) / 2

bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
m_size = m_max - m_min

# Scale to fit the largest skeleton dimension
axis_idx = max(range(3), key=lambda i: sk_size[i])
scale = sk_size[axis_idx] / m_size[axis_idx] if m_size[axis_idx] > 0 else 1.0
mesh.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Align centers + ground level
bb = [Vector(c) for c in mesh.bound_box]
m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
m_ctr = (m_min + m_max) / 2
mesh.location = Vector((sk_ctr.x - m_ctr.x, sk_ctr.y - m_ctr.y, sk_min.z - m_min.z))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- bind: nearest-bone-segment weights (ONLY included bones) ---
import numpy as np

# Build bone segments for included bones only
inc_set = set(include_idx)
segs_h = []
segs_t = []
seg_names = []
for i in include_idx:
    h = to_blender(wpos[i])
    par = bones[i]['parent']
    # find tail: first included child
    tail = None
    for j in include_idx:
        if bones[j]['parent'] == i:
            tail = to_blender(wpos[j])
            break
    if tail is None or (tail - h).length < 0.01:
        tail = h + Vector((0, 0, 0.03))
    segs_h.append(h)
    segs_t.append(tail)
    seg_names.append(bones[i]['name'])

H = np.array([s[:] for s in segs_h])  # (B,3)
T = np.array([s[:] for s in segs_t])  # (B,3)
D = T - H
dd = np.maximum((D * D).sum(1), 1e-12)

n = len(mesh.data.vertices)
co = np.empty(n * 3)
mesh.data.vertices.foreach_get('co', co)
V = co.reshape(n, 3)

# Distance from each vertex to each included bone segment
ap = V[:, None, :] - H[None, :, :]
tpar = np.clip((ap * D[None, :, :]).sum(2) / dd[None, :], 0.0, 1.0)
closest = H[None, :, :] + tpar[:, :, None] * D[None, :, :]
dist = np.sqrt(((V[:, None, :] - closest) ** 2).sum(2))

K = 4
top = np.argpartition(dist, K, axis=1)[:, :K]
topd = np.take_along_axis(dist, top, 1)
w = 1.0 / np.maximum(topd, 0.005) ** 2
w /= w.sum(1, keepdims=True)

# Create vertex groups for included bones only
vgs = [mesh.vertex_groups.new(name=name) for name in seg_names]
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
print(f'Weighted verts: {n_w}/{n}')

# --- export skinned glb ---
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB',
                          export_skins=True, export_yup=True,
                          export_tangents=True)
print(f'DONE: exported {OUT_GLB}')
