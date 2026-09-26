# -*- coding: utf-8 -*-
"""把 WH3 原版动画 clip 注入已有 GLB（自制单位 bound.glb 用原版骨名，直接命中）。

用法:
  python inject_anims_glb.py <in.glb> [out.glb] [选项]

  --skeleton X    骨架名（默认 auto：从 pack 扫 animations/skeletons/*.anim 按骨名重合自动选）
  --clips a,b,c   clip 内部路径或 stem；'auto' 按 AUTO_CLIP_PATTERNS 自动挑
  --anim-dir X    auto 模式下限定 animations/battle/<skel>/<X>/ 子目录（武器类别）
  --limit N       auto 模式最多取 N 条（默认 10）
  --dry           只报告骨架匹配与 clip 命中，不写文件
  --strip         先剥掉已有 animations 再注入（重做/修复用，会压实 BIN）

轨道按骨名绑到 GLB 节点（bound.glb 用原版骨架骨名，直绑无需映射）。
clip 中 GLB 缺少的骨被跳过；GLB 有而 clip 没有的骨保持 rest。
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wh3_export_unit_glb as X   # 复用 pack 解析/clip 解析/四元数工具
from parse_anim_skeleton import parse_anim

COMP_F32 = 5126
SKEL_CACHE = Path(__file__).resolve().parents[1] / 'scratch' / 'wh3_export' / 'skel_cache'


# ------------------------------------------------------------------ GLB 读写

def read_glb(path):
    raw = Path(path).read_bytes()
    assert raw[:4] == b'glTF'
    jlen, jtype = struct.unpack_from('<II', raw, 12)
    gltf = json.loads(raw[20:20 + jlen])
    off = 20 + jlen
    binbuf = b''
    while off < len(raw):
        clen, ctype = struct.unpack_from('<II', raw, off)
        chunk = raw[off + 8:off + 8 + clen]
        if ctype == 0x004E4942:
            binbuf = chunk
            break
        off += 8 + clen
    return gltf, binbuf


def write_glb(path, gltf, binbuf):
    if binbuf:
        gltf['buffers'] = [{'byteLength': len(binbuf)}]
    jb = json.dumps(gltf, separators=(',', ':')).encode()
    jb += b' ' * (-len(jb) % 4)
    bb = binbuf + b'\x00' * (-len(binbuf) % 4)
    total = 12 + 8 + len(jb) + (8 + len(bb) if bb else 0)
    out = [b'glTF' + struct.pack('<II', 2, total),
           struct.pack('<II', len(jb), 0x4E4F534A) + jb]
    if bb:
        out.append(struct.pack('<II', len(bb), 0x004E4942) + bb)
    Path(path).write_bytes(b''.join(out))


class BinAppender:
    def __init__(self, gltf, binbuf):
        self.gltf = gltf
        self.bin = bytearray(binbuf)
        self.gltf.setdefault('bufferViews', [])
        self.gltf.setdefault('accessors', [])

    def acc(self, arr, ctype, minmax=False):
        data = arr.tobytes()
        pad = -len(self.bin) % 4
        if pad:
            self.bin += b'\x00' * pad
        off = len(self.bin)
        self.bin += data
        bv = len(self.gltf['bufferViews'])
        self.gltf['bufferViews'].append(
            {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)})
        a = {'bufferView': bv, 'componentType': COMP_F32,
             'count': len(arr), 'type': ctype}
        if minmax:
            a['min'] = [float(x) for x in np.asarray(arr).reshape(len(arr), -1).min(0)]
            a['max'] = [float(x) for x in np.asarray(arr).reshape(len(arr), -1).max(0)]
        self.gltf['accessors'].append(a)
        return len(self.gltf['accessors']) - 1


# ------------------------------------------------------------------ 骨架匹配

def _skel_bones(skel_name):
    """骨架名 -> (骨名集合, skel dict)，缓存到 scratch。"""
    SKEL_CACHE.mkdir(parents=True, exist_ok=True)
    lp = SKEL_CACHE / ('skel_%s.anim' % skel_name)
    if not lp.exists():
        try:
            _n, payload = X.resolve_payload(
                'animations/skeletons/%s.anim' % skel_name, SKEL_CACHE)
        except Exception:
            return None
        lp.write_bytes(payload)
    try:
        sk = parse_anim(lp)
    except Exception:
        return None
    return set(b['name'] for b in sk['bones']), sk


import os.path

def _name_affinity(skel_name, unit_token):
    """骨架名与单位名的亲和度：czx_<前缀> 常为截断前缀，取公共前缀长+包含加分。"""
    a = 'czx_' + unit_token if unit_token else ''
    s = skel_name
    cp = len(os.path.commonprefix([a, s]))
    bonus = 0
    tail = s[4:] if s.startswith('czx_') else s
    if tail and (tail in unit_token or unit_token in tail):
        bonus = len(tail)
    return cp + bonus


def detect_skeleton(node_names, unit_token=''):
    """GLB 节点名集合 -> (skel_name, skel dict, hit_count, coverage)"""
    cand = [Path(n).stem for n in X.grep_pack('animations/skeletons/')
            if n.endswith('.anim') and '/' not in
            n.split('skeletons/')[1].strip('/')]
    scored = []
    for name in cand:
        r = _skel_bones(name)
        if not r:
            continue
        bset, sk = r
        hit = len(set(node_names) & bset)
        cov = hit / max(1, len(bset))
        aff = _name_affinity(name, unit_token)
        scored.append((name, sk, hit, cov, aff))
    scored.sort(key=lambda t: (t[2], t[4], t[3]), reverse=True)
    return scored


# clip 语义挑选表：(stem 子串, 每类最多取几条)
CLIP_WANT = [
    ('stand_idle_01', 1), ('stand_idle_02', 1),
    ('combat_walk_01', 1), ('walk_01', 1), ('run_01', 1), ('charge_01', 1),
    ('attack_01', 1), ('attack_02', 1), ('attack_03', 1),
    ('hit_01', 1), ('death_01', 1), ('celebrate_01', 1),
]


def pick_clips(skel_name, anim_dir, limit):
    """从 animations/battle/<skel>/ 全树按语义挑 clip；目录为空时回退同 hit 骨架。"""
    hits = [n for n in X.grep_pack('animations/battle/%s/' % skel_name)
            if n.endswith('.anim')]
    if anim_dir:
        hits = [n for n in hits
                if ('/' + anim_dir + '/') in n or n.split('battle/')[1].split('/')[1] == anim_dir]
    picked = []
    for pat, cap in CLIP_WANT:
        got = 0
        for n in hits:
            if n in picked:
                continue
            stem = Path(n).stem
            if pat in stem and 'pose' not in stem:
                picked.append(n)
                got += 1
                if got >= cap:
                    break
        if len(picked) >= limit:
            break
    return picked[:limit]


# ------------------------------------------------------------------ 注入

def inject(gltf, binbuf, skel, clip_refs):
    name2node = {}
    for i, n in enumerate(gltf['nodes']):
        nm = n.get('name')
        if nm and 'mesh' not in n:
            name2node[nm] = i
    skel_frame = skel['frames'][0]
    skel_bone = {b['name']: i for i, b in enumerate(skel['bones'])}
    rest_pos = skel_frame['positions']
    app = BinAppender(gltf, binbuf)
    gltf.setdefault('animations', [])

    # 平移缩放基准：GLB root rest 长 / 骨架 root rest 长
    gscale = 1.0
    for rn in ('root', 'animroot', 'pelvis'):
        ni = name2node.get(rn)
        bi = skel_bone.get(rn)
        if ni is None or bi is None:
            continue
        g = np.asarray(gltf['nodes'][ni].get('translation', [0, 0, 0]),
                       dtype=np.float64)
        s = np.asarray(rest_pos[bi], dtype=np.float64)
        if np.linalg.norm(s) > 1e-6:
            gscale = float(np.linalg.norm(g) / np.linalg.norm(s)) or 1.0
            break

    results = []
    for cref in clip_refs:
        try:
            cin, cpl = X.resolve_payload(cref, SKEL_CACHE)
            cfile = SKEL_CACHE / cin.replace('/', '__')
            if not cfile.exists():
                cfile.write_bytes(cpl)
            clip = X.parse_anim_clip(cfile)
        except Exception as exc:
            results.append((str(cref), 'resolve fail: %s' % exc))
            continue
        if clip['skeleton_name'] != skel['skeleton_name']:
            results.append((cin, 'skeleton mismatch %s' % clip['skeleton_name']))
            continue
        part_idx = max(range(len(clip['parts'])),
                       key=lambda i: len(clip['parts'][i]['frames']))
        nf = len(clip['parts'][part_idx]['frames'])
        if nf == 0:
            results.append((cin, '0 frames (pose file)'))
            continue
        rate = clip['frame_rate'] or 20.0
        times = np.arange(nf, dtype=np.float32) / rate
        a_t = app.acc(times, 'SCALAR', minmax=True)
        samplers, channels = [], []
        kept = 0
        for cb, b in enumerate(clip['bones']):
            ni = name2node.get(b['name'])
            if ni is None:
                continue
            poss = np.zeros((nf, 3), dtype=np.float32)
            quats = np.zeros((nf, 4), dtype=np.float32)
            prev = None
            for f in range(nf):
                pos, quat = X.resolve_locals(clip, part_idx, f, skel_frame)
                p, q = pos[cb], X.qnorm(quat[cb])
                if prev is not None and sum(a_ * b_ for a_, b_ in zip(q, prev)) < 0:
                    q = [-x for x in q]
                prev = q
                poss[f] = p
                quats[f] = q
            a_q = app.acc(quats, 'VEC4')
            samplers.append({'input': a_t, 'interpolation': 'LINEAR',
                             'output': a_q})
            channels.append({'sampler': len(samplers) - 1,
                             'target': {'node': ni, 'path': 'rotation'}})
            # 平移：仅 clip 中真实运动的骨注入轨道；GLB rest 锚定 + rest 长度比缩放
            move = np.abs(poss - poss[0]).max()
            if move > 1e-4:
                bi = skel_bone.get(b['name'])
                s_rest = np.asarray(rest_pos[bi], dtype=np.float64)                     if bi is not None else np.zeros(3)
                g_rest = np.asarray(
                    gltf['nodes'][ni].get('translation', [0, 0, 0]),
                    dtype=np.float64)
                s_b = (np.linalg.norm(g_rest) / np.linalg.norm(s_rest)
                       if np.linalg.norm(s_rest) > 1e-6 else gscale)
                if not np.isfinite(s_b) or s_b <= 0:
                    s_b = gscale
                poss_out = g_rest + (poss - poss[0]) * s_b
                a_p = app.acc(poss_out.astype(np.float32), 'VEC3')
                samplers.append({'input': a_t, 'interpolation': 'LINEAR',
                                 'output': a_p})
                channels.append({'sampler': len(samplers) - 1,
                                 'target': {'node': ni,
                                            'path': 'translation'}})
            kept += 1
        if not kept:
            results.append((cin, 'no bone tracks matched GLB nodes'))
            continue
        gltf['animations'].append({'name': Path(str(cref)).stem,
                                   'samplers': samplers, 'channels': channels})
        results.append((cin, 'ok %d frames %d bones' % (nf, kept)))
    return app, results


def strip_anims(gltf, binbuf):
    """剥掉全部 animations 并压实 BIN（移除孤儿 accessor/bufferView）。"""
    if not gltf.get('animations'):
        return binbuf
    used_acc = set()
    for m in gltf.get('meshes', []):
        for pr in m.get('primitives', []):
            used_acc.update(pr.get('attributes', {}).values())
            if 'indices' in pr:
                used_acc.add(pr['indices'])
            for t in pr.get('targets', []):
                used_acc.update(t.values())
    for s in gltf.get('skins', []):
        if 'inverseBindMatrices' in s:
            used_acc.add(s['inverseBindMatrices'])
    accs = gltf.get('accessors', [])
    used_bv = set()
    for ai in used_acc:
        bv = accs[ai].get('bufferView')
        if bv is not None:
            used_bv.add(bv)
    for img in gltf.get('images', []):
        if 'bufferView' in img:
            used_bv.add(img['bufferView'])
    bv_sorted = sorted(used_bv)
    nb = bytearray()
    bv_new_off = {}
    for bvi in bv_sorted:
        bv = gltf['bufferViews'][bvi]
        off = bv.get('byteOffset', 0)
        pad = -len(nb) % 4
        nb += b'\x00' * pad
        bv_new_off[bvi] = len(nb)
        nb += binbuf[off:off + bv['byteLength']]
    bv_idx = {o: i for i, o in enumerate(bv_sorted)}
    gltf['bufferViews'] = [dict(gltf['bufferViews'][o], byteOffset=bv_new_off[o])
                           for o in bv_sorted]
    acc_sorted = sorted(used_acc)
    acc_idx = {o: i for i, o in enumerate(acc_sorted)}
    gltf['accessors'] = [dict(accs[o],
                             **({'bufferView': bv_idx[accs[o]['bufferView']]}
                                if 'bufferView' in accs[o] else {}))
                         for o in acc_sorted]
    for m in gltf.get('meshes', []):
        for pr in m.get('primitives', []):
            pr['attributes'] = {k: acc_idx[v]
                                for k, v in pr['attributes'].items()}
            if 'indices' in pr:
                pr['indices'] = acc_idx[pr['indices']]
            if 'targets' in pr:
                pr['targets'] = [{k: acc_idx[v] for k, v in t.items()}
                                 for t in pr['targets']]
    for s in gltf.get('skins', []):
        if 'inverseBindMatrices' in s:
            s['inverseBindMatrices'] = acc_idx[s['inverseBindMatrices']]
    for img in gltf.get('images', []):
        if 'bufferView' in img:
            img['bufferView'] = bv_idx[img['bufferView']]
    gltf['animations'] = []
    return bytes(nb)

def main():
    args = sys.argv[1:]
    if len(args) < 1:
        print(__doc__)
        return
    inp = Path(args[0])
    if len(args) > 1 and args[1].endswith('.glb'):
        out, i = Path(args[1]), 2
    else:
        out, i = inp, 1
    skel_name, clips, anim_dir, limit, dry, strip = 'auto', 'auto', '', 10, False, False
    while i < len(args):
        a = args[i]
        if a == '--skeleton':
            skel_name = args[i + 1]; i += 2
        elif a == '--clips':
            clips = args[i + 1]; i += 2
        elif a == '--anim-dir':
            anim_dir = args[i + 1]; i += 2
        elif a == '--limit':
            limit = int(args[i + 1]); i += 2
        elif a == '--strip':
            strip = True; i += 1
        elif a == '--dry':
            dry = True; i += 1
        else:
            print('unknown arg', a); i += 1

    gltf, binbuf = read_glb(inp)
    node_names = [n.get('name', '') for n in gltf['nodes']]

    if skel_name == 'auto':
        unit_token = inp.stem
        for pre in ('czx_dgm_', 'czx_pkm_', 'pkm_', 'wargreymon_'):
            if unit_token.startswith(pre):
                unit_token = unit_token[len(pre):]
                break
        unit_token = unit_token.replace('_bound', '')
        unit_token = ''.join(c for c in unit_token if not c.isdigit()).strip('_')
        print('detecting skeleton over %d nodes (unit=%s)...'
              % (len(node_names), unit_token))
        cands = detect_skeleton(node_names, unit_token)
        if not cands or cands[0][2] == 0:
            raise RuntimeError('no skeleton matched')
        skel_name, skel, hit, cov = cands[0][:4]
        clip_refs = pick_clips(skel_name, anim_dir, limit)
        for name, sk2, h2, c2, _a in cands:
            if clip_refs:
                break
            skel_name, skel, hit, cov = name, sk2, h2, c2
            clip_refs = pick_clips(skel_name, anim_dir, limit)
        print('skeleton=%s hit=%d cov=%.2f' % (skel_name, hit, cov))
    else:
        r = _skel_bones(skel_name)
        if not r:
            raise RuntimeError('skeleton not in pack: ' + skel_name)
        _bset, skel = r
        hit = len(set(node_names) & _bset)
        print('skeleton=%s hit=%d' % (skel_name, hit))
        clip_refs = pick_clips(skel_name, anim_dir, limit)

    if clips != 'auto':
        clip_refs = clips.split(',')
    print('clips:', clip_refs)

    if dry:
        return
    if strip:
        binbuf = strip_anims(gltf, binbuf)
        print('stripped anims, bin ->', len(binbuf))
    app, results = inject(gltf, binbuf, skel, clip_refs)
    for r in results:
        print('  ', r)
    write_glb(out, gltf, bytes(app.bin))
    print('wrote', out, Path(out).stat().st_size, 'bytes,',
          len(gltf.get('animations', [])), 'anims total')


if __name__ == '__main__':
    main()
