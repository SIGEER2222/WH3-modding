# Blender 4.x headless: "x-ray" skeleton-mesh fit render —
# translucent ghost model + colored capsule bones inside, single pass.
#
# usage:
#   blender -b -P blender_pose_ghost.py -- <skinned.glb> <pose.json> <skel.json> <out_dir> <frame_csv>
import bpy
import json
import sys
import os
import colorsys
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT_DIR = argv[0], argv[1], argv[2], argv[3]
FRAMES = [int(x) for x in argv[4].split(',')] if len(argv) > 4 else [0]

pose = json.load(open(POSE_JSON, encoding='utf-8'))
bones = pose['bones']
nframes = len(pose['world'])

skel = json.load(open(SKEL_JSON, encoding='utf-8'))
bind_g = {b['name']: i for i, b in enumerate(skel['bones'])}
bind_pos = skel['world_pos_frame0']
bind_quat = skel['world_quat_frame0']

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

if arm is None:
    # static GLB (donor ground truth): build armature from skel json
    def _tb(v):
        return Vector((v[0], -v[2], v[1]))
    sbones = skel['bones']
    swp, swq = skel['world_pos_frame0'], skel['world_quat_frame0']
    arm_data = bpy.data.armatures.new('armature')
    arm = bpy.data.objects.new('armature', arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    ebs = []
    for i, b in enumerate(sbones):
        eb = arm_data.edit_bones.new(b['name'])
        head = _tb(swp[i])
        tail = None
        for j, c in enumerate(sbones):
            if c['parent'] == i:
                tail = _tb(swp[j])
                break
        if tail is None or (tail - head).length < 0.01:
            tail = head + Vector((0, 0.05, 0))
        eb.head, eb.tail = head, tail
        ebs.append(eb)
    for i, b in enumerate(sbones):
        if b['parent'] >= 0:
            ebs[i].parent = ebs[b['parent']]
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.select_set(False)

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_inv = C.inverted()

def quat_to_mat(q):
    return Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()

name_to_pb = {pb.name: pb for pb in arm.pose.bones}
bone_by_name = {b.name: b for b in arm.data.bones}

def apply_frame(fi):
    frame = pose['world'][fi]
    wp, wq = frame['pos'], frame['quat']
    desired = {}
    for i, b in enumerate(bones):
        m_g = Matrix.Translation(Vector(wp[i])) @ quat_to_mat(wq[i])
        j = bind_g.get(b['name'])
        if j is not None:
            b_g = Matrix.Translation(Vector(bind_pos[j])) @ quat_to_mat(bind_quat[j])
            delta_b = C @ (m_g @ b_g.inverted()) @ C_inv
            desired[b['name']] = delta_b @ bone_by_name[b['name']].matrix_local
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
            ppose = desired[pname]
            pb.matrix_basis = (prest.inverted() @ rest).inverted() @ ppose.inverted() @ d
    bpy.context.view_layer.update()
    place_capsules()
for o in meshes:
    for slot in o.material_slots:
        m = slot.material
        if m is None:
            continue
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bsdf.inputs['Alpha'].default_value = 0.28
            bsdf.inputs['Roughness'].default_value = 0.8
        m.surface_render_method = 'BLENDED'

# --- capsule bone per bone, colored by chain group ---
CHAIN_ORDER = ['root', 'animroot', 'pelvis', 'spine', 'neck', 'head',
               'jaw', 'tongue', 'clav', 'upperarm', 'lowerarm', 'hand',
               'upperleg', 'lowerleg', 'foot', 'toe', 'tail', 'leg',
               'barrel', 'chassis', 'wheel', 'hatch', 'wing', 'spike',
               'bell', 'necklace', 'ear', 'eye', 'platform', 'skulls']
def chain_idx(name):
    n = name.lower()
    for i, key in enumerate(CHAIN_ORDER):
        if key in n:
            return i
    return len(CHAIN_ORDER) + (hash(name) % 6)

def chain_color(name):
    i = chain_idx(name)
    h = (i * 0.137) % 1.0
    r, g, b = colorsys.hsv_to_rgb(h, 0.55, 1.0)
    return (r, g, b, 1)

mats = {}
def bone_mat(name):
    c = chain_color(name)
    key = tuple(round(x, 2) for x in c)
    if key not in mats:
        m = bpy.data.materials.new('b')
        m.use_nodes = True
        bsdf = m.node_tree.nodes['Principled BSDF']
        bsdf.inputs['Base Color'].default_value = c
        bsdf.inputs['Emission Color'].default_value = c
        bsdf.inputs['Emission Strength'].default_value = 0.6
        bsdf.inputs['Roughness'].default_value = 0.7
        mats[key] = m
    return mats[key]

# shared capsule mesh: unit cylinder + rounded look via smooth shading
caps = bpy.data.meshes.new('cap')
SEG = 8
vs, fs = [], []
# cylinder body y0..y1 plus rounded caps
rings = [(0.0, 0.35), (0.06, 0.55), (0.5, 0.55), (0.94, 0.35), (1.0, 0.0)]
# simpler: hexagonal shaft with pointed-ish ends
vs = [(0, 0, 0)]
for ry, rr in ((0.10, 0.5), (0.85, 0.5)):
    for k in range(SEG):
        import math
        vs.append((rr * math.cos(2 * math.pi * k / SEG), ry, rr * math.sin(2 * math.pi * k / SEG)))
vs.append((0, 1, 0))
fs = []
for k in range(SEG):
    a, b2 = 1 + k, 1 + (k + 1) % SEG
    fs.append((0, a, b2))
    c, d2 = 1 + SEG + k, 1 + SEG + (k + 1) % SEG
    fs.append((a, c, d2))
    fs.append((a, d2, b2))
    fs.append((c, 1 + 2 * SEG, d2))
caps.from_pydata(vs, [], fs)

cap_obs = {}
for b in arm.data.bones:
    me = caps.copy()
    me.materials.append(bone_mat(b.name))
    ob = bpy.data.objects.new('cap_' + b.name, me)
    bpy.context.collection.objects.link(ob)
    cap_obs[b.name] = ob

def place_capsules():
    """Position each capsule exactly on the POSED bone head->tail (world)."""
    for pb in arm.pose.bones:
        ob = cap_obs.get(pb.name)
        if ob is None:
            continue
        h = arm.matrix_world @ pb.head
        t = arm.matrix_world @ pb.tail
        d = t - h
        L = max(d.length, 0.02)
        rot = Vector((0, 1, 0)).rotation_difference(d.normalized())
        rad = max(L * 0.10, 0.012)
        ob.matrix_world = (Matrix.Translation(h)
                           @ rot.to_matrix().to_4x4()
                           @ Matrix.Diagonal((rad, L, rad, 1)))

def mesh_bounds_world():
    dg = bpy.context.evaluated_depsgraph_get()
    xs, ys, zs = [], [], []
    for o in meshes:
        oe = o.evaluated_get(dg)
        mw = oe.matrix_world
        for c in oe.bound_box:
            p = mw @ Vector(c)
            xs.append(p.x); ys.append(p.y); zs.append(p.z)
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))

bmin, bmax = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
for fi in range(0, nframes, max(1, nframes // 8)):
    apply_frame(fi)
    mn, mx = mesh_bounds_world()
    bmin = Vector(map(min, bmin, mn)); bmax = Vector(map(max, bmax, mx))
ctr = (bmin + bmax) / 2
size = max((bmax - bmin).length, 0.5)

scene = bpy.context.scene
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
camob.location = (ctr.x + size * 0.9, ctr.y - size * 0.9, ctr.z + size * 0.45)
d = Vector(ctr) - camob.location
camob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob

for rot, en in ((0.6, 4.0), (-0.7, 2.5), (1.2, 1.5)):
    l = bpy.data.lights.new('l', 'SUN')
    lo = bpy.data.objects.new('l', l)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = (rot, 0.2, 0.8) if rot == 0.6 else (rot, -0.5, -2.0) if rot < 0 else (rot, 0.0, -0.5)
    l.energy = en

scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.8
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.55, 0.6, 1)

os.makedirs(OUT_DIR, exist_ok=True)
for fi in FRAMES:
    apply_frame(fi)
    scene.render.filepath = os.path.join(OUT_DIR, 'f%03d.png' % fi)
    bpy.ops.render.render(write_still=True)
print('rendered %d frames to %s' % (len(FRAMES), OUT_DIR))
