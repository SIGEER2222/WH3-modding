# -*- coding: utf-8 -*-
"""glb_src_to_anim.py — GLB 原生剪辑 -> WH3 .anim v8 转换器（同骨架空间桥）

背景：bound.glb 的动画节点空间与其蒙皮 bind 空间不同——GLB 里
    vertex = nodeWorld_i * IBM_i * bindpos
而引擎侧是
    vertex = animWorld_i * invmat_i * bindpos,  invmat_i = inv(worldFrame0_i)
令 animWorld_i = nodeWorld_i * D_i,  D_i = IBM_i * M(worldFrame0_i)
则局部帧满足  animLocal_i = inv(D_par) * L_node_i * D_i
（skel 中 parent<0 的根骨: animLocal = nodeWorld * D, nodeWorld 走 GLB 父链）

用法:
    python tools/glb_src_to_anim.py <bound.glb> <skel.json> <clip|ALL|regex>
        <out_dir_or_file.anim> [--rate 20] [--name-map a=b,...]
输出骨架名取 skel json 的 skeleton_name；帧间局部 TRS 与 GLB 逐帧一致。
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from anim_rw import write_file, parse_anim8


# ---------- GLB ----------

def load_glb(path):
    d = Path(path).read_bytes()
    assert d[:4] == b'glTF'
    jlen, jtype = struct.unpack_from('<II', d, 12)
    assert jtype == 0x4E4F534A
    j = json.loads(d[20:20 + jlen])
    boff = 20 + jlen
    blen, btype = struct.unpack_from('<II', d[boff:boff + 8])
    assert btype == 0x004E4942
    binb = d[boff + 8:boff + 8 + blen]
    return j, binb


def acc(j, binb, ai):
    a = j['accessors'][ai]
    bv = j['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    dt = {5126: '<f4', 5123: '<u2', 5121: '<u1', 5125: '<u4'}[a['componentType']]
    return np.frombuffer(binb, dtype=dt, count=a['count'] * n,
                         offset=off).reshape(a['count'], n).astype(np.float64)


# ---------- 数学 ----------

def trs_to_mat(t, q, s):
    x, y, z, w = q
    R = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
    M = np.eye(4)
    M[:3, :3] = R * np.asarray(s)
    M[:3, 3] = t
    return M


def quat_to_mat4(p, q):
    return trs_to_mat(p, q, [1, 1, 1])


def mat_to_quat(M):
    R = M[:3, :3]
    # 去 scale（列归一）
    n = np.linalg.norm(R, axis=0)
    n[n < 1e-12] = 1.0
    R = R / n
    tr = np.trace(R)
    if tr > 0:
        s = np.sqrt(tr + 1.0) * 2
        q = [(R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s,
             (R[1, 0] - R[0, 1]) / s, s / 4]
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = np.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        q = [s / 4, (R[0, 1] + R[1, 0]) / s, (R[0, 2] + R[2, 0]) / s,
             (R[2, 1] - R[1, 2]) / s]
    elif R[1, 1] > R[2, 2]:
        s = np.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        q = [(R[0, 1] + R[1, 0]) / s, s / 4, (R[1, 2] + R[2, 1]) / s,
             (R[0, 2] - R[2, 0]) / s]
    else:
        s = np.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        q = [(R[0, 2] + R[2, 0]) / s, (R[1, 2] + R[2, 1]) / s, s / 4,
             (R[1, 0] - R[0, 1]) / s]
    q = np.array(q)
    return q / np.linalg.norm(q)


def sample_vec(times, vals, t):
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    i = np.searchsorted(times, t) - 1
    f = (t - times[i]) / max(times[i + 1] - times[i], 1e-9)
    return vals[i] * (1 - f) + vals[i + 1] * f


def sample_quat(times, vals, t):
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    i = np.searchsorted(times, t) - 1
    a, b = vals[i].copy(), vals[i + 1].copy()
    if np.dot(a, b) < 0:
        b = -b
    f = (t - times[i]) / max(times[i + 1] - times[i], 1e-9)
    q = a * (1 - f) + b * f
    return q / np.linalg.norm(q)


# ---------- 主转换 ----------

def convert(glb_path, skel_path, clip_sel, out_path, rate=20.0, name_map=None):
    j, binb = load_glb(glb_path)
    skel = json.loads(Path(skel_path).read_text(encoding='utf-8'))
    name_map = name_map or {}

    nidx = {n.get('name'): i for i, n in enumerate(j['nodes'])}
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []):
            par[c] = i

    def rest_trs(i):
        n = j['nodes'][i]
        return (np.array(n.get('translation', [0, 0, 0.])),
                np.array(n.get('rotation', [0, 0, 0, 1.])),
                np.array(n.get('scale', [1, 1, 1.])))

    def node_world(i, local_cache=None):
        m = trs_to_mat(*rest_trs(i)) if local_cache is None else local_cache[i]
        while i in par:
            i = par[i]
            pm = trs_to_mat(*rest_trs(i)) if local_cache is None else local_cache[i]
            m = pm @ m
        return m

    # IBM
    ibm = {}
    for sk in j.get('skins', []):
        ibm_arr = acc(j, binb, sk['inverseBindMatrices'])
        for k, ni_ in enumerate(sk['joints']):
            ibm[ni_] = ibm_arr[k].reshape(4, 4).T

    bones = skel['bones']
    bc = len(bones)
    wf0 = [quat_to_mat4(skel['world_pos_frame0'][i],
                        skel['world_quat_frame0'][i]) for i in range(bc)]

    # skel 骨 -> GLB 节点；D_i = IBM_i * worldF0_i
    b2n = []
    D = []
    for i, b in enumerate(bones):
        nm = name_map.get(b['name'], b['name'])
        ni_ = nidx.get(nm)
        assert ni_ is not None, f"bone {b['name']}({nm}) not in GLB nodes"
        b2n.append(ni_)
        assert ni_ in ibm, f"bone {nm} has no IBM"
        D.append(ibm[ni_] @ wf0[i])
    Dinv = [np.linalg.inv(d) for d in D]

    # 父校验：skel 父骨必须等于 GLB 最近 skel 祖骨
    for i, b in enumerate(bones):
        if b['parent'] < 0:
            continue
        gi = b2n[i]
        while gi in par:
            gi = par[gi]
            hit = next((k for k, v in enumerate(b2n) if v == gi), None)
            if hit is not None:
                assert hit == b['parent'], \
                    f"bone {b['name']}: glb parent {bones[hit]['name']} != skel parent {bones[b['parent']]['name']}"
                break

    # 选剪辑
    anims = {a['name']: a for a in j.get('animations', [])}
    if clip_sel == 'ALL':
        sel = list(anims)
    else:
        sel = [n for n in anims if clip_sel in n or n == clip_sel]
    assert sel, f"no clip matched {clip_sel}"

    multi = len(sel) > 1
    results = {}
    for cn in sel:
        a = anims[cn]
        # 通道 -> {node: {path: (times, vals)}}
        chans = {}
        dur = 0.0
        for ch in a['channels']:
            ni_ = ch['target']['node']
            sam = a['samplers'][ch['sampler']]
            ts = acc(j, binb, sam['input']).ravel()
            vs = acc(j, binb, sam['output'])
            chans.setdefault(ni_, {})[ch['target']['path']] = (ts, vs)
            dur = max(dur, float(ts[-1]))

        nf = max(2, int(round(dur * rate)) + 1)
        play_time = (nf - 1) / rate
        frames = []
        prev_q = [None] * bc
        for k in range(nf):
            t = min(k / rate, dur)
            # 每节点局部矩阵缓存（只算 skel 骨及其祖先即可，但全算更简单）
            Lmat = {}
            for ni_ in nidx.values():
                chs = chans.get(ni_, {})
                rt, rq, rs = rest_trs(ni_)
                if 'translation' in chs:
                    ts, vs = chs['translation']
                    rt = sample_vec(ts, vs, t)
                if 'rotation' in chs:
                    ts, vs = chs['rotation']
                    rq = sample_quat(ts, vs, t)
                if 'scale' in chs:
                    ts, vs = chs['scale']
                    rs = sample_vec(ts, vs, t)
                Lmat[ni_] = trs_to_mat(rt, rq, rs)

            lp, lq = [], []
            for i, b in enumerate(bones):
                ni_ = b2n[i]
                L = Lmat[ni_]
                if b['parent'] < 0:
                    # 根骨：local = nodeWorld * D
                    W = node_world(ni_, Lmat) @ D[i]
                    al = W
                else:
                    al = Dinv[b['parent']] @ L @ D[i]
                lp.append(al[:3, 3].tolist())
                q = mat_to_quat(al)
                if prev_q[i] is not None and np.dot(prev_q[i], q) < 0:
                    q = -q
                prev_q[i] = q
                lq.append(q.tolist())
            frames.append({'transforms': lp, 'quaternions': lq})

        anim = {'version': 8, 'unk0': 1, 'frame_rate': float(rate),
                'skeleton_name': skel['skeleton_name'], 'flags': [],
                'play_time': play_time,
                'bones': [{'name': b['name'], 'parent': b['parent']}
                          for b in bones],
                'unk_v8': 6,
                'parts': [{'tb': [12] * bc, 'rb': [8] * bc, 'rt': [], 'rq': [],
                           'stc': 0, 'sqc': 0, 'static': None,
                           'ftc': bc, 'fqc': bc, 'frames': frames}],
                'was_zstd': False, 'tail': b''}
        results[cn] = anim

        if out_path:
            if multi:
                op = Path(out_path) / f'{cn}.anim'
            else:
                op = Path(out_path)
                if op.suffix != '.anim':
                    op = op / f'{cn}.anim'
            op.parent.mkdir(parents=True, exist_ok=True)
            write_file(anim, str(op), zstd_compress=True)
            print(f'{cn}: {nf}f {play_time:.2f}s -> {op}')

    return results


if __name__ == '__main__':
    args = sys.argv[1:]
    glb, skel, sel, out = args[:4]
    rate = 20.0
    nm = {}
    if '--rate' in args:
        rate = float(args[args.index('--rate') + 1])
    if '--name-map' in args:
        for kv in args[args.index('--name-map') + 1].split(','):
            a, b = kv.split('=')
            nm[a] = b
    convert(glb, skel, sel, out, rate=rate, name_map=nm)
