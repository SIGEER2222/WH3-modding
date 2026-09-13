# -*- coding: utf-8 -*-
"""Dump a donor RMV2 as static GLB + weights NPZ for ground-truth rendering.

Vertex order is identical in both outputs so vertex groups map 1:1.

Usage:
  python dump_donor_groundtruth.py <donor.rmv2> <out_stem> [--lod 0]
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import parse_rmv2
from rmv2_to_glb import build_glb


def main():
    donor = parse_rmv2(Path(sys.argv[1]))
    stem = Path(sys.argv[2])
    lod = int(sys.argv[sys.argv.index('--lod') + 1]) if '--lod' in sys.argv else 0
    b = donor['bytes']
    models = donor['models'][lod] if lod < len(donor['models']) else donor['models'][0]

    pos_l, idx_l, bi_l, bw_l = [], [], [], []
    voff = 0
    for m in models:
        vsize = (m['index_off'] - m['vertex_off']) // m['vertex_count']
        a = np.frombuffer(b[m['vertex_off']:m['index_off']],
                          dtype=np.uint8).reshape(m['vertex_count'], vsize)
        if vsize == 32:
            pos = a[:, 0:12].copy().view('<f4').reshape(-1, 3)
            if not np.isfinite(pos).all() or np.abs(pos).max() > 1000:
                pos = a[:, 0:6].copy().view('<f2').reshape(-1, 3).astype(np.float64)
                bi = a[:, 8:12].copy()
                bw = a[:, 12:16].copy()
            else:
                bi = a[:, 12:16].copy()
                bw = a[:, 16:20].copy()
        elif vsize == 36:
            pos4 = a[:, 0:8].copy().view('<f2').reshape(-1, 4).astype(np.float64)
            pos = pos4[:, :3] * pos4[:, 3:4]
            bi = a[:, 8:12].copy()
            bw = a[:, 12:16].copy()
        else:
            continue
        idx = np.frombuffer(b[m['index_off']:m['index_off'] + m['index_count'] * 2],
                            dtype='<u2').copy().astype(np.uint32) + voff
        pos_l.append(pos.astype(np.float64)); idx_l.append(idx)
        bi_l.append(bi); bw_l.append(bw.astype(np.float64) / 255.0)
        voff += len(pos)

    pos = np.concatenate(pos_l); idx = np.concatenate(idx_l)
    bi = np.concatenate(bi_l); bw = np.concatenate(bw_l)
    nrm = np.zeros_like(pos); uv = np.zeros((len(pos), 2))
    out_glb = stem.with_suffix('.glb')
    build_glb([(stem.name, pos.astype('<f4'), uv.astype('<f4'),
                nrm.astype('<f4'), idx)], out_glb)
    np.savez_compressed(str(stem) + '_weights.npz', bone_idx=bi, weights=bw)
    print(f'{out_glb}: {len(pos)} verts, weights npz saved')


if __name__ == '__main__':
    main()
