# -*- coding: utf-8 -*-
"""Pack a mod's loose battle animsuite .bin files into a .animpack container.

WH3 battle animation system only loads animsuite bins embedded inside
``.animpack`` containers under ``animations/`` (vanilla:
``animations/database/battle/bin/animation_tables*.animpack``; working mods
e.g. Imperial Arbiter ``h3_yu_monsters.animpack``, salzaar digimon
``chr###.animpack``). A loose ``animations/database/battle/bin/<key>.bin``
in a mod pack is NOT registered -> units render in bind pose with no
move/attack/etc. animations. [实测 2026-09-23]

.animpack payload format (uncompressed):
    u32 entry_count
    per entry:  str16 internal_path | u32 byte_len | bytes
internal_path convention: ``animations/database/battle/bin/<animset_key>.bin``
(matches vanilla animation_tables.animpack and chr004.animpack).

Usage:
    python tools/pack_animsets.py <mod_dir_name> [--out <name>.animpack] [--remove-loose]

- Scans  mod_files/<mod>/animations/database/battle/bin/*.bin
- Writes mod_files/<mod>/animations/database/battle/bin/<out>.animpack
  (default: <mod>_animsets.animpack)
- Skips existing .animpack files; loose .bin kept unless --remove-loose.
"""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _wr_str(s: str) -> bytes:
    b = s.encode("utf-8")
    return struct.pack("<H", len(b)) + b


def build_animpack(bin_paths: list[Path], mod_root: Path) -> bytes:
    out = bytearray()
    out += struct.pack("<I", len(bin_paths))
    for bp in bin_paths:
        internal = "animations/database/battle/bin/" + bp.name
        data = bp.read_bytes()
        out += _wr_str(internal)
        out += struct.pack("<I", len(data))
        out += data
    return bytes(out)


def parse_animpack(payload: bytes):
    """Yield (internal_path, bin_bytes) — for verification."""
    (cnt,) = struct.unpack_from("<I", payload, 0)
    off = 4
    for _ in range(cnt):
        (ln,) = struct.unpack_from("<H", payload, off)
        off += 2
        name = payload[off:off + ln].decode("utf-8")
        off += ln
        (bl,) = struct.unpack_from("<I", payload, off)
        off += 4
        yield name, payload[off:off + bl]
        off += bl
    if off != len(payload):
        raise ValueError(f"trailing {len(payload) - off} bytes")


def bin_animset_name(b: bytes) -> str:
    (ln,) = struct.unpack_from("<H", b, 8)
    return b[10:10 + ln].decode("utf-8")


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    mod = args[0]
    out_name = None
    remove_loose = "--remove-loose" in args
    if "--out" in args:
        out_name = args[args.index("--out") + 1]

    mod_root = ROOT / "mod_files" / mod
    bin_dir = mod_root / "animations" / "database" / "battle" / "bin"
    if not bin_dir.is_dir():
        print(f"no bin dir: {bin_dir}")
        return 1

    bins = sorted(p for p in bin_dir.glob("*.bin"))
    if not bins:
        print("no loose .bin files found")
        return 1

    out_name = out_name or f"{mod}_animsets.animpack"
    out_path = bin_dir / out_name

    payload = build_animpack(bins, mod_root)

    # self-check: re-parse
    names = []
    for path, data in parse_animpack(payload):
        names.append((path, bin_animset_name(data), len(data)))
    out_path.write_bytes(payload)

    print(f"{out_path.relative_to(mod_root)}  <-  {len(bins)} bins, {len(payload)} bytes")
    for path, inner, bl in names:
        stem = Path(path).stem
        flag = "OK" if stem == inner else f"MISMATCH(inner={inner})"
        print(f"   {stem:46s} {bl:7d}B  {flag}")
    if remove_loose:
        for bp in bins:
            bp.unlink()
        print(f"removed {len(bins)} loose .bin")
    else:
        print("loose .bin kept (harmless either way; delete later if desired)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
