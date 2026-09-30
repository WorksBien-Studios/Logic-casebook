"""Render the Logic Casebook app icon (light, dark and tinted variants).

Motif: a vermilion hanko (seal) stamped on a ruled deduction grid -- the app's
"case closed" stamp (see HankoSeal.swift) over its core logic-grid mechanic,
on the app's paper/vermilion palette (ios/.../Theme.swift). The seal carries
the kanji 論 (logic) from the title 完全論理事件簿.

Apple rules honoured: 1024x1024 PNG, sRGB, no alpha channel, full-bleed square
(iOS applies the corner mask), no borrowed imagery. The only glyph is a single
kanji from our own title, rendered with IPAGothic (IPA Font License, which
permits embedding glyph shapes in artwork).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else
           "ios/App/LogicCasebook/Assets.xcassets/AppIcon.appiconset")
FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
SIZE, SS = 1024, 3  # final size, supersampling factor
S = SIZE * SS

# Ledger marks behind the seal: (row, col, kind) on a 4x4 grid.
MARKS = [(0, 1, "c"), (0, 3, "x"), (1, 0, "x"), (2, 3, "c"), (3, 0, "c"), (3, 2, "x"), (1, 3, "x")]


def hexrgb(v):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255)


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    px = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        px.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def render(bg_top, bg_bottom, line, mark_c, mark_x, seal, seal_glyph):
    img = gradient(bg_top, bg_bottom)
    d = ImageDraw.Draw(img)

    # Ruled grid, full bleed, 4x4 cells.
    n, m = 4, 96 * SS
    step = (S - 2 * m) / n
    lw = 8 * SS
    for i in range(n + 1):
        p = m + i * step
        h = lw // 2  # extend so the outer corners close cleanly
        d.line([(p, m - h), (p, S - m + h)], fill=line, width=lw)
        d.line([(m - h, p), (S - m + h, p)], fill=line, width=lw)
    for r, c, kind in MARKS:
        cx, cy = m + (c + 0.5) * step, m + (r + 0.5) * step
        if kind == "c":
            rr = 52 * SS
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=mark_c, width=16 * SS)
        else:
            k, w = 40 * SS, 16 * SS
            for sgn in (-1, 1):
                d.line([(cx - k, cy - sgn * k), (cx + k, cy + sgn * k)], fill=mark_x, width=w)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    d.ellipse([cx + sx * k - w / 2, cy + sy * k - w / 2, cx + sx * k + w / 2, cy + sy * k + w / 2], fill=mark_x)

    # The seal: filled disc + offset ring, rotated -9 degrees like HankoSeal.swift.
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    c0 = S / 2
    r_disc, r_ring, ring_w = 300 * SS, 352 * SS, 14 * SS
    ld.ellipse([c0 - r_disc, c0 - r_disc, c0 + r_disc, c0 + r_disc], fill=seal + (255,))
    ld.ellipse([c0 - r_ring, c0 - r_ring, c0 + r_ring, c0 + r_ring], outline=seal + (255,), width=ring_w)
    font = ImageFont.truetype(FONT, 380 * SS)
    ld.text((c0, c0), "論", font=font, fill=seal_glyph + (255,), anchor="mm")
    layer = layer.rotate(9, resample=Image.BICUBIC, center=(c0, c0))
    img.paste(layer, (0, 0), layer)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


variants = {
    "icon-light.png": render(hexrgb(0xFAF7F1), hexrgb(0xF1EBDD), hexrgb(0xDDD2BC), hexrgb(0xE2B4A8),
                             hexrgb(0xC9BDA8), hexrgb(0xA8402E), hexrgb(0xF7F4EE)),
    "icon-dark.png": render(hexrgb(0x211D1A), hexrgb(0x120F0D), hexrgb(0x3A342E), hexrgb(0x6A3A2E),
                            hexrgb(0x4A423B), hexrgb(0xE08267), hexrgb(0x1A1310)),
    # Tinted: grayscale on near-black; iOS colourises it with the user's tint.
    "icon-tinted.png": render(hexrgb(0x262626), hexrgb(0x0E0E0E), hexrgb(0x3C3C3C), hexrgb(0x5A5A5A),
                              hexrgb(0x505050), hexrgb(0xF2F2F2), hexrgb(0x111111)),
}
OUT.mkdir(parents=True, exist_ok=True)
for name, img in variants.items():
    assert img.mode == "RGB" and img.size == (SIZE, SIZE)  # RGB => no alpha channel
    img.save(OUT / name, "PNG", optimize=True)
    print("wrote", OUT / name)
