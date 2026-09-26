# -*- coding: utf-8 -*-
"""Retarget a vanilla .anim clip onto a fitted (custom) skeleton.

Bones with no translation track keep our bind-pose local offsets -> custom
proportions preserved. Rotation tracks copy verbatim (absolute local TRS).
'root'/'animroot' translation scaled by height ratio; be_prop_* kept.

usage: retarget_clip.py <clip.anim> <fitted_skel.json> <out.anim> [--pose out.pose.json]
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from anim_rw import parse_anim8, write_file, _rd_str, Reader


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz]


def qconj(q):
    return [-q[0], -q[1], -q[2], q[3]]


def qrot(q, v):
    return qmul(qmul(q, [v[0], v[1], v[2], 0]), qconj(q))[:3]


def load_clip(path):
    """Parse clip into anim dict (v8). v6/v7 clips are converted to the v8
    dict shape (f32 tracks -> bitrate 12/8, maps >=10000 -> static slots)."""
    try:
        return parse_anim8(path)
    except ValueError:
        pass
    from parse_anim_clip import parse_anim_clip
    c = parse_anim_clip(path)
    bones = c['bones']
    bc = len(bones)
    parts = []
    for p in c['parts']:
        tm, rm = p['trans_map'], p['rot_map']
        tb, rb = [], []
        for m in tm:
            tb.append(12 if 0 <= m < 10000 else (-12 if m >= 10000 else 0))
        for m in rm:
            rb.append(8 if 0 <= m < 10000 else (-8 if m >= 10000 else 0))
        stc = sum(1 for b in tb if b < 0)
        sqc = sum(1 for b in rb if b < 0)
        ftc = sum(1 for b in tb if b > 0)
        fqc = sum(1 for b in rb if b > 0)
        parts.append({'tb': tb, 'rb': rb, 'rt': [], 'rq': [],
                      'stc': stc, 'sqc': sqc, 'static': p['static_frame'],
                      'ftc': ftc, 'fqc': fqc, 'frames': p['frames']})
    return {'version': 8, 'unk0': c.get('unk0', 1),
            'frame_rate': c['frame_rate'], 'skeleton_name': c['skeleton_name'],
            'flags': c.get('flags', []), 'play_time': c['play_time'],
            'bones': bones, 'unk_v8': 6, 'parts': parts,
            'was_zstd': False, 'tail': b''}


def resolve_bone_locals(clip, part, frame, skel_locals):
    """Per-bone local pos/quat for a frame. skel_locals=(pos_list,quat_list)
    of OUR skeleton bind pose, used wherever the clip has no track."""
    pos, quat = [], []
    sp, sq = skel_locals
    bc = len(clip['bones'])
    for i in range(bc):
        tb = part['tb'][i]
        if tb > 0:      # dynamic trans
            pos.append(frame['transforms'][part['_tm_dyn'][i]])
        elif tb < 0:    # static trans -> replace with OUR bind offset
            pos.append(list(sp[i]))
        else:           # no trans -> OUR bind offset
            pos.append(list(sp[i]))
        rb = part['rb'][i]
        if rb > 0:
            quat.append(frame['quaternions'][part['_rm_dyn'][i]])
        elif rb < 0:
            quat.append(list(sq[i]))
        else:
            quat.append(list(sq[i]))
    return pos, quat


def world_from_locals(bones, pos, quat):
    n = len(bones)
    wp, wq = [None] * n, [None] * n
    for i, b in enumerate(bones):
        p, q = pos[i], quat[i]
        par = b['parent']
        if par < 0:
            wp[i], wq[i] = list(p), list(q)
        else:
            o = qrot(wq[par], p)
            wp[i] = [wp[par][0] + o[0], wp[par][1] + o[1], wp[par][2] + o[2]]
            wq[i] = qmul(wq[par], q)
    return wp, wq


def build_dyn_maps(part):
    """Index maps for dynamic track arrays (order of appearance)."""
    tm, rm = [], []
    tc = rc = 0
    for b in part['tb']:
        tm.append(tc) if b > 0 else tm.append(-1)
        tc += 1 if b > 0 else 0
    for b in part['rb']:
        rm.append(rc) if b > 0 else rm.append(-1)
        rc += 1 if b > 0 else 0
    part['_tm_dyn'] = tm
    part['_rm_dyn'] = rm


def qinv_norm(q):
    n = sum(c * c for c in q) ** 0.5
    return [-q[0] / n, -q[1] / n, -q[2] / n, q[3] / n]


def donor_bind_locals(donor_skel):
    """Derive donor bind local TRS from world frame0 + hierarchy."""
    bones = donor_skel['bones']
    wp, wq = donor_skel['world_pos_frame0'], donor_skel['world_quat_frame0']
    lp, lq = [None] * len(bones), [None] * len(bones)
    for i, b in enumerate(bones):
        par = b['parent']
        if par < 0:
            lp[i], lq[i] = list(wp[i]), list(wq[i])
        else:
            qi = qinv_norm(wq[par])
            lp[i] = list(qrot(qi, [wp[i][k] - wp[par][k] for k in range(3)]))
            lq[i] = list(qmul(qi, wq[i]))
    return lp, lq


def _slerp_id(q, t):
    """Interpolate identity -> q by t (damp a rotation delta)."""
    if q[3] < 0:
        q = [-c for c in q]
    r = [q[0] * t, q[1] * t, q[2] * t, 1.0 + (q[3] - 1.0) * t]
    n = sum(c * c for c in r) ** 0.5
    return [c / n for c in r]


def retarget_delta(clip, fit_skel, donor_skel, new_skel_name,
                   ref='frame0', damp=None, pos_damp=None):
    """World-rotation-delta retarget for mismatched bind poses.

    For every rotation-tracked bone, the donor's world-space delta is
    applied on top of OUR bind world orientation -> our creature keeps its
    hunched/proportioned silhouette while limbs move like the donor.
    ref='frame0': delta measured vs each clip's own frame-0 pose (best when
    our bind pose resembles the donor's animated stance, not its T-pose).
    ref='bind': delta measured vs donor bind pose.
    Positions follow our bind local offsets; root/animroot copy the
    donor's world-space root motion scaled by bind height ratio.
    damp: optional {name_regex: factor} — rotation deltas for matching
    bones are blended toward identity (e.g. {'tail_': 0.5} tames whip
    on much-longer-than-donor tails).
    pos_damp: optional {name_regex: factor} — scales the donor's world
    root-motion delta for matching root/animroot bones (e.g. {'^root$': 0.4}
    reins in a donor leap that would fling a small unit sky-high).
    """
    import re as _re
    damp_re = [( _re.compile(k), v) for k, v in (damp or {}).items()]
    pos_re = [( _re.compile(k), v) for k, v in (pos_damp or {}).items()]
    bones = clip['bones']
    bc = len(bones)
    name2i = {b['name']: i for i, b in enumerate(bones)}
    di = {b['name']: i for i, b in enumerate(donor_skel['bones'])}
    d_wp = donor_skel['world_pos_frame0']
    d_wq = donor_skel['world_quat_frame0']
    d_lp, d_lq = donor_bind_locals(donor_skel)
    sp = fit_skel['local_pos_frame0']
    sq = fit_skel['local_quat_frame0']
    o_wp = fit_skel['world_pos_frame0']
    o_wq = fit_skel['world_quat_frame0']
    ri, di_root = name2i.get('root'), di.get('root')
    ratio = (o_wp[ri][1] / d_wp[di_root][1]) if ri is not None and di_root is not None else 1.0
    clip = dict(clip)
    clip['skeleton_name'] = new_skel_name
    world = []
    for part in clip['parts']:
        build_dyn_maps(part)
        # static slots -> our bind locals
        if part['static'] is not None:
            st = part['static']
            ti = qi = 0
            for i in range(bc):
                if part['tb'][i] < 0:
                    st['transforms'][ti] = list(sp[i]); ti += 1
                    if i < len(part['rt']):
                        part['rt'][i] = (part['rt'][i][0], list(sp[i]))
            for i in range(bc):
                if part['rb'][i] < 0:
                    st['quaternions'][qi] = list(sq[i]); qi += 1
                    if i < len(part['rq']):
                        part['rq'][i] = (part['rq'][i][0], list(sq[i]))
        # donor reference world pose (frame0 of clip, or donor bind)
        ref_wp = ref_wq = None
        if ref == 'frame0' and part['frames']:
            fr0 = part['frames'][0]
            dpos0, dquat0 = [], []
            for i in range(bc):
                dpos0.append(list(fr0['transforms'][part['_tm_dyn'][i]]) if part['tb'][i] > 0 else d_lp[i])
                dquat0.append(list(fr0['quaternions'][part['_rm_dyn'][i]]) if part['rb'][i] > 0 else d_lq[i])
            ref_wp, ref_wq = world_from_locals(bones, dpos0, dquat0)
        else:
            ref_wp, ref_wq = d_wp, d_wq
        for fr in part['frames']:
            # donor world pose this frame (donor bind for untracked bones)
            dpos, dquat = [], []
            for i in range(bc):
                tb = part['tb'][i]
                dpos.append(list(fr['transforms'][part['_tm_dyn'][i]]) if tb > 0 else d_lp[i])
                rb = part['rb'][i]
                dquat.append(list(fr['quaternions'][part['_rm_dyn'][i]]) if rb > 0 else d_lq[i])
            wpd, wqd = world_from_locals(bones, dpos, dquat)
            # our world pose: rotation deltas applied to our bind
            wpo, wqo = [None] * bc, [None] * bc
            for i, b in enumerate(bones):
                par = b['parent']
                j = di.get(b['name'])
                dampf = next((v for rx, v in damp_re if rx.search(b['name'])), 1.0)
                if par < 0:
                    if part['rb'][i] > 0 and j is not None:
                        rq0 = ref_wq[i] if ref == 'frame0' else ref_wq[j]
                        dq = qmul(wqd[i], qinv_norm(rq0))
                        if dampf < 1.0:
                            dq = _slerp_id(dq, dampf)
                        wqo[i] = qmul(dq, o_wq[i])
                    else:
                        wqo[i] = list(o_wq[i])
                    if b['name'] in ('root', 'animroot') and j is not None:
                        rp0 = ref_wp[i] if ref == 'frame0' else ref_wp[j]
                        pf = next((v for rx, v in pos_re
                                   if rx.search(b['name'])), 1.0)
                        wpo[i] = [o_wp[i][k] + (wpd[i][k] - rp0[k]) * ratio * pf
                                  for k in range(3)]
                    else:
                        wpo[i] = list(o_wp[i])
                    continue
                if part['rb'][i] > 0 and j is not None:
                    rq0 = ref_wq[i] if ref == 'frame0' else ref_wq[j]
                    dq = qmul(wqd[i], qinv_norm(rq0))
                    if dampf < 1.0:
                        dq = _slerp_id(dq, dampf)
                    wqo[i] = qmul(dq, o_wq[i])
                else:
                    wqo[i] = qmul(wqo[par], sq[i])
                if b['name'] in ('root', 'animroot') and j is not None:
                    rp0 = ref_wp[i] if ref == 'frame0' else ref_wp[j]
                    pf = next((v for rx, v in pos_re
                               if rx.search(b['name'])), 1.0)
                    wpo[i] = [o_wp[i][k] + (wpd[i][k] - rp0[k]) * ratio * pf
                              for k in range(3)]
                else:
                    o = qrot(wqo[par], sp[i])
                    wpo[i] = [wpo[par][k] + o[k] for k in range(3)]
            # write back: local TRS = parent_world^-1 @ world
            for i, b in enumerate(bones):
                par = b['parent']
                if par < 0:
                    lp_i, lq_i = wpo[i], wqo[i]
                else:
                    qip = qinv_norm(wqo[par])
                    lp_i = list(qrot(qip, [wpo[i][k] - wpo[par][k] for k in range(3)]))
                    lq_i = qmul(qip, wqo[i])
                n = sum(c * c for c in lq_i) ** 0.5
                if n:
                    lq_i = [c / n for c in lq_i]
                if part['tb'][i] > 0:
                    fr['transforms'][part['_tm_dyn'][i]] = list(lp_i)
                if part['rb'][i] > 0:
                    fr['quaternions'][part['_rm_dyn'][i]] = lq_i
            world.append({'pos': [list(p) for p in wpo], 'quat': [list(q) for q in wqo]})
        # Retargeted locals live in OUR skeleton's bone basis — the donor's
        # per-bone quantize ranges (rt/rq) don't cover them and write_anim8
        # clamps to ±127 -> limbs fold overhead (taomon etc). Promote
        # quantized dynamic tracks to lossless encodings (tb 3->12, rb 4->8);
        # static slots keep their ranges (already patched to encode exactly).
        part['tb'] = [12 if t == 3 else t for t in part['tb']]
        part['rb'] = [8 if r == 4 else r for r in part['rb']]
    return clip, world


def retarget(clip, fit_skel, new_skel_name):
    """Return (modified clip dict, list-of-frames world poses)."""
    bones = clip['bones']
    bc = len(bones)
    sp = fit_skel['local_pos_frame0']
    sq = fit_skel['local_quat_frame0']
    # root/animroot translation scale = our root height / template root height
    name2i = {b['name']: i for i, b in enumerate(bones)}
    ri = name2i.get('root')
    ratio = float(fit_skel.get('root_scale', 1.0))
    clip = dict(clip)
    clip['skeleton_name'] = new_skel_name
    world = []
    for part in clip['parts']:
        build_dyn_maps(part)
        # patch static frame to our bind locals (only slots that exist)
        if part['static'] is not None:
            st = part['static']
            ti = qi = 0
            for i in range(bc):
                if part['tb'][i] < 0:
                    v = list(sp[i])
                    st['transforms'][ti] = v; ti += 1
                    # widen quantize range so writer encodes v exactly (mx=v, d=0)
                    if i < len(part['rt']):
                        part['rt'][i] = (part['rt'][i][0], list(v))
            for i in range(bc):
                if part['rb'][i] < 0:
                    v = list(sq[i])
                    st['quaternions'][qi] = v; qi += 1
                    if i < len(part['rq']):
                        part['rq'][i] = (part['rq'][i][0], list(v))
        # dynamic trans bones: scale root/animroot translations so the
        # creature's stride matches its height; be_prop_* are origin-local
        dyn_names = [bones[i]['name'] for i in range(bc) if part['tb'][i] > 0]
        root_slots = [part['_tm_dyn'][i] for i in range(bc)
                      if part['tb'][i] > 0 and bones[i]['name'] in ('root', 'animroot')]
        for fr in part['frames']:
            for k in root_slots:
                fr['transforms'][k] = [c * ratio for c in fr['transforms'][k]]
        # world poses for verification
        for fi, fr in enumerate(part['frames']):
            pos, quat = resolve_bone_locals(clip, part, fr, (sp, sq))
            wp, wq = world_from_locals(bones, pos, quat)
            world.append({'pos': wp, 'quat': wq})
    return clip, world


if __name__ == '__main__':
    clip_path, skel_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    pose_out = None
    if '--pose' in sys.argv:
        pose_out = sys.argv[sys.argv.index('--pose') + 1]
    clip = load_clip(clip_path)
    skel = json.load(open(skel_path))
    new_name = skel.get('custom_name', skel['skeleton_name'])
    if '--delta' in sys.argv:
        # world-delta retarget: needs the DONOR skeleton for reference poses
        donor = json.load(open(sys.argv[sys.argv.index('--delta') + 1]))
        ref = 'bind'
        if '--ref' in sys.argv:
            ref = sys.argv[sys.argv.index('--ref') + 1]
        damp = {}
        if '--damp' in sys.argv:
            for kv in sys.argv[sys.argv.index('--damp') + 1].split(','):
                k, v = kv.split('=')
                damp[k] = float(v)
        clip, world = retarget_delta(clip, skel, donor, new_name,
                                     ref=ref, damp=damp or None)
    else:
        clip, world = retarget(clip, skel, new_name)
    n = write_file(clip, out_path, zstd_compress=True)
    print('wrote', out_path, n, 'bytes,',
          sum(len(p['frames']) for p in clip['parts']), 'frames')
    if pose_out:
        out = {'skeleton_name': new_name, 'frame_rate': clip['frame_rate'],
               'bones': clip['bones'], 'world': world}
        Path(pose_out).write_text(json.dumps(out))
        print('pose ->', pose_out)
