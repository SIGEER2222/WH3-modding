"""重建 !czx_yinyin_expedition_fix.pack。

从本机 Workshop 目录读取 !cth_yinyin_expedition.pack 与 cth_yinyin_pol.pack，
把必须生效的 DB 片段复制到唯一片段名 zzz_yinyin_exp_fix 下，生成 PFH5 pack
写入游戏 data 目录。详见 README.md。
"""
import struct, os, uuid, sys

WS = r'E:\Program Files (x86)\Steam2\steamapps\workshop\content\1142710'
DATA = r'E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III\data'
EXP_PACK = os.path.join(WS, '3670461603', '!cth_yinyin_expedition.pack')
BASE_PACK = os.path.join(WS, '2989226363', 'cth_yinyin_pol.pack')
OUT = os.path.join(DATA, '!czx_yinyin_expedition_fix.pack')
FRAG = 'zzz_yinyin_exp_fix'

def pack_files(path):
    data = open(path, 'rb').read()
    count = struct.unpack_from('<I', data, 16)[0]
    idx = struct.unpack_from('<I', data, 20)[0]
    dep = struct.unpack_from('<I', data, 12)[0]
    pp = 28 + dep
    ents = []
    for _ in range(count):
        size = struct.unpack_from('<I', data, pp)[0]
        pp += 5
        e = data.find(b'\x00', pp)
        ents.append((data[pp:e].decode('utf-8', 'replace'), size))
        pp = e + 1
    off = 28 + dep + idx
    files = {}
    for name, size in ents:
        files[name.replace('/', '\\')] = data[off:off + size]
        off += size
    return files

def reguid(raw):
    assert raw[:4] == b'\xfd\xfe\xfc\xff', 'not a DB fragment'
    glen = struct.unpack_from('<H', raw, 4)[0]
    new_guid = str(uuid.uuid4()).encode('utf-16le')
    return raw[:6] + new_guid + raw[6 + glen * 2:]

def main():
    exp = pack_files(EXP_PACK)
    base = pack_files(BASE_PACK)
    out_files = {
        f'db\\character_skill_nodes_tables\\{FRAG}':
            reguid(exp['db\\character_skill_nodes_tables\\cth_yinyin']),
        f'db\\character_skill_node_links_tables\\{FRAG}':
            reguid(exp['db\\character_skill_node_links_tables\\cth_yinyin']),
        f'db\\character_skill_node_set_items_tables\\{FRAG}':
            reguid(exp['db\\character_skill_node_set_items_tables\\cth_yinyin']),
        f'db\\character_skill_node_sets_tables\\{FRAG}':
            reguid(base['db\\character_skill_node_sets_tables\\cth_yinyin']),
    }
    names = sorted(out_files)
    index = bytearray()
    blob = bytearray()
    for n in names:
        raw = out_files[n]
        index += struct.pack('<I', len(raw)) + b'\x00' + n.encode('utf-8') + b'\x00'
        blob += raw
    header = (b'PFH5' + struct.pack('<I', 3) + b'\x00' * 4 + struct.pack('<I', 0)
              + struct.pack('<I', len(names)) + struct.pack('<I', len(index))
              + uuid.uuid4().bytes[:4])
    open(OUT, 'wb').write(header + bytes(index) + bytes(blob))
    print('wrote', OUT, 'files:', len(names))
    for n in names:
        print('  ', n, len(out_files[n]))

if __name__ == '__main__':
    sys.exit(main())
