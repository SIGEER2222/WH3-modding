# -*- coding: utf-8 -*-
"""Retarget a donor .anim clip onto a custom skeleton via an explicit bone map.

Unlike retarget_clip.py (same-name matching), this takes a JSON bonemap:
    {"OurBone": "donor_bone", ...}
so custom rigs (e.g. Pokemon Biped names) can be driven by vanilla clips.

Method: world-rotation-delta retarget (same math as retarget_clip --delta):
    our_world_q = donor_delta * our_bind_world_q
Unmapped bones keep their bind LOCAL pose relative to their (possibly
animated) parent, so they follow along without adding their own motion.
Bones mapped to donor 'root'/'animroot' also copy the donor's world-space
translation delta, scaled by --ratio (default: our Waist/root height over
donor root height).

usage: retarget_bonemap.py <donor_clip.anim> <donor_skel.json>
        <our_skel.json> <bonemap.json> <out.anim>
        [--pose out.pose.json] [--ratio f] [--damp regex=f,...]
        [--ref frame0|bind]
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from anim_rw import parse_anim8, write_file
from retarget_clip import (load_clip, build_dyn_maps, donor_bind_locals,
                           world_from_locals, qmul, qrot, qinv_norm, _slerp_id)


def locals_from_world(skel):
    """(local_pos, local_quat) bind pose from world frame0 + hierarchy."""
    bones = skel['bones']
    wp, wq = skel['world_pos_frame0'], skel['world_quat_frame0']
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


def retarget_bonemap(dclip, dskel, oskel, bonemap, new_skel_name,
                     ratio=None, damp=None, ref='frame0'):
    import re as _re
    damp_re = [(_re.compile(k), v) for k, v in (damp or {}).items()]

    ob = oskel['bones']
    bc = len(ob)
    # parents must precede children
    for i, b in enumerate(ob):
        assert b['parent'] < i, f"bone {i} {b['name']} parent order"
    o_wp, o_wq = oskel['world_pos_frame0'], oskel['world_quat_frame0']
    o_lp, o_lq = locals_from_world(oskel)

    dsk_bones = dskel['bones']
    di = {b['name']: i for i, b in enumerate(dsk_bones)}
    d_wp0, d_wq0 = dskel['world_pos_frame0'], dskel['world_quat_frame0']
    d_lp, d_lq = donor_bind_locals(dskel)

    cb = dclip['bones']
    ci = {b['name']: i for i, b in enumerate(cb)}
    # our-bone index -> clip-bone index (via donor name)
    our2clip = {}
    for i, b in enumerate(ob):
        dn = bonemap.get(b['name'])
        if dn is not None:
            if dn not in ci:
                raise KeyError(f"bonemap: donor bone '{dn}' (for {b['name']}) "
                               f"not in clip skeleton {dclip['skeleton_name']}")
            our2clip[i] = ci[dn]
    our2donor = {i: di[bonemap[ob[i]['name']]] for i in our2clip}

    if ratio is None:
        # pelvis-ish height ratio: our mapped-'root' bone world Y over donor root Y
        o_root = next((i for i in our2donor if bonemap[ob[i]['name']] == 'root'), None)
        d_root = di.get('root')
        if o_root is not None and d_root is not None and d_wp0[d_root][1] > 1e-3:
            # use the waist-ish child of our root mapping if it's at ground level
            h = o_wp[o_root][1]
            if h < 0.1 * d_wp0[d_root][1]:
                waist = next((i for i, b in enumerate(ob) if b['name'] == 'Waist'), None)
                if waist is not None:
                    h = o_wp[waist][1]
            ratio = h / d_wp0[d_root][1] if h > 1e-3 else 1.0
        else:
            ratio = 1.0

    out = {'version': 8, 'unk0': dclip.get('unk0', 1),
           'frame_rate': dclip['frame_rate'], 'skeleton_name': new_skel_name,
           'flags': list(dclip.get('flags', [])),
           'play_time': dclip['play_time'],
           'bones': [{'name': b['name'], 'parent': b['parent']} for b in ob],
           'unk_v8': dclip.get('unk_v8', 6), 'parts': [],
           'was_zstd': False, 'tail': b''}

    world_out = []
    for part in dclip['parts']:
        build_dyn_maps(part)
        # donor reference world pose
        ref_wp, ref_wq = d_wp0, d_wq0
        if ref == 'frame0' and part['frames']:
            fr0 = part['frames'][0]
            dp0 = [list(fr0['transforms'][part['_tm_dyn'][i]]) if part['tb'][i] > 0 else d_lp[i]
                   for i in range(len(cb))]
            dq0 = [list(fr0['quaternions'][part['_rm_dyn'][i]]) if part['rb'][i] > 0 else d_lq[i]
                   for i in range(len(cb))]
            ref_wp, ref_wq = world_from_locals(cb, dp0, dq0)

        n_fr = len(part['frames'])
        new_part = {'tb': [12] * bc, 'rb': [8] * bc, 'rt': [], 'rq': [],
                    'stc': 0, 'sqc': 0, 'static': None,
                    'ftc': bc, 'fqc': bc, 'frames': []}
        for fr in part['frames']:
            # donor world pose this frame
            dp = [list(fr['transforms'][part['_tm_dyn'][i]]) if part['tb'][i] > 0 else d_lp[i]
                  for i in range(len(cb))]
            dq = [list(fr['quaternions'][part['_rm_dyn'][i]]) if part['rb'][i] > 0 else d_lq[i]
                  for i in range(len(cb))]
            wpd, wqd = world_from_locals(cb, dp, dq)
            # our world pose
            wpo, wqo = [None] * bc, [None] * bc
            for i, b in enumerate(ob):
                par = b['parent']
                j = our2clip.get(i)
                if j is not None and part['rb'][j] > 0:
                    dampf = next((v for rx, v in damp_re if rx.search(b['name'])), 1.0)
                    dlt = qmul(wqd[j], qinv_norm(ref_wq[j]))
                    if dampf < 1.0:
                        dlt = _slerp_id(dlt, dampf)
                    wqo[i] = qmul(dlt, o_wq[i])
                elif par < 0:
                    wqo[i] = list(o_wq[i])
                else:
                    wqo[i] = qmul(wqo[par], o_lq[i])
                dname = bonemap.get(b['name'])
                if j is not None and dname in ('root', 'animroot'):
                    wpo[i] = [o_wp[i][k] + (wpd[j][k] - ref_wp[j][k]) * ratio
                              for k in range(3)]
                elif par < 0:
                    wpo[i] = list(o_wp[i])
                else:
                    o = qrot(wqo[par], o_lp[i])
                    wpo[i] = [wpo[par][k] + o[k] for k in range(3)]
            # world -> local
            lp_f, lq_f = [], []
            for i, b in enumerate(ob):
                par = b['parent']
                if par < 0:
                    lp_f.append(wpo[i]); lq_f.append(wqo[i])
                else:
                    qip = qinv_norm(wqo[par])
                    lp_f.append(list(qrot(qip, [wpo[i][k] - wpo[par][k]
                                                for k in range(3)])))
                    lq_f.append(qmul(qip, wqo[i]))
            new_part['frames'].append({'transforms': lp_f, 'quaternions': lq_f})
            world_out.append({'pos': [list(p) for p in wpo],
                              'quat': [list(q) for q in wqo]})
        out['parts'].append(new_part)
    return out, world_out, ratio


if __name__ == '__main__':
    a = sys.argv[1:]
    clip_p, dskel_p, oskel_p, map_p, out_p = a[:5]
    pose_out = None
    ratio = None
    damp = {}
    ref = 'frame0'
    if '--pose' in a:
        pose_out = a[a.index('--pose') + 1]
    if '--ratio' in a:
        ratio = float(a[a.index('--ratio') + 1])
    if '--damp' in a:
        for kv in a[a.index('--damp') + 1].split(','):
            k, v = kv.split('=')
            damp[k] = float(v)
    if '--ref' in a:
        ref = a[a.index('--ref') + 1]

    dclip = load_clip(clip_p)
    dskel = json.loads(Path(dskel_p).read_text())
    oskel = json.loads(Path(oskel_p).read_text())
    bonemap = json.loads(Path(map_p).read_text())
    new_name = oskel.get('custom_name', oskel['skeleton_name'])
    clip, world, ratio = retarget_bonemap(dclip, dskel, oskel, bonemap,
                                          new_name, ratio=ratio,
                                          damp=damp or None, ref=ref)
    n = write_file(clip, out_p, zstd_compress=True)
    print('wrote', out_p, n, 'bytes,',
          sum(len(p['frames']) for p in clip['parts']), 'frames, ratio', round(ratio, 3))
    if pose_out:
        Path(pose_out).write_text(json.dumps(
            {'skeleton_name': new_name, 'frame_rate': clip['frame_rate'],
             'bones': clip['bones'], 'world': world}))
        print('pose ->', pose_out)
