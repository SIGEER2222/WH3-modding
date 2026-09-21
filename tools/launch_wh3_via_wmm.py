"""通过 Wyccc Mod Manager 后端 API 启动战锤3并载入最新存档。

与 UI 的"启动游戏"走同一条代码路径：
get_bootstrap -> scan_mods -> launch_game(ordered_mod_ids, order_token, save_name)。

用法：
    python tools/launch_wh3_via_wmm.py [--save <存档文件名>]

需用 Windows Python 运行（仓库位于 Windows 侧）。游戏必须未在运行。
"""
from __future__ import annotations

import argparse
import sys

sys.path.insert(0, r"E:\Code\wyccc-warhammer-mod-manager")

from backend.api import API  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--save", default="", help="存档文件名（默认最新）")
    parser.add_argument("--menu", action="store_true",
                        help="不加载存档，只启动到主菜单")
    args = parser.parse_args()

    api = API()

    boot = api.call("get_bootstrap")
    if not boot.get("ok"):
        print("bootstrap failed:", boot)
        return 1
    data = boot["data"]
    mod_ids = list(data["enabled_order"])
    token = data["order_token"]
    playset = data["current_playset"].get("name")
    print(f"playset={playset} mods={len(mod_ids)} token={token}")

    scan = api.call("scan_mods", [False])
    if not scan.get("ok"):
        print("scan failed:", scan)
        return 1
    print(f"scanned assets={len(api._assets)}")

    if args.menu:
        save_name = ""
    else:
        save_name = args.save or api.save_games.latest()["name"]
    print(f"save={save_name or '(main menu)'}")

    result = api.call("launch_game", [mod_ids, token, save_name])
    print(result)
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
