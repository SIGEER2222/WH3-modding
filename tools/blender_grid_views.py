# Blender headless: render front + side + top views of a GLB with a
# 0.25m grid, as templates for hand-drawing skeleton landmarks.
#
# usage: blender -b -P blender_grid_views.py -- <glb> <out_prefix>
import bpy
import sys
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, PREFIX = argv[0], argv[1]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

allv = []
for m in meshes:
    for v in m.data.vertices:
        allv.append(m.matrix_world @ v.co)
mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
mx = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
c = (mn + mx) / 2

print('BBOX', tuple(round(v, 3) for v in mn), tuple(round(v, 3) for v in mx))

# flatten materials -> uniform gray viewport color (workbench reads diffuse_color)
gm_mesh = bpy.data.materials.new('meshgray')
gm_mesh.diffuse_color = (0.6, 0.6, 0.65, 1)
for m in meshes:
    m.data.materials.clear()
    m.data.materials.append(gm_mesh)

# grid on ground plane (z=mn.z) every 0.25m + vertical rulers
gm = bpy.data.materials.new('grid')
gm.diffuse_color = (0.05, 0.75, 0.1, 1)

step = 0.25
t = 0.03  # grid line thickness (m)
x0, x1 = np.floor(mn.x / step) * step, np.ceil(mx.x / step) * step
y0, y1 = np.floor(mn.y / step) * step, np.ceil(mx.y / step) * step
z0, z1 = np.floor(mn.z / step) * step, np.ceil(mx.z / step) * step

for x in np.arange(x0, x1 + 0.001, step):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, c.y, mn.z))
    o = bpy.context.object
    o.scale = (t / 2, (y1 - y0) / 2 + step, t / 2)
    o.data.materials.append(gm)
for y in np.arange(y0, y1 + 0.001, step):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(c.x, y, mn.z))
    o = bpy.context.object
    o.scale = ((x1 - x0) / 2 + step, t / 2, t / 2)
    o.data.materials.append(gm)
# vertical rulers at back-left corner
for z in np.arange(z0, z1 + 0.001, step):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x0, y1, z))
    o = bpy.context.object
    o.scale = (t, t, t / 2)
    o.data.materials.append(gm)

cam_data = bpy.data.cameras.new('cam')
cam_data.type = 'ORTHO'
cam = bpy.data.objects.new('cam', cam_data)
bpy.context.collection.objects.link(cam)
bpy.context.scene.camera = cam

sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'MATERIAL'
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.display.shading.background_type = 'WORLD'
w = bpy.data.worlds.new('w')
w.color = (0.12, 0.12, 0.14)
bpy.context.scene.world = w
sc.render.resolution_x = 900
sc.render.resolution_y = 900

diag = (mx - mn).length
# per-view ortho scale: max extent in the view plane
views = {
    'front': (Vector((c.x, mn.y - diag, c.z)), mx.x - mn.x, mx.z - mn.z),
    'side':  (Vector((mx.x + diag, c.y, c.z)), mx.y - mn.y, mx.z - mn.z),
    'top':   (Vector((c.x, c.y, mx.z + diag)), mx.x - mn.x, mx.y - mn.y),
}
for name, (loc, vw, vh) in views.items():
    cam.location = loc
    cam.rotation_euler = (c - loc).to_track_quat('-Z', 'Y').to_euler()
    cam_data.ortho_scale = max(vw, vh) * 1.18
    sc.render.filepath = f'{PREFIX}_{name}.png'
    bpy.ops.render.render(write_still=True)
    print('saved', sc.render.filepath)
