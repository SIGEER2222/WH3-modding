# Blender 4.x headless: render two passes per frame —
#   solid/  model only
#   bones/  bone octahedra only, transparent background
# Composite externally (PIL) -> bones always drawn on top.
#
# usage:
#   blender -b -P blender_pose_bones.py -- <skinned.glb> <pose.json> <skel.json> <out_dir> <step> [frame_csv]
import bpy
import json
import sys
import os
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT_DIR, STEP = argv[0], argv[1], argv[2], argv[3], int(argv[4])
FRAMES = [int(x) for x in argv[5].split(',')] if len(argv) > 5 else None

pose = json.load(open(POSE_JSON, encoding='utf-8'))
bones = pose['bones']
nframes = len(pose['world'])

skel = json.load(open(SKEL_JSON, encoding='utf-8'))
bind_g = {b['name']: i for i, b in enumerate(skel['bones'])}
bind_pos = skel['world_pos_frame0']
bind_quat = skel['world_quat_frame0']

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

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

# --- octahedron per bone (bone-parent anchors at TAIL -> shift -L on Y) ---
bmat = bpy.data.materials.new('bone')
bmat.use_nodes = True
bbsdf = bmat.node_tree.nodes['Principled BSDF']
bbsdf.inputs['Base Color'].default_value = (1.0, 0.35, 0.05, 1)
bbsdf.inputs['Emission Color'].default_value = (1.0, 0.3, 0.0, 1)
bbsdf.inputs['Emission Strength'].default_value = 2.0
bbsdf.inputs['Roughness'].default_value = 0.6

def make_octa(name, length):
    r = max(length * 0.10, 0.008)
    my = length * 0.22
    vs = [(0, 0, 0), (0, length, 0),
          (r, my, 0), (-r, my, 0), (0, my, r), (0, my, -r)]
    fs = [(0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2),
          (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(vs, [], fs)
    me.materials.append(bmat)
    return me

octa_obs = []
for b in arm.data.bones:
    L = max(b.length, 0.02)
    me = make_octa('oct_' + b.name, L)
    ob = bpy.data.objects.new('oct_' + b.name, me)
    bpy.context.collection.objects.link(ob)
    ob.parent = arm
    ob.parent_type = 'BONE'
    ob.parent_bone = b.name
    # bone-parent space origin = bone tail; octahedron spans head->tail
    ob.matrix_world = arm.matrix_world @ b.matrix_local @ Matrix.Translation((0, -L, 0))
    # wireframe modifier -> renders like Blender's own bone display
    wm = ob.modifiers.new('w', 'WIREFRAME')
    wm.thickness = max(L * 0.02, 0.006)
    wm.use_replace = True
    octa_obs.append(ob)

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
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.9
gp.materials.append(gm)

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
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.8
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.35, 0.35, 0.4, 1)
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

solid_dir = os.path.join(OUT_DIR, 'solid')
bones_dir = os.path.join(OUT_DIR, 'bones')
os.makedirs(solid_dir, exist_ok=True)
os.makedirs(bones_dir, exist_ok=True)

frames = FRAMES if FRAMES else list(range(0, nframes, STEP))
for fi in frames:
    apply_frame(fi)
    # pass 1: model only
    for ob in octa_obs:
        ob.hide_render = True
    scene.render.film_transparent = False
    scene.render.filepath = os.path.join(solid_dir, 'f%03d.png' % fi)
    bpy.ops.render.render(write_still=True)
    # pass 2: bones only, transparent bg
    for ob in octa_obs:
        ob.hide_render = False
    for o in meshes:
        o.hide_render = True
    gob.hide_render = True
    scene.render.film_transparent = True
    scene.render.filepath = os.path.join(bones_dir, 'f%03d.png' % fi)
    bpy.ops.render.render(write_still=True)
    for o in meshes:
        o.hide_render = False
    gob.hide_render = False
print('rendered %d frames x2 to %s' % (len(frames), OUT_DIR))
