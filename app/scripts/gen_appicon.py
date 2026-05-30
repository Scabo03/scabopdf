#!/usr/bin/env python3
"""Generate the ScaboPDF iOS AppIcon set (PNG, no alpha channel).

Minimal but tidy design: indigo vertical gradient, a white rounded
"document" card with text lines, and a play glyph (the app reads PDFs
aloud for a blind user). A polished icon is a later pass; this is a
valid, App Store-acceptable placeholder with no transparency.
"""
import json
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "ScaboPDF", "Images.xcassets", "AppIcon.appiconset")
M = 1024


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def master():
    img = Image.new("RGB", (M, M))
    px = img.load()
    top = (38, 42, 110)      # deep indigo
    bot = (58, 96, 190)      # blue
    for y in range(M):
        c = lerp(top, bot, y / (M - 1))
        for x in range(M):
            px[x, y] = c
    d = ImageDraw.Draw(img)

    # Document card (rounded white rectangle, slightly portrait)
    cw, ch = 470, 580
    cx, cy = (M - cw) // 2, (M - ch) // 2 - 20
    d.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=54, fill=(248, 249, 252))
    # folded corner
    fold = 120
    d.polygon(
        [(cx + cw - fold, cy), (cx + cw, cy + fold), (cx + cw - fold, cy + fold)],
        fill=(210, 218, 235),
    )

    # Text lines
    line_x0 = cx + 70
    line_x1 = cx + cw - 70
    ly = cy + 180
    for i in range(5):
        x1 = line_x1 if i < 4 else line_x0 + (line_x1 - line_x0) * 0.55
        d.rounded_rectangle([line_x0, ly, x1, ly + 26], radius=13, fill=(120, 132, 165))
        ly += 64

    # Play glyph (audio) in an accent circle, bottom-right overlapping the card
    r = 118
    px0, py0 = cx + cw - 60, cy + ch - 60
    d.ellipse([px0 - r, py0 - r, px0 + r, py0 + r], fill=(255, 156, 64))
    tri = [(px0 - 38, py0 - 52), (px0 - 38, py0 + 52), (px0 + 56, py0)]
    d.polygon(tri, fill=(255, 255, 255))
    return img


def main():
    base = master()
    # (idiom, size, scale, pixels) — covers the full iPhone + iPad + marketing
    # matrix App Store requires for a universal (TARGETED_DEVICE_FAMILY 1,2) app.
    specs = [
        ("iphone", "20x20", "2x", 40), ("iphone", "20x20", "3x", 60),
        ("iphone", "29x29", "2x", 58), ("iphone", "29x29", "3x", 87),
        ("iphone", "40x40", "2x", 80), ("iphone", "40x40", "3x", 120),
        ("iphone", "60x60", "2x", 120), ("iphone", "60x60", "3x", 180),
        ("ipad", "20x20", "1x", 20), ("ipad", "20x20", "2x", 40),
        ("ipad", "29x29", "1x", 29), ("ipad", "29x29", "2x", 58),
        ("ipad", "40x40", "1x", 40), ("ipad", "40x40", "2x", 80),
        ("ipad", "76x76", "1x", 76), ("ipad", "76x76", "2x", 152),
        ("ipad", "83.5x83.5", "2x", 167),
        ("ios-marketing", "1024x1024", "1x", 1024),
    ]
    images = []
    written = {}
    for idiom, size, scale, px in specs:
        fn = f"icon-{px}.png"
        if px not in written:
            im = base.resize((px, px), Image.LANCZOS).convert("RGB")
            im.save(os.path.join(OUT, fn))
            written[px] = fn
        images.append({"idiom": idiom, "scale": scale, "size": size, "filename": fn})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("Wrote", len(written), "PNGs:", sorted(written.keys()))


if __name__ == "__main__":
    main()
