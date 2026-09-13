# Blender 4.x headless script: build WH3 armature from parsed .anim JSON,
# import a GLB mesh, fit it to the skeleton, TOPOLOGY-AWARE weight bind,
# export skinned GLB.
#
# v2 vs blender_rig.py: nearest-segment distance alone tears thin shells and
# lets limbs grab unrelated mesh. This version:
#   1) nearest-bone-segment gives an initial per-vertex bone OWNER
#   2) majority-vote label smoothing over mesh adjacency (4 rounds) removes
#      stray cross-body assignments — regions follow surface topology
#   3) the one-hot owner vectors are diffused over adjacency (3 rounds),
#      producing smooth joint gradients only near region boundaries
#   4) cap to top-4 influences + normalize (RMV2 weighted4)
# (Blender ARMATURE_AUTO was tried and fails outright on these non-manifold
# game meshes: "Bone Heat Weighting: failed to find solution".)
#
# Usage:
#   blender -b -P blender_rig2.py -- <skel.json> <in.glb> <out.glb> <fit_axis> [exclude_regex] [save.blend] [yaw_deg] [rules_json]
# save.blend (optional): also save the armature+mesh+weights as a .blend for
# manual weight-painting; paint, then re-export glTF (skinned) to re-convert.
# yaw_deg (optional): rotate mesh this many degrees about Z BEFORE fitting —
# use when the source model faces a different direction than the skeleton
# (misaligned facing = limbs bind to opposite-side bones = mesh folds on anim).
import bpy
import json
import sys
import re
import math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
SKEL_JSON, IN_GLB, OUT_GLB = argv[0], argv[1], argv[2]
FIT_AXIS = argv[3] if len(argv) > 3 else 'auto'
EXCLUDE_RE = re.compile(argv[4]) if len(argv) > 4 and argv[4] else None
SAVE_BLEND = argv[5] if len(argv) > 5 else None
YAW_DEG = float(argv[6]) if len(argv) > 6 else 0.0

data = json.load(open(SKEL_JSON, encoding='utf-8'))
bones = data['bones']
wpos = data['world_pos_frame0']

bpy.ops.wm.read_factory_settings(use_empty=True)

def to_blender(v):
    return Vector((v[0], -v[2], v[1]))

# --- build armature (all bones) ---
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
    tail = None
    for j, c in enumerate(bones):
        if c['parent'] == i:
            tail = to_blender(wpos[j]); break
    if tail is None or (tail - head).length < 0.01:
        tail = head + Vector((0, 0, 0.03))
    eb.head = head; eb.tail = tail
    ebs.append(eb)
for i, b in enumerate(bones):
    if b['parent'] >= 0:
        ebs[i].parent = ebs[b['parent']]
bpy.ops.object.mode_set(mode='OBJECT')

# --- import + join + fit mesh ---
bpy.ops.import_scene.gltf(filepath=IN_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# if the input was already skinned, strip old skinning so it doesn't fight
# the new bind: delete imported armature objects, drop armature modifiers,
# clear all vertex groups (re-created per-bone below; stale same-named
# groups would be silently suffixed .001 and lose the weights)
for o in [o for o in bpy.context.scene.objects
          if o.type == 'ARMATURE' and o is not arm_obj]:
    bpy.data.objects.remove(o, do_unlink=True)
mesh.vertex_groups.clear()
for m in list(mesh.modifiers):
    if m.type == 'ARMATURE':
        mesh.modifiers.remove(m)

if YAW_DEG:
    # rotate vertex data directly — ops transform_apply can silently no-op
    # on multi-user/unselected data in background mode
    mesh.data.transform(Matrix.Rotation(math.radians(YAW_DEG), 4, 'Z'))
    print('yaw applied:', YAW_DEG,
          'bounds:', tuple(round(v, 2) for v in mesh.bound_box[0]),
          tuple(round(v, 2) for v in mesh.bound_box[6]))

sk_pts = [to_blender(p) for p in wpos]
sk_min = Vector((min(p.x for p in sk_pts), min(p.y for p in sk_pts), min(p.z for p in sk_pts)))
sk_max = Vector((max(p.x for p in sk_pts), max(p.y for p in sk_pts), max(p.z for p in sk_pts)))
sk_size = sk_max - sk_min

bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
m_size = m_max - m_min
if FIT_AXIS != 'nofit':
    axis_idx = {'x': 0, 'y': 1, 'z': 2}[FIT_AXIS] if FIT_AXIS != 'auto' else \
        max(range(3), key=lambda i: sk_size[i])
    scale = sk_size[axis_idx] / m_size[axis_idx]
    mesh.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bb = [Vector(c) for c in mesh.bound_box]
    m_min = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    m_max = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    m_ctr = (m_min + m_max) / 2
    sk_ctr = (sk_min + sk_max) / 2
    mesh.location = Vector((sk_ctr.x - m_ctr.x, sk_ctr.y - m_ctr.y, sk_min.z - m_min.z))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
print('MESH bounds after fit:', tuple(round(v, 2) for v in m_min),
      tuple(round(v, 2) for v in m_max))

# --- weightable bones ---
EXCLUDE = re.compile(
    r'prop|cape|skirt|belt|sleeve|cloth|loincloth|flag|tabard|fx|icon|camera'
    r'|weapon|shield|quiver|scabbard|plume|tassel|feather|wing|hair|beard'
    r'|finger|thumb|attach|slot|mount|platform|antenna|eyestalk|banner|be_',
    re.I)
allowed_idx = [i for i, b in enumerate(bones)
               if not EXCLUDE.search(b['name'])
               and not (EXCLUDE_RE and EXCLUDE_RE.search(b['name']))]
print('weightable bones:', len(allowed_idx), '/', len(bones))

# --- bone segments ---
segs = []
for i, b in enumerate(bones):
    h = to_blender(wpos[i])
    t = None
    for j, c in enumerate(bones):
        if c['parent'] == i:
            t = to_blender(wpos[j]); break
    if t is None or (t - h).length < 0.01:
        t = h + Vector((0, 0, 0.03))
    segs.append((h, t))
H = np.array([s[0] for s in segs])
T = np.array([s[1] for s in segs])
D = T - H
dd = np.maximum((D * D).sum(1), 1e-12)

n = len(mesh.data.vertices)
co = np.empty(n * 3)
mesh.data.vertices.foreach_get('co', co)
V = co.reshape(n, 3)

# distance vertex -> bone segment
ap = V[:, None, :] - H[None, :, :]
tpar = np.clip((ap * D[None, :, :]).sum(2) / dd[None, :], 0.0, 1.0)
closest = H[None, :, :] + tpar[:, :, None] * D[None, :, :]
dist = np.sqrt(((V[:, None, :] - closest) ** 2).sum(2))
dist[:, [i for i in range(len(bones)) if i not in allowed_idx]] = np.inf

# --- 1) initial owner = nearest allowed bone segment ---
owner = dist.argmin(1)

# --- 1b) region rules: verts in a spatial region bind only to allow-listed bones ---
# RULES_JSON (argv[7]): JSON string or .json path, e.g.
#   [{"name":"head","when":[{"axis":"z","op":">","pct":70},
#     {"axis":"y","op":">","pct":55}],"allow":"neck|head|gullet"}]
# axes are GAME space: x=lateral, y=up, z=forward. All whens are ANDed.
RULES = []
if len(argv) > 7 and argv[7]:
    spec = argv[7]
    RULES = json.load(open(spec, encoding='utf-8')) if spec.endswith('.json') \
        else json.loads(spec)
if RULES:
    VG = np.stack([V[:, 0], V[:, 2], -V[:, 1]], 1)  # blender -> game coords
    AX = {'x': 0, 'y': 1, 'z': 2}
    for rule in RULES:
        mask = np.ones(n, dtype=bool)
        for c in rule['when']:
            col = VG[:, AX[c['axis']]]
            thr = np.percentile(col, c['pct'])
            mask &= (col > thr) if c['op'] == '>' else (col < thr)
        are = re.compile(rule['allow'], re.I)
        rallow = [i for i in allowed_idx if are.search(bones[i]['name'])]
        if not rallow or not mask.any():
            print('rule', rule.get('name'), 'empty (bones=%d verts=%d) - skipped'
                  % (len(rallow), int(mask.sum())))
            continue
        pick = np.array(rallow)[dist[np.ix_(np.nonzero(mask)[0], rallow)].argmin(1)]
        owner[mask] = pick
        print('rule', rule.get('name', '?'), ':', int(mask.sum()),
              'verts ->', len(rallow), 'bones')

# --- adjacency from faces ---
import collections
adj = [[] for _ in range(n)]
for poly in mesh.data.polygons:
    vs = poly.vertices
    for k in range(len(vs)):
        a, b = vs[k], vs[(k + 1) % len(vs)]
        adj[a].append(b); adj[b].append(a)
adj = [np.array(sorted(set(a)), dtype=np.int64) for a in adj]

# --- 2) majority-vote label smoothing ---
B = len(bones)
for rnd in range(4):
    new_owner = owner.copy()
    for v in range(n):
        nb = adj[v]
        if nb.size == 0:
            continue
        cnt = np.bincount(np.concatenate([owner[nb], [owner[v]]]),
                          minlength=B)
        new_owner[v] = cnt.argmax()
    owner = new_owner
print('regions:', len(set(owner.tolist())))

# --- 3) diffuse one-hot owner vectors -> smooth joint gradients ---
W = np.zeros((n, B), dtype=np.float64)
W[np.arange(n), owner] = 1.0
for rnd in range(3):
    Wn = W.copy()
    for v in range(n):
        nb = adj[v]
        if nb.size:
            Wn[v] = 0.5 * W[v] + 0.5 * W[nb].mean(0)
    W = Wn

# --- 4) cap top-4, normalize, write vertex groups ---
K = 4
top = np.argpartition(-W, K - 1, axis=1)[:, :K]
topw = np.take_along_axis(W, top, 1)
topw = np.maximum(topw, 0)
topw /= np.maximum(topw.sum(1, keepdims=True), 1e-12)

vgs = [mesh.vertex_groups.new(name=b['name']) for b in bones]
for vi in range(n):
    for k in range(K):
        wt = float(topw[vi, k])
        if wt > 0.001:
            vgs[top[vi, k]].add([vi], wt, 'REPLACE')

mod = mesh.modifiers.new('Armature', 'ARMATURE')
mod.object = arm_obj
mesh.parent = arm_obj
mesh.parent_type = 'ARMATURE'
n_w = sum(1 for v in mesh.data.vertices if len(v.groups) > 0)
print('weighted verts:', n_w, '/', n)

bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB',
                          export_skins=True, export_yup=True,
                          export_tangents=True)
print('DONE: exported', OUT_GLB)
if SAVE_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=SAVE_BLEND)
    print('SAVED blend:', SAVE_BLEND)
