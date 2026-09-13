# Blender 4.x headless: ground-truth render of a vanilla donor RMV2.
# Builds armature from skel json, imports static donor GLB, applies TRUE
# CA weights from NPZ, poses with parsed clip, renders frames.
#
# usage:
#   blender -b -P blender_donor_render.py -- <donor.glb> <weights.npz> <pose.json> <skel.json> <out_dir> <step>
import bpy
import json
import sys
import os
import numpy as np
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, NPZ, POSE_JSON, SKEL_JSON, OUT_DIR, STEP = \
    argv[0], argv[1], argv[2], argv[3], argv[4], int(argv[5])

skel = json.load(open(SKEL_JSON, encoding='utf-8'))
bones = skel['bones']
wpos = skel['world_pos_frame0']
wquat = skel['world_quat_frame0']
wgt = np.load(NPZ)

pose = json.load(open(POSE_JSON, encoding='utf-8'))
clip_bones = pose['bones']
nframes = len(pose['world'])
bind_g = {b['name']: i for i, b in enumerate(bones)}

bpy.ops.wm.read_factory_settings(use_empty=True)


def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


# armature
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

# mesh
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# vertex groups from donor weights (wh3 bone idx -> group name)
vgs = [mesh.vertex_groups.new(name=b['name']) for b in bones]
bone_idx = wgt['bone_idx']
weights = wgt['weights']
n = len(mesh.data.vertices)
print('mesh verts', n, 'weights verts', len(bone_idx))
for i in range(min(n, len(bone_idx))):
    for c in range(4):
        w = float(weights[i, c])
        bi = int(bone_idx[i, c])
        if w > 0.001 and bi < len(vgs):
            vgs[bi].add([i], w, 'REPLACE')
mod = mesh.modifiers.new('arm', 'ARMATURE')
mod.object = arm_obj
mesh.parent = arm_obj

# ---- posing (same math as blender_pose_anim) ----
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_inv = C.inverted()


def quat_to_mat(q):
    return Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()


name_to_pb = {pb.name: pb for pb in arm_obj.pose.bones}
bone_by_name = {b.name: b for b in arm_obj.data.bones}


def apply_frame(fi):
    frame = pose['world'][fi]
    wp, wq = frame['pos'], frame['quat']
    desired = {}
    for i, b in enumerate(clip_bones):
        m_g = Matrix.Translation(Vector(wp[i])) @ quat_to_mat(wq[i])
        j = bind_g.get(b['name'])
        if j is not None:
            b_g = Matrix.Translation(Vector(wpos[j])) @ quat_to_mat(wquat[j])
            delta_b = C @ (m_g @ b_g.inverted()) @ C_inv
            desired[b['name']] = delta_b @ bone_by_name[b['name']].matrix_local
        else:
            desired[b['name']] = C @ m_g @ C_inv
    for i, b in enumerate(clip_bones):
        pb = name_to_pb.get(b['name'])
        if pb is None:
            continue
        rest = bone_by_name[b['name']].matrix_local
        d = desired[b['name']]
        if b['parent'] < 0 or clip_bones[b['parent']]['name'] not in name_to_pb:
            pb.matrix_basis = rest.inverted() @ d
        else:
            pname = clip_bones[b['parent']]['name']
            prest = bone_by_name[pname].matrix_local
            ppose = desired[pname]
            pb.matrix_basis = (prest.inverted() @ rest).inverted() @ \
                ppose.inverted() @ d
    bpy.context.view_layer.update()


def mesh_bounds_world():
    dg = bpy.context.evaluated_depsgraph_get()
    oe = mesh.evaluated_get(dg)
    mw = oe.matrix_world
    pts = [mw @ Vector(c) for c in oe.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


bmin, bmax = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for fi in range(0, nframes, max(1, nframes // 8)):
    apply_frame(fi)
    mn, mx = mesh_bounds_world()
    bmin = Vector(map(min, bmin, mn))
    bmax = Vector(map(max, bmax, mx))
ctr = (bmin + bmax) / 2
size = max((bmax - bmin).length, 0.5)

gp = bpy.data.meshes.new('g')
s = size * 4
gp.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [],
               [(0, 1, 2, 3)])
gob = bpy.data.objects.new('g', gp)
bpy.context.collection.objects.link(gob)
gob.location.z = bmin.z - 0.01
gm = bpy.data.materials.new('gm')
gm.use_nodes = True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.4, 0.4, 0.45, 1)
gp.materials.append(gm)

scene = bpy.context.scene
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
camob.location = (ctr.x + size * 0.9, ctr.y - size * 0.9, ctr.z + size * 0.45)
d = Vector(ctr) - camob.location
camob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob

for i, (rot, en) in enumerate([((0.6, 0.2, 0.8), 4.0), ((-0.7, -0.5, -2.0), 2.5),
                                ((1.2, 0.0, -0.5), 1.5)]):
    li = bpy.data.lights.new('l%d' % i, 'SUN')
    lo = bpy.data.objects.new('l%d' % i, li)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot
    li.energy = en

scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.8
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.35, 0.35, 0.4, 1)

os.makedirs(OUT_DIR, exist_ok=True)
for fi in range(0, nframes, STEP):
    apply_frame(fi)
    scene.render.filepath = os.path.join(OUT_DIR, 'f%03d.png' % fi)
    bpy.ops.render.render(write_still=True)
print('rendered', len(range(0, nframes, STEP)), 'frames to', OUT_DIR)
