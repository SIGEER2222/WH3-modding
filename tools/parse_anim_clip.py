# -*- coding: utf-8 -*-
"""Parse WH3 .anim clip files (v6/v7/v8) -> JSON world transforms per frame.

Ported from AssetEditor Shared/GameFiles/Animation/AnimationFile.cs:
- v8: per-bone bitrate optimization (TranslationBitRate/RotationBitRate sbytes),
  range-map quantized tracks, static frame for constant bones.
- v6/v7: two bone_count int32 mapping tables (translation/rotation) then
  optional static frame (v7) + dynamic frames.
Bones with mapping -1 fall back to the skeleton bind pose (frame 0 of the
skeleton .anim), merged in via --skel <skeleton.json>.
"""
import json
import struct
import sys
from pathlib import Path


def read_str(buf, off):
    (ln,) = struct.unpack_from('<H', buf, off)
    off += 2
    return buf[off:off + ln].decode('utf-8', errors='replace'), off + ln


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


class Chunk:
    def __init__(self, buf):
        self.buf = buf
        self.off = 0

    def u32(self):
        v, = struct.unpack_from('<I', self.buf, self.off)
        self.off += 4
        return v

    def i32(self):
        v, = struct.unpack_from('<i', self.buf, self.off)
        self.off += 4
        return v

    def u16(self):
        v, = struct.unpack_from('<H', self.buf, self.off)
        self.off += 2
        return v

    def f32(self):
        v, = struct.unpack_from('<f', self.buf, self.off)
        self.off += 4
        return v

    def sbyte(self):
        v, = struct.unpack_from('<b', self.buf, self.off)
        self.off += 1
        return v

    def sbytes(self, n):
        v = struct.unpack_from('<%db' % n, self.buf, self.off)
        self.off += n
        return list(v)

    def shorts(self, n):
        v = struct.unpack_from('<%dh' % n, self.buf, self.off)
        self.off += n * 2
        return list(v)

    def string(self):
        ln = self.u16()
        s = self.buf[self.off:self.off + ln].decode('utf-8', errors='replace')
        self.off += ln
        return s


def read_frame(ch, pos_count, rot_count):
    transforms = [[ch.f32(), ch.f32(), ch.f32()] for _ in range(pos_count)]
    quats = []
    for _ in range(rot_count):
        q = ch.shorts(4)
        quats.append([c / 32767.0 for c in q])
    return {'transforms': transforms, 'quaternions': quats}


def read_frame_v8(ch, opt, dynamic):
    bc = opt['bone_count']
    transforms = []
    for i in range(bc):
        br = opt['trans_bitrate'][i] if dynamic else -opt['trans_bitrate'][i]
        if br == 12:
            transforms.append([ch.f32(), ch.f32(), ch.f32()])
        elif br == 3:
            d = ch.sbytes(3)
            mn, mx = opt['range_trans'][i]
            transforms.append([mx[c] + d[c] / 127.0 * mn[c] for c in range(3)])
        elif br in (0, -12, -3):
            pass
        else:
            raise ValueError('unknown trans bitrate %d' % br)
    quats = []
    for i in range(bc):
        br = opt['rot_bitrate'][i] if dynamic else -opt['rot_bitrate'][i]
        if br == 8:
            q = ch.shorts(4)
            quats.append([c / 32767.0 for c in q])
        elif br == 4:
            d = ch.sbytes(4)
            mn, mx = opt['range_quat'][i]
            quats.append([mx[c] + d[c] / 127.0 * mn[c] for c in range(4)])
        elif br in (0, -8, -4):
            pass
        else:
            raise ValueError('unknown rot bitrate %d' % br)
    return {'transforms': transforms, 'quaternions': quats}


def parse_anim_clip(path):
    buf = Path(path).read_bytes()
    if len(buf) > 8 and buf[4:8] == b'\x28\xb5\x2f\xfd':
        import zstandard as _z
        buf = _z.ZstdDecompressor().decompress(buf[4:], max_output_size=64_000_000)
    ch = Chunk(buf)
    version = ch.u32()
    ch.u32()                       # unknown0, always 1
    frame_rate = ch.f32()
    skeleton_name = ch.string()
    if version >= 6:
        for _ in range(ch.u32()):  # flag variables (v8 writes count=0)
            ch.string()
    play_time = ch.f32()
    bone_count = ch.u32()
    bones = []
    for _ in range(bone_count):
        name = ch.string()
        parent = ch.i32()
        bones.append({'name': name, 'parent': parent})

    parts = []
    if version == 8:
        ch.u32()                   # UnknownValue_v8
        part_count = ch.u32()
        for _ in range(part_count):
            opt = {'bone_count': bone_count}
            opt['trans_bitrate'] = ch.sbytes(bone_count)
            opt['rot_bitrate'] = ch.sbytes(bone_count)
            # mappings: bitrate>0 -> dynamic index, <0 -> static index, 0 -> none
            tm, rm, tc, sc, rc, rsc = [], [], 0, 0, 0, 0
            for i in range(bone_count):
                b = opt['trans_bitrate'][i]
                if b < 0:
                    tm.append(10000 + sc); sc += 1
                elif b > 0:
                    tm.append(tc); tc += 1
                else:
                    tm.append(-1)
            for i in range(bone_count):
                b = opt['rot_bitrate'][i]
                if b < 0:
                    rm.append(10000 + rsc); rsc += 1
                elif b > 0:
                    rm.append(rc); rc += 1
                else:
                    rm.append(-1)
            nrt = ch.u32()
            nrq = ch.u32()
            opt['range_trans'] = [([ch.f32(), ch.f32(), ch.f32()],
                                   [ch.f32(), ch.f32(), ch.f32()])
                                  for _ in range(nrt)]
            opt['range_quat'] = []
            for _ in range(nrq):
                mn = [ch.f32(), ch.f32(), ch.f32(), ch.f32()]
                mx = [ch.f32(), ch.f32(), ch.f32(), ch.f32()]
                opt['range_quat'].append((mn, mx))

            stc = ch.u32()
            sqc = ch.u32()
            static_frame = read_frame_v8(ch, opt, False) if (stc or sqc) else None
            ftc = ch.u32()
            fqc = ch.u32()
            frame_count = ch.u32()
            frames = []
            if ftc or fqc:
                for _ in range(frame_count):
                    frames.append(read_frame_v8(ch, opt, True))
            parts.append({'trans_map': tm, 'rot_map': rm,
                          'static_frame': static_frame, 'frames': frames})
    else:
        # v6/v7: mapping tables then frames; single part
        trans_map = [ch.i32() for _ in range(bone_count)]
        rot_map = [ch.i32() for _ in range(bone_count)]
        static_frame = None
        if version == 7:
            spc, src = ch.u32(), ch.u32()
            if spc or src:
                static_frame = read_frame(ch, spc, src)
        apc, arc, frame_count = ch.i32(), ch.i32(), ch.i32()
        frames = []
        if apc or arc:
            for _ in range(frame_count):
                frames.append(read_frame(ch, apc, arc))
        parts.append({'trans_map': trans_map, 'rot_map': rot_map,
                      'static_frame': static_frame, 'frames': frames})

    return {'version': version, 'skeleton_name': skeleton_name,
            'frame_rate': frame_rate, 'play_time': play_time,
            'bone_count': bone_count, 'bones': bones, 'parts': parts}


def resolve_locals(clip, part_idx, frame_idx, skel_frame=None):
    """Resolve per-bone local (pos, quat) for one frame.

    skel_frame: {'positions': [...], 'quaternions': [...]} bind pose from the
    skeleton .anim JSON ('frames'[0]); required for bones with mapping -1.
    """
    part = clip['parts'][part_idx]
    frame = part['frames'][frame_idx]
    static = part['static_frame']
    pos, quat = [], []
    for i in range(clip['bone_count']):
        m = part['trans_map'][i]
        if m >= 10000:
            pos.append(static['transforms'][m - 10000])
        elif m >= 0:
            pos.append(frame['transforms'][m])
        elif skel_frame is not None:
            pos.append(skel_frame['positions'][i])
        else:
            pos.append([0.0, 0.0, 0.0])
        m = part['rot_map'][i]
        if m >= 10000:
            quat.append(static['quaternions'][m - 10000])
        elif m >= 0:
            quat.append(frame['quaternions'][m])
        elif skel_frame is not None:
            quat.append(skel_frame['quaternions'][i])
        else:
            quat.append([0.0, 0.0, 0.0, 1.0])
    return pos, quat


def world_from_locals(bones, pos, quat):
    wp, wq = [None] * len(bones), [None] * len(bones)
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


if __name__ == '__main__':
    # usage: parse_anim_clip.py <clip.anim> <out.json> [skel.json]
    clip_path, out_path = sys.argv[1], sys.argv[2]
    skel_frame = None
    if len(sys.argv) > 3:
        skel = json.load(open(sys.argv[3], encoding='utf-8'))
        skel_frame = skel['frames'][0]
    clip = parse_anim_clip(clip_path)
    # pick part with most frames
    part_idx = max(range(len(clip['parts'])),
                   key=lambda i: len(clip['parts'][i]['frames']))
    n_frames = len(clip['parts'][part_idx]['frames'])
    world = []
    for f in range(n_frames):
        pos, quat = resolve_locals(clip, part_idx, f, skel_frame)
        wp, wq = world_from_locals(clip['bones'], pos, quat)
        world.append({'pos': wp, 'quat': wq})
    out = {'skeleton_name': clip['skeleton_name'],
           'bone_count': clip['bone_count'],
           'frame_rate': clip['frame_rate'],
           'part_count': len(clip['parts']),
           'used_part': part_idx,
           'frame_count': n_frames,
           'bones': clip['bones'],
           'world': world}
    Path(out_path).write_text(json.dumps(out), encoding='utf-8')
    print(Path(clip_path).name, '-> parts:', len(clip['parts']),
          'frames:', n_frames, 'bones:', clip['bone_count'])
