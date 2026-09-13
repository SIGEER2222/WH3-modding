# Blender 4.x headless: uniformly rescale a skinned GLB's mesh vertex data
# (keeps armature, recomputes bind matrices on export).
# usage: blender -b -P blender_rescale_glb.py -- <in.glb> <out.glb> <scale>
import bpy
import sys
from mathutils import Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
IN, OUT, S = argv[0], argv[1], float(argv[2])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    o.data.transform(Matrix.Scale(S, 4))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB',
                          export_skins=True, export_yup=True)
print('rescaled', S, '->', OUT)
