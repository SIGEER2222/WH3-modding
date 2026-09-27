# -*- coding: utf-8 -*-
"""Build manifest for batch source-anim dump+inject (CS 'With Animations.fbx'
-> bound.glb src_* clips).

usage: dgm_srcanim_manifest.py
writes scratch/dgm_srcanim/manifest.json + units.json
"""
import json, os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rep = json.load(open(os.path.join(ROOT, 'scratch/dgm_pub_batch/report.json'),
                     encoding='utf-8'))

fbx_by_chr = {}
pat = os.path.join(ROOT, 'scratch/dgm_pub_src/ex/*/**/*.fbx')
for p in glob.glob(pat, recursive=True):
    bn = os.path.basename(p)
    m = re.search(r'chr(\d+)', bn)
    if m and 'animation' in bn.lower():
        fbx_by_chr.setdefault('chr' + m.group(1), []).append(p)

out_root = os.path.join(ROOT, 'scratch/dgm_srcanim')
os.makedirs(out_root, exist_ok=True)
manifest, units = [], []
batch_dir = os.path.join(ROOT, 'scratch/dgm_pub_batch')
for d in sorted(os.listdir(batch_dir)):
    if not d.startswith('czx_dgm_'):
        continue
    jp = os.path.join(batch_dir, d, 'jmap.json')
    if not os.path.exists(jp):
        continue
    m = re.search(r'chr(\d+)', rep.get(d, {}).get('glb', ''))
    if not m:
        continue
    fxs = fbx_by_chr.get('chr' + m.group(1), [])
    if not fxs:
        continue
    glb = os.path.join('E:/Code/model-studio/models', d + '_bound.glb')
    if not os.path.exists(glb):
        continue
    outd = os.path.join(out_root, d)
    os.makedirs(outd, exist_ok=True)
    manifest.append({'fbx': fxs[0],
                     'out': os.path.join(outd, 'src_anims.json')})
    units.append(d)

json.dump(manifest, open(os.path.join(out_root, 'manifest.json'), 'w'),
          indent=1)
json.dump(units, open(os.path.join(out_root, 'units.json'), 'w'), indent=1)
print(len(units), 'units')
for u in units:
    print(' ', u)
