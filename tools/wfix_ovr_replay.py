# -*- coding: utf-8 -*-
"""wfix.ovr 补丁档重放层（ovr_layer_eval_20260927 方案 A 实装）。

每单元一文件 `wfix.ovr.json`（schema wfix.ovr/v1），写器只读不写。
被 hook 的写器在重建权重后调本模块重放修权——离线直改 GLB 的修法不再
被 featbone/bind 重写浪潮静默回退（B9 rosemon 系全灭教训）。

补丁档查找序（先中先赢）：
  scratch/dgm_pub_batch/<u>/wfix.ovr.json                        （评估档 canonical）
  scratch/pipeline/dgm_audit/ovr_patches/<u>_bound/wfix.ovr.json （gen_wfix_ovr 产出）
  scratch/pipeline/dgm_audit/ovr_patches/<u>/wfix.ovr.json

kind 分派：
  jmap_ovr        —— 写器读 map/jmap 后、权重推导前合并 map 条目
  reassign_pred   —— 谓词命中行按 mode 改写（top4 量化之前）
  residual_graft  —— 残域骨回植：∃b∈bones 且 d(v,bpos[b]) < ratio*d(v,bpos[dom])
                     的行主导槽改挂该 b

谓词只走几何/骨名语义（禁用顶点索引）；谓词或 mode 不支持时打 stale/
unsupported 告警进 report，绝不静默误改。
"""
import json
import os

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, 'scratch', 'dgm_srcanim')
BATCH = os.path.join(ROOT, 'scratch', 'dgm_pub_batch')
OVR_DIR = os.path.join(ROOT, 'scratch', 'pipeline', 'dgm_audit', 'ovr_patches')

_EPS = 0.02  # 承权判定阈（与 dgm_featbone 的 w>0.02 口径一致）


def ovr_paths(unit):
    """单元补丁档候选路径（unit 可带或不带 _bound 后缀，两种都试）。"""
    u = unit[:-6] if unit.endswith('_bound') else unit
    return [os.path.join(BATCH, u, 'wfix.ovr.json'),
            os.path.join(OVR_DIR, u + '_bound', 'wfix.ovr.json'),
            os.path.join(OVR_DIR, u, 'wfix.ovr.json')]


def load_ovr(unit):
    """找补丁档；无档返回 (None, None)，有档返回 (doc, path)。"""
    for p in ovr_paths(unit):
        if os.path.exists(p):
            try:
                return json.load(open(p, encoding='utf-8')), p
            except Exception:
                return None, p  # 损坏档也报路径——写器侧告警
    return None, None


def apply_jmap_ovr(map_dict, ovr):
    """合并全部 jmap_ovr 条目进 map；返回 (新map, 被覆写键列表)。
    写器侧 new_map 回写时须对被覆写键做防回灌剔除（见 strip_ovr_keys）。"""
    out = dict(map_dict or {})
    keys = []
    for p in (ovr or {}).get('patches', []):
        if p.get('kind') != 'jmap_ovr':
            continue
        for k, v in (p.get('map') or {}).items():
            out[k] = v
            keys.append(k)
    return out, keys


def strip_ovr_keys(map_dict, ovr_keys):
    """new_map 回写防回灌：剔除 jmap_ovr 覆写过的非 '_' 前缀键——
    OVR 是持久补丁层，覆写值不能烤进生成物否则下游把它当原始映射再生成。"""
    out = dict(map_dict)
    for k in ovr_keys:
        if not k.startswith('_'):
            out.pop(k, None)
    return out


# ── 谓词求值 ─────────────────────────────────────────────────────
def _cmp(a, cmp_, v):
    return {'lt': a < v, 'lte': a <= v, 'gt': a > v,
            'gte': a >= v, 'eq': a == v,
            'abs_gt': np.abs(a) > v, 'abs_lt': np.abs(a) < v}[cmp_]


def _col(names, nm):
    try:
        return names.index(nm)
    except ValueError:
        return -1


def _dist_to_bone(pos, bpos, nm):
    """顶点到骨 rest 世界位距离；bpos 缺该骨返回 +inf 向量。"""
    if not bpos or nm not in bpos:
        return np.full(len(pos), np.inf)
    return np.sqrt(((pos - np.asarray(bpos[nm], float)) ** 2).sum(1))


def eval_pred(pred, ctx):
    """谓词→命中行 bool 掩码。ctx={W,names,pos,bpos(可缺),}。
    未知 op 返回 None（调用方记 unsupported，不静默放行）。"""
    if pred is None:
        return np.ones(ctx['W'].shape[0], bool)  # 无 pred=全行（同 always）
    n = ctx['W'].shape[0]
    op = pred.get('op', 'always')
    W, names, pos = ctx['W'], ctx['names'], ctx['pos']
    dom_idx = W.argmax(1)
    dom_name = [names[i] for i in dom_idx]
    if op == 'always':
        return np.ones(n, bool)
    if op in ('all', 'any'):
        subs = [eval_pred(p, ctx) for p in pred.get('items', [])]
        if any(s is None for s in subs):
            return None
        out = np.ones(n, bool) if op == 'all' else np.zeros(n, bool)
        for s in subs:
            out = out & s if op == 'all' else out | s
        return out
    if op == 'dom_in':
        s = set(pred.get('bones', []))
        return np.array([d in s for d in dom_name])
    if op == 'pos':
        ax = 'xyz'.index(pred.get('axis', 'y'))
        return _cmp(pos[:, ax], pred.get('cmp', 'gt'), pred.get('v', 0))
    if op == 'top':
        return _cmp(W.max(1), pred.get('cmp', 'lt'), pred.get('v', 0))
    if op == 'wspan':  # 权重离散度=非主导权重占比
        top = W.max(1)
        return _cmp(1.0 - top, pred.get('cmp', 'gt'), pred.get('v', 0))
    if op in ('d', 'd_dom'):  # 顶点离主导骨距离
        bpos = ctx.get('bpos')
        d = np.array([_dist_to_bone(pos[i:i + 1], bpos, dom_name[i])[0]
                      for i in range(n)])
        return _cmp(d, pred.get('cmp', 'gt'), pred.get('v', 0))
    if op == 'd_alt':  # 顶点离最近非主导骨距离
        bpos = ctx.get('bpos')
        if not bpos:
            return None
        d = np.full(n, np.inf)
        for i in range(n):
            cand = [np.linalg.norm(pos[i] - np.asarray(bpos[b]))
                    for b in bpos if b != dom_name[i]]
            d[i] = min(cand) if cand else np.inf
        return _cmp(d, pred.get('cmp', 'lt'), pred.get('v', 0))
    if op == 'd_alt_ratio_dom':  # d_alt / d_dom
        bpos = ctx.get('bpos')
        if not bpos:
            return None
        r = np.full(n, np.inf)
        for i in range(n):
            dd = _dist_to_bone(pos[i:i + 1], bpos, dom_name[i])[0]
            cand = [np.linalg.norm(pos[i] - np.asarray(bpos[b]))
                    for b in bpos if b != dom_name[i]]
            da = min(cand) if cand else np.inf
            r[i] = da / max(dd, 1e-9)
        return _cmp(r, pred.get('cmp', 'lt'), pred.get('v', 0))
    return None


# ── 行改写（mode 分派）─────────────────────────────────────────────
def _set_row(W, r, target_col):
    """单行权重整体改挂 target_col。"""
    s = W[r].sum()
    W[r] = 0.0
    W[r, target_col] = s


def _apply_mode(p, rows, W, names, ctx):
    """对命中行按 mode 改写 W；返回 (hits, note)。不支持 mode→(None,msg)。"""
    mode = p.get('mode')
    bpos = ctx.get('bpos')
    pos = ctx['pos']
    hits = int(rows.sum())
    if mode == 'to_bone':
        c = _col(names, p.get('to'))
        if c < 0:
            return None, 'to bone missing: %s' % p.get('to')
        for r in np.where(rows)[0]:
            _set_row(W, r, c)
    elif mode == 'map':  # 骨名对骨名移交（dom 骨→map 目标）
        mp = p.get('map') or {}
        dom_idx = W.argmax(1)
        moved = 0
        for r in np.where(rows)[0]:
            dn = names[dom_idx[r]]
            if dn in mp and _col(names, mp[dn]) >= 0:
                _set_row(W, r, _col(names, mp[dn]))
                moved += 1
        hits = moved
    elif mode == 'strip':  # 剥掉指定骨在命中行上的权重
        strip = set(p.get('strip', []))
        cols = [_col(names, b) for b in strip if _col(names, b) >= 0]
        for r in np.where(rows)[0]:
            W[r, cols] = 0.0
            s = W[r].sum()
            if s > 0:
                W[r] /= s
    elif mode == 'rigid_dominant':  # 只留主导骨
        for r in np.where(rows)[0]:
            c = int(W[r].argmax())
            s = W[r].sum()
            W[r] = 0.0
            W[r, c] = s
    elif mode in ('rigid_nearest', 'nearest_in_set'):  # 最近骨刚挂
        if not bpos:
            return None, 'bpos missing'
        cand = p.get('bones') or p.get('target_set') or list(bpos.keys())
        cand = [b for b in cand if b in bpos and _col(names, b) >= 0]
        if not cand:
            return None, 'no candidate bones'
        for r in np.where(rows)[0]:
            b = min(cand, key=lambda b: np.linalg.norm(pos[r] - bpos[b]))
            _set_row(W, r, _col(names, b))
    elif mode == 'smooth_bands':  # kNN 拉普拉斯近似（无邻接表的场景解）
        it, lam = int(p.get('iters', 2)), float(p.get('lam', 0.5))
        k = min(8, len(pos))
        idx = np.where(rows)[0]
        # 分块 kNN——避免 n×n 距离矩阵爆内存
        nb_rows = {}
        CH = 256
        for s0 in range(0, len(idx), CH):
            blk = idx[s0:s0 + CH]
            dn = np.sqrt(((pos[blk, None, :] - pos[None]) ** 2).sum(2))
            for j, r in enumerate(blk):
                nb_rows[r] = np.argsort(dn[j])[1:k + 1]
        for _ in range(it):
            Wn = np.array([W[nb_rows[r]].mean(0) for r in idx])
            W[idx] = (1 - lam) * W[idx] + lam * Wn
        s = W.sum(1, keepdims=True)
        np.divide(W, s, out=W, where=s > 1e-9)
    elif mode == 'transfer_share':  # src 骨份额移交 to 骨
        cs, ct = _col(names, p.get('src')), _col(names, p.get('to'))
        if cs < 0 or ct < 0:
            return None, 'src/to bone missing'
        share = float(p.get('share', 1.0))
        for r in np.where(rows)[0]:
            d = W[r, cs] * share
            W[r, cs] -= d
            W[r, ct] += d
    elif mode == 'ankle_tsplit':  # 踝簇残域：近簇行按骨轴 t 分裂上/下带
        # （fixskin_b8_residual 语义：cluster_radius 近簇门槛 + per-侧
        #  upper→lower 骨轴投影，t<=split_t→upper 骨、t>split_t→lower 骨）
        if not bpos:
            return None, 'bpos missing'
        st = float(p.get('split_t', 1.0))
        cr = p.get('cluster_radius')
        upn = [b for b in p.get('upper', [])
               if _col(names, b) >= 0 and b in bpos]
        lwn = [b for b in p.get('lower', [])
               if _col(names, b) >= 0 and b in bpos]
        clu = upn + lwn
        if not upn or not lwn:
            return None, 'upper/lower bones missing'
        ratio = float(p.get('ratio', 0.8))
        hits = 0
        for r in np.where(rows)[0]:
            nb = min(clu, key=lambda b: np.linalg.norm(pos[r] - bpos[b]))
            dm = np.linalg.norm(pos[r] - bpos[nb])
            dom = names[int(W[r].argmax())]
            dd = _dist_to_bone(pos[r:r + 1], bpos, dom)[0]
            # 残域门槛：近簇（dm<cluster_radius）或比主导骨更近比率内
            if not ((cr is not None and dm <= float(cr)) or
                    dm < ratio * dd or dom in clu):
                continue
            side = 'left' if '_left' in nb else \
                   ('right' if '_right' in nb else None)
            if side is None:
                continue
            ub = next((b for b in upn if '_%s' % side in b), None)
            lb = next((b for b in lwn if '_%s' % side in b), None)
            if ub is None or lb is None:
                continue
            seg = np.asarray(bpos[lb], float) - np.asarray(bpos[ub], float)
            dd2 = float(seg @ seg)
            t = float((pos[r] - np.asarray(bpos[ub], float)) @ seg) / dd2 \
                if dd2 > 1e-12 else np.inf
            _set_row(W, r, _col(names, ub if t <= st else lb))
            hits += 1
    elif mode == 'merge':  # 骨列份额并入（src→dst 逐行加和后清零 src）
        mp = p.get('map') or {}
        pairs = [(_col(names, s), _col(names, d)) for s, d in mp.items()]
        pairs = [(a, b) for a, b in pairs if a >= 0 and b >= 0]
        if not pairs:
            return None, 'merge map bones missing'
        for r in np.where(rows)[0]:
            for cs, ct in pairs:
                W[r, ct] += W[r, cs]
                W[r, cs] = 0.0
    elif mode == 'rigid_prim':  # 整 prim 刚挂单骨（key=per-node prim 下标）
        pid = ctx.get('prim_id')
        if pid is None:
            return None, 'prim_id ctx missing'
        moved = 0
        for pk, tgt in (p.get('prims') or {}).items():
            c = _col(names, tgt)
            if c < 0:
                continue
            for r in np.where(rows & (pid == int(pk)))[0]:
                _set_row(W, r, c)
                moved += 1
        hits = moved
    elif mode == 'src_nn_map':
        # 恒等语义：两个写器重建权重本身就是「源 NN 忠实映射」产物
        # （featbone W_new=sW[src_nn] 并集 / bind=_remap_prim_weights 源 NN）——
        # 重放即保留管线诚实输出，记 hits 留档不静默
        pass
    else:
        return None, 'unsupported mode: %s' % mode
    return hits, None


def _residual_graft(p, rows, W, names, ctx):
    """残域回植：∃b∈bones 使 d(v,bpos[b])<ratio*d(v,bpos[dom]) 的行主导槽改挂 b。
    twins 组按组内最小距离并计；骨缺 jcol→跳过记档（auto_phantom 不造骨——
    IBM 缺失场景造骨是 featbone 职责，重放层只调权重）。"""
    bpos = ctx.get('bpos')
    if not bpos:
        return 0, 'bpos missing'
    pos, ratio = ctx['pos'], float(p.get('ratio', 0.8))
    bones = [b for b in p.get('bones', []) if _col(names, b) >= 0]
    if not bones:
        return 0, 'no graft bones in joint space'
    twins = [t for t in p.get('twins', []) if t]
    groups = [list(t) for t in twins] + [[b] for b in bones
                                       if not any(b in t for t in twins)]
    moved = 0
    for r in np.where(rows)[0]:
        dom = names[int(W[r].argmax())]
        dd = _dist_to_bone(pos[r:r + 1], bpos, dom)[0]
        best = None
        for gp in groups:
            ds = [_dist_to_bone(pos[r:r + 1], bpos, b)[0] for b in gp]
            b = gp[int(np.argmin(ds))]
            dmin = min(ds)
            if dmin < ratio * dd and (best is None or dmin < best[1]):
                best = (b, dmin)
        if best:
            s = W[r].sum(); W[r] = 0.0
            W[r, _col(names, best[0])] = s
            moved += 1
    return moved, None


def apply_patches(W, names, pos, bpos, ovr, prim_id=None):
    """重放 OVR 补丁到权重矩阵 W（联合骨名空间，names=列名序）。
    prim_id=每顶点 prim 下标（per-node，rigid_prim 用）。hits=0 记 stale，
    mode 优先于 kind 分派（residual_graft+mode=ankle_tsplit 实档存在），
    补丁尾挂 assert_zero 骨名在全部补丁落完后复核非零行数。"""
    rep = {'patches': [], 'applied': 0, 'stale': [], 'unsupported': []}
    ctx = {'W': W, 'names': names, 'pos': pos, 'bpos': bpos or {},
           'prim_id': prim_id}
    az = []
    for i, p in enumerate((ovr or {}).get('patches', [])):
        kind = p.get('kind')
        ent = {'i': i, 'kind': kind, 'note': p.get('note', '')[:80]}
        if kind == 'jmap_ovr':
            ent['skipped'] = 'merged at map stage'  # 已在 map 阶段消费
            rep['patches'].append(ent)
            continue
        az += p.get('assert_zero') or []
        rows = eval_pred(p.get('pred'), ctx)
        if rows is None:
            ent['unsupported'] = 'pred op'
            rep['unsupported'].append(i)
            rep['patches'].append(ent)
            continue
        if p.get('mode'):          # mode 优先（residual_graft+mode 实档存在）
            h, err = _apply_mode(p, rows, W, names, ctx)
        elif kind == 'reassign_pred':
            h, err = _apply_mode(p, rows, W, names, ctx)
        elif kind == 'residual_graft':
            h, err = _residual_graft(p, rows, W, names, ctx)
        else:
            h, err = None, 'unsupported kind: %s' % kind
        if h is None:
            ent['unsupported'] = err
            rep['unsupported'].append(i)
        else:
            ent['hits'] = h
            ent['rows'] = int(rows.sum())
            if h == 0:
                rep['stale'].append(i)
                ent['stale'] = True
            rep['applied'] += h
        rep['patches'].append(ent)
    if az:  # assert_zero 复核：补丁落完后这些骨列应近零权
        viol = {}
        for nm in az:
            c = _col(names, nm)
            if c < 0:
                continue
            cnt = int((W[:, c] > _EPS).sum())
            if cnt:
                viol[nm] = cnt
        if viol:
            rep['assert_zero_viol'] = viol
    return rep


# ── 槽位格式互转（digimon_batch bind 的 (jj,ww) 4 槽表 ↔ 稠密 W）─────
def slots_to_dense(jj, ww, ncol):
    W = np.zeros((len(jj), ncol), np.float32)
    for r in range(len(jj)):
        for k in range(jj.shape[1]):
            c = int(jj[r, k])
            if 0 <= c < ncol and ww[r, k] > 0:
                W[r, c] += ww[r, k]
    return W


def dense_to_slots(W, k=4):
    """稠密 W → top-k (jj,ww)，行内重归一。"""
    n = len(W)
    jj = np.zeros((n, k), np.uint16)
    ww = np.zeros((n, k), np.float32)
    top = np.argsort(-W, 1)[:, :k]
    for r in range(n):
        cols = top[r]
        vals = W[r, cols]
        o = np.argsort(-vals)
        jj[r] = cols[o]
        ww[r] = vals[o]
    s = ww.sum(1, keepdims=True)
    np.divide(ww, s, out=ww, where=s > 1e-9)
    return jj, ww


# ── nzJ/主导骨直方图守卫 ──────────────────────────────────────────
def nzj_hist(W):
    """每顶点非零关节数直方图 + 主导骨计数（名→行数）。"""
    nz = (W > _EPS).sum(1)
    return {'nzJ_med': float(np.median(nz)) if len(nz) else 0.0,
            'nzJ_hist': {int(k): int(v) for k, v in
                         zip(*np.unique(nz, return_counts=True))},
            'dom': None}


def dom_hist(W, names):
    dom = W.argmax(1)
    out = {}
    for i in dom:
        out[names[int(i)]] = out.get(names[int(i)], 0) + 1
    return out


def weight_guard(names_pre, W_pre, names_post, W_post,
                 nzj_drop_thr=0.0, dom_exclude=None):
    """写前/写后权重守卫：nzJ 中位跌>阈或主导骨集收缩 → risk=True。
    pre/post 行序须同顶点序（同 tpos 集合不同骨名空间合法）；
    dom_exclude=有意的辅助骨剥离（如 animroot）不报收缩。"""
    nz_pre = (W_pre > _EPS).sum(1)
    nz_post = (W_post > _EPS).sum(1)
    dom_pre = dom_hist(W_pre, names_pre)
    dom_post = dom_hist(W_post, names_post)
    excl = set(dom_exclude or ())
    lost = sorted(set(dom_pre) - set(dom_post) - excl)
    return {'nzJ_med_pre': float(np.median(nz_pre)) if len(nz_pre) else 0.0,
            'nzJ_med_post': float(np.median(nz_post)) if len(nz_post) else 0.0,
            'nzJ_median_drop': float(np.median(nz_pre) - np.median(nz_post))
            if len(nz_pre) and len(nz_post) else 0.0,
            'dom_lost': lost, 'dom_gained': sorted(set(dom_post) - set(dom_pre)),
            'risk': bool(bool(lost) or
                         (len(nz_pre) and len(nz_post) and
                          float(np.median(nz_pre) - np.median(nz_post))
                          > nzj_drop_thr))}
