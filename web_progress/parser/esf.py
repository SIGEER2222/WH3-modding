# -*- coding: utf-8 -*-
"""ESF (Empire Save File) CBAB/CAAB reader for Total War: WARHAMMER III save games.

Format reference: RPFM `rpfm_lib/src/files/esf/` (MIT License,
Copyright (c) 2017-2026 Ismael Gutiérrez González,
https://github.com/Frodo45127/rpfm). This is an independent Python
implementation of the same on-disk format, extended with the byte layout
verified against real WH3 9.x saves (record names use u16 length prefixes).

WH3 .save layout:
  outer ESF (CBAB) whose root contains a COMPRESSED_DATA record holding an
  LZMA1-compressed inner ESF (the actual CAMPAIGN_SAVE_GAME tree).
"""

import lzma
import struct

SIGNATURE_CBAB = b"\xcb\xab\x00\x00"
SIGNATURE_CAAB = b"\xca\xab\x00\x00"

# Node type markers (RPFM esf/mod.rs)
BOOL, I8, I16, I32, I64, U8, U16, U32, U64, F32, F64 = range(0x01, 0x0c)
COORD_2D, COORD_3D, UTF16, ASCII, ANGLE = 0x0c, 0x0d, 0x0e, 0x0f, 0x10
BOOL_TRUE, BOOL_FALSE = 0x12, 0x13
U32_ZERO, U32_ONE, U32_BYTE, U32_16BIT, U32_24BIT = 0x14, 0x15, 0x16, 0x17, 0x18
I32_ZERO, I32_BYTE, I32_16BIT, I32_24BIT, F32_ZERO = 0x19, 0x1a, 0x1b, 0x1c, 0x1d
UNKNOWN_21, UNKNOWN_23, UNKNOWN_24, UNKNOWN_25, UNKNOWN_26 = 0x21, 0x23, 0x24, 0x25, 0x26
ARRAY_FIRST, ARRAY_LAST = 0x41, 0x5d
U8_ARRAY = 0x46

PRIM_ADVANCE = {
    BOOL: 1, I8: 1, I16: 2, I32: 4, I64: 8, U8: 1, U16: 2, U32: 4, U64: 8,
    F32: 4, F64: 8, COORD_2D: 8, COORD_3D: 12, UTF16: 4, ASCII: 4, ANGLE: 2,
    BOOL_TRUE: 0, BOOL_FALSE: 0, U32_ZERO: 0, U32_ONE: 0, I32_ZERO: 0, F32_ZERO: 0,
    U32_BYTE: 1, U32_16BIT: 2, U32_24BIT: 3,
    I32_BYTE: 1, I32_16BIT: 2, I32_24BIT: 3,
    UNKNOWN_21: 4, UNKNOWN_23: 1, UNKNOWN_24: 2, UNKNOWN_25: 4,
}

_ZERO_VALUE = {U32_ZERO: 0, U32_ONE: 1, I32_ZERO: 0, F32_ZERO: 0.0}

_STR_FMT = {
    I8: "<b", I16: "<h", I32: "<i", I64: "<q", U8: "<B", U16: "<H",
    U32: "<I", U64: "<Q", F32: "<f", F64: "<d",
    COORD_2D: "<2f", COORD_3D: "<3f", ANGLE: "<h",
    U32_BYTE: "<B", U32_16BIT: "<H", I32_BYTE: "<b", I32_16BIT: "<h",
    UNKNOWN_21: "<I", UNKNOWN_23: "<B", UNKNOWN_24: "<H", UNKNOWN_25: "<I",
}


class EsfError(Exception):
    pass


def read_cauleb128(data, pos):
    """Compressed unsigned LEB128 (7 bits per byte, high bit = continue)."""
    value = 0
    byte = data[pos]
    pos += 1
    while byte & 0x80:
        value = (value << 7) | (byte & 0x7F)
        byte = data[pos]
        pos += 1
    return (value << 7) | (byte & 0x7F), pos


class EsfFile:
    """Parsed header + string tables of one ESF buffer (outer or inner)."""

    __slots__ = ("signature", "unknown_1", "creation_date", "record_names",
                 "strings_utf16", "strings_utf8", "names_offset")

    def __init__(self, data):
        if data[:4] == SIGNATURE_CBAB:
            self.signature = "CBAB"
        elif data[:4] == SIGNATURE_CAAB:
            self.signature = "CAAB"
        else:
            raise EsfError("not an ESF buffer (magic %r)" % bytes(data[:4]))
        self.unknown_1 = struct.unpack_from("<I", data, 4)[0]
        self.creation_date = struct.unpack_from("<I", data, 8)[0]
        self.names_offset = struct.unpack_from("<I", data, 12)[0]
        pos = self.names_offset
        count, pos = self._u16(data, pos)
        names = []
        # Record names: u16 length prefixes on WH3 9.x saves (verified against
        # real bytes; differs from RPFM's u8 CBAB doc). CAAB keeps u8 per RPFM.
        if self.signature == "CBAB":
            for _ in range(count):
                n, pos = self._u16(data, pos)
                names.append(data[pos:pos + n].decode("utf-8", "replace"))
                pos += n
        else:
            for _ in range(count):
                n = data[pos]
                pos += 1
                names.append(data[pos:pos + n].decode("utf-8", "replace"))
                pos += n
        self.record_names = names

        self.strings_utf16 = {}
        self.strings_utf8 = {}
        if self.signature == "CBAB":
            n16, pos = self._u32(data, pos)
            for _ in range(n16):
                slen, pos = self._u32(data, pos)
                s = data[pos:pos + slen * 2].decode("utf-16-le", "replace")
                pos += slen * 2
                idx, pos = self._u32(data, pos)
                self.strings_utf16[idx] = s
            n8, pos = self._u32(data, pos)
            for _ in range(n8):
                slen, pos = self._u32(data, pos)
                s = data[pos:pos + slen].decode("utf-8", "replace")
                pos += slen
                idx, pos = self._u32(data, pos)
                self.strings_utf8[idx] = s
        else:  # CAAB: u16 sizes + u16 indices
            n16, pos = self._u16(data, pos)
            for _ in range(n16):
                slen, pos = self._u16(data, pos)
                s = data[pos:pos + slen * 2].decode("utf-16-le", "replace")
                pos += slen * 2
                idx, pos = self._u16(data, pos)
                self.strings_utf16[idx] = s
            n8, pos = self._u16(data, pos)
            for _ in range(n8):
                slen, pos = self._u16(data, pos)
                s = data[pos:pos + slen].decode("utf-8", "replace")
                pos += slen
                idx, pos = self._u16(data, pos)
                self.strings_utf8[idx] = s

    @staticmethod
    def _u16(data, pos):
        return struct.unpack_from("<H", data, pos)[0], pos + 2

    @staticmethod
    def _u32(data, pos):
        return struct.unpack_from("<I", data, pos)[0], pos + 4


def read_primitive(data, pos, marker, esf):
    """Read one primitive value. Returns (value, new_pos)."""
    if marker == UTF16:
        idx = struct.unpack_from("<I", data, pos)[0]
        return esf.strings_utf16.get(idx, "<utf16:%d>" % idx), pos + 4
    if marker == ASCII:
        idx = struct.unpack_from("<I", data, pos)[0]
        return esf.strings_utf8.get(idx, "<utf8:%d>" % idx), pos + 4
    if marker in _ZERO_VALUE:
        return _ZERO_VALUE[marker], pos
    if marker in (BOOL_TRUE, BOOL_FALSE):
        return marker == BOOL_TRUE, pos
    if marker == U32_24BIT:
        return int.from_bytes(data[pos:pos + 3], "little"), pos + 3
    if marker == I32_24BIT:
        return int.from_bytes(data[pos:pos + 3], "little", signed=True), pos + 3
    if marker == UNKNOWN_26:
        first = data[pos]
        pos += 1
        if first % 8 == 0 and first != 0:
            payload = data[pos:pos + first]
            pos += first
        else:
            payload = data[pos:pos + 7]
            pos += 7
        if pos < len(data) and data[pos] == 0x9C:
            pos += 1
        return bytes(payload), pos
    fmt = _STR_FMT.get(marker)
    if fmt is None:
        raise EsfError("cannot read primitive marker 0x%02x at %d" % (marker, pos))
    size = struct.calcsize(fmt)
    vals = struct.unpack_from(fmt, data, pos)
    return (vals if len(vals) > 1 else vals[0]), pos + size


def walk_esf(data, esf, on_record=None):
    """Single-pass structural walk of the ESF node tree.

    on_record(path, name, version, parent_collector) is called for every record
    (path is the live path list — treat as read-only). It may return a
    collector object; primitives inside that record's subtree are then reported
    to collector.primitive(marker, value) and arrays to collector.array(marker,
    start, end). Nested records inherit the parent collector unless they return
    their own. Returning None keeps the parent collector.
    """
    names = esf.record_names
    n_names = len(names)
    len_data = len(data)

    def read_record_header(pos, is_root):
        next_byte = data[pos]
        pos += 1
        if not (next_byte & 0x80):
            raise EsfError("expected record marker at %d" % (pos - 1))
        has_non_opt = bool(next_byte & 0x20) or is_root
        if has_non_opt:
            name_index = struct.unpack_from("<H", data, pos)[0]
            pos += 2
            version = data[pos]
            pos += 1
        else:
            version = (next_byte & 0x1E) >> 1
            name_index = ((next_byte & 1) << 8) | data[pos]
            pos += 1
        if name_index >= n_names:
            raise EsfError("record name index %d out of range at %d" % (name_index, pos))
        block_size, pos = read_cauleb128(data, pos)
        if next_byte & 0x40:
            group_count, pos = read_cauleb128(data, pos)
            has_nested = True
        else:
            group_count = 1
            has_nested = False
        return names[name_index], version, has_nested, group_count, pos, pos + block_size

    path = []
    root_name, root_version, root_nested, root_groups, pos, root_final = read_record_header(16, True)
    path.append(root_name)
    root_collector = None
    if on_record is not None:
        root_collector = on_record(path, root_name, root_version, None)

    # frame: [final_block, has_nested, remaining_groups, collector, name, mid_group_entry]
    stack = [[root_final, root_nested, root_groups, root_collector, root_name, None]]

    while stack:
        frame = stack[-1]
        final_block, has_nested, group_count, collector, rec_name, mid_entry = frame
        if mid_entry is None:
            if group_count == 0:
                stack.pop()
                path.pop()
                if pos != final_block:
                    raise EsfError("record %s block underrun %d != %d"
                                   % (rec_name, pos, final_block))
                continue
            frame[2] = group_count - 1
            if has_nested:
                entry_size, pos = read_cauleb128(data, pos)
                mid_entry = pos + entry_size
            else:
                mid_entry = final_block
            frame[5] = mid_entry
        # process children until group end or a child record starts
        child_pushed = False
        while pos < mid_entry:
            marker = data[pos]
            if marker & 0x80:
                cname, cversion, c_nested, c_groups, pos, c_final = read_record_header(pos, False)
                path.append(cname)
                c_collector = collector
                if on_record is not None:
                    ret = on_record(path, cname, cversion, collector)
                    if ret is not None:
                        c_collector = ret
                stack.append([c_final, c_nested, c_groups, c_collector, cname, None])
                child_pushed = True
                break
            if marker in PRIM_ADVANCE:
                if collector is None:
                    pos += 1 + PRIM_ADVANCE[marker]
                else:
                    val, pos = read_primitive(data, pos + 1, marker, esf)
                    collector.primitive(marker, val)
            elif ARRAY_FIRST <= marker <= ARRAY_LAST:
                size, pos = read_cauleb128(data, pos + 1)
                end = pos + size
                if end > len_data:
                    raise EsfError("array overruns buffer at %d" % pos)
                if collector is not None:
                    collector.array(marker, pos, end)
                pos = end
            else:
                raise EsfError("unknown node marker 0x%02x at %d" % (marker, pos))
        if child_pushed:
            continue
        if pos != mid_entry:
            raise EsfError("record %s group underrun %d != %d" % (rec_name, pos, mid_entry))
        if collector is not None and hasattr(collector, "end_group"):
            collector.end_group()
        frame[5] = None  # group done; next iteration starts the following group
    return root_collector


class _CompressedDataCollector:
    """Collects everything inside COMPRESSED_DATA; pieces are picked afterwards
    because the game may store the size with optimized int markers."""

    def __init__(self):
        self._data = None
        self.ints = []
        self.u8_arrays = []

    def primitive(self, marker, value):
        if isinstance(value, int):
            self.ints.append(value)

    def array(self, marker, start, end):
        if marker == U8_ARRAY:
            self.u8_arrays.append((start, end))

    def payload(self):
        if not self.u8_arrays:
            return None
        start, end = self.u8_arrays[0]
        return bytes(self._data[start:end])

    def magic5(self):
        if len(self.u8_arrays) < 2:
            return None
        start, end = self.u8_arrays[1]
        return bytes(self._data[start:end])

    def size(self):
        return self.ints[0] if self.ints else None


def decompress_campaign_env(outer_data, esf=None):
    """Extract + LZMA-decompress the inner ESF from an outer .save CBAB buffer."""
    if esf is None:
        esf = EsfFile(outer_data)

    collector = _CompressedDataCollector()
    collector._data = outer_data

    def on_record(path, name, version, parent):
        if name == "COMPRESSED_DATA":
            return collector
        return parent

    walk_esf(outer_data, esf, on_record=on_record)
    size = collector.size()
    magic5 = collector.magic5()
    payload = collector.payload()
    if payload is None or size is None or magic5 is None:
        raise EsfError("COMPRESSED_DATA/COMPRESSED_DATA_INFO not found or incomplete "
                       "(ints=%d u8arrays=%d)" % (len(collector.ints), len(collector.u8_arrays)))
    fixed = magic5 + struct.pack("<Q", size & 0xFFFFFFFF) + payload
    try:
        return lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(fixed)
    except lzma.LZMAError:
        fixed = magic5 + b"\xff" * 8 + payload
        return lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(fixed)


def load_save(save_path):
    """Read a .save file from disk and return (esf_meta, inner_esf_bytes)."""
    with open(save_path, "rb") as f:
        outer = f.read()
    esf = EsfFile(outer)
    inner = decompress_campaign_env(outer, esf)
    return esf, inner
