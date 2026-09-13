# -*- coding: utf-8 -*-
"""List/extract battle animation clips for given skeletons from CA anim packs."""
import struct, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from export_gamedata import iter_pack_entries, GAME_DATA

def list_index(path):
    """Return [(name, offset, size)] without reading payloads."""
    with open(path, 'rb') as f:
        header = f.read(28)
        if len(header) != 28 or header[:4] not in (b"PFH5", b"PFH6"):
            return []
        _, _, dep_size, file_count, index_size, _ = struct.unpack_from("<6i", header, 4)
        f.seek(28 + dep_size)
        index = f.read(index_size)
        data_offset = 28 + dep_size + index_size
        cursor, offset, out = 0, data_offset, []
        for _ in range(file_count):
            size = struct.unpack_from("<i", index, cursor)[0]
            cursor += 5
            end = index.find(b"\0", cursor)
            name = index[cursor:end].decode("utf-8", errors="replace")
            cursor = end + 1
            out.append((name.replace("\\", "/"), offset, size))
            offset += size
        return out

def main():
    skels = sys.argv[1].split(',') if len(sys.argv) > 1 else [
        'humanoid06', 'humanoid01b', 'humanoid11b', 'spider01', 'crab01']
    packs = sorted(GAME_DATA.glob('anim*.pack'))
    for pack in packs:
        names = list_index(pack)
        hits = [n for n, _, _ in names if n.startswith('animations/battle/')]
        if not hits:
            continue
        print(f'== {pack.name}: {len(hits)} battle anims')
        for sk in skels:
            pref = f'animations/battle/{sk}/'
            mine = [n for n in hits if n.startswith(pref)]
            if mine:
                print(f'  {sk}: {len(mine)} clips')
                # show a few attack/idle examples
                atk = [n for n in mine if 'attack' in n.lower()][:3]
                idle = [n for n in mine if 'stand_idle' in n.lower() or '/stand/' in n.lower()][:3]
                for n in (atk + idle):
                    print('    ', n)

if __name__ == '__main__':
    main()
