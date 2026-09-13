# Blender 4.x headless: import a skinned GLB, apply a parsed WH3 clip frame
# (world TRS per bone, game Y-up coords) and render a still for validation.
#
# usage:
#   blender -b -P blender_pose_render.py -- <skinned.glb> <pose.json> <frame_idx> <out.png>
import bpy
import json
import sys
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, FRAME_IDX, OUT = argv[0], argv[1], int(argv[2]), argv[3]
SKEL_JSON = argv[4] if len(argv) > 4 else None

pose = json.load(open(POSE_JSON, encoding='utf-8'))
bones = pose['bones']
frame = pose['world'][FRAME_IDX]
wp, wq = frame['pos'], frame['quat']

skel = json.load(open(SKEL_JSON, encoding='utf-8')) if SKEL_JSON else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

# game(Y-up) -> blender(Z-up): (x,y,z) -> (x,-z,y); build change-of-basis 4x4
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_inv = C.inverted()

def quat_to_mat(q):
    # game quat (x,y,z,w) -> 4x4 rotation
    return Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()

# desired armature-space matrix per bone (in json bone order: parents first)
# NOTE: the GLB armature's bone rest orientation (roll) is NOT the skeleton's
# frame0 orientation, so we cannot pose pb.matrix = anim world directly.
# Correct target: apply the animation's world-space delta (A @ B^-1) on top of
# the Blender bone rest frame:  desired = C@(A@B^-1)@C_inv @ bone.matrix_local
bind_g = {}
if skel is not None:
    bind_g = {b['name']: i for i, b in enumerate(skel['bones'])}
    bind_pos = skel['world_pos_frame0']
    bind_quat = skel['world_quat_frame0']

desired = {}
name_to_pb = {pb.name: pb for pb in arm.pose.bones}
bone_by_name = {b.name: b for b in arm.data.bones}
for i, b in enumerate(bones):
    m_g = Matrix.Translation(Vector(wp[i])) @ quat_to_mat(wq[i])
    anim_b = C @ m_g @ C_inv
    j = bind_g.get(b['name'])
    if j is not None:
        b_g = Matrix.Translation(Vector(bind_pos[j])) @ quat_to_mat(bind_quat[j])
        delta_b = C @ (m_g @ b_g.inverted()) @ C_inv
        desired[b['name']] = delta_b @ bone_by_name[b['name']].matrix_local
    else:
        desired[b['name']] = anim_b

# set matrix_basis so that armature-space pose == desired, parents first
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

# frame camera on posed skeleton joints
pts = [Vector((p[0], -p[2], p[1])) for p in wp]
mn = Vector((min(v.x for v in pts), min(v.y for v in pts), min(v.z for v in pts)))
mx = Vector((max(v.x for v in pts), max(v.y for v in pts), max(v.z for v in pts)))
ctr = (mn + mx) / 2
size = max((mx - mn).length, 0.5)

# ground plane at lowest joint
gp = bpy.data.meshes.new('g')
s = size * 4
gp.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [],
               [(0, 1, 2, 3)])
gob = bpy.data.objects.new('g', gp)
bpy.context.collection.objects.link(gob)
gob.location.z = mn.z - 0.01
gm = bpy.data.materials.new('gm')
gm.diffuse_color = (0.15, 0.15, 0.18, 1)
gp.materials.append(gm)

scene = bpy.context.scene
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
camob.location = (ctr.x + size * 1.4, ctr.y - size * 1.4, ctr.z + size * 0.5)
d = Vector(ctr) - camob.location
camob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob

light = bpy.data.lights.new('l', 'SUN')
lob = bpy.data.objects.new('l', light)
bpy.context.collection.objects.link(lob)
lob.rotation_euler = (0.6, 0.2, 0.8)
light.energy = 3.0
light2 = bpy.data.lights.new('l2', 'SUN')
lob2 = bpy.data.objects.new('l2', light2)
bpy.context.collection.objects.link(lob2)
lob2.rotation_euler = (-0.6, -0.4, -2.0)
light2.energy = 1.5

scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.filepath = OUT
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.05, 0.05, 0.08, 1)
bpy.ops.render.render(write_still=True)
print('rendered', OUT)
