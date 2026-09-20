# Blender 4.x headless: render a skinned GLB in bind pose with the armature
# drawn as solid bone cylinders (EEVEE-visible), colored per chain.
#
# usage: blender -b -P blender_skel_overlay.py -- <skinned.glb> <out.png> [--bonesub regex]
import bpy
import sys
import re
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
GLB, OUT = argv[0], argv[1]
sub = re.compile(argv[argv.index('--bonesub') + 1]) if '--bonesub' in argv else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

# mesh lightly dithered but clearly readable — 0.78 alpha keeps bones
# visible through the body while the silhouette stays legible
mat = bpy.data.materials.new('meshmat')
mat.use_nodes = True
bs = mat.node_tree.nodes['Principled BSDF']
bs.inputs['Base Color'].default_value = (0.6, 0.55, 0.68, 1)
bs.inputs['Roughness'].default_value = 0.8
bs.inputs['Alpha'].default_value = 0.78
mat.surface_render_method = 'DITHERED'
for m in meshes:
    m.data.materials.clear()
    m.data.materials.append(mat)

CHAIN_COLORS = [
    ('head|neck|jaw|snout|face|mouth|mandible', (1.0, 0.1, 0.1, 1)),  # head bright red
    ('leg|foot|ankle|toe|thigh|knee', (0.1, 0.8, 0.15, 1)),   # legs green
    ('arm|hand|clav|thumb|finger|shoulder', (0.15, 0.45, 1.0, 1)),  # arms blue
    ('claw|pincer', (0.75, 0.1, 0.9, 1)),          # claws purple
    ('rear|tail|shell|sac|abdomen', (1.0, 0.55, 0.05, 1)),   # rear/tail orange
    ('spine|pelvis|hip|torso|chest', (1.0, 0.85, 0.1, 1)),   # torso yellow
]

bone_mats = {}


def chain_color(name):
    for pat, col in CHAIN_COLORS:
        if re.search(pat, name):
            return col
    return (0.8, 0.8, 0.8, 1)


# draw each bone as a cylinder head->first-child-head; childless bones
# extend along the parent direction (Blender's tail_local is arbitrary for
# imported glTF bones and draws misleading spikes)
children = {}
for b in arm.data.bones:
    if b.parent:
        children.setdefault(b.parent.name, []).append(b.name)
B = {b.name: b for b in arm.data.bones}


def bone_dir(name):
    b = B[name]
    h = arm.matrix_world @ b.head_local
    if b.parent:
        ph = arm.matrix_world @ b.parent.head_local
        d = h - ph
        if d.length > 0.01:
            return d.normalized()
    return Vector((0, 0, 1))


def stick_end(b):
    h = arm.matrix_world @ b.head_local
    for cn in children.get(b.name, []):
        if not sub or sub.search(cn):
            return arm.matrix_world @ B[cn].head_local
    return h + bone_dir(b.name) * 0.12


nb = 0
for b in arm.data.bones:
    if sub and not sub.search(b.name):
        continue
    h = arm.matrix_world @ b.head_local
    t = stick_end(b)
    d = t - h
    L = d.length
    if L < 0.01:
        continue
    col = chain_color(b.name)
    if col not in bone_mats:
        m = bpy.data.materials.new('bm%d' % len(bone_mats))
        m.use_nodes = True
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = col
        if 'Emission Color' in m.node_tree.nodes['Principled BSDF'].inputs:
            m.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = col
            m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 0.6
        bone_mats[col] = m
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=max(L * 0.045, 0.012), depth=L)
    c = bpy.context.active_object
    c.location = (h + t) / 2
    c.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    c.data.materials.append(bone_mats[col])
    nb += 1
print('bones drawn:', nb)

# joint spheres
for b in arm.data.bones:
    if sub and not sub.search(b.name):
        continue
    h = arm.matrix_world @ b.head_local
    col = chain_color(b.name)
    if col not in bone_mats:
        continue
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, segments=12, location=h)
    bpy.context.active_object.data.materials.append(bone_mats[col])

bb = []
for m in meshes:
    bb += [m.matrix_world @ Vector(c) for c in m.bound_box]
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
ctr = (mn + mx) / 2
size = max((mx - mn).length, 0.5)

VIEW = argv[argv.index('--view') + 1] if '--view' in argv else 'persp'
scene = bpy.context.scene
cam = bpy.data.cameras.new('c')
camob = bpy.data.objects.new('c', cam)
bpy.context.collection.objects.link(camob)
if VIEW == 'front':
    camob.location = (ctr.x, ctr.y - size * 1.05, ctr.z + size * 0.15)
elif VIEW == 'side':
    camob.location = (ctr.x + size * 1.05, ctr.y, ctr.z + size * 0.15)
elif VIEW == 'top':
    camob.location = (ctr.x, ctr.y, ctr.z + size * 1.2)
else:
    camob.location = (ctr.x + size * 0.85, ctr.y - size * 0.85, ctr.z + size * 0.42)
camob.rotation_euler = (Vector(ctr) - camob.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera = camob
for i, (rot, en) in enumerate([((0.6, 0.2, 0.8), 4.0), ((-0.7, -0.5, -2.0), 2.5), ((1.2, 0.0, -0.5), 1.5)]):
    li = bpy.data.lights.new('l%d' % i, 'SUN')
    lo = bpy.data.objects.new('l%d' % i, li)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = rot
    li.energy = en
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.6
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.22, 0.22, 0.26, 1)
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('saved', OUT)
