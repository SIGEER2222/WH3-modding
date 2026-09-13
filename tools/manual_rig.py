# -*- coding: utf-8 -*-
"""Rule-driven manual rigging: assign vertex groups by spatial regions.

Equivalent to hand weight-painting, but scriptable and repeatable. Each rule
selects a region of the mesh and assigns bones; rules apply in order, first
match wins, unmatched verts keep existing weights.

Usage:
  python manual_rig.py <skinned.glb> <skel.json> <rules.json>

Rules JSON:
[
  {"name": "legs",   "sel": {"ymax": 1.2},          "assign": "nearest:leg_"},
  {"name": "spikes", "sel": {"ymin": 4.0},          "assign": "bone:spine_2"},
  {"name": "armL",   "sel": {"xmin": 0.5},          "assign": "nearest:arm_l"},
  {"name": "core",   "sel": {},                      "assign": "keep"}
]

sel keys (all optional, ANDed, in GLB/game space: x=right, y=up, z=forward):
  xmin/xmax/ymin/ymax/zmin/zmax : float bounds
  cx/cy/cz + r                  : sphere select
  bone_far: "<regex>"           : only verts whose nearest bone segment does NOT match regex
  bone_near: "<regex>"          : only verts whose nearest bone segment matches regex

assign:
  "bone:<name>"     -> rigid weight 1.0 to that bone
  "nearest:<regex>" -> rigid 1.0 to the nearest bone whose name matches regex
  "keep"            -> keep transferred weights
"""
import json
import re
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import read_glb


def main():
    glb_path = Path(sys.argv[1])
    skel = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
    rules = json.loads(Path(sys.argv[3]).read_text(encoding='utf-8'))

    wp = np.array(skel['world_pos_frame0'], dtype=np.float64)
    names = [b['name'] for b in skel['bones']]
    parent = [b.get('parent', -1) for b in skel['bones']]
    name2i = {n: i for i, n in enumerate(names)}

    segs = [(wp[parent[i]], wp[i], i) if parent[i] >= 0 else (wp[i], wp[i], i)
            for i in range(len(names))]

    js, binbuf = read_glb(glb_path)
    prim = js['meshes'][0]['primitives'][0]
    at = prim['attributes']
    pa = js['accessors'][at['POSITION']]
    pbv = js['bufferViews'][pa['bufferView']]
    poff = pbv.get('byteOffset', 0) + pa.get('byteOffset', 0)
    pos = np.frombuffer(binbuf, dtype='<f4', count=pa['count'] * 3,
                        offset=poff).reshape(-1, 3).astype(np.float64)
    n = len(pos)

    ja = js['accessors'][at['JOINTS_0']]
    wa = js['accessors'][at['WEIGHTS_0']]
    jbvv = js['bufferViews'][ja['bufferView']]
    joff = jbvv.get('byteOffset', 0) + ja.get('byteOffset', 0)
    wbv = js['bufferViews'][wa['bufferView']]
    woff = wbv.get('byteOffset', 0) + wa.get('byteOffset', 0)
    joints = np.frombuffer(binbuf, dtype=np.uint8, count=n * 4,
                           offset=joff).reshape(n, 4).copy()
    weights = np.frombuffer(binbuf, dtype='<f4', count=n * 4,
                            offset=woff).reshape(n, 4).copy()
    skin = js['skins'][0]
    joint_names = [js['nodes'][j]['name'] for j in skin['joints']]
    wh2joint = {name2i[nm]: ji for ji, nm in enumerate(joint_names) if nm in name2i}

    # per-vert distance to every bone segment (n x nb) — used by bone_near/far/nearest
    d_all = np.full((n, len(names)), 1e18)
    for a, bpt, bi in segs:
        ab = bpt - a
        L2 = float(ab @ ab)
        if L2 < 1e-12:
            d = ((pos - a) ** 2).sum(1)
        else:
            t = np.clip(((pos - a) @ ab) / L2, 0, 1)
            d = ((pos - (a + t[:, None] * ab)) ** 2).sum(1)
        d_all[:, bi] = np.sqrt(np.maximum(d, 0))
    nearest_b = d_all.argmin(1)

    def sel_mask(sel):
        m = np.ones(n, dtype=bool)
        for ax, key in ((0, 'x'), (1, 'y'), (2, 'z')):
            if key + 'min' in sel:
                m &= pos[:, ax] >= sel[key + 'min']
            if key + 'max' in sel:
                m &= pos[:, ax] <= sel[key + 'max']
        if 'r' in sel:
            c = np.array([sel.get('cx', 0), sel.get('cy', 0), sel.get('cz', 0)])
            m &= ((pos - c) ** 2).sum(1) <= sel['r'] ** 2
        if 'bone_near' in sel:
            rgx = re.compile(sel['bone_near'])
            m &= np.array([bool(rgx.search(names[b])) for b in nearest_b])
        if 'bone_far' in sel:
            rgx = re.compile(sel['bone_far'])
            m &= np.array([not rgx.search(names[b]) for b in nearest_b])
        return m

    stats = []
    for rule in rules:
        m = sel_mask(rule.get('sel', {}))
        if not m.any():
            stats.append((rule.get('name', '?'), 0, 'empty'))
            continue
        assign = rule['assign']
        vi = np.nonzero(m)[0]
        if assign == 'keep':
            stats.append((rule.get('name', '?'), len(vi), 'kept'))
            continue
        if assign.startswith('bone:'):
            bn = assign[5:]
            if bn not in wh2joint:
                stats.append((rule.get('name', '?'), len(vi), f'BAD BONE {bn}'))
                continue
            joints[vi] = 0
            weights[vi] = 0
            joints[vi, 0] = wh2joint[name2i[bn]]
            weights[vi, 0] = 1.0
            stats.append((rule.get('name', '?'), len(vi), f'-> {bn}'))
        elif assign.startswith('nearest:'):
            rgx = re.compile(assign[8:])
            allow = [i for i, nm in enumerate(names) if rgx.search(nm) and i in wh2joint]
            if not allow:
                stats.append((rule.get('name', '?'), len(vi), 'BAD REGEX'))
                continue
            sub = d_all[np.ix_(vi, allow)]
            nb_sel = np.array(allow)[sub.argmin(1)]
            joints[vi] = 0
            weights[vi] = 0
            for i, b in zip(vi, nb_sel):
                joints[i, 0] = wh2joint[b]
                weights[i, 0] = 1.0
            used = sorted({names[b] for b in nb_sel})
            stats.append((rule.get('name', '?'), len(vi), f'-> nearest of {len(allow)} bones'))
        else:
            stats.append((rule.get('name', '?'), len(vi), f'BAD ASSIGN {assign}'))

    out = bytearray(binbuf)
    out[joff:joff + n * 4] = joints.tobytes()
    out[woff:woff + weights.nbytes] = weights.astype('<f4').tobytes()
    jsb = json.dumps(js, separators=(',', ':')).encode()
    while len(jsb) % 4:
        jsb += b' '
    binb = bytes(out)
    while len(binb) % 4:
        binb += b'\x00'
    glb = bytearray()
    glb += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jsb) + 8 + len(binb))
    glb += struct.pack('<II', len(jsb), 0x4E4F534A) + jsb
    glb += struct.pack('<II', len(binb), 0x004E4942) + binb
    glb_path.write_bytes(bytes(glb))
    for nm, cnt, info in stats:
        print(f'  {nm}: {cnt} verts {info}')


if __name__ == '__main__':
    main()
