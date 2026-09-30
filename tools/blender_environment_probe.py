"""Render one bound model pose in a deterministic terrain probe scene."""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, POSE_JSON, SKEL_JSON, OUT_DIR, TERRAIN = argv[:5]
OUT_DIR = os.path.abspath(OUT_DIR)
pose = json.load(open(POSE_JSON, encoding="utf-8"))
skel = json.load(open(SKEL_JSON, encoding="utf-8"))
bones = pose["bones"]
bind_g = {bone["name"]: i for i, bone in enumerate(skel["bones"])}
bind_pos = skel["world_pos_frame0"]
bind_quat = skel["world_quat_frame0"]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
bone_by_name = {bone.name: bone for bone in arm.data.bones}
pose_by_name = {bone.name: bone for bone in arm.pose.bones}

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_inv = C.inverted()


def quat_matrix(q):
    return Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()


def apply_frame(frame_index):
    frame = pose["world"][frame_index]
    desired = {}
    for index, bone in enumerate(bones):
        model = Matrix.Translation(Vector(frame["pos"][index])) @ quat_matrix(frame["quat"][index])
        bind_index = bind_g.get(bone["name"])
        if bind_index is not None:
            bind = Matrix.Translation(Vector(bind_pos[bind_index])) @ quat_matrix(bind_quat[bind_index])
            delta = C @ (model @ bind.inverted()) @ C_inv
            desired[bone["name"]] = delta @ bone_by_name[bone["name"]].matrix_local
        else:
            desired[bone["name"]] = C @ model @ C_inv
    for bone in bones:
        pb = pose_by_name.get(bone["name"])
        if pb is None:
            continue
        rest = bone_by_name[bone["name"]].matrix_local
        target = desired[bone["name"]]
        if bone["parent"] < 0:
            pb.matrix_basis = rest.inverted() @ target
        else:
            parent = bones[bone["parent"]]["name"]
            parent_rest = bone_by_name[parent].matrix_local
            pb.matrix_basis = (parent_rest.inverted() @ rest).inverted() @ desired[parent].inverted() @ target
    bpy.context.view_layer.update()


def bounds():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = Vector((1e9, 1e9, 1e9))
    high = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        for corner in evaluated.bound_box:
            point = evaluated.matrix_world @ Vector(corner)
            low = Vector(map(min, low, point))
            high = Vector(map(max, high, point))
    return low, high


def add_mesh(name, vertices, faces, material):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    return obj


def make_material(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    return material


apply_frame(0)
low, high = bounds()
center = (low + high) / 2
size = max((high - low).length, 0.5)
ground = make_material("probe_ground", (0.26, 0.29, 0.33))
terrain_angle = math.radians(12 if TERRAIN == "slope_up_12deg" else 0)
span = size * 4
base = low.z - 0.02 - math.tan(terrain_angle) * low.x
floor_vertices = [
    (-span, -span, base - math.tan(terrain_angle) * span),
    (span, -span, base + math.tan(terrain_angle) * span),
    (span, span, base + math.tan(terrain_angle) * span),
    (-span, span, base - math.tan(terrain_angle) * span),
]
add_mesh("probe_floor", floor_vertices, [(0, 1, 2, 3)], ground)

obstacle = None
if TERRAIN == "obstacle_025h":
    obstacle_mat = make_material("probe_obstacle", (0.42, 0.25, 0.12))
    bpy.ops.mesh.primitive_cube_add(size=1)
    obstacle = bpy.context.object
    obstacle.name = "probe_obstacle_025h"
    obstacle.dimensions = (0.45, 0.45, 0.25)
    obstacle.location = (center.x, center.y + size * 0.18, base + 0.125)
    obstacle.data.materials.append(obstacle_mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

camera_data = bpy.data.cameras.new("probe_camera")
camera = bpy.data.objects.new("probe_camera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (center.x + size * 0.9, center.y - size * 0.9, center.z + size * 0.45)
camera.rotation_euler = (Vector(center) - camera.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.scene.camera = camera
for rotation, energy in [((0.6, 0.2, 0.8), 4.0), ((-0.7, -0.5, -2.0), 2.5)]:
    light_data = bpy.data.lights.new("probe_sun", "SUN")
    light = bpy.data.objects.new("probe_sun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = rotation
    light_data.energy = energy

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = 0.8
scene.world = bpy.data.worlds.new("probe_world")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.34, 0.38, 1)
os.makedirs(OUT_DIR, exist_ok=True)
scene.render.filepath = os.path.join(OUT_DIR, "frame000.png")
bpy.ops.render.render(write_still=True)

low, high = bounds()
result = {
    "terrain": TERRAIN,
    "frame": 0,
    "mesh_bounds_blender": {"low": list(low), "high": list(high)},
    "ground": {"angle_deg": round(math.degrees(terrain_angle), 3), "base_at_x0": base},
    "obstacle": {"height": 0.25, "present": obstacle is not None},
    "render": os.path.join(OUT_DIR, "frame000.png"),
}
with open(os.path.join(OUT_DIR, "probe.json"), "w", encoding="utf-8") as handle:
    json.dump(result, handle, indent=2)
print("ENVIRONMENT_PROBE", TERRAIN, result["render"])
