# -*- coding: utf-8 -*-
"""Rigid-bind vertices in a box region to one bone.

For hard-surface extremities (giant claw blades): verts beyond a threshold
must follow the limb bone rigidly or NN weights shear them into ribbons.

Usage:
  python rigidify_region.py <bound.glb> <skel.json> <bone> --axis x --gt 2.5
      [--axis x --lt -2.5] ...
  Multiple --axis/--gt/--lt filters AND together. Bone picked per-vertex
  sign when <bone> contains '{sign}' (e.g. 'hand_{sign}' -> hand_left/right
  where sign = 'left' if x<0 else 'right').
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
    bone_spec = sys.argv[3]
    axes = {'x': 0, 'y': 1, 'z': 2}
    conds = []  # (axis_idx, 'gt'|'lt', value)
    ax = 0
    i = 4
    while i < len(sys.argv):
        t = sys.argv[i]
        if t == '--axis':
            ax = axes[sys.argv[i + 1]]; i += 2
        elif t in ('--gt', '--lt'):
            conds.append((ax, t[2:], float(sys.argv[i + 1]))); i += 2
        else:
            i += 1

    names = [b['name'] for b in skel['bones']]
    name2i = {n: k for k, n in enumerate(names)}
    bone_l = name2i[bone_spec.format(sign='left')] if '{sign}' in bone_spec else name2i[bone_spec]
    bone_r = name2i[bone_spec.format(sign='right')] if '{sign}' in bone_spec else bone_l

    data = bytearray(glb_path.read_bytes())
    jlen = struct.unpack_from('<I', data, 12)[0]
    gltf = json.loads(data[20:20 + jlen])
    boff = 20 + jlen + 8
    binbuf = data[boff:]

    n_hit = 0
    for mesh in gltf['meshes']:
        for pr in mesh['primitives']:
            pos = read_accessor(gltf, binbuf, pr['attributes']['POSITION'])
            ji_ai = pr['attributes'].get('JOINTS_0')
            we_ai = pr['attributes'].get('WEIGHTS_0')
            if ji_ai is None:
                continue
            acc = gltf['accessors'][ji_ai]
            bv = gltf['bufferViews'][acc['bufferView']]
            joff = boff + bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
            accw = gltf['accessors'][we_ai]
            bvw = gltf['bufferViews'][accw['bufferView']]
            woff = boff + bvw.get('byteOffset', 0) + accw.get('byteOffset', 0)
            jdt = {5121: np.uint8, 5123: np.uint16}[acc['componentType']]
            jsz = np.dtype(jdt).itemsize
            for vi in range(len(pos)):
                ok = True
                for ax, op, val in conds:
                    if op == 'gt' and not pos[vi, ax] > val:
                        ok = False
                    if op == 'lt' and not pos[vi, ax] < val:
                        ok = False
                if not ok:
                    continue
                bone = bone_l if pos[vi, 0] < 0 else bone_r
                jo = joff + vi * 4 * jsz
                wo = woff + vi * 4 * 4
                struct.pack_into('<4' + ('B' if jsz == 1 else 'H'), data, jo, bone, 0, 0, 0)
                struct.pack_into('<4f', data, wo, 1.0, 0.0, 0.0, 0.0)
                n_hit += 1
    glb_path.write_bytes(bytes(data))
    print('rigidified', n_hit, 'verts ->', bone_spec)


if __name__ == '__main__':
    main()
