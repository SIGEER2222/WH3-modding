# -*- coding: utf-8 -*-
"""CLI: parse one save and print/emit the campaign summary JSON.

Usage: python -m web_progress.parse_save <save_path> [out.json]
"""
import json
import sys
import time

from .parser.campaign import summarize_save


def main():
    if len(sys.argv) < 2:
        print("usage: parse_save <save_path> [out.json]")
        return 2
    t0 = time.time()
    summary = summarize_save(sys.argv[1])
    dt = time.time() - t0
    text = json.dumps(summary, ensure_ascii=False, indent=1)
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            f.write(text)
    save = summary["save"]
    player = summary["player"] or {}
    print("parsed in %.1fs" % dt)
    print("save: %s | campaign: %s | version: %s" % (save["name"], save["campaign"], save["version"]))
    print("turn: %s | season: %s | player: %s (%s)" % (
        save["turn"], save["season"], save["player_faction_key"], save["player_faction_name"]))
    print("player treasury: %s | forces: %s | units: %s | characters: %s" % (
        player.get("treasury"), player.get("forces"), player.get("units"), player.get("characters")))
    print("world: %s factions, %s regions | mods: %d" % (
        summary["world"]["faction_count"], summary["world"]["region_count"], len(save["mods"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
