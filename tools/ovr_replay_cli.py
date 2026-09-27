#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ovr_replay_cli.py — wfix.ovr 补丁档独立 GLB 重放器（验收窗/lacy 用）

不走 bind/featbone 重建链，直接把 <unit>/wfix.ovr.json 重放进 bound GLB：
  rest_scale_fix  —— 节点层：档列 node.scale→1 + 子树全后代 T 吸收
                     + ibm_redo 关节 IBM=inv(W') 重写（rest 位 ε 守卫内建）
  谓词/模式补丁   —— JOINTS_0/WEIGHTS_0 slots→dense→apply_patches→top4
                     回写（跨 skin 联合骨名空间；补丁引到 skin 外骨名时
                     自动扩 joints 并补 IBM=inv(W_node)）
  jmap_ovr        —— CLI 无 map 层，记 skipped（属写器映射阶段语义）

用法：
  python tools/ovr_replay_cli.py <glb|unit> [more...]
  python tools/ovr_replay_cli.py --all [--dry] [--report out.json]

  --all     批扫 ovr_patches/ 下全部 wfix.ovr.json 档
  --dry     全量演算+守卫记账，零写盘
  --report  汇总 JSON 落盘路径
真实写盘前先备份 <glb>.bak_ovr（备份已存在则不覆盖）。
"""
import argparse
import json
import os
import shutil
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np          # noqa: E402
import dgm_automap as am    # noqa: E402
import wfix_ovr_replay as wovr  # noqa: E402
from dgm_featbone import acc_write, MODELS  # noqa: E402

OVR_DIR = os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), 'scratch', 'pipeline',
    'dgm_audit', 'ovr_patches')


def resolve_glb(arg):
    """arg = glb 路径或 unit 名 → (glb_path, unit) 或 None。"""
    if arg.lower().endswith('.glb') and os.path.exists(arg):
        return arg, os.path.splitext(os.path.basename(arg))[0]
    for cand in (os.path.join(MODELS, arg + '.glb'),
                 os.path.join(MODELS, arg + '_bound.glb')):
        if os.path.exists(cand):
            return cand, os.path.splitext(os.path.basename(cand))[0]
    return None


def load_ovr_flex(unit):
    """unit 可能带/不带 _bound 后缀——两侧都试。"""
    ovr, p = wovr.load_ovr(unit)
    if ovr is None and unit.endswith('_bound'):
        ovr, p = wovr.load_ovr(unit[:-6])
    return ovr, p


def replay_glb(glb_path, unit, dry=False):
    rep = {'glb': glb_path, 'unit': unit}
    ovr, ovr_path = load_ovr_flex(unit)
    if not ovr:
        rep['skip'] = 'no wfix.ovr.json'
        return rep
    rep['ovr_path'] = ovr_path
    g, binb0 = am.read_glb(glb_path)
    binb = bytearray(binb0)
    dirty = False

    # ── 1) rest_scale_fix：节点层归一（先于权重层——操作域正交）
    rs = wovr.apply_rest_scale_fix(g, ovr)
    rep['rest_scale_fix'] = rs
    _, wmat = wovr._world_idx(g)
    redo = set(rs['ibm_redo']) if rs else set()
    ibm_over = {}                      # skin idx -> {local_ji: inv(W')}
    if redo:
        for si, sk in enumerate(g.get('skins', [])):
            for ji, jn in enumerate(sk['joints']):
                nm = g['nodes'][jn].get('name')
                if nm in redo:
                    ibm_over.setdefault(si, {})[ji] = np.linalg.inv(
                        wmat(jn))
        dirty = dirty or bool(ibm_over)

    # ── 2) 权重补丁（jmap_ovr/rest_scale_fix 以外的 kind/pred/mode）
    wpatch = [p for p in ovr.get('patches', [])
              if p.get('kind') not in ('jmap_ovr', 'rest_scale_fix')
              or p.get('pred') or p.get('mode')]
    if wpatch:
        names, jidx = [], {}
        for sk in g.get('skins', []):
            for j in sk['joints']:
                nm = g['nodes'][j].get('name')
                if nm not in jidx:
                    jidx[nm] = len(names)
                    names.append(nm)
        prims, pos_all, off = [], [], 0
        for ni, n in enumerate(g['nodes']):
            if 'mesh' not in n or 'skin' not in n:
                continue
            sk = g['skins'][n['skin']]
            local = [g['nodes'][j].get('name') for j in sk['joints']]
            Wn = wmat(ni)
            for pi, p in enumerate(
                    g['meshes'][n['mesh']].get('primitives', [])):
                at = p.get('attributes', {})
                if 'JOINTS_0' not in at or 'WEIGHTS_0' not in at:
                    continue
                pos = am.acc(g, binb0, at['POSITION'])
                pos = pos @ Wn[:3, :3].T + Wn[:3, 3]
                prims.append((ni, pi, p, local, off, len(pos)))
                pos_all.append(pos)
                off += len(pos)
        if prims:
            pos_cat = np.vstack(pos_all)
            W = np.zeros((off, len(names)), np.float32)
            pid = np.full(off, -1, np.int32)
            for ni, pi, p, local, o, nv in prims:
                at = p['attributes']
                jj = am.acc(g, binb0, at['JOINTS_0']).astype(np.int64)
                ww = am.acc(g, binb0, at['WEIGHTS_0'])
                cols = np.array([jidx[x] for x in local])
                for k in range(4):
                    m = jj[:, k] < len(local)
                    W[o + np.nonzero(m)[0], cols[jj[m, k]]] += ww[m, k]
                pid[o:o + nv] = pi
            W0 = W.copy()
            bpos = wovr.bind_positions(g, binb, am.acc)
            orep = wovr.apply_patches(W, names, pos_cat, bpos, ovr,
                                      prim_id=pid)
            orep['path'] = ovr_path
            orep['guard'] = wovr.weight_guard(
                names, W0, names, W, dom_exclude={'animroot'})
            rep['wfix_ovr'] = orep
            dirty = dirty or bool(orep['applied'])
            # 回写：top4 按各 skin 局部 joints 空间量化；补丁引到 skin
            # 外骨名时扩 joints（IBM 补 inv(W_node) 入 ibm_over）
            lidx = {nm: i for i, nm in enumerate(names)}
            for ni, pi, p, local, o, nv in prims:
                n = g['nodes'][ni]
                si = n['skin']
                sk = g['skins'][si]
                Wp = W[o:o + nv]
                top = np.argsort(-Wp, axis=1)[:, :4]
                need = sorted({names[c] for c in np.unique(top)
                               if Wp[:, c].max() > 1e-6
                               and names[c] not in set(local)})
                for nm in need:
                    ti = next((i for i, x in enumerate(g['nodes'])
                               if x.get('name') == nm), None)
                    if ti is None:
                        continue
                    sk['joints'].append(ti)
                    local.append(nm)
                    ibm_over.setdefault(si, {})[len(local) - 1] = \
                        np.linalg.inv(wmat(ti))
                lcol = np.array([jidx[x] for x in local])
                J = np.zeros((nv, 4), np.uint16)
                Wq = np.zeros((nv, 4), np.float32)
                ar = np.arange(nv)
                for k in range(4):
                    c = top[:, k]
                    J[:, k] = [local.index(names[x]) for x in c]
                    Wq[:, k] = Wp[ar, c]
                Wq /= np.maximum(Wq.sum(1, keepdims=True), 1e-9)
                at = p['attributes']
                at['JOINTS_0'] = acc_write(g, binb, J, 5123, 'VEC4')
                at['WEIGHTS_0'] = acc_write(g, binb, Wq, 5126, 'VEC4')
                dirty = True

    # ── 3) IBM accessor 统一重写（rest_scale 逆补偿 + joints 扩展补偿）
    for si, ov in ibm_over.items():
        sk = g['skins'][si]
        old = np.asarray(
            am.acc(g, binb, sk['inverseBindMatrices']),
            np.float32).reshape(-1, 16).copy()
        al = np.zeros((len(sk['joints']), 16), np.float32)
        al[:len(old)] = old
        for ji, m in ov.items():
            al[ji] = np.asarray(m, np.float32).T.reshape(16)
        sk['inverseBindMatrices'] = acc_write(g, binb, al, 5126, 'MAT4')

    rep['dirty'] = dirty
    rep['risk'] = bool(
        (rs and (rs['rest_world_viol'] or rs['missing']))
        or rep.get('wfix_ovr', {}).get('guard', {}).get('risk'))
    if dry or not dirty:
        rep['written'] = False
        return rep
    bak = glb_path + '.bak_ovr'
    if not os.path.exists(bak):
        shutil.copy2(glb_path, bak)
    rep['backup'] = bak
    g['buffers'][0]['byteLength'] = len(binb)
    jout = json.dumps(g, separators=(',', ':')).encode()
    jout += b' ' * ((4 - len(jout) % 4) % 4)
    bout = bytes(binb) + b'\x00' * ((4 - len(binb) % 4) % 4)
    total = 12 + 8 + len(jout) + 8 + len(bout)
    out = b'glTF' + struct.pack('<II', 2, total) + \
        struct.pack('<I', len(jout)) + b'JSON' + jout + \
        struct.pack('<I', len(bout)) + b'BIN\x00' + bout
    open(glb_path, 'wb').write(out)
    rep['written'] = True
    return rep


def main():
    ap = argparse.ArgumentParser(description='wfix.ovr GLB 重放器')
    ap.add_argument('targets', nargs='*',
                    help='glb 路径或 unit 名（可多个）')
    ap.add_argument('--all', action='store_true',
                    help='批扫 ovr_patches/ 全部档')
    ap.add_argument('--dry', action='store_true', help='只演算不写盘')
    ap.add_argument('--report', help='汇总 JSON 落盘路径')
    a = ap.parse_args()
    targets = list(a.targets)
    if a.all:
        for d in sorted(os.listdir(OVR_DIR)):
            if os.path.exists(os.path.join(OVR_DIR, d, 'wfix.ovr.json')):
                targets.append(d)
    reps = []
    for t in targets:
        rv = resolve_glb(t)
        if rv is None:
            print(f'{t:40s} SKIP 找不到 glb')
            reps.append({'unit': t, 'skip': 'no glb'})
            continue
        glb, unit = rv
        try:
            r = replay_glb(glb, unit, dry=a.dry)
        except Exception:
            import traceback
            traceback.print_exc()
            reps.append({'unit': unit, 'error': 'exception'})
            continue
        reps.append(r)
        rs = r.get('rest_scale_fix') or {}
        wo = r.get('wfix_ovr') or {}
        print('%-40s rs_fixed=%-3d viol=%-3d wfix_applied=%-6s stale=%-3s '
              'risk=%s %s' % (
                  unit, len(rs.get('fixed', [])), len(rs.get(
                      'rest_world_viol', [])),
                  wo.get('applied'), len(wo.get('stale', [])),
                  r.get('risk'),
                  'DRY' if a.dry else ('WRITTEN' if r.get('written')
                                       else 'clean/noop')))
    if a.report:
        json.dump(reps, open(a.report, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print('report ->', a.report)


if __name__ == '__main__':
    main()
