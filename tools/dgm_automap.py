# -*- coding: utf-8 -*-
"""Auto-build src->tgt bone map by WEIGHT CORRELATION on shared geometry.

For each source skin joint s (from the CS source GLB) and target joint t
(bound.glb skin), accumulate  W[s,t] = sum_v w_s(v) * w_t(v)  over matched
vertex pairs (each bound vert -> nearest source vert in normalised space).
map[s] = argmax_t W[s,t].  Robust to rest-pose and joint-origin differences:
it matches flesh to flesh, not joint to joint.

  source glb : scratch/dgm_pub_src/glb/<report.glb>  (or salzaar fallback)
  target glb : models/<u>_bound.glb
  out        : scratch/dgm_srcanim/<u>/map.json + automap_report.json

usage: dgm_automap.py [unit ...]     (default: units_nojmap.json)
       pass any unit key to compare against its existing jmap.json
"""
import json, os, re, struct, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, 'scratch', 'dgm_srcanim')
BATCH = os.path.join(ROOT, 'scratch', 'dgm_pub_batch')
MODELS = 'E:/Code/model-studio/models'
SRC_GLB_DIRS = [os.path.join(ROOT, 'scratch', 'dgm_pub_src', 'glb'),
                os.path.join(ROOT, 'scratch', 'salzaar_digimon', 'glb')]

ROOTISH = re.compile(
    r'^(J_root|GRP_joint|GRP_root|GRP_mesh|prefab|chr\d+|.*\.\d+|Dot)$')
CENTERISH = re.compile(r'^(J_center|J_pelvis|center|pelvis|hips|J_hips)$',
                       re.I)
AUX_TGT = re.compile(
    r'prop|cape|skirt|belt|cloth|flag|tabard|fx_|icon|camera|weapon|shield'
    r'|quiver|scabbard|attach|slot|mount|platform|banner|be_prop|_end$',
    re.I)
# candidate orientation fixes for source GLBs (CS exports vary):
#   I raw | C  z-up(+Z up) | C2 z-up(-Z up) | C3 z-up(-Z up,-Y fwd)
ORIENTS = {
    'raw': np.eye(3),
    'zup+': np.array([[1., 0., 0.], [0., 0., 1.], [0., -1., 0.]]),
    'zup-': np.array([[1., 0., 0.], [0., 0., -1.], [0., 1., 0.]]),
    'zupf': np.array([[1., 0., 0.], [0., 0., -1.], [0., -1., 0.]]),
}
C = ORIENTS['zup+']


def normalize_v(pos):
    lo = pos.min(0)
    return (pos - lo) / max(1e-9, (pos.max(0) - lo)[1])


def nn_median(a, b):
    idx = np.empty(len(a), np.int64)
    for i0 in range(0, len(a), 512):
        blk = a[i0:i0 + 512]
        d = ((blk[:, None, :] - b[None, :, :]) ** 2).sum(-1)
        idx[i0:i0 + 512] = d.argmin(1)
    return np.median(np.sqrt(((a - b[idx]) ** 2).sum(1))), idx


def best_orient(tn, spos):
    """pick the source->target orientation with lowest NN median."""
    best = ('raw', 1e9, None)
    for name, M in ORIENTS.items():
        sn = normalize_v(spos @ M)
        med, _ = nn_median(tn[:2000], sn)
        if med < best[1]:
            best = (name, float(med), sn)
    return best[0], best[1], best[2]


def read_glb(path):
    d = open(path, 'rb').read()
    jl = struct.unpack('<I', d[12:16])[0]
    g = json.loads(d[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', d[off:off + 4])[0]
    return g, d[off + 8:off + 8 + bl]


def acc(g, binb, ai):
    a = g['accessors'][ai]
    bv = g['bufferViews'][a['bufferView']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    ncomp = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4,
             'MAT4': 16}[a['type']]
    dt = {5120: np.int8, 5121: np.uint8, 5122: np.int16,
          5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a['componentType']]
    return np.frombuffer(binb, dtype=dt, count=a['count'] * ncomp,
                         offset=off).reshape(a['count'], ncomp).astype(
                             np.float32)


def skin_data(g, binb):
    """-> (joint_names[list], vert_pos Nx3, W NxJ) concatenated over
    skinned prims; W columns live in a union joint-name space so multiple
    skins are handled correctly."""
    if not g.get('skins'):
        return [], None, None
    jnames = []          # global joint-name space
    jidx = {}            # name -> column
    for sk in g['skins']:
        for j in sk['joints']:
            nm = g['nodes'][j].get('name')
            if nm not in jidx:
                jidx[nm] = len(jnames)
                jnames.append(nm)
    out_pos, out_w = [], []
    nodes = g.get('nodes', [])
    par = {}
    for i, n in enumerate(nodes):
        for c in n.get('children', []):
            par[c] = i

    def lmat(n):
        if 'matrix' in n:
            return np.array(n['matrix']).reshape(4, 4).T
        x, y, z, w = n.get('rotation', [0, 0, 0, 1])
        R = np.array([
            [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
            [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
            [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
        s = np.array(n.get('scale', [1, 1, 1]))
        m = np.eye(4)
        m[:3, :3] = R * s[None, :]
        m[:3, 3] = n.get('translation', [0, 0, 0])
        return m
    wc = {}

    def wmat(i):
        if i not in wc:
            wc[i] = lmat(nodes[i]) if par.get(i) is None \
                else wmat(par[i]) @ lmat(nodes[i])
        return wc[i]
    for ni, n in enumerate(nodes):
        if 'mesh' not in n or 'skin' not in n:
            continue
        sk = g['skins'][n['skin']]
        local = [g['nodes'][j].get('name') for j in sk['joints']]
        nm = wmat(ni)
        for p in g['meshes'][n['mesh']].get('primitives', []):
            at = p.get('attributes', {})
            if 'JOINTS_0' not in at or 'WEIGHTS_0' not in at:
                continue
            pos = acc(g, binb, at['POSITION'])
            pos = pos @ nm[:3, :3].T + nm[:3, 3]   # mesh-local -> world
            jj = acc(g, binb, at['JOINTS_0']).astype(int)
            ww = acc(g, binb, at['WEIGHTS_0'])
            W = np.zeros((len(pos), len(jnames)), np.float32)
            for k in range(4):
                v = jj[:, k] < len(local)
                cols = np.array([jidx[local[j]] for j in jj[v, k]])
                W[np.nonzero(v)[0], cols] += ww[v, k]
            out_pos.append(pos)
            out_w.append(W)
    if not out_pos:
        return jnames, None, None
    return jnames, np.vstack(out_pos), np.vstack(out_w)


def normalize(pos):
    lo, hi = pos.min(0), pos.max(0)
    span = hi - lo
    zup = span[2] > 2 * span[1]
    p = pos @ C if zup else pos.copy()
    lo, hi = p.min(0), p.max(0)
    return (p - lo) / max(1e-9, (hi - lo)[1]), zup


def build_map(unit, glb_name):
    g, b = read_glb(os.path.join(MODELS, unit + '_bound.glb'))
    tnames, tpos, tW = skin_data(g, b)
    if tpos is None:
        return None, 'no tgt skin'
    src_path = None
    for d in SRC_GLB_DIRS:
        p = os.path.join(d, glb_name)
        if os.path.exists(p):
            src_path = p
            break
    if not src_path:
        return None, 'no src glb: ' + glb_name
    gs, bs = read_glb(src_path)
    snames, spos, sW = skin_data(gs, bs)
    if spos is None:
        return None, 'no src skin'

    tn = normalize_v(tpos)
    o_name, o_med, sn = best_orient(tn, spos)
    # nearest src vert for each tgt vert
    _, src_nn = nn_median(tn, sn)
    # W[s,t] correlation
    Wc = sW[src_nn].T @ tW           # J_src x J_tgt
    s_mass = Wc.sum(1) + 1e-9
    best_t = Wc.argmax(1)
    conf = Wc[np.arange(len(snames)), best_t] / s_mass

    jmap, rep = {}, []
    for i, sn in enumerate(snames):
        if ROOTISH.match(sn or ''):
            jmap[sn] = 'animroot'
            rep.append((sn, 'animroot', 1.0))
            continue
        if CENTERISH.match(sn or ''):
            jmap[sn] = 'root'
            rep.append((sn, 'root', 1.0))
            continue
        tn_ = tnames[best_t[i]] if best_t[i] < len(tnames) else None
        if conf[i] > 0.08 and tn_ and not AUX_TGT.search(tn_):
            jmap[sn] = tn_
        rep.append((sn, tn_, round(float(conf[i]), 3)))
    root_src = None
    for cand in ('J_center', 'J_root'):
        if jmap.get(cand) == 'root':
            root_src = cand
            break
    if root_src is None:
        for sn, tn_ in jmap.items():
            if tn_ == 'root':
                root_src = sn
                break
    if root_src is None:
        return None, 'NO ROOT SRC'
    jmap = {root_src: 'root',
            **{k: v for k, v in jmap.items() if k != root_src}}
    jmap['_root_src'] = root_src
    jmap['_root_tgt'] = 'root'
    info = {'src_glb': src_path, 'orient': o_name, 'nn_med': round(o_med, 4),
            'mapped': len(jmap) - 2, 'src_joints': len(snames),
            'tgt_used': len(set(v for k, v in jmap.items()
                                if not k.startswith('_'))),
            'tgt_total': len(tnames),
            'unmatched': [r[0] for r in rep
                          if r[1] is None or r[2] <= 0.08],
            'low_conf': [r for r in rep if 0.08 < r[2] < 0.4],
            'report': rep}
    return jmap, info


def main():
    args = sys.argv[1:]
    units = args or json.load(open(os.path.join(SA, 'units_nojmap.json')))
    rep_all = json.load(open(os.path.join(BATCH, 'report.json'),
                             encoding='utf-8'))
    summ = {}
    for u in units:
        glb_name = rep_all.get(u, {}).get('glb')
        if not glb_name:
            summ[u] = 'no report glb'
            continue
        jm, info = build_map(u, glb_name)
        if jm is None:
            summ[u] = info
            print(u, 'FAIL', info)
            continue
        json.dump(jm, open(os.path.join(SA, u, 'map.json'), 'w'), indent=1)
        info.pop('report', None)
        summ[u] = info
        print(u, 'mapped', info['mapped'], '/', info['src_joints'],
              '-> tgt', info['tgt_used'], '/', info['tgt_total'],
              '| unmatched', len(info['unmatched']),
              '| lowconf', len(info['low_conf']))
    json.dump(summ, open(os.path.join(SA, 'automap_summary.json'), 'w'),
              indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
