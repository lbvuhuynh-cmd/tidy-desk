#!/usr/bin/env python3
"""Draws the placeholder app icon (1024x1024, opaque PNG) into AppIcon.appiconset.

A tidy oak desk seen from above: a 3x3 grid where the devices fit snugly
(keyboard, monitor, mug, plant, phone), with a soft LED edge. Colours follow Theme.swift.
Needs Pillow:  pip install pillow
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4  # supersampling for smooth edges
OUT = Path(__file__).resolve().parent.parent / "TidyDesk/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def rgb(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


BG_TOP, BG_BOTTOM = rgb(0x6FA595), rgb(0x3F7567)  # sage accent gradient
DESK, DESK_EDGE, SLOT = rgb(0xE3D4BF), rgb(0xC9B394), rgb(0xD8C7AF)
SLATE, GRAPHITE, LAVENDER = (107, 133, 168), (87, 94, 107), (148, 130, 181)
SAGE, CLAY, HONEY = (115, 158, 138), (196, 135, 107), (204, 166, 110)
LED = [(125, 204, 199), (140, 163, 237), (189, 153, 230), (242, 168, 191)]


def main():
    s = SIZE * SS
    img = Image.new("RGB", (s, s))
    d = ImageDraw.Draw(img)
    for y in range(s):  # vertical gradient background
        t = y / (s - 1)
        d.line([(0, y), (s, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))

    # Desk with an LED glow behind it.
    m = 150 * SS
    desk = (m, m, s - m, s - m)
    glow = Image.new("RGB", (s, s), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, c in enumerate(LED):
        off = i * 6 * SS
        gd.rounded_rectangle((desk[0] - 18 * SS + off, desk[1] - 18 * SS, desk[2] + 18 * SS - off, desk[3] + 18 * SS),
                             radius=130 * SS, outline=c, width=22 * SS)
    glow = glow.filter(ImageFilter.GaussianBlur(28 * SS))
    img = Image.composite(glow, img, glow.convert("L").point(lambda v: min(255, v * 2)))
    d = ImageDraw.Draw(img)

    d.rounded_rectangle((desk[0], desk[1] + 14 * SS, desk[2], desk[3] + 14 * SS), radius=110 * SS, fill=rgb(0x2F5A4F))  # shadow
    d.rounded_rectangle(desk, radius=110 * SS, fill=DESK, outline=DESK_EDGE, width=10 * SS)

    # 3x3 grid inside the desk.
    pad, gap = 62 * SS, 22 * SS
    inner = desk[2] - desk[0] - 2 * pad
    cell = (inner - 2 * gap) / 3

    def rect(row, col, w=1, h=1):
        x0 = desk[0] + pad + col * (cell + gap)
        y0 = desk[1] + pad + row * (cell + gap)
        return (x0, y0, x0 + w * cell + (w - 1) * gap, y0 + h * cell + (h - 1) * gap)

    for r in range(3):
        for c in range(3):
            d.rounded_rectangle(rect(r, c), radius=34 * SS, fill=SLOT)

    def tile(box, color):
        d.rounded_rectangle((box[0], box[1] + 8 * SS, box[2], box[3] + 8 * SS), radius=34 * SS,
                            fill=tuple(max(0, v - 45) for v in color))
        d.rounded_rectangle(box, radius=34 * SS, fill=color)

    # Monitor (2x1), mug, keyboard (2x1), plant, phone (1x1), mouse (1x1) and a lamp: a full, tidy desk.
    tile(rect(0, 0, 2, 1), GRAPHITE)
    tile(rect(0, 2), HONEY)
    tile(rect(1, 0, 2, 1), SLATE)
    tile(rect(1, 2, 1, 2), SAGE)
    tile(rect(2, 0), CLAY)
    tile(rect(2, 1), LAVENDER)

    white = (250, 248, 244)
    # Monitor screen + stand.
    b = rect(0, 0, 2, 1)
    cx = (b[0] + b[2]) / 2
    d.rounded_rectangle((b[0] + 60 * SS, b[1] + 38 * SS, b[2] - 60 * SS, b[3] - 62 * SS), radius=14 * SS, fill=white)
    d.rectangle((cx - 10 * SS, b[3] - 62 * SS, cx + 10 * SS, b[3] - 38 * SS), fill=white)
    d.rounded_rectangle((cx - 50 * SS, b[3] - 42 * SS, cx + 50 * SS, b[3] - 30 * SS), radius=6 * SS, fill=white)
    # Keyboard keys.
    b = rect(1, 0, 2, 1)
    kw, kh, kg = 30 * SS, 24 * SS, 12 * SS
    cols = 7
    total = cols * kw + (cols - 1) * kg
    x0 = (b[0] + b[2]) / 2 - total / 2
    y0 = (b[1] + b[3]) / 2 - (2 * kh + kg) / 2
    for row in range(2):
        for k in range(cols):
            x = x0 + k * (kw + kg)
            y = y0 + row * (kh + kg)
            d.rounded_rectangle((x, y, x + kw, y + kh), radius=6 * SS, fill=white)
    # Mug.
    b = rect(0, 2)
    cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
    d.rounded_rectangle((cx - 42 * SS, cy - 36 * SS, cx + 30 * SS, cy + 42 * SS), radius=16 * SS, fill=white)
    d.ellipse((cx + 12 * SS, cy - 18 * SS, cx + 58 * SS, cy + 24 * SS), outline=white, width=12 * SS)
    # Plant: pot + leaves.
    b = rect(1, 2, 1, 2)
    cx = (b[0] + b[2]) / 2
    d.rounded_rectangle((cx - 44 * SS, b[3] - 120 * SS, cx + 44 * SS, b[3] - 40 * SS), radius=14 * SS, fill=white)
    for dx, top in ((-38, 0.32), (0, 0.22), (38, 0.32)):
        d.ellipse((cx + dx * SS - 30 * SS, b[1] + (b[3] - b[1]) * top, cx + dx * SS + 30 * SS, b[3] - 120 * SS),
                  fill=(232, 243, 236))
    # Phone.
    b = rect(2, 0)
    cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
    d.rounded_rectangle((cx - 30 * SS, cy - 52 * SS, cx + 30 * SS, cy + 52 * SS), radius=14 * SS, fill=white)
    # Mouse.
    b = rect(2, 1)
    cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
    d.rounded_rectangle((cx - 30 * SS, cy - 46 * SS, cx + 30 * SS, cy + 46 * SS), radius=30 * SS, fill=white)
    d.line((cx, cy - 44 * SS, cx, cy - 10 * SS), fill=LAVENDER, width=6 * SS)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
