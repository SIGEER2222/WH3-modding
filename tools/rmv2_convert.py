# -*- coding: utf-8 -*-
"""RMV2 v8 reader/writer + skinned GLB -> RMV2 converter.

Ported from TheAssetEditor (donkeyProgramming) C# sources.
Strategy: parse a donor RMV2 (same skeleton family), keep its material block
(attachment points, params, transform) and replace only mesh data + textures.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np


# ---------------- RMV2 low level ----------------

def u16(b, o): return struct.unpack_from('<H', b, o)[0]
def u32(b, o): return struct.unpack_from('<I', b, o)[0]
def i32(b, o): return struct.unpack_from('<i', b, o)[0]
def f32(b, o): return struct.unpack_from('<f', b, o)[0]


def half(x):
    return struct.pack('<e', float(x))


def normal_to_byte(f):
    return int(round((f + 1.0) / 2.0 * 255.0)) & 0xFF


def fix_str(s, size):
    b = s.encode('utf-8')[:size]
    return b + b'\x00' * (size - len(b))


# ---------------- RMV2 reader (for donor template) ----------------

def parse_weighted_material(b, off):
    """Parse WeightedMaterial block, return (dict, total_size)."""
    start = off
    vertex_type = u16(b, off); off += 2
    model_name = b[off:off + 32].split(b'\x00')[0].decode('utf8', 'replace'); off += 32
    tex_dir = b[off:off + 256].split(b'\x00')[0].decode('utf8', 'replace'); off += 256
    filters = b[off:off + 256].split(b'\x00')[0].decode('utf8', 'replace'); off += 256
    off += 2  # padding bytes
    transform = b[off:off + 156]; off += 156  # RmvTransform raw
    matrix_index, parent_matrix_index = struct.unpack_from('<ii', b, off); off += 8
    counts = struct.unpack_from('<6I', b, off); off += 24
    off += 124  # padding array

    ap_count, tex_count, str_count, flt_count, int_count, vec_count = counts

    aps = []
    for _ in range(ap_count):
        name = b[off:off + 32].split(b'\x00')[0].decode('utf8', 'replace')
        mat = b[off + 32:off + 80]      # RmvMatrix3x4 = 12 floats = 48B
        bidx = i32(b, off + 80)
        aps.append((name, mat, bidx))
        off += 84

    texs = []
    for _ in range(tex_count):
        ttype = i32(b, off)
        path = b[off + 4:off + 260].split(b'\x00')[0].decode('utf8', 'replace')
        texs.append((ttype, path))
        off += 260

    strings = []
    for _ in range(str_count):
        idx = i32(b, off); off += 4
        ln = u16(b, off); off += 2
        s = b[off:off + ln].decode('utf8', 'replace'); off += ln
        strings.append((idx, s))
    floats = []
    for _ in range(flt_count):
        idx = i32(b, off); v = f32(b, off + 4); off += 8
        floats.append((idx, v))
    ints = []
    for _ in range(int_count):
        idx = i32(b, off); v = i32(b, off + 4); off += 8
        ints.append((idx, v))
    vecs = []
    for _ in range(vec_count):
        idx = i32(b, off); v = struct.unpack_from('<4f', b, off + 4); off += 20
        vecs.append((idx, v))

    return {
        'vertex_type': vertex_type, 'model_name': model_name, 'tex_dir': tex_dir,
        'filters': filters, 'transform': transform, 'matrix_index': matrix_index,
        'parent_matrix_index': parent_matrix_index, 'attachments': aps,
        'textures': texs, 'strings': strings, 'floats': floats,
        'ints': ints, 'vec4s': vecs,
    }, off - start


COMMON_HEADER_SIZE = 80  # u16+u16+5*u32+24+32


def parse_rmv2(path):
    b = Path(path).read_bytes()
    assert b[:4] == b'RMV2'
    version = u32(b, 4)
    lod_count = u32(b, 8)
    skeleton = b[12:140].split(b'\x00')[0].decode('utf8', 'replace')
    off = 140
    lods = []
    for _ in range(lod_count):
        # V7/V8 lod header: 4*u32 + f32 + u32 + 4*u8 = 28
        lods.append(struct.unpack_from('<4IfI4B', b, off))
        off += 28
    models = []
    for lod in lods:
        mesh_count, _, _, first_off, _cam, _lvl, _q, _p0, _p1, _p2 = lod
        loff = first_off
        lod_models = []
        for _ in range(mesh_count):
            (mtype, rflag, mesh_size, voff, vcnt, ioff, icnt) = struct.unpack_from('<HH5I', b, loff)
            mat, msize = parse_weighted_material(b, loff + COMMON_HEADER_SIZE)
            lod_models.append({
                'material': mat, 'vertex_count': vcnt, 'index_count': icnt,
                'vertex_off': loff + voff, 'index_off': loff + ioff,
                'mesh_size': mesh_size, 'model_type': mtype,
                'shader_params': b[loff + 48:loff + 80],
                'render_flag': rflag,
            })
            loff += mesh_size
        models.append(lod_models)
    # attach lod headers to each model dict for reuse
    for li, lod_models in enumerate(models):
        for m in lod_models:
            m['lod_headers'] = lods
    return {'bytes': b, 'version': version, 'skeleton': skeleton, 'lods': lods, 'models': models}


# ---------------- vertex packing ----------------

def encode_position_extra_precision(v):
    """V8 half-float position with best-fit W scale (vectorized-ish)."""
    x, y, z = float(v[0]), float(v[1]), float(v[2])
    best_w, best_err = 1.0, float('inf')
    for i in range(1024):
        w = 1.0 + i / 1024.0
        hx = np.float16(x / w); hy = np.float16(y / w); hz = np.float16(z / w)
        err = (abs(x - float(hx) * w) + abs(y - float(hy) * w) + abs(z - float(hz) * w))
        if err < best_err:
            best_err, best_w = err, w
            bx, by, bz = hx, hy, hz
    return struct.pack('<eeee', bx, by, bz, np.float16(best_w))


def encode_positions_extra_precision(V):
    """Vectorized version: V (n,3) -> packed half4 bytes."""
    n = V.shape[0]
    ws = 1.0 + np.arange(1024) / 1024.0          # (1024,)
    best_err = np.full(n, np.inf)
    best_w = np.ones(n)
    best = np.zeros((n, 3), dtype=np.float16)
    for i in range(1024):
        w = ws[i]
        h = (V / w).astype(np.float16)
        rec = h.astype(np.float64) * w
        err = np.abs(V - rec).sum(1)
        m = err < best_err
        best_err[m] = err[m]
        best_w[m] = w
        best[m] = h[m]
    out = np.empty((n, 4), dtype=np.float16)
    out[:, :3] = best
    out[:, 3] = best_w.astype(np.float16)
    return out.tobytes()


# ---------------- GLB skinned reader ----------------

def read_glb(path):
    d = open(path, 'rb')
    d.read(12)
    clen, _ = struct.unpack('<II', d.read(8))
    js = json.loads(d.read(clen))
    blen, _ = struct.unpack('<II', d.read(8))
    binbuf = d.read(blen)
    return js, binbuf


COMP = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2),
        5125: ('I', 4), 5126: ('f', 4)}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_accessor(js, binbuf, idx):
    a = js['accessors'][idx]
    bv = js['bufferViews'][a['bufferView']]
    fmt, size = COMP[a['componentType']]
    ncomp = NCOMP[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', size * ncomp)
    count = a['count']
    if stride == size * ncomp:
        arr = np.frombuffer(binbuf, dtype=np.dtype(fmt).newbyteorder('<'),
                            count=count * ncomp, offset=off).reshape(count, ncomp)
    else:
        arr = np.zeros((count, ncomp), dtype=np.dtype(fmt).newbyteorder('<'))
        for i in range(count):
            arr[i] = np.frombuffer(binbuf, dtype=np.dtype(fmt).newbyteorder('<'),
                                   count=ncomp, offset=off + i * stride)
    if a.get('normalized') and fmt in ('B', 'b', 'H', 'h'):
        arr = arr.astype(np.float32)
    return arr


def glb_mesh(glb_path, skeleton_json):
    """Return dict with positions(normals/tangents/uv/indices) + rmv bone indices/weights."""
    js, binbuf = read_glb(glb_path)
    prim = js['meshes'][0]['primitives'][0]
    at = prim['attributes']
    pos = read_accessor(js, binbuf, at['POSITION']).astype(np.float64)
    nrm = read_accessor(js, binbuf, at['NORMAL']).astype(np.float64)
    uv = read_accessor(js, binbuf, at['TEXCOORD_0']).astype(np.float64)
    tan = read_accessor(js, binbuf, at['TANGENT']).astype(np.float64) if 'TANGENT' in at else None
    joints = read_accessor(js, binbuf, at['JOINTS_0'])
    weights = read_accessor(js, binbuf, at['WEIGHTS_0']).astype(np.float64)
    idx = read_accessor(js, binbuf, prim['indices']).reshape(-1)

    # joint mapping: skin.joints -> node -> name -> wh3 bone index
    skel = json.load(open(skeleton_json, encoding='utf-8'))
    name2idx = {b['name']: i for i, b in enumerate(skel['bones'])}
    skin = js['skins'][0]
    joint_names = [js['nodes'][j]['name'] for j in skin['joints']]
    joint_map = np.array([name2idx[n] for n in joint_names], dtype=np.uint8)
    bone_idx = joint_map[joints]  # (n,4) wh3 indices
    return pos, nrm, uv, tan, idx, bone_idx, weights


# ---------------- RMV2 writer ----------------

def write_weighted_material(mat, vertex_type, tex_dir, textures, model_name):
    out = bytearray()
    out += struct.pack('<H', vertex_type)
    out += fix_str(model_name, 32)
    out += fix_str(tex_dir, 256)
    out += fix_str(mat['filters'], 256)
    out += b'\x00\x00'
    out += mat['transform']                      # 156B raw
    out += struct.pack('<ii', mat['matrix_index'], mat['parent_matrix_index'])
    out += struct.pack('<6I', len(mat['attachments']), len(textures),
                       len(mat['strings']), len(mat['floats']),
                       len(mat['ints']), len(mat['vec4s']))
    out += b'\x00' * 124
    for name, mraw, bidx in mat['attachments']:
        out += fix_str(name, 32) + mraw + struct.pack('<i', bidx)
    for ttype, path in textures:
        out += struct.pack('<i', ttype) + fix_str(path, 256)
    for idx, s in mat['strings']:
        bs = s.encode('utf-8')
        out += struct.pack('<iH', idx, len(bs)) + bs
    for idx, v in mat['floats']:
        out += struct.pack('<if', idx, v)
    for idx, v in mat['ints']:
        out += struct.pack('<ii', idx, v)
    for idx, v in mat['vec4s']:
        out += struct.pack('<i4f', idx, *v)
    return bytes(out)


def write_rmv2_v8(out_path, skeleton_name, mesh, donor_model):
    """mesh: (pos, nrm, uv, tan, idx, bone_idx, weights) — positions already in RMV2 space."""
    pos, nrm, uv, tan, idx, bone_idx, weights = mesh
    n = len(pos)

    # V8 Cinematic vertex: half4 pos, byte4 boneidx, byte4 bonew, byte4 normal,
    # half2 uv, byte4 binormal, byte4 tangent, byte4 colour = 36 bytes
    vsize = 36
    mat = donor_model['material']

    # --- build per-vertex columns then interleave (36 bytes/vertex) ---
    # positions: extra-precision half4
    n = len(pos)
    ws = 1.0 + np.arange(1024) / 1024.0
    best_err = np.full(n, np.inf)
    best_w = np.ones(n)
    best = np.zeros((n, 3), dtype=np.float16)
    for i in range(1024):
        w = ws[i]
        h = (pos / w).astype(np.float16)
        err = np.abs(pos - h.astype(np.float64) * w).sum(1)
        m = err < best_err
        best_err[m] = err[m]
        best_w[m] = w
        best[m] = h[m]
    pos4 = np.empty((n, 4), dtype=np.float16)
    pos4[:, :3] = best
    pos4[:, 3] = best_w.astype(np.float16)

    # bone index / weight
    bw = np.round(weights * 255).astype(np.int64)
    for i in range(n):
        s = bw[i].sum()
        if s != 255:
            k = int(np.argmax(bw[i]))
            bw[i, k] += 255 - s
    bw = np.clip(bw, 0, 255).astype(np.uint8)

    def byte4(arr3, w=-1.0):
        o = np.empty((n, 4), dtype=np.uint8)
        o[:, :3] = np.round((np.clip(arr3, -1, 1) + 1.0) / 2.0 * 255.0).astype(np.uint8)
        o[:, 3] = normal_to_byte(w)
        return o

    if tan is None:
        tan = np.zeros((n, 4))
        tan[:, 0] = 1.0
    binorm = np.cross(nrm, tan[:, :3]) * tan[:, 3:4]
    uvh = np.empty((n, 2), dtype=np.float16)
    uvh[:, 0] = uv[:, 0]
    uvh[:, 1] = uv[:, 1]
    col = np.full((n, 4), 255, dtype=np.uint8)

    # interleave: pos8 | bidx4 | bw4 | nrm4 | uv4 | bin4 | tan4 | col4
    verts = np.empty((n, 36), dtype=np.uint8)
    verts[:, 0:8] = pos4.view(np.uint8).reshape(n, 8)
    verts[:, 8:12] = bone_idx.astype(np.uint8)
    verts[:, 12:16] = bw
    verts[:, 16:20] = byte4(nrm)
    verts[:, 20:24] = uvh.view(np.uint8).reshape(n, 4)
    verts[:, 24:28] = byte4(binorm)
    verts[:, 28:32] = byte4(tan[:, :3])
    verts[:, 32:36] = col
    verts = verts.tobytes()

    idxb = idx.astype('<u2').tobytes()

    mat_bytes = write_weighted_material(mat, 4, mat['tex_dir'],
                                        mat['textures'], mat['model_name'])
    header_size = COMMON_HEADER_SIZE + len(mat_bytes)
    voff = header_size
    ioff = voff + len(verts)
    mesh_size = ioff + len(idxb)

    mins = pos.min(0); maxs = pos.max(0)
    common = struct.pack('<HH5I', donor_model['model_type'], 0, mesh_size,
                         voff, n, ioff, len(idx))
    common += struct.pack('<6f', mins[0], mins[1], mins[2], maxs[0], maxs[1], maxs[2])
    common += donor_model.get('shader_params', fix_str('default_dry ', 12) + b'\x00' * 20)

    model_block = common + mat_bytes + verts + idxb

    # file header: RMV2 + ver8 + lods + skeleton(128)
    # replicate the mesh across the same LOD structure as the donor
    donor_lods = donor_model.get('lod_headers') or []
    lods = max(1, len(donor_lods))
    fh = b'RMV2' + struct.pack('<II', 8, lods) + fix_str(skeleton_name, 128)
    lod_header_size = 28
    out = bytearray(fh)
    first_mesh_off = len(fh) + lods * lod_header_size
    for li in range(lods):
        dist = donor_lods[li][4] if donor_lods else 10000.0
        lvl = donor_lods[li][5] if donor_lods else li
        q = donor_lods[li][6] if donor_lods else 0
        off = first_mesh_off + li * len(model_block)
        out += struct.pack('<4IfI4B', 1, n * vsize, len(idx) * 2, off,
                           dist, lvl, q, 0, 0, 0)
    for li in range(lods):
        out += model_block
    Path(out_path).write_bytes(bytes(out))
    print('wrote', out_path, len(out), 'bytes,', n, 'verts x', lods, 'lods')
