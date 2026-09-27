# -*- coding: utf-8 -*-
"""Batch-inject dumped CS source actions into bound GLBs as src_* clips.

For each unit in scratch/dgm_srcanim/units.json with a dumped
src_anims.json:
  map  = scratch/dgm_pub_batch/<u>/jmap.json + _root_src/_root_tgt
  inject_src_anim.py models/<u>_bound.glb src_anims.json map.json out.glb
  (in-place replace, one-time .bak_srcanim backup)

usage: dgm_srcanim_inject.py [unit ...]
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, 'scratch', 'dgm_srcanim')
INJECT = os.path.join(ROOT, 'scratch', 'garu_qa', 'inject_src_anim.py')
MODELS = 'E:/Code/model-studio/models'
FPS = '30'  # CS clips authored on 30fps grid (same convention as nxo pilot)

units = sys.argv[1:] or json.load(open(os.path.join(SA, 'units.json')))
done, skip = [], []
for u in units:
    src = os.path.join(SA, u, 'src_anims.json')
    jp = os.path.join(ROOT, 'scratch', 'dgm_pub_batch', u, 'jmap.json')
    glb = os.path.join(MODELS, u + '_bound.glb')
    if not (os.path.exists(src) and os.path.exists(jp)
            and os.path.exists(glb)):
        skip.append(u)
        continue
    jmap = json.load(open(jp, encoding='utf-8'))
    srcd = json.load(open(src))
    # CS rigs are Z-up & tiny (~1/15): convert every world matrix to Y-up
    # target space via C4 @ m @ C4^T (rotation conjugation + position map)
    import numpy as np
    C = np.array([[1., 0., 0.], [0., 0., 1.], [0., -1., 0.]])
    C4 = np.eye(4); C4[:3, :3] = C
    C4T = C4.T

    def conv(m):
        return (C4 @ np.array(m) @ C4T).tolist()

    ps = np.array([np.array(v)[:3, 3] for v in srcd['rest'].values()])
    span = ps.max(0) - ps.min(0)
    zup = span[2] > 2 * span[1]
    if zup:
        srcd['rest'] = {k: conv(v) for k, v in srcd['rest'].items()}
        for ad in srcd['actions'].values():
            ad['frames'] = [{k: conv(v) for k, v in f.items()}
                            for f in ad['frames']]
        convp = os.path.join(SA, u, 'src_anims_yup.json')
        json.dump(srcd, open(convp, 'w'))
        src = convp
    rest = set(srcd['rest'])
    # root translation carrier: prefer a src bone already mapped to 'root'
    # (J_center = CS pelvis center first); never steal a bone mapped elsewhere
    root_src = None
    for cand in ('J_center', 'J_root'):
        if jmap.get(cand) == 'root' and cand in rest:
            root_src = cand
            break
    if root_src is None:
        for s, t in jmap.items():
            if t == 'root' and s in rest:
                root_src = s
                break
    if root_src is None:
        # nothing feeds 'root' -> promote a bone mapped to animroot
        for cand in ('J_center', 'J_root'):
            if jmap.get(cand) in ('animroot', 'root') and cand in rest:
                root_src = cand
                break
    if root_src is None:
        print(u, 'NO ROOT SRC - skip')
        skip.append(u)
        continue
    # inject reverse-lookup picks the FIRST src key mapping to 'root';
    # several CS jmaps map multiple bones to root -> put root_src first
    jmap = {root_src: 'root',
            **{k: v for k, v in jmap.items() if k != root_src}}
    jmap['_root_src'] = root_src
    jmap['_root_tgt'] = 'root'
    mp = os.path.join(SA, u, 'map.json')
    json.dump(jmap, open(mp, 'w'), indent=1)
    bak = glb + '.bak_srcanim'
    if not os.path.exists(bak):
        with open(glb, 'rb') as f:
            data = f.read()
        with open(bak, 'wb') as f:
            f.write(data)
    out = glb + '.new'
    r = subprocess.run(
        [sys.executable, INJECT, glb, src, mp, out, '--fps', FPS],
        capture_output=True, text=True)
    log = os.path.join(SA, u, 'inject.log')
    open(log, 'w', encoding='utf-8').write(r.stdout + '\n' + r.stderr)
    if r.returncode != 0 or not os.path.exists(out):
        print(u, 'INJECT FAIL', r.stderr[-300:])
        skip.append(u)
        continue
    os.replace(out, glb)
    n_anims = len(srcd['actions'])
    print(u, 'OK', n_anims, 'clips injected (root_src=%s)' % root_src)
    done.append(u)
print('done', len(done), 'skip', len(skip), skip)
