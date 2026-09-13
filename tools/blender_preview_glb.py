# Blender 4.x headless: import a GLB, frame it, render front+side views to PNG.
# Usage: blender -b -P blender_preview_glb.py -- <in.glb> <out_prefix>
import bpy
import sys
import math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
IN_GLB, OUT_PREFIX = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN_GLB)

meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not meshes:
    print('NO MESH'); sys.exit(1)

# join all
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# bounds
bb = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
ctr = (mn + mx) / 2
size = mx - mn
radius = max(size.x, size.y, size.z)
print('BOUNDS min', tuple(round(v,2) for v in mn), 'max', tuple(round(v,2) for v in mx), 'size', tuple(round(v,2) for v in size))

# camera
cam_data = bpy.data.cameras.new('cam')
cam = bpy.data.objects.new('cam', cam_data)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam
cam_data.clip_end = max(100, radius * 10)

# light
sun = bpy.data.lights.new('sun', 'SUN')
sun.energy = 4
sun_o = bpy.data.objects.new('sun', sun)
bpy.context.collection.objects.link(sun_o)
sun_o.rotation_euler = (math.radians(50), 0, math.radians(30))

# world grey
w = bpy.data.worlds.new('w')
w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.25, 0.25, 0.3, 1)
w.node_tree.nodes['Background'].inputs[1].default_value = 0.6
bpy.context.scene.world = w

sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.display.shading.cavity_type = 'BOTH'
sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x = 640
sc.render.resolution_y = 640
sc.render.film_transparent = False

d = radius * 2.2
views = {
    'front': Vector((ctr.x, ctr.y - d, ctr.z)),
    'side':  Vector((ctr.x + d, ctr.y, ctr.z)),
    'top':   Vector((ctr.x, ctr.y, ctr.z + d)),
}
for name, pos in views.items():
    cam.location = pos
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f'{OUT_PREFIX}_{name}.png'
    bpy.ops.render.render(write_still=True)
    print('wrote', sc.render.filepath)
