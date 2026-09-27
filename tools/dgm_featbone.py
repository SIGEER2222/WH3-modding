# -*- coding: utf-8 -*-
"""Composite-skeleton surgery: add feature bones (tail/ear/whisker/wing/...),
fix semantically-wrong map entries, rebuild skin weights from SOURCE weights.

Why:  hu1-family bound rigs (72j) lack bones for quadruped/tailed anatomy, so
tail/ear flesh sat on leg/skirt bones (weight debt) and src anims drove wrong
bones.  Here we create the missing joints in bound.glb, translate src skin
weights through a corrected map, and rewrite JOINTS_0/WEIGHTS_0.

New-bone bind placement:
  pos  = src joint position from inv(srcIBM), mapped through the automap
         orientation + normalize -> tgt space (flesh-verified, nn_med~0).
  rot  = orthonormal frame, +Y down the chain (injection's dq@rest transplant
         reproduces the src delta exactly; orientation of rest only shifts
         local frames).
  IBM  = inv(new joint rest world) -> verts stay put at rest.

usage: dgm_featbone.py <unit> [<unit> ...] [--dry]
"""
import json, os, re, struct, sys, shutil
import numpy as np
import importlib.util

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, 'scratch', 'dgm_srcanim')
BATCH = os.path.join(ROOT, 'scratch', 'dgm_pub_batch')
MODELS = 'E:/Code/model-studio/models'
SRC_GLB_DIRS = [os.path.join(ROOT, 'scratch', 'dgm_pub_src', 'glb'),
                os.path.join(ROOT, 'scratch', 'salzaar_digimon', 'glb')]

spec = importlib.util.spec_from_file_location(
    'am', os.path.join(ROOT, 'tools', 'dgm_automap.py'))
am = importlib.util.module_from_spec(spec)
spec.loader.exec_module(am)

FAM_PATS = [(r'tail|hippo|shippo', 'tail'), (r'ear|mimi', 'ear'),
            (r'whisker|hige', 'whisker'), (r'wing|tuba|hane', 'wing'),
            (r'horn|tuno|angle', 'horn'), (r'fin|hire', 'fin'),
            (r'hair|kami', 'hair'), (r'tongue|bero', 'tongue'),
            (r'ribbon|muffler|scarf', 'cloth'), (r'cloth|mant', 'cloth'),
            (r'jaw|agito|mouth', 'jaw'), (r'breast|mune', 'breast'),
            (r'frill', 'frill'), (r'beard', 'beard'),
            (r'antenna|antena', 'antenna'), (r'needle|hari', 'needle'),
            (r'hizumi|hida', 'hida'), (r'tare', 'tare')]


def fam(s):
    s = s.lower()
    for p, f in FAM_PATS:
        if re.search(r'(^|_)(' + p + r')(_|\d|$)', s):
            return f
    return None


def side_of(s):
    s = s.lower()
    if re.search(r'(_l($|[\d_])|_left)', s):
        return 'l'
    if re.search(r'(_r($|[\d_])|_right)', s):
        return 'r'
    return ''


def fam_member(jname, f):
    return re.search(r'(^|_)' + f + r'(_|\d|$)', jname) is not None


# name-driven target preferences for non-feature remap fixes
NAME2TGT = {
    'j_head': ['head', 'neck_0'],
    'j_jaw': ['jaw', 'neck_0', 'head'],
    'j_mouth': ['jaw', 'head'],
    'j_neck': ['neck_0', 'spine_2', 'head'],
    'j_spine01': ['spine_0', 'spine_1', 'root'],
    'j_spine02': ['spine_1', 'spine_2', 'spine_0'],
    'j_spine03': ['spine_2', 'spine_1'],
    'j_eye_l': ['eye_left'], 'j_eye_r': ['eye_right'],
    'j_nose': ['head'], 'j_brow': ['eyebrow', 'head'],
    'j_teeth': ['jaw', 'head'], 'j_tongue': ['jaw'],
}
BAD_TGT = re.compile(
    r'eye|eyebrow|shoulder_pad|prop|cape|skirt|be_prop|fx_|attach', re.I)


def quat_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_quat(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1) * 2
        return np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s,
                         (m[1, 0] - m[0, 1]) / s, s / 4])
    i = int(np.argmax(np.diag(m)))
    j, k = (i + 1) % 3, (i + 2) % 3
    s = np.sqrt(max(1e-12, 1 + m[i, i] - m[j, j] - m[k, k])) * 2
    q = np.zeros(4)
    q[3] = (m[k, j] - m[j, k]) / s
    q[i] = s / 4
    q[j] = (m[j, i] + m[i, j]) / s
    q[k] = (m[k, i] + m[i, k]) / s
    return q / np.linalg.norm(q)


def lmat_of(n):
    if 'matrix' in n:
        return np.array(n['matrix'], dtype=np.float64).reshape(4, 4).T
    q = np.array(n.get('rotation', [0, 0, 0, 1]), dtype=np.float64)
    R = quat_mat(q / np.linalg.norm(q))
    s = np.array(n.get('scale', [1, 1, 1]), dtype=np.float64)
    m = np.eye(4)
    m[:3, :3] = R @ np.diag(s)
    m[:3, 3] = n.get('translation', [0, 0, 0])
    return m


def parents_of(g):
    par = {}
    for i, n in enumerate(g['nodes']):
        for c in n.get('children', []):
            par[c] = i
    return par


def acc_write(g, binb, arr, comptype, typ):
    data = arr.tobytes()
    off = len(binb)
    binb += data
    pad = (4 - len(binb) % 4) % 4
    binb += b'\x00' * pad
    g['bufferViews'].append({'buffer': 0, 'byteOffset': off,
                             'byteLength': len(data)})
    g['accessors'].append({'bufferView': len(g['bufferViews']) - 1,
                           'componentType': comptype,
                           'count': len(arr), 'type': typ})
    return len(g['accessors']) - 1


def run(unit, dry=False):
    bp = os.path.join(MODELS, unit + '_bound.glb')
    mp = os.path.join(SA, unit, 'map.json')
    rep = json.load(open(os.path.join(BATCH, 'report.json'), encoding='utf-8'))
    glb_name = rep[unit]['glb']
    # ---- dump rest worlds (needed early: src-glb file selection depends
    #      on matching IBM scale convention to the dump's)
    rest_src = {}
    rest_file = None
    for cand in ('src_anims_yup.json', 'src_anims.json'):
        p = os.path.join(SA, unit, cand)
        if os.path.exists(p):
            sd_ = json.load(open(p))
            rest_src = {k: np.array(v) for k, v in
                        sd_.get('rest', {}).items()}
            if rest_src:
                rest_file = cand
                break
    if not rest_src:
        return {'skip': 'no dump rest data'}

    # pick the src glb whose bind scale matches the dump rest scale
    # (identical flesh exists in multiple exports with different IBM
    #  unit conventions; wrong choice collapses verts to joints)
    rd = np.median([np.linalg.det(np.linalg.inv(
        np.array(rest_src[n])[:3, :3])) if abs(np.linalg.det(
            np.array(rest_src[n])[:3, :3])) > 1e-12 else np.nan
        for n in rest_src])
    rd = np.nan_to_num(rd, nan=1.0)
    sp = None
    gs = bs = None
    best = np.inf
    for d in SRC_GLB_DIRS:
        p = os.path.join(d, glb_name)
        if not os.path.exists(p):
            continue
        gg, bb = am.read_glb(p)
        det_ok = []
        for sk in gg.get('skins', []):
            ibm = am.acc(gg, bb, sk['inverseBindMatrices']).reshape(-1, 4, 4)
            for k_, j in enumerate(sk['joints']):
                nm = gg['nodes'][j].get('name')
                if nm in rest_src and abs(np.linalg.det(
                        np.array(rest_src[nm])[:3, :3])) > 1e-12:
                    det_ok.append(np.linalg.det(ibm[k_]))
        if not det_ok:
            continue
        score = abs(np.log10(max(np.median(det_ok), 1e-30)
                         / max(rd, 1e-30)))
        if score < best:
            best, sp, gs, bs = score, p, gg, bb
    if sp is None:
        return {'skip': 'no src glb'}
    g, binb0 = am.read_glb(bp)
    tnames, tpos, tW = am.skin_data(g, binb0)
    snames, spos, sW = am.skin_data(gs, bs)
    if tpos is None or spos is None:
        return {'skip': 'missing skin'}
    binb = bytearray(binb0)

    tn = am.normalize_v(tpos)
    o_name, o_med, sn = am.best_orient(tn, spos)
    if o_med > 0.05:
        return {'skip': f'nn_med {o_med:.3f} too large'}
    _, src_nn = am.nn_median(tn, sn)
    nn_dist = np.sqrt(((tn - sn[src_nn]) ** 2).sum(1))

    old_map = json.load(open(mp, encoding='utf-8'))
    spar_idx = parents_of(gs)
    spar = {gs['nodes'][i].get('name'): gs['nodes'][p].get('name')
            for i, p in spar_idx.items()}
    tpar = parents_of(g)
    tnode_name = {n.get('name'): i for i, n in enumerate(g['nodes'])}
    tset = set(tnode_name)

    # tgt node rest worlds
    tWc = {}

    def tWmat(i):
        if i not in tWc:
            lm = lmat_of(g['nodes'][i])
            tWc[i] = lm if tpar.get(i) is None else tWmat(tpar[i]) @ lm
        return tWc[i]
    for i in range(len(g['nodes'])):
        tWmat(i)

    # ---- src bind joint transforms (inv IBM, first skin covering each joint)
    s_ib = {}
    for sk in gs.get('skins', []):
        ibm = am.acc(gs, bs, sk['inverseBindMatrices']).reshape(-1, 4, 4)
        ibm = np.transpose(ibm, (0, 2, 1))
        for k, j in enumerate(sk['joints']):
            nm = gs['nodes'][j].get('name')
            if nm not in s_ib:
                s_ib[nm] = np.linalg.inv(ibm[k])
    M = am.ORIENTS[o_name]
    spM = spos @ M                      # oriented src verts (as normalize_v)
    slo = spM.min(0)
    ss = (spM.max(0) - slo)[1]
    tlo, ts = tpos.min(0), (tpos.max(0) - tpos.min(0))[1]
    s_norm = ts / ss
    # full affine  C_glb :  glb-space point -> tgt-space point
    # row-vec:  p_tgt = (p@M - slo) * s_norm + tlo
    # column:   v_tgt = C_glb @ v_src
    C_glb = np.eye(4)
    C_glb[:3, :3] = M.T * s_norm
    C_glb[:3, 3] = tlo - slo * s_norm
    C_glb_inv = np.linalg.inv(C_glb)

    def to_tgt(p):
        return np.asarray(p, dtype=np.float64) @ C_glb[:3, :3].T \
            + C_glb[:3, 3]

    # (rest_src / rest_file loaded above for src-glb selection)

    def tgt_bind(s):
        """src joint bind world expressed in tgt space."""
        return C_glb @ s_ib[s]

    def flesh_pos(sname):
        if sname not in snames:
            return None
        ci = snames.index(sname)
        w = sW[:, ci]
        sv = spos[w > 0.15]
        if not len(sv):
            sv = spos[w > 0.02]
        if not len(sv):
            return None
        return ((sv @ M - slo) / ss).mean(0) * ts + tlo

    # ---- plan: remap or create per src feature bone
    new_map = dict(old_map)
    new_bones = {}
    counters = {}
    created = []
    remapped_fam = []

    # unit-level mirror vote: where do src _l bones' flesh sit in tgt space?
    lx = [np.mean(tpos[tW[:, tnames.index(j)] > 0.3, 0])
          for j in ('hand_left', 'upperleg_left', 'foot_left')
          if j in tnames]
    tgt_left_sign = np.sign(np.mean(lx)) or 1.0
    votes = []
    for s in snames:
        if side_of(s) == 'l':
            fp = flesh_pos(s)
            if fp is not None:
                votes.append(np.sign(fp[0]) == tgt_left_sign)
    mirrored = votes and (sum(votes) / len(votes) < 0.5)

    def eff_side(sd):
        if mirrored and sd:
            return 'r' if sd == 'l' else 'l'
        return sd

    def new_name(f, side):
        base = f
        sd = {'l': 'left', 'r': 'right'}.get(side, '')
        k = counters.get((f, sd), 0)
        while True:
            cand = f'{base}_{sd}_{k}' if sd else f'{base}_{k}'
            if cand not in tset and cand not in new_bones.values():
                counters[(f, sd)] = k + 1
                return cand
            k += 1

    # existing same-family tgt bones for positional remap
    fam_tgt = {}
    for s in snames:
        f = fam(s or '')
        if not f:
            continue
        fam_tgt.setdefault(f, [j for j in tset if fam_member(j, f)])

    pending = []
    for s in snames:
        f = fam(s or '')
        if not f or s not in s_ib:
            continue
        cur = new_map.get(s)
        cands = fam_tgt.get(f) or []
        if cands:
            # pick existing same-family tgt bone nearest this src joint
            jp = to_tgt(s_ib[s][:3, 3])
            best = min(cands, key=lambda j: np.linalg.norm(
                tWmat(tnode_name[j])[:3, 3] - jp))
            if cur != best:
                remapped_fam.append((s, cur, best))
                new_map[s] = best
            continue
        pending.append(s)

    # assign chain indices base->tip (src hierarchy depth), so tail_0 is
    # always the chain base regardless of skin-joint listing order
    pset = set(pending)
    def chain_depth(s):
        d, p = 0, spar.get(s)
        while p is not None:
            d += 1
            if p not in pset:
                break
            p = spar.get(p)
        return d
    for s in sorted(pending, key=lambda x: (fam(x), eff_side(side_of(x)),
                                            chain_depth(x))):
        f = fam(s)
        sd = eff_side(side_of(s))
        nm = new_name(f, sd)
        new_bones[s] = nm
        new_map[s] = nm
        created.append((s, nm, f))

    # ---- fix suspicious non-feature mappings via name table
    fixed = []
    for s, t in list(new_map.items()):
        if s.startswith('_') or s in new_bones:
            continue
        key = s.lower()
        if key in NAME2TGT:
            prefs = NAME2TGT[key]
            if t not in prefs:
                for cand in prefs:
                    if cand in tset:
                        new_map[s] = cand
                        fixed.append((s, t, cand))
                        break
        elif t and BAD_TGT.search(t):
            fixed.append((s, t, 'KEEP?badtgt'))

    # ---- side consistency: non-mirrored units must keep src _l -> tgt _left
    if not mirrored:
        for s, t in list(new_map.items()):
            if s.startswith('_') or not t or s in new_bones:
                continue
            sd = side_of(s)
            if sd == 'l' and '_right' in t:
                alt = t.replace('_right', '_left')
            elif sd == 'r' and '_left' in t:
                alt = t.replace('_left', '_right')
            else:
                continue
            if alt in tset:
                new_map[s] = alt
                fixed.append((s, t, alt))

    # ---- create nodes (chain parents first via src-hierarchy DFS)
    nodes = g['nodes']
    order, seen = [], set()

    def visit(s):
        p = spar.get(s)
        if p in new_bones and p not in seen:
            visit(p)
        if s in new_bones and s not in seen:
            order.append(s)
            seen.add(s)

    for s in snames:
        if s in new_bones:
            visit(s)

    def map_parent(s):
        p = spar.get(s)
        while p is not None:
            if p in new_bones:
                return new_bones[p]
            t = new_map.get(p)
            if t in tset:
                return t
            p = spar.get(p)
        return 'root' if 'root' in tset else 'animroot'

    node_world = {}
    for s in order:
        nm = new_bones[s]
        par_nm = map_parent(s)
        pi = tnode_name.get(par_nm)
        if pi is None:
            return {'fail': f'no parent node {par_nm}'}
        parW = tWmat(pi)
        W = tgt_bind(s)             # exact src bind world in tgt space
        L = np.linalg.inv(parW) @ W
        sc = np.linalg.norm(L[:3, :3], axis=0)
        q = mat_quat(L[:3, :3] / np.maximum(sc, 1e-9))
        ni = len(nodes)
        nodes.append({'name': nm,
                      'translation': [float(v) for v in L[:3, 3]],
                      'rotation': [float(v) for v in q],
                      'scale': [float(v) for v in sc]})
        nodes[pi].setdefault('children', []).append(ni)
        tnode_name[nm] = ni
        tWc[ni] = W
        node_world[s] = W
        tset.add(nm)

    # ---- extend skins
    new_names = [new_bones[s] for s in order]
    n_new = len(order)
    ibm_new = np.stack([np.linalg.inv(node_world[s]) for s in order]) \
        if n_new else np.zeros((0, 4, 4))
    for sk in g.get('skins', []):
        sk['joints'].extend(tnode_name[nm] for nm in new_names)
        if n_new:
            old = am.acc(g, binb, sk['inverseBindMatrices'])
            al = np.vstack([old.reshape(-1, 16),
                            np.transpose(ibm_new, (0, 2, 1))
                            .reshape(-1, 16)]).astype(np.float32)
            sk['inverseBindMatrices'] = acc_write(g, binb, al, 5126, 'MAT4')

    # ---- rebuild weights in union joint-name space
    jcol = {}
    for sk in g.get('skins', []):
        for j in sk['joints']:
            nm = g['nodes'][j].get('name')
            if nm not in jcol:
                jcol[nm] = len(jcol)
    W_new = np.zeros((len(tpos), len(jcol)), np.float32)
    sname_i = {nm: i for i, nm in enumerate(snames)}
    for s, t in new_map.items():
        if s in sname_i and t in jcol:
            W_new[:, jcol[t]] += sW[src_nn, sname_i[s]]
    low = (W_new.sum(1) < 0.3) | (nn_dist > 0.05)
    for i, nm in enumerate(tnames):
        if nm in jcol:
            W_new[low, jcol[nm]] += tW[low, i]
    W_new /= np.maximum(W_new.sum(1, keepdims=True), 1e-9)

    # ---- rewrite JOINTS_0/WEIGHTS_0 per skinned prim (same order as
    #      skin_data concatenation)
    off_v = 0
    for ni, n in enumerate(g['nodes']):
        if 'mesh' not in n or 'skin' not in n:
            continue
        sk = g['skins'][n['skin']]
        local = [g['nodes'][j].get('name') for j in sk['joints']]
        lcol = np.array([jcol[nm] for nm in local])
        for p in g['meshes'][n['mesh']].get('primitives', []):
            at = p.get('attributes', {})
            if 'JOINTS_0' not in at or 'WEIGHTS_0' not in at:
                continue
            nv = am.acc(g, binb0, at['POSITION']).shape[0]
            Wp = W_new[off_v:off_v + nv]
            off_v += nv
            top = np.argsort(-Wp, axis=1)[:, :4]
            J = np.zeros((nv, 4), np.uint16)
            Wq = np.zeros((nv, 4), np.float32)
            ar = np.arange(nv)
            for k in range(4):
                J[:, k] = lcol[top[:, k]]
                Wq[:, k] = Wp[ar, top[:, k]]
            Wq /= np.maximum(Wq.sum(1, keepdims=True), 1e-9)
            at['JOINTS_0'] = acc_write(g, binb, J, 5123, 'VEC4')
            at['WEIGHTS_0'] = acc_write(g, binb, Wq, 5126, 'VEC4')

    # ---- featbone drive constants for injector:
    #   node world(t) = K_i @ G_dump(t)   (per-bone bridge, incl. pose delta)
    #   K_i = C_glb @ B_i @ inv(rest_i)
    featbones = {}
    kmap = {}
    for s in order:
        if s in rest_src and abs(np.linalg.det(rest_src[s])) > 1e-12:
            Ki = C_glb @ s_ib[s] @ np.linalg.inv(rest_src[s])
            featbones[new_bones[s]] = s
            kmap[new_bones[s]] = [[float(v) for v in r] for r in Ki]
    new_map['_featbone'] = featbones
    new_map['_K'] = kmap

    report = {'orient': o_name, 'nn_med': round(o_med, 5),
              'mirrored': bool(mirrored),
              'new_bones': {s: new_bones[s] for s in order},
              'n_new': n_new, 'fixed_map': fixed,
              'remapped_fam': remapped_fam,
              'lowmass_verts': int(low.sum()),
              'rest_file': rest_file,
              'n_K': len(kmap)}
    if dry:
        return report

    bak = bp + '.bak_featbone'
    if not os.path.exists(bak):
        shutil.copy2(bp, bak)
    g['buffers'][0]['byteLength'] = len(binb)
    jout = json.dumps(g, separators=(',', ':')).encode()
    jout += b' ' * ((4 - len(jout) % 4) % 4)
    bout = bytes(binb) + b'\x00' * ((4 - len(binb) % 4) % 4)
    total = 12 + 8 + len(jout) + 8 + len(bout)
    out = b'glTF' + struct.pack('<II', 2, total) + \
        struct.pack('<I', len(jout)) + b'JSON' + jout + \
        struct.pack('<I', len(bout)) + b'BIN\x00' + bout
    open(bp, 'wb').write(out)
    json.dump(new_map, open(mp, 'w'), indent=1)
    json.dump(report,
              open(os.path.join(SA, unit, 'featbone_report.json'), 'w'),
              indent=1)
    return report


if __name__ == '__main__':
    units = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry' in sys.argv
    for u in units:
        try:
            r = run(u, dry)
            print(u, json.dumps(r, ensure_ascii=False)[:900])
        except Exception:
            import traceback
            traceback.print_exc()
