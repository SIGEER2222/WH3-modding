# Blender 4.x headless: import a skinned GLB, apply a parsed WH3 clip
# frame-by-frame and render every Nth frame for GIF assembly.
#
# v2: tight mesh-bounds camera (was joint-bounds -> model too small),
#     brighter backdrop + exposure lift for dark Zerg palettes.
#
# usage:
#   blender -b -P blender_pose_anim.py -- <skinned.glb> <pose.json> <skel.json> <out_dir> <step>
import bpy
import json
import sys
import os
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT_DIR, STEP = argv[0], argv[1], argv[2], argv[3], int(argv[4])

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

def mesh_bounds_world():
    dg = bpy.context.evaluated_depsgraph_get()
    xs, ys, zs = [], [], []
    for o in meshes:
        oe = o.evaluated_get(dg)
        mw = oe.matrix_world
        for c in oe.bound_box:  # local bbox corners, cheap
            p = mw @ Vector(c)
            xs.append(p.x); ys.append(p.y); zs.append(p.z)
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))

# bounds over sampled frames so the camera covers the whole action
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
gm.diffuse_color = (0.5, 0.5, 0.55, 1)
gm.use_nodes = True
gmn = gm.node_tree.nodes['Principled BSDF']
gmn.inputs['Base Color'].default_value = (0.4, 0.4, 0.45, 1)
gmn.inputs['Roughness'].default_value = 0.9
gp.materials.append(gm)

scene = bpy.context.scene
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
# 3/4 view, tight: distance ~1.1x diagonal keeps model ~70% of frame
camob.location = (ctr.x + size * 0.9, ctr.y - size * 0.9, ctr.z + size * 0.45)
d = Vector(ctr) - camob.location
camob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob

light = bpy.data.lights.new('l', 'SUN')
lob = bpy.data.objects.new('l', light)
bpy.context.collection.objects.link(lob)
lob.rotation_euler = (0.6, 0.2, 0.8)
light.energy = 4.0
light2 = bpy.data.lights.new('l2', 'SUN')
lob2 = bpy.data.objects.new('l2', light2)
bpy.context.collection.objects.link(lob2)
lob2.rotation_euler = (-0.7, -0.5, -2.0)
light2.energy = 2.5
light3 = bpy.data.lights.new('l3', 'SUN')
lob3 = bpy.data.objects.new('l3', light3)
bpy.context.collection.objects.link(lob3)
lob3.rotation_euler = (1.2, 0.0, -0.5)
light3.energy = 1.5

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
print('rendered %d frames to %s' % (len(range(0, nframes, STEP)), OUT_DIR))
