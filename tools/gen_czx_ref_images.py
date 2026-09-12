# -*- coding: utf-8 -*-
"""Generate front-view reference images for image-to-3D tools.

These are original vector-style concept sheets used as input for external
image-to-3D generation (Meshy, Tripo, etc.). They are NOT game assets and
not extracted SC2 artwork.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(r"E:\Code\WH3-modding")
OUT = ROOT / "mod_files" / "czx_swarm_expansion" / "reference_3d"
S = 1024  # canvas size


def canvas():
    im = Image.new("RGB", (S, S), (26, 26, 30))
    d = ImageDraw.Draw(im)
    # subtle vertical gradient backdrop
    for y in range(S):
        t = y / S
        c = (int(38 - 10 * t), int(34 - 8 * t), int(44 - 10 * t))
        d.line((0, y, S, y), fill=c)
    return im


def shade(draw, box, base, hi):
    """Draw an ellipse with a darker rim and a highlight, cheap pseudo-shading."""
    x0, y0, x1, y1 = box
    draw.ellipse(box, fill=base)
    pad = int((x1 - x0) * 0.12)
    draw.ellipse((x0 + pad, y0 + pad, x1 - pad, y1 - pad), fill=hi)


def mutalisk():
    """Front view: serpentine body, large double wings, bladed tail."""
    im = canvas()
    d = ImageDraw.Draw(im)
    cx = S // 2
    purple = (122, 58, 150)
    purple_hi = (165, 88, 190)
    wing = (88, 42, 110)
    wing_hi = (120, 60, 148)
    bone = (190, 168, 140)
    glow = (236, 151, 67)

    # wings: layered membranes
    for sign in (-1, 1):
        pts = [
            (cx + sign * 40, 430),
            (cx + sign * 120, 250),
            (cx + sign * 320, 120),
            (cx + sign * 470, 170),
            (cx + sign * 400, 300),
            (cx + sign * 330, 430),
            (cx + sign * 180, 520),
            (cx + sign * 60, 500),
        ]
        d.polygon(pts, fill=wing)
        inner = [
            (cx + sign * 80, 430),
            (cx + sign * 150, 290),
            (cx + sign * 320, 180),
            (cx + sign * 420, 210),
            (cx + sign * 360, 320),
            (cx + sign * 300, 430),
            (cx + sign * 170, 490),
            (cx + sign * 80, 470),
        ]
        d.polygon(inner, fill=wing_hi)
        # wing ribs
        for i in range(1, 4):
            tipx = cx + sign * (150 + i * 90)
            tipy = 200 + (i - 2) * 30
            d.line((cx + sign * 60, 450, tipx, tipy), fill=(60, 28, 78), width=6)
        # wing spikes
        d.polygon([(cx + sign * 320, 120), (cx + sign * 350, 60), (cx + sign * 360, 130)], fill=bone)
        d.polygon([(cx + sign * 470, 170), (cx + sign * 500, 110), (cx + sign * 480, 190)], fill=bone)

    # tail: serpentine blades hanging down
    for off, wdt in ((-70, 26), (0, 30), (70, 26)):
        d.polygon(
            [(cx + off - wdt, 620), (cx + off + wdt, 620),
             (cx + off + wdt // 2, 940), (cx + off, 980), (cx + off - wdt // 2, 940)],
            fill=purple)
        d.polygon(
            [(cx + off - 8, 700), (cx + off + 8, 700), (cx + off, 960)],
            fill=purple_hi)

    # body
    shade(d, (cx - 90, 380, cx + 90, 660), purple, purple_hi)
    # chest ridges
    for i in range(4):
        y = 460 + i * 42
        d.arc((cx - 70, y, cx + 70, y + 50), 200, 340, fill=(70, 32, 92), width=6)

    # head
    shade(d, (cx - 60, 300, cx + 60, 420), purple, purple_hi)
    # horn crest
    d.polygon([(cx - 50, 330), (cx - 90, 260), (cx - 60, 340)], fill=bone)
    d.polygon([(cx + 50, 330), (cx + 90, 260), (cx + 60, 340)], fill=bone)
    # eyes (glowing)
    d.ellipse((cx - 42, 340, cx - 16, 366), fill=glow)
    d.ellipse((cx + 16, 340, cx + 42, 366), fill=glow)
    # mandibles
    d.polygon([(cx - 40, 390), (cx - 90, 430), (cx - 46, 420)], fill=bone)
    d.polygon([(cx + 40, 390), (cx + 90, 430), (cx + 46, 420)], fill=bone)

    # small forelimb claws
    for sign in (-1, 1):
        d.polygon([(cx + sign * 80, 560), (cx + sign * 150, 620),
                   (cx + sign * 140, 650), (cx + sign * 90, 620)], fill=purple)
        d.polygon([(cx + sign * 150, 620), (cx + sign * 170, 660),
                   (cx + sign * 140, 650)], fill=bone)

    _finish(im, "MUTALISK / czx_feilong")
    return im


def roach():
    """Front view: bulky armored insect, six legs, plated carapace, spines."""
    im = canvas()
    d = ImageDraw.Draw(im)
    cx = S // 2
    green = (96, 138, 62)
    green_hi = (140, 180, 90)
    armor = (70, 100, 48)
    bone = (188, 160, 120)
    eye = (197, 219, 93)

    # six legs (three per side)
    leg_cols = [(60, 160, 40), (52, 138, 34), (44, 116, 30)]
    for sign in (-1, 1):
        segs = [
            # (hipx, hipy, kneex, kneey, footx, footy)
            (cx + sign * 110, 480, cx + sign * 260, 360, cx + sign * 360, 300),
            (cx + sign * 140, 620, cx + sign * 320, 560, cx + sign * 420, 590),
            (cx + sign * 120, 760, cx + sign * 300, 800, cx + sign * 400, 880),
        ]
        for i, (hx, hy, kx, ky, fx, fy) in enumerate(segs):
            c = leg_cols[i]
            d.line((hx, hy, kx, ky), fill=c, width=26)
            d.line((kx, ky, fx, fy), fill=tuple(int(v * 0.8) for v in c), width=20)
            # foot spike
            d.polygon([(fx - 16, fy), (fx + 16, fy), (fx, fy + 46)], fill=bone)

    # main carapace (big oval)
    shade(d, (cx - 160, 380, cx + 160, 780), green, green_hi)
    # carapace plates
    for i in range(4):
        y = 430 + i * 78
        d.arc((cx - 150, y, cx + 150, y + 110), 180, 360, fill=armor, width=10)
    # back spines
    for off in (-80, -28, 28, 80):
        d.polygon([(cx + off - 14, 400), (cx + off + 14, 400),
                   (cx + off, 310)], fill=bone)

    # head (lower, beetle-like)
    shade(d, (cx - 95, 280, cx + 95, 420), green, green_hi)
    d.ellipse((cx - 95, 300, cx + 95, 430), outline=armor, width=8)
    # acid sacs on cheeks
    d.ellipse((cx - 120, 330, cx - 70, 390), fill=(120, 190, 70))
    d.ellipse((cx + 70, 330, cx + 120, 390), fill=(120, 190, 70))
    # eyes
    d.ellipse((cx - 45, 315, cx - 15, 345), fill=eye)
    d.ellipse((cx + 15, 315, cx + 45, 345), fill=eye)
    d.ellipse((cx - 36, 322, cx - 24, 336), fill=(20, 30, 18))
    d.ellipse((cx + 24, 322, cx + 36, 336), fill=(20, 30, 18))
    # mandibles / tusks
    d.polygon([(cx - 60, 400), (cx - 120, 470), (cx - 80, 480), (cx - 40, 430)], fill=bone)
    d.polygon([(cx + 60, 400), (cx + 120, 470), (cx + 80, 480), (cx + 40, 430)], fill=bone)

    # abdomen tail stub
    d.polygon([(cx - 60, 770), (cx + 60, 770), (cx + 30, 880), (cx - 30, 880)], fill=armor)

    _finish(im, "ROACH / czx_zhanglang")
    return im


def kerrigan():
    """Front view: slim humanoid in chitin armor, bone wing-blades on the back,
    A-pose. Proportions kept close to a WH3 human hero for rig reuse."""
    im = canvas()
    d = ImageDraw.Draw(im)
    cx = S // 2
    skin = (195, 155, 132)
    skin_hi = (218, 184, 158)
    chitin = (92, 50, 138)
    chitin_hi = (138, 84, 190)
    chitin_dk = (62, 32, 96)
    bone = (200, 180, 150)
    glow = (110, 230, 235)

    # back wing-blades: three blades per side, originating behind the shoulders
    for sign in (-1, 1):
        blades = [
            # (root_x, root_y, tip_x, tip_y, width)
            (cx + sign * 60, 400, cx + sign * 300, 120, 46),
            (cx + sign * 60, 430, cx + sign * 370, 260, 40),
            (cx + sign * 60, 460, cx + sign * 340, 430, 34),
        ]
        for rx, ry, tx, ty, wd in blades:
            d.polygon([(rx - sign * 10, ry + 14), (rx + sign * 10, ry - 14),
                       (tx + sign * wd // 3, ty + wd), (tx, ty - 10),
                       (tx - sign * wd // 3, ty + wd // 2)],
                      fill=chitin_dk)
            d.line((rx, ry, tx, ty), fill=bone, width=5)

    # legs (A-pose, digitigrade armored)
    for sign in (-1, 1):
        d.polygon([(cx + sign * 26 - 20, 610), (cx + sign * 26 + 20, 610),
                   (cx + sign * 78 + 16, 880), (cx + sign * 78 - 16, 880)],
                  fill=chitin)
        d.polygon([(cx + sign * 52 - 10, 760), (cx + sign * 52 + 34, 780),
                   (cx + sign * 78 + 16, 880), (cx + sign * 78 - 16, 880)],
                  fill=chitin_hi)
        # talon foot
        d.polygon([(cx + sign * 58, 880), (cx + sign * 98, 880),
                   (cx + sign * 116, 934), (cx + sign * 48, 934)], fill=bone)

    # hip armor skirt
    d.polygon([(cx - 56, 560), (cx + 56, 560), (cx + 40, 660), (cx - 40, 660)],
              fill=chitin_dk)

    # torso: slim armored cuirass
    d.polygon([(cx - 66, 370), (cx + 66, 370), (cx + 42, 560), (cx - 42, 560)],
              fill=chitin)
    d.polygon([(cx - 46, 392), (cx + 46, 392), (cx + 30, 540), (cx - 30, 540)],
              fill=chitin_hi)
    d.line((cx, 392, cx, 540), fill=chitin_dk, width=5)

    # pauldrons + arms (A-pose, clawed forearms)
    for sign in (-1, 1):
        d.polygon([(cx + sign * 44, 360), (cx + sign * 118, 332),
                   (cx + sign * 148, 392), (cx + sign * 62, 414)], fill=chitin)
        d.polygon([(cx + sign * 88, 330), (cx + sign * 136, 292),
                   (cx + sign * 118, 352)], fill=bone)
        # upper + fore arm
        d.line((cx + sign * 108, 414, cx + sign * 152, 560), fill=chitin, width=26)
        d.line((cx + sign * 152, 560, cx + sign * 186, 668), fill=chitin_hi, width=22)
        # blade claws
        d.polygon([(cx + sign * 186, 668), (cx + sign * 252, 736),
                   (cx + sign * 216, 748), (cx + sign * 170, 692)], fill=bone)
        d.polygon([(cx + sign * 176, 672), (cx + sign * 196, 760),
                   (cx + sign * 172, 752), (cx + sign * 158, 690)], fill=bone)

    # neck + head (small, in front of wings)
    d.rectangle((cx - 14, 330, cx + 14, 372), fill=skin)
    shade(d, (cx - 44, 232, cx + 44, 344), skin, skin_hi)
    # cheek chitin
    d.polygon([(cx - 44, 300), (cx - 58, 330), (cx - 40, 340)], fill=chitin)
    d.polygon([(cx + 44, 300), (cx + 58, 330), (cx + 40, 340)], fill=chitin)
    # glowing eyes
    d.ellipse((cx - 28, 282, cx - 8, 300), fill=glow)
    d.ellipse((cx + 8, 282, cx + 28, 300), fill=glow)
    # forehead crest (single blade)
    d.polygon([(cx - 12, 246), (cx + 12, 246), (cx, 190)], fill=chitin_hi)

    _finish(im, "KERRIGAN / czx_kerrigan")
    return im


def _finish(im, label):
    """Add neutral-floor shadow, label and soft vignette."""
    w, h = im.size
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((w * 0.2, h * 0.88, w * 0.8, h * 0.97), fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    im = Image.alpha_composite(im.convert("RGBA"), shadow)
    d = ImageDraw.Draw(im)
    d.rectangle((0, h - 34, w, h), fill=(14, 14, 16))
    d.text((16, h - 28), f"front view reference - {label} - A-pose, orthographic",
           fill=(200, 200, 200))
    im.convert("RGB").save(OUT / f"{label.split('/')[-1].strip()}.png")


OUT.mkdir(parents=True, exist_ok=True)
for fn in (mutalisk, roach, kerrigan):
    fn()
print(f"reference images written to {OUT}")
