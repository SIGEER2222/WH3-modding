# -*- coding: utf-8 -*-
"""Batch featbone surgery + re-injection for units with dumped src actions.

Per unit:
  1. restore  models/<u>_bound.glb            <- .bak_srcanim (donor clips,
     no src_*) — re-injecting onto the current file would duplicate clips
     and surgical tail truncation is unsafe where donor clips were appended
     after the src block.
  2. dgm_featbone.run(u)                      — add anatomy bones, rebuild
     weights from the src GLB, write _featbone/_K into map.json.
  3. inject_src_anim.py bound.glb src_anims_yup.json map.json --fps 30
     — re-append src_* clips, now driving the new feature bones too.

Idempotent: the .bak_srcanim restore makes every step reproducible.
usage: dgm_featbone_batch.py [unit ...]   (default: all with map+dump)
"""
import json, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dgm_featbone as fb

SA = os.path.join(ROOT, 'scratch', 'dgm_srcanim')
INJECT = os.path.join(ROOT, 'scratch', 'garu_qa', 'inject_src_anim.py')
MODELS = 'E:/Code/model-studio/models'

units = sys.argv[1:]
if len(units) == 1 and units[0].endswith('.json'):
    units = json.load(open(units[0]))
if not units:
    units = sorted(
        u for u in os.listdir(SA)
        if u.startswith('czx_')
        and os.path.exists(os.path.join(SA, u, 'map.json'))
        and (os.path.exists(os.path.join(SA, u, 'src_anims_yup.json'))
             or os.path.exists(os.path.join(SA, u, 'src_anims.json'))))

done, skip = [], []
for u in units:
    glb = os.path.join(MODELS, u + '_bound.glb')
    bak = glb + '.bak_srcanim'
    yup = os.path.join(SA, u, 'src_anims_yup.json')
    if not os.path.exists(yup):
        yup = os.path.join(SA, u, 'src_anims.json')
    mp = os.path.join(SA, u, 'map.json')
    try:
        if not os.path.exists(bak):
            print(u, 'SKIP no .bak_srcanim'); skip.append(u); continue
        shutil.copy2(bak, glb)
        rep = fb.run(u)
        if 'skip' in rep or 'fail' in rep or 'error' in rep:
            print(u, 'SKIP', rep); skip.append(u); continue
        out = glb + '.new'
        r = subprocess.run(
            [sys.executable, INJECT, glb, yup, mp, out, '--fps', '30'],
            capture_output=True, text=True)
        open(os.path.join(SA, u, 'inject_featbone.log'), 'w',
             encoding='utf-8').write(r.stdout + '\n' + r.stderr)
        if r.returncode != 0 or not os.path.exists(out):
            print(u, 'INJECT FAIL', r.stderr[-200:]); skip.append(u); continue
        os.replace(out, glb)
        print(u, 'OK n_new=%d fixed=%d remap=%d nn=%s mir=%s' % (
            rep['n_new'], len(rep.get('fixed_map', rep.get('fixed', []))),
            len(rep.get('remapped_fam', [])), rep['nn_med'], rep['mirrored']),
            flush=True)
        done.append(u)
    except Exception as e:
        print(u, 'ERROR', type(e).__name__, e); skip.append(u)

print('done', len(done), 'skip', len(skip), skip)
