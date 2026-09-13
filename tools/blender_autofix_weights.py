# Blender 4.x headless: auto-fix bad skin weights on a skinned GLB.
#
# Detector: an edge stretched >2x under animation means its two endpoints
# are being torn apart by different bones — at least one is misassigned.
# Fix: reassign the minority-side vertex to the bone its good-edge
# neighbors predominantly follow, soft-blended by neighbor fractions.
#
# usage:
#   blender -b -P blender_autofix_weights.py -- <in.glb> <pose.json> <skel.json> <out.glb>
import bpy
import json
import sys
import numpy as np
import collections
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT_GLB = argv[:4]

pose = json.load(open(POSE_JSON, encoding='utf-8'))
bones = pose['bones']
world = pose['world']
nframes = len(world)

skel = json.load(open(SKEL_JSON, encoding='utf-8'))
bind_g = {b['name']: i for i, b in enumerate(skel['bones'])}
bind_pos = skel['world_pos_frame0']
bind_quat = skel['world_quat_frame0']

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_inv = C.inverted()

def quat_to_mat(q):
    return Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()

name_to_pb = {pb.name: pb for pb in arm.pose.bones}
bone_by_name = {b.name: b for b in arm.data.bones}

def apply_frame(fi):
    frame = world[fi]
    wp, wq = frame['pos'], frame['quat']
    desired = {}
    for i, b in enumerate(bones):
        m_g = Matrix.Translation(Vector(wp[i])) @ quat_to_mat(wq[i])
        j = bind_g.get(b['name'])
        if j is not None:
            b_g = Matrix.Translation(Vector(bind_pos[j])) @ quat_to_mat(bind_quat[j])
            desired[b['name']] = C @ (m_g @ b_g.inverted()) @ C_inv @ bone_by_name[b['name']].matrix_local
        else:
            desired[b['name']] = C @ m_g @ C_inv
    for i, b in enumerate(bones):
        pb = name_to_pb.get(b['name'])
        if pb is None:
            continue
        rest = bone_by_name[b['name']].matrix_local
        d = desired[b['name']]
        if b['parent'] < 0 or bones[b['parent']]['name'] not in name_to_pb:
            pb.matrix_basis = rest.inverted() @ d
        else:
            pname = bones[b['parent']]['name']
            prest = bone_by_name[pname].matrix_local
            pb.matrix_basis = (prest.inverted() @ rest).inverted() @ desired[pname].inverted() @ d
    bpy.context.view_layer.update()

n = len(mesh.data.vertices)
co = np.empty(n * 3)
mesh.data.vertices.foreach_get('co', co)
REST = co.reshape(n, 3).copy()

# edges from faces (dedup)
eset = set()
for poly in mesh.data.polygons:
    vs = poly.vertices
    for k in range(len(vs)):
        a, b2 = vs[k], vs[(k + 1) % len(vs)]
        eset.add((min(a, b2), max(a, b2)))
E = np.array(sorted(eset))
rest_len_raw = np.linalg.norm(REST[E[:, 0]] - REST[E[:, 1]], axis=1)
# ignore degenerate (near-zero rest length) edges — they produce fake
# stretch ratios; only look at edges at least 1/4 of median length
med_len = np.median(rest_len_raw[rest_len_raw > 0])
valid_edge = rest_len_raw > med_len * 0.25
rest_len = np.maximum(rest_len_raw, 1e-4)

# adjacency
adj = [[] for _ in range(n)]
for a, b2 in eset:
    adj[a].append(b2); adj[b2].append(a)
adj = [np.array(a, dtype=np.int64) for a in adj]

# current dominant bone (owner) per vertex + weight dict
vg_names = [g.name for g in mesh.vertex_groups]
vg_idx = {g.index: g.name for g in mesh.vertex_groups}
owner = np.zeros(n, dtype=np.int64)
maxw = np.zeros(n)
for v in mesh.data.vertices:
    for e in v.groups:
        if e.weight > maxw[v.index]:
            maxw[v.index] = e.weight
            owner[v.index] = e.group
name_of = {i: vg_idx.get(i, '?') for i in range(len(vg_names) + 2)}

# sample posed positions
dg = bpy.context.evaluated_depsgraph_get()
max_stretch = np.zeros(len(E))
frames = list(range(0, nframes, max(1, nframes // 6)))
for fi in frames:
    apply_frame(fi)
    dg.update()
    oe = mesh.evaluated_get(dg)
    me = oe.to_mesh()
    pc = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', pc)
    oe.to_mesh_clear()
    P = pc.reshape(-1, 3)
    sl = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1) / rest_len
    max_stretch = np.maximum(max_stretch, sl)

BAD = (max_stretch > 2.0) & valid_edge
print('edges:', len(E), 'bad:', int(BAD.sum()), 'worst: %.1fx' % max_stretch.max())

# fix pass: for verts on bad edges, owner = majority among neighbors on good edges
fixed = 0
bad_vert = np.zeros(n, dtype=bool)
bad_vert[E[BAD].ravel()] = True
for vi in np.where(bad_vert)[0]:
    v = mesh.data.vertices[int(vi)]
    nb = adj[int(vi)]
    if nb.size == 0:
        continue
    cnt = collections.Counter(owner[u] for u in nb if u != int(vi))
    if not cnt:
        continue
    cand, votes = cnt.most_common(1)[0]
    if cand != owner[vi] and votes >= max(2, len(nb) // 3):
        # neighbor fraction -> weights among top-2 candidate groups
        frac = {g: c / len(nb) for g, c in cnt.items()}
        for e in list(v.groups):
            mesh.vertex_groups[e.group].remove([v.index])
        for g, f in sorted(frac.items(), key=lambda x: -x[1])[:4]:
            mesh.vertex_groups[g].add([v.index], max(f, 0.15), 'REPLACE')
        tot = sum(e.weight for e in v.groups)
        for e in v.groups:
            mesh.vertex_groups[e.group].add([v.index], e.weight / tot, 'REPLACE')
        owner[vi] = cand
        fixed += 1
print('fixed verts:', fixed)

bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB',
                          export_skins=True, export_yup=True,
                          export_tangents=True)
print('DONE', OUT_GLB)
