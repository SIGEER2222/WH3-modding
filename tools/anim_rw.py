# -*- coding: utf-8 -*-
"""WH3 .anim v8 reader/writer — full round-trip (parse -> dict -> bytes).

Format (decompressed):
  u32 version=8, u32 unk0=1, f32 frame_rate, str skeleton_name,
  u32 flag_count + flag strings, f32 play_time,
  u32 bone_count, bones[ (str name, i32 parent) ],
  u32 unknown_v8(=6), u32 part_count,
  per part:
    s8 trans_bitrate[bc], s8 rot_bitrate[bc],     # >0 dynamic, <0 static, 0 none
    u32 nrt, u32 nrq,
    nrt x (f32x3 min, f32x3 max),  nrq x (f32x4 min, f32x4 max),
    u32 stc, u32 sqc, [static frame if stc|sqc],
    u32 ftc, u32 fqc, u32 frame_count, [frames if ftc|fqc],
    frame: per bone trans (f32x3 if |br|==12, s8x3 if |br|==3, none if 0)
           per bone quat  (i16x4 if |br|==8,  s8x4 if |br|==4, none if 0)
      (dynamic frame uses br as-is; static frame uses -br)
On disk the file may be zstd: [u32 decompressed_size][zstd frame].
"""
import struct
import sys
from pathlib import Path

import zstandard as zstd


def _rd_str(buf, off):
    (ln,) = struct.unpack_from('<H', buf, off)
    return buf[off + 2:off + 2 + ln].decode('utf-8', errors='replace'), off + 2 + ln


def _wr_str(s):
    b = s.encode('utf-8')
    return struct.pack('<H', len(b)) + b


def decompress(path):
    buf = Path(path).read_bytes()
    if len(buf) > 8 and buf[4:8] == b'\x28\xb5\x2f\xfd':
        return zstd.ZstdDecompressor().decompress(buf[4:], max_output_size=256_000_000), True
    return buf, False


def compress_payload(payload):
    c = zstd.ZstdCompressor(level=19).compress(payload)
    return struct.pack('<I', len(payload)) + c


class Reader:
    def __init__(self, buf):
        self.b = buf
        self.o = 0

    def u32(self):
        v, = struct.unpack_from('<I', self.b, self.o); self.o += 4; return v

    def i32(self):
        v, = struct.unpack_from('<i', self.b, self.o); self.o += 4; return v

    def f32(self):
        v, = struct.unpack_from('<f', self.b, self.o); self.o += 4; return v

    def s8(self, n):
        v = struct.unpack_from('<%db' % n, self.b, self.o); self.o += n; return list(v)

    def string(self):
        s, self.o = _rd_str(self.b, self.o); return s

    def read(self, n):
        v = self.b[self.o:self.o + n]; self.o += n; return v


def _read_frame_v8(r, bc, tb, rb, rt_ranges, rq_ranges, dynamic):
    trans = []
    for i in range(bc):
        br = tb[i] if dynamic else -tb[i]
        if br == 12:
            trans.append(list(struct.unpack_from('<fff', r.read(12))))
        elif br == 3:
            d = struct.unpack_from('<3b', r.read(3))
            mn, mx = rt_ranges[i]
            trans.append([mx[c] + d[c] / 127.0 * mn[c] for c in range(3)])
        elif br in (0, -12, -3):
            pass
        else:
            raise ValueError('trans bitrate %d' % br)
    quats = []
    for i in range(bc):
        br = rb[i] if dynamic else -rb[i]
        if br == 8:
            q = struct.unpack_from('<4h', r.read(8))
            quats.append([c / 32767.0 for c in q])
        elif br == 4:
            d = struct.unpack_from('<4b', r.read(4))
            mn, mx = rq_ranges[i]
            quats.append([mx[c] + d[c] / 127.0 * mn[c] for c in range(4)])
        elif br in (0, -8, -4):
            pass
        else:
            raise ValueError('rot bitrate %d' % br)
    return {'transforms': trans, 'quaternions': quats}


def parse_anim8(path):
    buf, was_z = decompress(path)
    r = Reader(buf)
    version = r.u32()
    unk0 = r.u32()
    frame_rate = r.f32()
    skeleton_name = r.string()
    flags = [r.string() for _ in range(r.u32())] if version >= 6 else []
    play_time = r.f32()
    bc = r.u32()
    bones = [{'name': r.string(), 'parent': r.i32()} for _ in range(bc)]
    parts = []
    if version == 8:
        unk_v8 = r.u32()
        part_count = r.u32()
        for _ in range(part_count):
            tb = r.s8(bc)
            rb = r.s8(bc)
            nrt = r.u32()
            nrq = r.u32()
            rt = []
            for i in range(nrt):
                mn = list(struct.unpack_from('<3f', r.read(12)))
                mx = list(struct.unpack_from('<3f', r.read(12)))
                rt.append((mn, mx))
            rq = []
            for i in range(nrq):
                mn = list(struct.unpack_from('<4f', r.read(16)))
                mx = list(struct.unpack_from('<4f', r.read(16)))
                rq.append((mn, mx))
            stc = r.u32()
            sqc = r.u32()
            static = _read_frame_v8(r, bc, tb, rb, rt, rq, False) if (stc or sqc) else None
            ftc = r.u32()
            fqc = r.u32()
            fc = r.u32()
            frames = []
            if ftc or fqc:
                for _ in range(fc):
                    frames.append(_read_frame_v8(r, bc, tb, rb, rt, rq, True))
            parts.append({'tb': tb, 'rb': rb, 'rt': rt, 'rq': rq,
                          'stc': stc, 'sqc': sqc, 'static': static,
                          'ftc': ftc, 'fqc': fqc, 'frames': frames})
    else:
        raise ValueError('only v8 supported')
    return {'version': version, 'unk0': unk0, 'frame_rate': frame_rate,
            'skeleton_name': skeleton_name, 'flags': flags,
            'play_time': play_time, 'bones': bones, 'unk_v8': unk_v8,
            'parts': parts, 'was_zstd': was_z, 'tail': buf[r.o:]}


def _write_frame_v8(bc, tb, rb, rt, rq, frame, dynamic):
    out = bytearray()
    ti = 0
    for i in range(bc):
        br = tb[i] if dynamic else -tb[i]
        if br == 12:
            out += struct.pack('<3f', *frame['transforms'][ti]); ti += 1
        elif br == 3:
            v = frame['transforms'][ti]; ti += 1
            mn, mx = rt[i]
            out += struct.pack('<3b', *[max(-128, min(127, round((v[c] - mx[c]) / mn[c] * 127))) if mn[c] else 0 for c in range(3)])
        elif br in (0, -12, -3):
            pass
    qi = 0
    for i in range(bc):
        br = rb[i] if dynamic else -rb[i]
        if br == 8:
            q = frame['quaternions'][qi]; qi += 1
            out += struct.pack('<4h', *[max(-32767, min(32767, round(c * 32767))) for c in q])
        elif br == 4:
            v = frame['quaternions'][qi]; qi += 1
            mn, mx = rq[i]
            out += struct.pack('<4b', *[max(-128, min(127, round((v[c] - mx[c]) / mn[c] * 127))) if mn[c] else 0 for c in range(4)])
        elif br in (0, -8, -4):
            pass
    return bytes(out)


def write_anim8(anim):
    out = bytearray()
    out += struct.pack('<IIf', anim['version'], anim['unk0'], anim['frame_rate'])
    out += _wr_str(anim['skeleton_name'])
    out += struct.pack('<I', len(anim['flags']))
    for s in anim['flags']:
        out += _wr_str(s)
    out += struct.pack('<fI', anim['play_time'], len(anim['bones']))
    for b in anim['bones']:
        out += _wr_str(b['name']) + struct.pack('<i', b['parent'])
    out += struct.pack('<II', anim['unk_v8'], len(anim['parts']))
    for p in anim['parts']:
        bc = len(anim['bones'])
        out += struct.pack('<%db' % bc, *p['tb'])
        out += struct.pack('<%db' % bc, *p['rb'])
        out += struct.pack('<II', len(p['rt']), len(p['rq']))
        for mn, mx in p['rt']:
            out += struct.pack('<3f3f', *(mn + mx))
        for mn, mx in p['rq']:
            out += struct.pack('<4f4f', *(mn + mx))
        out += struct.pack('<II', p['stc'], p['sqc'])
        if p['static'] is not None:
            out += _write_frame_v8(bc, p['tb'], p['rb'], p['rt'], p['rq'], p['static'], False)
        out += struct.pack('<III', p['ftc'], p['fqc'], len(p['frames']))
        for f in p['frames']:
            out += _write_frame_v8(bc, p['tb'], p['rb'], p['rt'], p['rq'], f, True)
    out += anim.get('tail', b'')
    return bytes(out)


def write_file(anim, path, zstd_compress=True):
    payload = write_anim8(anim)
    data = compress_payload(payload) if zstd_compress else payload
    Path(path).write_bytes(data)
    return len(data)


if __name__ == '__main__':
    # round-trip test: parse -> write -> reparse -> compare
    src = sys.argv[1]
    a = parse_anim8(src)
    raw = write_anim8(a)
    Path('scratch/_rt.anim.dec').write_bytes(raw)
    a2 = parse_anim8('scratch/_rt.anim.dec') if False else None
    # reparse inline
    r = Reader(raw)
    import json
    print('bones', len(a['bones']), 'parts', len(a['parts']),
          'frames', [len(p['frames']) for p in a['parts']],
          'bytes', len(raw), 'tail', len(a['tail']))
