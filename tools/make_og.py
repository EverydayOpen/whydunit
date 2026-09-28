"""Render site/static/og.png (1200x630 social preview) and apple-touch-icon.png (180x180, opaque: iOS fills
transparent pixels with black), and copy favicon.png and icon.png from the app icon.

Stdlib only; reuses tools/make_icon.py (the icon master, coverage and compositing helpers). The wordmark
"Whydunit" is drawn like the icon: monoline strokes as signed distance functions, so edges get analytic
antialiasing. Centred composition, so previews that crop to a square still show the icon and most of the name.

Run from the repo root (about a minute):  python tools/make_og.py
"""
import math
import os
import shutil
import struct
import zlib
from array import array

import make_icon as icon

W, H = 1200, 630
TOOLS = os.path.dirname(os.path.abspath(__file__))
STATIC = os.path.join(TOOLS, "..", "site", "static")
BG_TOP, BG_BOTTOM = (0.985, 0.985, 0.992), (0.918, 0.929, 0.961)
GLOW = (0.29, 0.56, 1.00)                  # the icon's top blue
INK = (0.114, 0.114, 0.122)                # #1d1d1f
ICON, ICON_TOP = 384, 44                   # icon canvas size and top edge
XH, BASELINE = 62.0, 532.0                 # wordmark x-height (px) and baseline

# Glyphs in x-height units, y up from the baseline, as stroke centrelines. S is the half stroke width;
# centrelines sit S inside the x-height (T), baseline (B), ascender (A) and descender (D).
S = 0.1
T, B, A, D = 0.9, 0.1, 1.35, -0.4
GLYPHS = {   # ("l", x0, y0, x1, y1) line; ("a", cx, cy, r, deg0, deg1) arc; ("o", cx, cy, r) dot
    "W": [("l", 0.1, A, 0.46, B), ("l", 0.46, B, 0.82, A), ("l", 0.82, A, 1.18, B), ("l", 1.18, B, 1.54, A)],
    "h": [("l", 0.1, A, 0.1, B), ("a", 0.5, 0.5, 0.4, 0, 180), ("l", 0.9, 0.5, 0.9, B)],
    "y": [("l", 0.1, T, 0.5, B), ("l", 0.9, T, 0.25, D)],
    "d": [("a", 0.5, 0.5, 0.4, 0, 360), ("l", 0.9, A, 0.9, B)],
    "u": [("l", 0.1, T, 0.1, 0.5), ("a", 0.5, 0.5, 0.4, 180, 360), ("l", 0.9, T, 0.9, B)],
    "n": [("l", 0.1, T, 0.1, B), ("a", 0.5, 0.5, 0.4, 0, 180), ("l", 0.9, 0.5, 0.9, B)],
    "i": [("l", 0.1, T, 0.1, B), ("o", 0.1, 1.27, 0.125)],
    "t": [("l", 0.28, 1.22, 0.28, B), ("l", 0.02, T, 0.56, T)],
}
GAP = 0.12   # space between the visual edges of neighbouring letters


def stroke_dist(s, x, y):
    if s[0] == "l":
        return icon.seg(x, y, *s[1:]) - S
    if s[0] == "o":
        return math.hypot(x - s[1], y - s[2]) - s[3]
    _, cx, cy, r, a0, a1 = s
    ang = math.degrees(math.atan2(y - cy, x - cx)) % 360
    if a1 - a0 >= 360 or a0 <= ang <= a1 or ang + 360 <= a1:
        return abs(math.hypot(x - cx, y - cy) - r) - S
    ends = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in (a0, a1)]
    return min(math.hypot(x - ex, y - ey) for ex, ey in ends) - S


def x_extent(strokes):
    xs = []
    for s in strokes:
        if s[0] == "l":
            xs += [s[1] - S, s[3] + S, s[1] + S, s[3] - S]
        else:
            r = s[3] + (S if s[0] == "a" else 0)
            xs += [s[1] - r, s[1] + r]
    return min(xs), max(xs)


def layout(word):
    """[(x offset, strokes, left, right)] in x-height units, and the total width."""
    placed, pen = [], 0.0
    for ch in word:
        lo, hi = x_extent(GLYPHS[ch])
        placed.append((pen - lo, GLYPHS[ch], pen, pen + hi - lo))
        pen += hi - lo + GAP
    return placed, pen - GAP


def resample(px, n, m):
    """Bilinear n -> m on a premultiplied square buffer (used for m > n / 2, then halved)."""
    out = array("f", bytes(m * m * 16))
    k = n / m
    for y in range(m):
        sy = min(n - 1.0, max(0.0, (y + 0.5) * k - 0.5))
        y0 = int(sy)
        y1, fy = min(y0 + 1, n - 1), sy - y0
        for x in range(m):
            sx = min(n - 1.0, max(0.0, (x + 0.5) * k - 0.5))
            x0 = int(sx)
            x1, fx = min(x0 + 1, n - 1), sx - x0
            i00, i01, i10, i11 = (y0 * n + x0) * 4, (y0 * n + x1) * 4, (y1 * n + x0) * 4, (y1 * n + x1) * 4
            o = (y * m + x) * 4
            for c in range(4):
                top = px[i00 + c] + (px[i01 + c] - px[i00 + c]) * fx
                bot = px[i10 + c] + (px[i11 + c] - px[i10 + c]) * fx
                out[o + c] = top + (bot - top) * fy
    return out


def render(master):
    px = array("f", bytes(W * H * 16))
    gx, gy = W / 2, ICON_TOP + ICON / 2
    for y in range(H):
        t = y / (H - 1)
        base = [BG_TOP[c] + (BG_BOTTOM[c] - BG_TOP[c]) * t for c in range(3)]
        for x in range(W):
            i = (y * W + x) * 4
            px[i:i + 4] = array("f", base + [1.0])
            g = max(0.0, 1.0 - math.hypot((x - gx) / 1.6, y - gy) / 330) ** 2 * 0.10   # soft glow behind the icon
            if g:
                icon.over(px, i, *GLOW, g)

    # Icon: 1024 master -> bilinear to 2x -> 2x2 box filter, for clean edges at an arbitrary size.
    small = icon.half(resample(master, icon.N, 2 * ICON), 2 * ICON)
    left = int(W / 2 - ICON / 2)
    for y in range(ICON):
        for x in range(ICON):
            s, d = (y * ICON + x) * 4, ((ICON_TOP + y) * W + left + x) * 4
            k = 1.0 - small[s + 3]
            for c in range(4):
                px[d + c] = small[s + c] + px[d + c] * k

    placed, width = layout("Whydunit")
    x0 = W / 2 - width * XH / 2
    for y in range(int(BASELINE - (A + S) * XH) - 2, int(BASELINE - (D - S) * XH) + 3):
        v = (BASELINE - y - 0.5) / XH
        for x in range(int(x0) - 2, int(x0 + width * XH) + 3):
            u = (x + 0.5 - x0) / XH
            d = min((stroke_dist(s, u - off, v) for off, strokes, lo, hi in placed
                     if lo - 0.1 <= u <= hi + 0.1 for s in strokes), default=1e9)
            a = icon.cov(d * XH)
            if a:
                icon.over(px, (y * W + x) * 4, *INK, a)
    return px


def write_png(path, px, w, h):
    """Opaque RGB PNG."""
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        row = px[y * w * 4:(y + 1) * w * 4]
        for x in range(w):
            raw += bytes(min(255, int(row[4 * x + c] * 255 + 0.5)) for c in range(3))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"sRGB", b"\0"))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def main():
    os.makedirs(STATIC, exist_ok=True)
    shutil.copyfile(os.path.join(icon.OUT, "icon_32x32@2x.png"), os.path.join(STATIC, "favicon.png"))
    shutil.copyfile(os.path.join(icon.OUT, "icon_128x128@2x.png"), os.path.join(STATIC, "icon.png"))
    master = icon.render()
    # 180 px (Apple's size) on white; the macOS icon's ~10% margin gives iOS's mask room around the artwork.
    touch = icon.half(resample(master, icon.N, 360), 360)
    for i in range(0, len(touch), 4):
        k = 1.0 - touch[i + 3]   # premultiplied "over" white: c + (1 - a)
        for c in range(3):
            touch[i + c] += k
    write_png(os.path.join(STATIC, "apple-touch-icon.png"), touch, 180, 180)
    write_png(os.path.join(STATIC, "og.png"), render(master), W, H)
    print(f"wrote og.png, favicon.png, icon.png, apple-touch-icon.png to {os.path.normpath(STATIC)}")


if __name__ == "__main__":
    main()
