# -*- coding: utf-8 -*-
"""Rigid-bind core-mass vertices to the nearest torso bone.

For bulbous units (baneling sac on spider skeleton): the big ball must move
rigidly with one body bone or NN-transferred weights shear it apart.

Verts whose nearest bone segment belongs to the CORE set get weight 1.0 to
that bone; everything else keeps its existing weights.

Usage:
  python rigidify_core.py <skinned.glb> <skel.json> core_bone1,core_bone2,... [--ymin F]

--ymin: rigidify every vertex with y >= F regardless of nearest-bone
(used when a huge sac/bulb sits far above the torso bones so its surface
verts are nearer to limb segments than to the body chain).
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import read_glb, read_accessor


def main():
    glb_path = Path(sys.argv[1])
    skel = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))
    core_names = set(sys.argv[3].split(','))
    ymin = None
    if '--ymin' in sys.argv:
        ymin = float(sys.argv[sys.argv.index('--ymin') + 1])
    wp = np.array(skel['world_pos_frame0'], dtype=np.float64)
    names = [b['name'] for b in skel['bones']]
    parent = [b.get('parent', -1) for b in skel['bones']]
    name2i = {n: i for i, n in enumerate(names)}

    # bone segments: parent->bone
    segs = []  # (a, b, bone_idx)
    for i, n in enumerate(names):
        p = parent[i]
        if p >= 0:
            segs.append((wp[p], wp[i], i))
        else:
            segs.append((wp[i], wp[i], i))

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
    skin = js['skins'][0]
    joint_names = [js['nodes'][j]['name'] for j in skin['joints']]
    wh2joint = {name2i[nm]: ji for ji, nm in enumerate(joint_names) if nm in name2i}

    # nearest bone per vert — among core bones only when --ymin is set
    core_idx = {name2i[c] for c in core_names if c in name2i}
    best_b = np.zeros(n, dtype=int)
    best_d = np.full(n, 1e18)
    for a, bpt, bi in segs:
        if ymin is not None and bi not in core_idx:
            continue
        ab = bpt - a
        L2 = float(ab @ ab)
        if L2 < 1e-12:
            d = ((pos - a) ** 2).sum(1)
        else:
            t = np.clip(((pos - a) @ ab) / L2, 0, 1)
            d = ((pos - (a + t[:, None] * ab)) ** 2).sum(1)
        m = d < best_d
        best_d[m] = d[m]
        best_b[m] = bi

    # read current weights
    jbvv = js['bufferViews'][ja['bufferView']]
    joff = jbvv.get('byteOffset', 0) + ja.get('byteOffset', 0)
    wbv = js['bufferViews'][wa['bufferView']]
    woff = wbv.get('byteOffset', 0) + wa.get('byteOffset', 0)
    joints = np.frombuffer(binbuf, dtype=np.uint8,
                           count=n * 4, offset=joff).reshape(n, 4).copy()
    ct = wa['componentType']
    assert ct == 5126
    weights = np.frombuffer(binbuf, dtype='<f4', count=n * 4,
                            offset=woff).reshape(n, 4).copy()

    fixed = 0
    for i in range(n):
        if best_b[i] in core_idx and (ymin is None or pos[i, 1] >= ymin):
            joints[i] = 0
            weights[i] = 0
            joints[i, 0] = wh2joint[best_b[i]]
            weights[i, 0] = 1.0
            fixed += 1
    print(f'rigidified {fixed}/{n} verts to core bones {sorted(core_names & set(names))}')

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


if __name__ == '__main__':
    main()
