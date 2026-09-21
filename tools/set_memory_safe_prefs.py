# -*- coding: utf-8 -*-
"""把 WH3 的 AppData 画质/内存档位设为 OOM 安全值。

背景：16GB 物理内存 + 百余项单位类 Mod 的机器，在
`minimise_memory_usage false` + `gfx_*_quality 3`(ultra) + `gfx_unit_size 3`
下，战斗 init 的提交内存会冲到 40-47GB 并触发 System Event 2004（虚拟内存
耗尽）→ 引擎 fail-fast 崩溃。详见
warhammer-mod-development_generic/references/crash_and_load_order_diagnostics.md
§10.19。

用法（须用 Windows Python 运行，脚本硬编码本机路径）：
  python tools/set_memory_safe_prefs.py            # 降到 level 2
  python tools/set_memory_safe_prefs.py --level 1  # 更激进，画质损失更大
  python tools/set_memory_safe_prefs.py --dry      # 只看会改什么
"""
import argparse
import os
import re
import shutil
import time

PREF = os.path.join(
    os.environ.get("APPDATA", ""),
    r"The Creative Assembly\Warhammer3\scripts\preferences.script.txt")

# 键 -> 目标值（level 2 / level 1）。None 表示该 level 不改。
PLAN = {
    "minimise_memory_usage": (True, True),          # bool
    "gfx_texture_quality": (2, 1),
    "gfx_unit_size": (2, 1),
    "gfx_unit_quality": (2, 1),
    "gfx_effects_quality": (2, 1),
    "gfx_terrain_quality": (2, 1),
    "gfx_shadow_quality": (2, 1),
    "gfx_tree_quality": (2, 1),
    "gfx_grass_quality": (2, 1),
    "gfx_water_quality": (2, 1),
    "gfx_sky_quality": (2, 1),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", type=int, default=2, choices=[1, 2])
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    if not os.path.isfile(PREF):
        print(f"preferences not found: {PREF}")
        return 1
    idx = 0 if a.level == 2 else 1

    text = open(PREF, "r", encoding="utf-8").read()
    out = text
    changes = []
    for key, targets in PLAN.items():
        want = targets[idx]
        m = re.search(rf"^{re.escape(key)} ([^;]+);", out, re.M)
        if not m:
            continue
        cur = m.group(1).strip()
        want_s = "true" if isinstance(want, bool) else str(want)
        if cur != want_s:
            out = out[:m.start(1)] + want_s + out[m.end(1):]
            changes.append(f"  {key}: {cur} -> {want_s}")

    if not changes:
        print("already at safe level, nothing to do")
        return 0
    print(f"level={a.level} changes:")
    print("\n".join(changes))
    if a.dry:
        return 0

    bak = PREF + ".bak_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copy2(PREF, bak)
    with open(PREF, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    print(f"\nbackup -> {bak}")
    print("note: if a game instance is running, a clean exit may overwrite "
          "these values from memory -- re-run this script after the game "
          "closes if the crash returns.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
