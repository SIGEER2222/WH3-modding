# -*- coding: utf-8 -*-
"""Offline binding-frame identity check for bound GLBs.

At rest pose every vertex must skin to its authored position:
    v' = sum_j w_j * (W_node(j) @ IBM(j)) * v  ==  v
Any loss of node scale / wrong IBM shows up as exploded verts.

usage: dgm_bindcheck.py <glb ...>   exit non-zero if any unit fails
"""
import json, struct, sys
import numpy as np


def load(p):
    d = open(p, 'rb').read()
    jl = struct.unpack('<I', d[12:16])[0]
    g = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', d[off:off + 4])[0]
    return g, d[off + 8:off + 8 + bl]


def acc(g, b, i):
    a = g['accessors'][i]
    bv = g['bufferViews'][a['bufferView']]
    tmap = {5120: np.int8, 5121: np.uint8, 5122: np.int16,
            5123: np.uint16, 5125: np.uint32, 5126: np.float32}
    nmap = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    n, t = nmap[a['type']], tmap[a['componentType']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.frombuffer(b, t, a['count'] * n, off).reshape(a['count'], n)


def acc_norm(g, b, i):
    """accessor read for normalized uint16 attributes (WEIGHTS)."""
    a = g['accessors'][i]
    arr = acc(g, b, i)
    if a['componentType'] == 5123:
        return arr.astype(np.float32) / 65535.0
    return arr


def lmat(n):
    if 'matrix' in n:
        return np.array(n['matrix']).reshape(4, 4).T
    m = np.eye(4)
    if 'rotation' in n:
        x, y, z, w = n['rotation']
        m[:3, :3] = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    if 'scale' in n:
        m[:3, :3] = m[:3, :3] @ np.diag(n['scale'])
    if 'translation' in n:
        m[:3, 3] = n['translation']
    return m


def check(p, thr=0.05):
    g, b = load(p)
    nodes = g['nodes']
    par = {}
    for i, n in enumerate(nodes):
        for c in n.get('children', []):
            par[c] = i
    W = {}
    def wmat(i):
        if i not in W:
            lm = lmat(nodes[i])
            W[i] = (wmat(par[i]) @ lm) if i in par else lm
        return W[i]
    worst = 0.0; nverts = 0
    for mesh_i, mesh in enumerate(g.get('meshes', [])):
        for prim in mesh['primitives']:
            at = prim['attributes']
            if 'JOINTS_0' not in at or 'WEIGHTS_0' not in at:
                continue
            skin_i = None
            # find node carrying this mesh
            for ni, n in enumerate(nodes):
                if n.get('mesh') == mesh_i and 'skin' in n:
                    skin_i = n['skin']
                    break
            if skin_i is None:
                continue
            skin = g['skins'][skin_i]
            ibm = acc(g, b, skin['inverseBindMatrices']).reshape(-1, 4, 4)
            ibm = np.transpose(ibm, (0, 2, 1))
            SM = np.zeros((4, 4))
            J = acc(g, b, at['JOINTS_0']).astype(int)
            Wt = acc_norm(g, b, at['WEIGHTS_0'])
            P = acc(g, b, at['POSITION'])
            Bm = np.stack([wmat(int(j)) @ ibm[k]
                           for k, j in enumerate(skin['joints'])])
            v = np.concatenate([P, np.ones((len(P), 1), np.float32)], 1)
            vs = np.zeros((len(P), 4), np.float64)
            for k in range(4):
                Bk = Bm[J[:, k]]            # (nv,4,4)
                vs += Wt[:, k:k + 1] * np.einsum('nij,nj->ni', Bk, v)
            err = np.linalg.norm(vs[:, :3] - v[:, :3], axis=1)
            worst = max(worst, float(err.max()))
            nverts += int((err > thr).sum())
    return worst, nverts


if __name__ == '__main__':
    bad = []
    for p in sys.argv[1:]:
        try:
            mx, nv = check(p)
            tag = 'FAIL' if mx > 0.05 else 'ok'
            print('%-46s max=%8.4f verts>0.05=%-6d %s' %
                  (p.split('/')[-1], mx, nv, tag))
            if mx > 0.05:
                bad.append(p)
        except Exception as e:
            print('%-46s ERROR %s' % (p.split('/')[-1], e))
            bad.append(p)
    sys.exit(1 if bad else 0)
