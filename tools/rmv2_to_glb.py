# -*- coding: utf-8 -*-
"""Export RMV2 (v7/v8 weighted meshes) to GLB, grouped by material.

Usage:
  python rmv2_to_glb.py <in.rmv2|payload.bin> <out_dir> [--lod N]

Decodes 32-byte "weighted" vertices (v7 vtype4) and 36-byte "cinematic" (v8):
  weighted(32): pos f32x3 | boneidx u8x4 | bonew u8x4 | nrm u8x4 | uv f16x2 | tan u8x4
  cinematic(36): pos f16x4 | boneidx u8x4 | bonew u8x4 | nrm u8x4 | uv f16x2 | bin u8x4 | tan u8x4 | col u8x4

Writes one GLB per material group: <out_dir>/<model>_<matkey>.glb
"""
import io
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from rmv2_convert import parse_rmv2


def decode_verts(raw, count, vsize):
    """Return (pos f32[n,3], uv f32[n,2], nrm f32[n,3]) from a vertex blob."""
    a = np.frombuffer(raw, dtype=np.uint8).reshape(count, vsize)
    if vsize == 32:
        pos = a[:, 0:12].copy().view('<f4').reshape(count, 3)
        uv = a[:, 24:28].copy().view('<f2').reshape(count, 2).astype(np.float32)
        nrm_b = a[:, 20:24].astype(np.float32)
    elif vsize == 36:
        pos4 = a[:, 0:8].copy().view('<f2').reshape(count, 4).astype(np.float32)
        pos = pos4[:, :3] * pos4[:, 3:4]
        uv = a[:, 20:24].copy().view('<f2').reshape(count, 2).astype(np.float32)
        nrm_b = a[:, 16:20].astype(np.float32)
    else:
        raise ValueError(f'unknown vsize {vsize}')
    nrm = (nrm_b[:, :3] / 255.0) * 2.0 - 1.0
    return pos.astype(np.float32), uv, nrm


def mat_key(m):
    texs = m['material'].get('textures', [])
    base = [t for t in texs if 'base_colour' in t[1].lower()]
    return base[0][1] if base else (texs[0][1] if texs else 'none')


def build_glb(groups, out_path):
    """groups: list of (name, pos[n,3], uv[n,2], nrm[n,3], idx u16/u32)."""
    binbuf = bytearray()
    accessors = []
    views = []

    def add(arr, target, comptype, acctype):
        off = len(binbuf)
        data = arr.tobytes()
        binbuf.extend(data)
        while len(binbuf) % 4:
            binbuf.append(0)
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data),
                      'target': target})
        a = {'bufferView': len(views) - 1, 'componentType': comptype,
             'count': len(arr) if arr.ndim == 1 else arr.shape[0], 'type': acctype}
        if comptype == 5126 and acctype in ('VEC3',):
            a['min'] = [float(x) for x in np.asarray(arr).min(0)]
            a['max'] = [float(x) for x in np.asarray(arr).max(0)]
        accessors.append(a)
        return len(accessors) - 1

    meshes = []
    nodes = []
    for gi, (name, pos, uv, nrm, idx) in enumerate(groups):
        ai_pos = add(pos.astype('<f4'), 34962, 5126, 'VEC3')
        ai_nrm = add(nrm.astype('<f4'), 34962, 5126, 'VEC3')
        ai_uv = add(uv.astype('<f4'), 34962, 5126, 'VEC2')
        idx32 = idx.astype('<u4')
        ai_idx = add(idx32, 34963, 5125, 'SCALAR')
        meshes.append({'name': name, 'primitives': [{
            'attributes': {'POSITION': ai_pos, 'NORMAL': ai_nrm, 'TEXCOORD_0': ai_uv},
            'indices': ai_idx, 'material': gi}]})
        nodes.append({'mesh': gi, 'name': name})

    gltf = {
        'asset': {'version': '2.0', 'generator': 'rmv2_to_glb'},
        'scene': 0, 'scenes': [{'nodes': list(range(len(nodes)))}],
        'nodes': nodes, 'meshes': meshes,
        'materials': [{'name': g[0], 'pbrMetallicRoughness': {'metallicFactor': 0.0}}
                      for g in groups],
        'accessors': accessors, 'bufferViews': views,
        'buffers': [{'byteLength': len(binbuf)}],
    }
    js = json.dumps(gltf, separators=(',', ':')).encode()
    while len(js) % 4:
        js += b' '
    out = bytearray()
    out += struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binbuf))
    out += struct.pack('<II', len(js), 0x4E4F534A) + js
    out += struct.pack('<II', len(binbuf), 0x004E4942) + binbuf
    Path(out_path).write_bytes(bytes(out))


def export_rmv2(rmv2_path, out_dir, lod=0):
    d = parse_rmv2(rmv2_path)
    b = d['bytes']
    models = d['models'][lod] if lod < len(d['models']) else d['models'][0]
    groups = {}
    order = []
    for m in models:
        vsize = (m['index_off'] - m['vertex_off']) // m['vertex_count']
        raw_v = b[m['vertex_off']:m['index_off']]
        raw_i = b[m['index_off']:m['index_off'] + m['index_count'] * 2]
        pos, uv, nrm = decode_verts(raw_v, m['vertex_count'], vsize)
        idx = np.frombuffer(raw_i, dtype='<u2').copy()
        key = mat_key(m)
        if key not in groups:
            groups[key] = []
            order.append(key)
        base = 0 if not groups[key] else sum(g[0].shape[0] for g in groups[key])
        groups[key].append((pos, uv, nrm, idx + 0))  # keep separate; merge at write
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(rmv2_path).stem
    made = []
    for key in order:
        gs = groups[key]
        pos = np.concatenate([g[0] for g in gs])
        uv = np.concatenate([g[1] for g in gs])
        nrm = np.concatenate([g[2] for g in gs])
        idx = np.concatenate([g[3] + off for g, off in
                              zip(gs, np.cumsum([0] + [x[0].shape[0] for x in gs[:-1]]))])
        name = f"{stem}_{Path(key).stem.replace('.', '_')[:40]}"
        out = out_dir / f"{name}.glb"
        build_glb([(name, pos, uv, nrm, idx)], out)
        made.append((out, len(pos), key))
        print(f"  {out.name}: {len(pos)} verts, mat={Path(key).name}")
    return made


if __name__ == '__main__':
    src = sys.argv[1]
    outdir = sys.argv[2]
    lod = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    export_rmv2(src, outdir, lod)
