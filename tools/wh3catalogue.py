#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""wh3catalogue.py —— 无头版 Mod Manager「单位图鉴」。

复用 wyccc-warhammer-mod-manager 后端 load_catalogue()，按当前 playset
(state.db) 的启用顺序合并：原版垫底 + 启用 pack/自动 Movie Pack 覆盖 +
已保存的单位修改，输出与启动器图鉴一致的单位面板数据（含 source_chain
标出每个单位的胜出 pack）。

用法：
    wh3catalogue.py                 # playset/来源/单位数 摘要 + 缺失文件
    wh3catalogue.py <unit_key>      # 单个单位面板 JSON（精确 key）
    wh3catalogue.py <子串>          # 无精确命中时列出前 20 个模糊匹配

须 Windows Python313（encyclopedia_assets 依赖 Pillow，压缩条目要
zstandard——与 wh3diag compat 同一环境要求）。路径可被环境变量覆盖：
WH3_GAME_ROOT / WH3_WMM_ROOT / WH3_WMM_APPDATA。
"""
import hashlib
import json
import os
import re
import sqlite3
import sys
from glob import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def local_path(s: str) -> Path:
    """Accept 'X:\\..' / POSIX paths (same convention as wh3diag)."""
    if os.name != "posix":
        return Path(os.path.expandvars(s))
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", s)
    if m:
        return Path("/mnt") / m.group(1).lower() / m.group(2).replace("\\", "/")
    return Path(s)


def _first_dir(cands) -> Path | None:
    for c in cands:
        if c and Path(c).is_dir():
            return Path(c)
    return None


def game_root() -> Path | None:
    return _first_dir([
        os.environ.get("WH3_GAME_ROOT"),
        r"E:\Program Files (x86)\Steam2\steamapps\common\Total War WARHAMMER III",
        "/mnt/e/Program Files (x86)/Steam2/steamapps/common/Total War WARHAMMER III",
    ])


def wmm_root() -> Path | None:
    return _first_dir([
        os.environ.get("WH3_WMM_ROOT"),
        r"E:\Code\wyccc-warhammer-mod-manager",
        "/mnt/e/Code/wyccc-warhammer-mod-manager",
    ])


def wmm_appdata() -> Path | None:
    cands = [os.environ.get("WH3_WMM_APPDATA")]
    ad = os.environ.get("APPDATA")
    if ad:
        cands.append(str(Path(ad) / "WycccModManager"))
    cands += sorted(glob("/mnt/[a-z]/Users/*/AppData/Roaming/WycccModManager"))
    return _first_dir(cands)


def _win_path(path: Path) -> str:
    s = str(path)
    if s.startswith("/mnt/") and len(s) > 6:
        s = s[5] + ":" + s[6:]
    return s.replace("\\", "/")


def _local_pack_id(path: Path) -> str:
    return "local:data:" + hashlib.sha256(
        _win_path(path).lower().encode()).hexdigest()[:18]


def main() -> int:
    if sys.platform != "win32":
        print("须 Windows Python313（backend 需要 Pillow/zstandard）", file=sys.stderr)
        return 2
    mm = wmm_root()
    g = game_root()
    ad = wmm_appdata()
    if not mm or not g or not ad:
        print("无法解析游戏/管理器路径（可设 WH3_GAME_ROOT/WH3_WMM_ROOT/WH3_WMM_APPDATA）",
              file=sys.stderr)
        return 2
    data_dir = g / "data"
    ws_root = g.parent.parent / "workshop" / "content" / "1142710"
    sys.path.insert(0, str(mm))
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    from backend.constants import (  # noqa: E402
        INTERNAL_FEATURE_PACK_NAMES, INTERNAL_RUNTIME_PACK_NAMES)
    from backend.models import ModAsset  # noqa: E402
    from backend.start_options import UNIT_DATA_PATCH_NAME  # noqa: E402
    from backend.unit_data_state import load_unit_data_edits  # noqa: E402
    from backend.unit_encyclopedia import load_catalogue  # noqa: E402

    def _asset(mod_id: str, path: Path, source: str) -> ModAsset:
        return ModAsset(
            id=mod_id, pack_name=path.name, display_name=path.stem,
            path=str(path), directory=str(path.parent), source=source)

    con = sqlite3.connect(str(ad / "state.db"))
    playset_id = con.execute(
        "SELECT value FROM app_state WHERE key='current_playset_id:warhammer3'"
    ).fetchone()[0]
    playset_name = con.execute(
        "SELECT name FROM playsets WHERE id=?", (playset_id,)).fetchone()[0]
    playset_ids = [r[0] for r in con.execute(
        "SELECT mod_id FROM playset_items WHERE playset_id=? ORDER BY position",
        (playset_id,)).fetchall()]

    mods: dict[str, ModAsset] = {}
    for pack in sorted(data_dir.glob("*.pack")):
        aid = _local_pack_id(pack)
        mods[aid] = _asset(aid, pack, "data")
    for pack in sorted(ws_root.glob("*/*.pack")):
        aid = f"steam:{pack.parent.name}:{pack.name}"
        mods[aid] = _asset(aid, pack, "steam")

    excluded = {n.casefold() for n in INTERNAL_FEATURE_PACK_NAMES}
    excluded |= {n.casefold() for n in INTERNAL_RUNTIME_PACK_NAMES}
    excluded.add(UNIT_DATA_PATCH_NAME.casefold())

    active_ids, missing = [], []
    for mod_id in playset_ids:
        asset = mods.get(mod_id)
        if asset is None and mod_id.startswith("steam:"):
            # Playset id 的大小写可能和盘上 pack 名不同，直接按 id 解析路径。
            _, wsid, pack_name = mod_id.split(":", 2)
            path = ws_root / wsid / pack_name
            if path.is_file():
                asset = _asset(mod_id, path, "steam")
                mods[mod_id] = asset
        if asset is None or not Path(asset.path).is_file():
            missing.append(mod_id)
            continue
        if Path(asset.path).name.casefold() in excluded:
            continue
        active_ids.append(mod_id)

    edits = load_unit_data_edits(ad / "runtime", "warhammer3")
    result, _assets = load_catalogue(data_dir, mods, active_ids, edits, "zh-CN")

    print(f"playset: {playset_name} ({playset_id})")
    print(f"active sources: {result.get('source_count')}, playset items: "
          f"{len(playset_ids)}, missing files: {len(missing)}")
    for m in missing:
        print(f"  MISSING {m}")
    print(f"saved unit edits applied: {len(edits)}")

    units = {u["key"]: u for u in result.get("units", [])}
    print(f"races: {len(result.get('races', []))}, units: {len(units)}")

    key = sys.argv[1] if len(sys.argv) > 1 else ""
    if key.startswith("--stats"):
        sub = sys.argv[2].lower() if len(sys.argv) > 2 else ""
        hits = sorted((units[k] for k in units if sub in k.lower()),
                      key=lambda u: u["key"])
        cols = ("key", "model_count", "recruitment_cost", "health",
                "armour_value", "shield", "melee_attack", "melee_defence",
                "morale", "charge_bonus", "melee_damage", "melee_ap_damage",
                "missile_damage", "missile_ap_damage", "range", "speed",
                "mass", "melee_bonus_v_large")
        print("\t".join(cols))
        for u in hits:
            print("\t".join(str(u.get(c, "")) for c in cols))
        return 0
    if key.startswith("--list"):
        sub = sys.argv[2].lower() if len(sys.argv) > 2 else key[6:].strip("-=").lower()
        hits = sorted(k for k in units if sub in k.lower())
        print(f"matches: {len(hits)}")
        print("\n".join(hits))
        return 0
    if key:
        hit = units.get(key)
        if hit is None:
            print(f"unit {key!r} not in catalogue")
            near = [k for k in units if key.lower() in k.lower()][:20]
            print("near:", *near, sep="\n  ")
            return 1
        print(json.dumps(hit, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
