# -*- coding: utf-8 -*-
"""Generate unit card / portrait / infopic PNGs for the 5 infested units
from the Blender front-view renders in tools/_out.

Outputs:
  ui/units/icons/<key>.png          60x130
  ui/portraits/units/no_culture/<key>.png  60x130
  ui/units/infopics/<key>.png       120x260
"""
from pathlib import Path
from PIL import Image

ROOT = Path(r"E:\Code\WH3-modding")
MOD = ROOT / "mod_files" / "zzz_czx_swarm_units"
OUT = ROOT / "tools" / "_out"

UNITS = {
    "czx_baolongshou": "card_baolongshou_front.png",
    "czx_inf_tank": "card_inf_tank_front.png",
    "czx_dehaka": "card_dehaka_front.png",
    "czx_inf_diamondback": "card_diamondback_front.png",
    "czx_inf_marine": "card_marine_front.png",
}

BG = (64, 64, 77)  # workbench world colour ~ (0.25,0.25,0.3)*255


def content_bbox(im):
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y][:3]
            if abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 45:
                xs.append(x)
                ys.append(y)
    if not xs:
        return (0, 0, w, h)
    return (max(min(xs) - 10, 0), max(min(ys) - 10, 0),
            min(max(xs) + 10, w), min(max(ys) + 10, h))


def make_card(im, w, h):
    box = content_bbox(im)
    crop = im.crop(box)
    # fit into portrait frame preserving aspect, anchored to bottom-center
    cw, ch = crop.size
    scale = min(w / cw, h / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    card = Image.new("RGB", (w, h), BG)
    card.paste(crop, ((w - nw) // 2, h - nh))
    return card


def main():
    for key, src in UNITS.items():
        im = Image.open(OUT / src).convert("RGB")
        icon = make_card(im, 60, 130)
        info = make_card(im, 120, 260)
        icon.save(MOD / "ui" / "units" / "icons" / f"{key}.png")
        icon.save(MOD / "ui" / "portraits" / "units" / "no_culture" / f"{key}.png")
        info.save(MOD / "ui" / "units" / "infopics" / f"{key}.png")
        print("cards for", key)


if __name__ == "__main__":
    main()
