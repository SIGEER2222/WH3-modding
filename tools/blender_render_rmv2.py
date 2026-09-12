# Blender headless: decode RMV2 v8 mesh -> build in scene -> render with base colour DDS.
# usage: blender -b -P blender_render_rmv2.py -- <rmv2> <basecolour.dds> <out.png>
import bpy
import struct
import sys
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
RMV2, TEX, OUT = argv[0], argv[1], argv[2]

b = open(RMV2, 'rb').read()
assert b[:4] == b'RMV2'
lod_count = struct.unpack_from('<I', b, 8)[0]
off = 140
lod = struct.unpack_from('<4IfI4B', b, off)
first_mesh = lod[3]
mtype, rflag, msize, voff, vcnt, ioff, icnt = struct.unpack_from('<HH5I', b, first_mesh)

verts = np.frombuffer(b, dtype=np.uint8, count=vcnt * 36, offset=first_mesh + voff).reshape(vcnt, 36)
pos = verts[:, 0:8].copy().view('<e').astype(np.float64)
w = pos[:, 3].copy()
pos[:, :3] *= np.where(w != 0, w, 1)[:, None]
# RMV2 space is Y-up; Blender is Z-up -> map (x,y,z) -> (x,-z,y)
pos[:, [1, 2]] = pos[:, [2, 1]]
pos[:, 1] *= -1
uv = verts[:, 20:24].copy().view('<e').astype(np.float64)
idx = np.frombuffer(b, dtype='<u2', count=icnt, offset=first_mesh + ioff).reshape(-1, 3)

bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new('m')
me.from_pydata(pos[:, :3].tolist(), [], idx.tolist())
me.update()
ob = bpy.data.objects.new('m', me)
bpy.context.collection.objects.link(ob)

# UV layer
uvl = me.uv_layers.new(name='UVMap')
for poly in me.polygons:
    for li in poly.loop_indices:
        vi = me.loops[li].vertex_index
        uvl.data[li].uv = (uv[vi, 0], uv[vi, 1])

# material with texture
mat = bpy.data.materials.new('m')
mat.use_nodes = True
bsdf = mat.node_tree.nodes['Principled BSDF']
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(TEX)
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
me.materials.append(mat)

# camera + light
scene = bpy.context.scene
mn = pos[:, :3].min(0); mx = pos[:, :3].max(0)
ctr = (mn + mx) / 2
size = float(np.max(mx - mn))
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
camob.location = (ctr[0] + size * 1.8, ctr[1] - size * 1.8, ctr[2] + size * 0.6)
d = Vector(ctr) - camob.location
camob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob

light = bpy.data.lights.new('l', 'SUN')
lob = bpy.data.objects.new('l', light)
bpy.context.collection.objects.link(lob)
lob.rotation_euler = (0.6, 0.2, 0.8)
light.energy = 3.0
# fill light
light2 = bpy.data.lights.new('l2', 'SUN')
lob2 = bpy.data.objects.new('l2', light2)
bpy.context.collection.objects.link(lob2)
lob2.rotation_euler = (-0.6, -0.4, -2.0)
light2.energy = 1.5

scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.render.resolution_x = 800
scene.render.resolution_y = 800
scene.render.filepath = OUT
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes['Background']
bg.inputs[0].default_value = (0.05, 0.05, 0.08, 1)
bpy.ops.render.render(write_still=True)
print('rendered', OUT)
