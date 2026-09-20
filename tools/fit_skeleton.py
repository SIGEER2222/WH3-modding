# -*- coding: utf-8 -*-
"""Fit a vanilla skeleton template into a custom mesh's anatomy.

Input:  template _skel/*.json (bones + world_pos/quat frame0)
        landmarks JSON {bone_name: [x,y,z]} in glTF coords (y-up, +z fwd)
Output: fitted skeleton JSON (world_pos_frame0 replaced; local pos/quat
        recomputed so parent chains stay attached).

Rules:
  - landmark bone: world pos = given
  - non-landmark bone with landmark ancestor A and descendant D:
      lerp between A_new and D_new by the bone's original chain fraction
  - only landmark ancestor: rigid-shift by (A_new - A_template)
  - no landmark in chain: keep template position
Local quats stay template's (clips drive absolute local rotations anyway;
bind orientation only needs to be self-consistent for IBM).
"""
import json
import struct
import sys
import numpy as np
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from anim_rw import parse_anim8, write_file


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


def quat_to_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_to_quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = np.sqrt(t + 1) * 2
        return [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s,
                (m[1, 0] - m[0, 1]) / s, s / 4]
    i = int(np.argmax([m[0, 0], m[1, 1], m[2, 2]]))
    j, k = (i + 1) % 3, (i + 2) % 3
    s = np.sqrt(m[i, i] - m[j, j] - m[k, k] + 1) * 2
    q = [0.0, 0.0, 0.0, 0.0]
    q[i] = s / 4
    q[j] = (m[j, i] + m[i, j]) / s
    q[k] = (m[k, i] + m[i, k]) / s
    q[3] = (m[k, j] - m[j, k]) / s
    return q


def fit(skel_json, landmarks):
    bones = skel_json['bones']
    n = len(bones)
    wp_t = np.array(skel_json['world_pos_frame0'])
    wq_t = [tuple(q) for q in skel_json['world_quat_frame0']]
    children = [[] for _ in range(n)]
    for i, b in enumerate(bones):
        if b['parent'] >= 0:
            children[b['parent']].append(i)

    lm = {k: np.array(v, dtype=float) for k, v in landmarks.items()}
    name2i = {b['name']: i for i, b in enumerate(bones)}
    lm_idx = {name2i[k]: v for k, v in lm.items() if k in name2i}
    missing = set(lm) - set(name2i)
    if missing:
        print('WARN unknown landmark bones:', sorted(missing))

    def nearest_lm_ancestor(i):
        p = bones[i]['parent']
        while p >= 0:
            if p in lm_idx:
                return p
            p = bones[p]['parent']
        return -1

    def nearest_lm_descendant(i):
        # BFS down; nearest landmark by chain steps
        frontier = list(children[i])
        dist = 0
        while frontier:
            nxt = []
            for c in frontier:
                if c in lm_idx:
                    return c
                nxt += children[c]
            frontier = nxt
            dist += 1
            if dist > 64:
                break
        return -1

    wp_new = [None] * n
    # process in hierarchy order (parents before children)
    for i in range(n):
        if i in lm_idx:
            wp_new[i] = lm_idx[i]
            continue
        a = nearest_lm_ancestor(i)
        d = nearest_lm_descendant(i)
        if a >= 0 and d >= 0:
            # fraction of original chain distance A->i within A->D
            la = np.linalg.norm(wp_t[d] - wp_t[a])
            li = np.linalg.norm(wp_t[i] - wp_t[a])
            t = min(1.0, li / la) if la > 1e-6 else 0.0
            wp_new[i] = wp_new[a] + (lm_idx[d] - wp_new[a]) * t
        elif a >= 0:
            wp_new[i] = wp_t[i] + (wp_new[a] - wp_t[a])
        else:
            wp_new[i] = wp_t[i]
    wp_new = np.array(wp_new)

    # Re-aim each bone's world orientation at its continuation child.
    # Keeping template quats after moving joints leaves every bone's local
    # frame pointing along the DONOR's limb direction; clips then rotate
    # limbs around wrong axes. For each bone we take the donor's aim dir
    # (bone->continuation child) and swing the world quat so the same local
    # aim now points at the NEW child position. Childless bones ride their
    # parent's swing (rigid with chain end).
    import re as _re

    def swing_quat(a, b):
        """Shortest-arc quat rotating normalized vec a -> b."""
        na = np.linalg.norm(a); nb = np.linalg.norm(b)
        if na < 1e-9 or nb < 1e-9:
            return [0.0, 0.0, 0.0, 1.0]
        a = a / na; b = b / nb
        c = np.cross(a, b); d = float(np.dot(a, b))
        if d < -0.999999:
            ax = np.cross(a, [1.0, 0.0, 0.0])
            if np.linalg.norm(ax) < 1e-6:
                ax = np.cross(a, [0.0, 1.0, 0.0])
            ax = ax / np.linalg.norm(ax)
            return [ax[0], ax[1], ax[2], 0.0]
        s = np.sqrt((1 + d) * 2); inv = 1.0 / s
        return [c[0] * inv, c[1] * inv, c[2] * inv, s * 0.5]

    def continuation_child(i):
        ch = children[i]
        if not ch:
            return -1
        base = _re.sub(r'_\d+$', '', bones[i]['name'])
        pref = [c for c in ch if bones[c]['name'].startswith(base)]
        if pref:
            return pref[0]
        interior = [c for c in ch if children[c]]
        return interior[0] if interior else ch[0]

    wq_new = [None] * n
    swing = [[0.0, 0.0, 0.0, 1.0]] * n
    for i, b in enumerate(bones):
        p = b['parent']
        parent_swing = swing[p] if p >= 0 else [0.0, 0.0, 0.0, 1.0]
        c = continuation_child(i)
        if c >= 0:
            d_old = wp_t[c] - wp_t[i]
            d_new = wp_new[c] - wp_new[i]
            s = swing_quat(d_old, d_new)
            # compose with parent swing so we also follow a moved parent chain
            s = qmul(s, parent_swing)
            swing[i] = s
            wq_new[i] = qmul(s, wq_t[i])
        else:
            swing[i] = parent_swing
            wq_new[i] = qmul(parent_swing, wq_t[i])

    # local pos = R_parent^-1 (world_i - world_parent) with NEW quats
    local_pos, local_quat = [], []
    for i, b in enumerate(bones):
        p = b['parent']
        if p < 0:
            local_pos.append(list(wp_new[i]))
            local_quat.append(list(wq_new[i]))
        else:
            lp = qrot(qconj(wq_new[p]), list(wp_new[i] - wp_new[p]))
            local_pos.append(lp)
            local_quat.append(list(qmul(qconj(wq_new[p]), wq_new[i])))
    return wp_new, wq_new, local_pos, local_quat


def write_skeleton(src_anim_path, dst_anim_path, new_name, local_pos, local_quat):
    """Patch a template skeleton .anim -> new skeleton file."""
    a = parse_anim8(src_anim_path)
    a['skeleton_name'] = new_name
    bc = len(a['bones'])
    for part in a['parts']:
        # skeleton files: all bones bitrate 12/8, frames = bind pose repeats
        for fr in part['frames']:
            for i in range(bc):
                fr['transforms'][i] = list(local_pos[i])
                fr['quaternions'][i] = list(local_quat[i])
        if part['static'] is not None:
            for i in range(bc):
                part['static']['transforms'][i] = list(local_pos[i])
                part['static']['quaternions'][i] = list(local_quat[i])
    return write_file(a, dst_anim_path, zstd_compress=True)


def write_invmats(world_pos, world_quat, dst_path):
    """bone_inv_trans_mats: u32 ver=1, u32 count, count x 12 f32.
    Verified against vanilla humanoid06: 4x3 = [R world rotation rows;
    row3 = -R^T @ pos]."""
    import zstandard as zstd
    out = bytearray(struct.pack('<II', 1, len(world_pos)))
    for p, q in zip(world_pos, world_quat):
        R = quat_to_mat(q)
        t = -R.T @ np.array(p)
        m43 = np.vstack([R, t.reshape(1, 3)])  # 4x3
        out += m43.astype('<f4').tobytes()
    payload = bytes(out)
    Path(dst_path).write_bytes(struct.pack('<I', len(payload)) +
                             zstd.ZstdCompressor(level=19).compress(payload))
    return len(payload)


if __name__ == '__main__':
    # usage: fit_skeleton.py <skel.json> <landmarks.json> <out.json>
    skel = json.load(open(sys.argv[1]))
    lm = json.load(open(sys.argv[2]))
    wp, wq, lp, lq = fit(skel, lm)
    skel['world_pos_frame0'] = wp.tolist()
    skel['world_quat_frame0'] = [list(q) for q in wq]
    skel['local_pos_frame0'] = lp
    skel['local_quat_frame0'] = lq
    json.dump(skel, open(sys.argv[3], 'w'))
    print('fitted ->', sys.argv[3])
