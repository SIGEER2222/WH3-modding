# -*- coding: utf-8 -*-
"""Batch-dump armature actions from FBX files into per-file JSON.

usage (inside Blender):
  blender -b -P tools/dgm_dump_anims.py -- <manifest.json>

manifest.json: [{"fbx": "...", "out": "..."}, ...]

Each output JSON:
  {"fps": <scene fps>, "rest": {bone: world4x4}, "actions":
    {base_name: {"frames": [{bone: world4x4}...], "f0": int}}}
"""
import bpy, sys, json, re, os, traceback

argv = sys.argv[sys.argv.index('--') + 1:]
manifest = json.load(open(argv[0], encoding='utf-8'))

for item in manifest:
    fbx_path, out_json = item['fbx'], item['out']
    if os.path.exists(out_json):
        print('SKIP', out_json)
        continue
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=fbx_path, use_anim=True)
        arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
        if not arms:
            print('NOARM', fbx_path)
            continue
        arm = arms[0]
        fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
        rest = {b.name: [list(r) for r in (arm.matrix_world @ b.matrix_local)]
                for b in arm.data.bones}
        out = {'fps': fps, 'rest': rest, 'actions': {}}
        seen_base = set()
        for act in bpy.data.actions:
            if not any(fc.data_path.startswith('pose.bones')
                       for fc in act.fcurves):
                continue
            name = act.name.split('|')[-2] if '|' in act.name else act.name
            base = re.sub(r'_\d+$', '', name)
            if base in seen_base:
                continue
            seen_base.add(base)
            arm.animation_data.action = act
            if hasattr(act, 'slots') and act.slots:
                arm.animation_data.action_slot = act.slots[0]
            f0 = int(act.frame_range[0])
            f1 = int(round(act.frame_range[1]))
            if f1 - f0 > 600 or f1 <= f0:
                continue
            fr = []
            for f in range(f0, f1 + 1):
                bpy.context.scene.frame_set(f)
                bpy.context.view_layer.update()
                fr.append({pb.name: [list(r) for r in
                                     (arm.matrix_world @ pb.matrix)]
                           for pb in arm.pose.bones})
            out['actions'][base] = {'frames': fr, 'f0': f0}
            print('DUMPED', os.path.basename(fbx_path), base,
                  f1 - f0 + 1, 'frames')
        json.dump(out, open(out_json, 'w'))
        print('WROTE', out_json, len(out['actions']), 'actions')
    except Exception:
        print('FAIL', fbx_path)
        traceback.print_exc()
print('ALLDONE')
