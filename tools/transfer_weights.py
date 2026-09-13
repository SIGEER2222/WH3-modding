# -*- coding: utf-8 -*-
"""Transfer CA-authored vertex weights from a donor RMV2 to our skinned GLB.

Both meshes share the same skeleton => same WH3 bone index space and
(approximately) the same bind-pose model space. For each vertex of our mesh
we query the k nearest donor vertices and accumulate a distance-weighted
vote per bone, then keep the top-4 influences (RMV2 weighted4 limit).

Usage:
  python transfer_weights.py <donor.rmv2> <skinned.glb> <skel.json> [--lod 0] [--k 8]

The GLB is patched in place (JOINTS_0/WEIGHTS_0 accessors rewritten).
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import parse_rmv2, read_glb, read_accessor


def donor_arrays(donor, lod=0):
    """Return (pos, bone_idx, weights, faces) from all lod0 meshes."""
    b = donor['bytes']
    models = donor['models'][lod] if lod < len(donor['models']) else donor['models'][0]
    pos_l, bi_l, bw_l, face_l = [], [], [], []
    voff = 0
    for m in models:
        vsize = (m['index_off'] - m['vertex_off']) // m['vertex_count']
        a = np.frombuffer(b[m['vertex_off']:m['index_off']],
                          dtype=np.uint8).reshape(m['vertex_count'], vsize)
        if vsize == 32:      # weighted — two known layouts
            pos = a[:, 0:12].copy().view('<f4').reshape(-1, 3)
            if not np.isfinite(pos).all() or np.abs(pos).max() > 1000:
                # f16 variant: pos f16x3+pad2 @0 | boneidx @8 | bonew @12
                pos = a[:, 0:6].copy().view('<f2').reshape(-1, 3).astype(np.float64)
                bi = a[:, 8:12].copy()
                bw = a[:, 12:16].copy()
            else:
                bi = a[:, 12:16].copy()
                bw = a[:, 16:20].copy()
        elif vsize == 36:    # cinematic
            pos4 = a[:, 0:8].copy().view('<f2').reshape(-1, 4).astype(np.float64)
            pos = pos4[:, :3] * pos4[:, 3:4]
            bi = a[:, 8:12].copy()
            bw = a[:, 12:16].copy()
        else:
            continue
        idx = np.frombuffer(b[m['index_off']:m['index_off'] + m['index_count'] * 2],
                            dtype='<u2').astype(np.int64) + voff
        pos_l.append(pos.astype(np.float64))
        bi_l.append(bi)
        bw_l.append(bw.astype(np.float64) / 255.0)
        face_l.append(idx.reshape(-1, 3))
        voff += len(pos)
    return (np.concatenate(pos_l), np.concatenate(bi_l), np.concatenate(bw_l),
            np.concatenate(face_l))


def main():
    donor_path = Path(sys.argv[1])
    glb_path = Path(sys.argv[2])
    skel = json.loads(Path(sys.argv[3]).read_text(encoding='utf-8'))
    lod, k = 0, 8
    for i, a in enumerate(sys.argv[4:], 4):
        if a == '--lod':
            lod = int(sys.argv[i + 1])
        elif a == '--k':
            k = int(sys.argv[i + 1])

    nb = len(skel['bones'])
    pos_l, bi_l, bw_l, face_l = [], [], [], []
    for dp in str(donor_path).split(','):
        donor = parse_rmv2(Path(dp))
        p, bi, bw, fc = donor_arrays(donor, lod)
        base = sum(len(x) for x in pos_l)
        pos_l.append(p); bi_l.append(bi); bw_l.append(bw); face_l.append(fc + base)
        print(f"donor part: {Path(dp).name} skel={donor['skeleton']} verts={len(p)}")
    dpos = np.concatenate(pos_l); dbi = np.concatenate(bi_l); dbw = np.concatenate(bw_l)
    dfaces = np.concatenate(face_l)
    dbw[dbi >= nb] = 0.0                     # 0xFF padding / invalid slots carry no weight
    dbi[dbi >= nb] = 0
    print(f"donor total verts={len(dpos)} (lod{lod})")

    js, binbuf = read_glb(glb_path)
    prim = js['meshes'][0]['primitives'][0]
    at = prim['attributes']
    ja = js['accessors'][at['JOINTS_0']]
    wa = js['accessors'][at['WEIGHTS_0']]
    assert ja['componentType'] == 5121 and ja['type'] == 'VEC4', 'JOINTS_0 must be u8x4'
    skin = js['skins'][0]
    name2idx = {b['name']: i for i, b in enumerate(skel['bones'])}
    joint_names = [js['nodes'][j]['name'] for j in skin['joints']]
    wh2joint = {}  # wh3 bone idx -> our joint slot
    for ji, n in enumerate(joint_names):
        if n in name2idx:
            wh2joint[name2idx[n]] = ji

    pa = js['accessors'][at['POSITION']]
    pbv = js['bufferViews'][pa['bufferView']]
    poff = pbv.get('byteOffset', 0) + pa.get('byteOffset', 0)
    pos = np.frombuffer(binbuf, dtype='<f4', count=pa['count'] * 3,
                        offset=poff).reshape(-1, 3).astype(np.float64)
    n = len(pos)
    print(f"ours: {glb_path.name} verts={n}")
    print(f"  donor bbox {dpos.min(0).round(2)} .. {dpos.max(0).round(2)}")
    print(f"  ours  bbox {pos.min(0).round(2)} .. {pos.max(0).round(2)}")

    # bbox-normalize our verts into donor space: mesh proportions differ from
    # donor's, so query nearest donor vertex after affine alignment.
    dmin, dmax = dpos.min(0), dpos.max(0)
    omin, omax = pos.min(0), pos.max(0)
    scale = (dmax - dmin) / np.maximum(omax - omin, 1e-6)
    pos_q = (pos - omin) * scale + dmin
    print(f"  norm scale {scale.round(3)}")

    mode = 'face'
    if '--mode' in sys.argv:
        mode = sys.argv[sys.argv.index('--mode') + 1]
    votes = np.zeros((n, nb), dtype=np.float64)
    if mode == 'face':
        # nearest-surface-point transfer: barycentric interpolation of the
        # hit triangle's corner weights — continuous weight field, strictly
        # better than vertex NN (same idea as Blender's data transfer).
        import trimesh
        dm = trimesh.Trimesh(vertices=dpos, faces=dfaces, process=False)
        closest, dist, tid = trimesh.proximity.closest_point(dm, pos_q)
        tri = dpos[dfaces[tid]]                              # (n,3,3)
        bary = trimesh.triangles.points_to_barycentric(tri, closest)
        corner_idx = dfaces[tid]                             # (n,3)
        for c in range(3):
            vi = corner_idx[:, c]
            w = bary[:, c]
            for cc in range(4):
                np.add.at(votes, (np.arange(n), dbi[vi, cc]),
                          w * dbw[vi, cc])
    else:
        tree = cKDTree(dpos)
        dist, idx = tree.query(pos_q, k=k)
        sigma = max(np.median(dist[:, 0]), 1e-4)
        for j in range(k):
            wj = np.exp(-(dist[:, j] ** 2) / (2 * sigma * sigma))
            di = dbi[idx[:, j]]      # (n,4) wh3 bone idx
            dw = dbw[idx[:, j]]      # (n,4)
            for c in range(4):
                np.add.at(votes, (np.arange(n), di[:, c]), wj * dw[:, c])

    # topology smoothing: blend each vertex's votes with its face-neighbors'
    # dominant-bone distribution — kills salt-and-pepper misassignments where
    # isolated verts grabbed a wrong bone (silk-thin parts, scale artifacts).
    idx_flat = read_accessor(js, binbuf, prim['indices']).reshape(-1)
    rows, cols = [], []
    for f in idx_flat.reshape(-1, 3):
        for a2, b2 in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            rows.append(a2); cols.append(b2)
            rows.append(b2); cols.append(a2)
    rows = np.asarray(rows); cols = np.asarray(cols)
    deg = np.bincount(rows, minlength=n).astype(np.float64)
    for _ in range(3):
        acc = np.zeros_like(votes)
        np.add.at(acc, rows, votes[cols])
        acc /= np.maximum(deg, 1)[:, None]
        votes = 0.6 * votes + 0.4 * acc

    # top-4 -> our joint slots + normalized weights
    top = np.argsort(-votes, axis=1)[:, :4]
    new_bi = np.zeros((n, 4), dtype=np.uint8)
    new_bw = np.zeros((n, 4), dtype=np.float64)
    fallback = wh2joint.get(0, 0)
    for i in range(n):
        nz = 0
        for b in top[i]:
            if votes[i, b] <= 0 or b not in wh2joint:
                continue
            new_bi[i, nz] = wh2joint[b]
            new_bw[i, nz] = votes[i, b]
            nz += 1
        if nz == 0:  # no votes at all -> bind to bone 0
            new_bi[i, 0] = fallback
            new_bw[i, 0] = 1.0
        else:
            s = new_bw[i, :nz].sum()
            new_bw[i, :nz] /= s
    # zero unused slots
    for i in range(n):
        nz = int((new_bw[i] > 0).sum())
        new_bi[i, nz:] = 0

    # patch buffer: JOINTS_0 u8x4
    jbv = js['bufferViews'][ja['bufferView']]
    joff = jbv.get('byteOffset', 0) + ja.get('byteOffset', 0)
    out = bytearray(binbuf)
    out[joff:joff + n * 4] = new_bi.tobytes()

    # WEIGHTS_0: float32 VEC4 or normalized u8/u16
    wbv = js['bufferViews'][wa['bufferView']]
    woff = wbv.get('byteOffset', 0) + wa.get('byteOffset', 0)
    ct = wa['componentType']
    if ct == 5126:
        wb = new_bw.astype('<f4')
    elif ct == 5121:
        wb = np.clip(np.round(new_bw * 255.0), 0, 255).astype(np.uint8)
    elif ct == 5123:
        wb = np.clip(np.round(new_bw * 65535.0), 0, 65535).astype('<u2')
    else:
        raise ValueError(f'WEIGHTS_0 ctype {ct}')
    assert wb.nbytes == wa['count'] * 4 * {5126: 4, 5121: 1, 5123: 2}[ct]
    out[woff:woff + wb.nbytes] = wb.tobytes()

    # rebuild GLB
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
    avg_inf = (new_bw > 0.01).sum(1).mean()
    print(f"transferred: {glb_path.name}  avg influences/vert={avg_inf:.2f}  k={k}")


if __name__ == '__main__':
    main()
