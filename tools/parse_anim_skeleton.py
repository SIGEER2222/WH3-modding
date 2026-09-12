# -*- coding: utf-8 -*-
"""Parse WH3 .anim skeleton files (v8) -> JSON for Blender armature building.

Ported from hexagon62/warhammer3_model_serializer main.cpp.
"""
import json
import struct
import sys
from pathlib import Path


def read_str(buf, off):
    (ln,) = struct.unpack_from('<H', buf, off)
    off += 2
    s = buf[off:off + ln].decode('utf-8', errors='replace')
    return s, off + ln


def parse_anim(path):
    buf = Path(path).read_bytes()
    off = 0
    version, unknown0 = struct.unpack_from('<II', buf, off)
    off += 8
    (frame_rate,) = struct.unpack_from('<f', buf, off)
    off += 4
    skeleton_name, off = read_str(buf, off)
    flag_count, play_time = struct.unpack_from('<If', buf, off)
    off += 8
    (bone_count,) = struct.unpack_from('<I', buf, off)
    off += 4
    bones = []
    for _ in range(bone_count):
        name, off = read_str(buf, off)
        (parent,) = struct.unpack_from('<i', buf, off)
        off += 4
        bones.append({'name': name, 'parent': parent})
    unknown1, unknown2 = struct.unpack_from('<II', buf, off)
    off += 8
    off += bone_count  # 0x0C bytes
    off += bone_count  # 0x08 bytes
    off += 16          # padding
    transform_count, quat_count, frame_count = struct.unpack_from('<III', buf, off)
    off += 12
    frames = []
    for _ in range(frame_count):
        transforms = []
        for _ in range(quat_count):  # note: swapped in original code
            x, y, z = struct.unpack_from('<fff', buf, off)
            off += 12
            transforms.append([x, y, z])
        quats = []
        for _ in range(transform_count):
            xi, yi, zi, wi = struct.unpack_from('<hhhh', buf, off)
            off += 8
            quats.append([xi / 32767.0, yi / 32767.0, zi / 32767.0, wi / 32767.0])
        frames.append({'positions': transforms, 'quaternions': quats})
    return {
        'version': version,
        'skeleton_name': skeleton_name,
        'bone_count': bone_count,
        'bones': bones,
        'frames': frames,
        'transform_count': transform_count,
        'quat_count': quat_count,
        'frame_count': frame_count,
    }


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz]


def qrot(q, v):
    qc = [-q[0], -q[1], -q[2], q[3]]
    return qmul(qmul(q, [v[0], v[1], v[2], 0]), qc)[:3]


def world_transforms(parsed, frame_idx=0):
    """Return list of (world_pos, world_quat) per bone."""
    bones = parsed['bones']
    frame = parsed['frames'][frame_idx]
    wp, wq = [None] * len(bones), [None] * len(bones)
    for i, b in enumerate(bones):
        p, q = frame['positions'][i], frame['quaternions'][i]
        par = b['parent']
        if par < 0:
            wp[i], wq[i] = list(p), q
        else:
            o = qrot(wq[par], p)
            wp[i] = [wp[par][0] + o[0], wp[par][1] + o[1], wp[par][2] + o[2]]
            wq[i] = qmul(wq[par], q)
    return wp, wq


if __name__ == '__main__':
    out_dir = Path(r'E:\Code\WH3-modding\tools\_skel')
    for anim in sorted(out_dir.glob('*.anim')):
        d = parse_anim(anim)
        wp, wq = world_transforms(d, 0)
        d['world_pos_frame0'] = wp
        d['world_quat_frame0'] = wq
        js = anim.with_suffix('.json')
        js.write_text(json.dumps(d, indent=1), encoding='utf-8')
        ys = [w[1] for w in wp]
        print(anim.name, '->', d['skeleton_name'], 'bones:', d['bone_count'],
              'frames:', d['frame_count'], 'height Y range:',
              round(min(ys), 2), '..', round(max(ys), 2))
