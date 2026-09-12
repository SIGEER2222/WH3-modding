# -*- coding: utf-8 -*-
"""Generate deterministic placeholder unit cards for the czx expansion.

These are original vector-style cards, not extracted SC2 assets or 3D models.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(r"E:\Code\WH3-modding")
OUT = ROOT / "mod_files" / "czx_swarm_expansion" / "ui"


def card(name: str, bg, accent, kind: str):
    w, h = 60, 130
    im = Image.new("RGBA", (w, h), bg + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, w - 2, h - 2), outline=(120, 70, 45, 255), width=2)
    d.rectangle((4, 4, w - 5, h - 5), outline=(30, 18, 24, 220), width=1)

    if kind == "mutalisk":
        d.ellipse((20, 42, 40, 83), fill=accent + (255,))
        d.polygon([(24, 51), (2, 27), (9, 62), (23, 70)], fill=(85, 38, 92, 255))
        d.polygon([(36, 51), (58, 27), (51, 62), (37, 70)], fill=(85, 38, 92, 255))
        d.polygon([(25, 74), (15, 111), (30, 86)], fill=(140, 49, 62, 255))
        d.polygon([(35, 74), (45, 111), (30, 86)], fill=(140, 49, 62, 255))
        d.ellipse((26, 46, 34, 57), fill=(236, 151, 67, 255))
    elif kind == "roach":
        d.ellipse((16, 36, 44, 97), fill=accent + (255,))
        d.ellipse((21, 26, 39, 54), fill=(89, 136, 67, 255))
        for x in (11, 49):
            d.line((30, 62, x, 43), fill=(174, 128, 62, 255), width=3)
            d.line((30, 73, x, 86), fill=(174, 128, 62, 255), width=3)
            d.line((30, 85, x + (5 if x < 30 else -5), 105), fill=(174, 128, 62, 255), width=3)
        d.ellipse((25, 28, 35, 39), fill=(197, 219, 93, 255))
        d.ellipse((28, 30, 32, 34), fill=(18, 29, 20, 255))
    elif kind == "kerrigan":
        d.ellipse((14, 28, 46, 88), fill=accent + (255,))
        d.polygon([(16, 39), (2, 14), (20, 27), (30, 13), (40, 27), (58, 14), (44, 42)], fill=(99, 46, 139, 255))
        d.ellipse((21, 47, 27, 53), fill=(98, 227, 232, 255))
        d.ellipse((33, 47, 39, 53), fill=(98, 227, 232, 255))
        d.polygon([(21, 90), (11, 119), (30, 101), (49, 119), (39, 90)], fill=(61, 33, 95, 255))
        d.line((30, 70, 30, 104), fill=(137, 241, 237, 230), width=2)
    else:
        d.ellipse((15, 34, 45, 96), fill=accent + (255,))

    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((10, 20, 50, 112), outline=accent + (80,), width=3)
    glow = glow.filter(ImageFilter.GaussianBlur(4))
    im = Image.alpha_composite(im, glow)
    return im.convert("RGB")


cards = {
    "czx_feilong": ((28, 17, 44), (182, 69, 163), "mutalisk"),
    "czx_zhanglang": ((25, 37, 24), (104, 157, 70), "roach"),
    "czx_kerrigan": ((31, 17, 48), (117, 64, 176), "kerrigan"),
    "czx_kerrigan_lord": ((31, 17, 48), (117, 64, 176), "kerrigan"),
}

for key, (bg, accent, kind) in cards.items():
    for folder in (OUT / "units" / "icons", OUT / "portraits" / "units" / "no_culture"):
        folder.mkdir(parents=True, exist_ok=True)
        card(key, bg, accent, kind).save(folder / f"{key}.png")
    info = card(key, bg, accent, kind).resize((120, 260), Image.Resampling.LANCZOS)
    info_folder = OUT / "units" / "infopics"
    info_folder.mkdir(parents=True, exist_ok=True)
    info.save(info_folder / f"{key}.png")

icons = {
    "czx_ability_mutalisk_regeneration": ((42, 21, 58), (208, 84, 190), "mutalisk"),
    "czx_ability_roach_regenerative_tissue": ((24, 55, 25), (143, 204, 85), "roach"),
    "czx_ability_zergling_adrenal_glands": ((63, 26, 21), (226, 111, 55), "roach"),
    "czx_ability_ultralisk_frenzied": ((55, 21, 19), (230, 94, 65), "kerrigan"),
}
for key, (bg, accent, kind) in icons.items():
    icon = card(key, bg, accent, kind).resize((38, 38), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", (38, 38), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((1, 1, 36, 36), fill=255)
    icon.putalpha(mask)
    icon_dir = OUT / "battle ui" / "ability_icons"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon.save(icon_dir / f"{key}.png")

print(f"generated {len(cards)} card sets and {len(icons)} ability icons under {OUT}")
