# Blender 4.x headless: import a skinned GLB, bake a parsed WH3 clip onto
# pose bones as real timeline keyframes, save a .blend for manual weight
# painting review.
#
# usage:
#   blender -b -P blender_make_review_blend.py -- <skinned.glb> <pose.json> <skel.json> <out.blend> [step]
import bpy
import json
import sys
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT = argv[0], argv[1], argv[2], argv[3]
STEP = int(argv[4]) if len(argv) > 4 else 1

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

scene = bpy.context.scene
scene.frame_start = 1
out_frames = list(range(0, nframes, STEP))
scene.frame_end = len(out_frames)

action = bpy.data.actions.new('clip')
if arm.animation_data is None:
    arm.animation_data_create()
arm.animation_data.action = action

for out_i, fi in enumerate(out_frames):
    apply_frame(fi)
    fno = out_i + 1
    for pb in arm.pose.bones:
        pb.keyframe_insert('location', frame=fno, group=pb.name)
        pb.keyframe_insert('rotation_quaternion', frame=fno, group=pb.name)
        pb.keyframe_insert('scale', frame=fno, group=pb.name)
    scene.frame_set(fno)

scene.render.fps = 15
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print('SAVED', OUT, len(out_frames), 'frames')
