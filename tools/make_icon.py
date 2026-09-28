"""Render the Whydunit app icon and write App/Assets.xcassets/AppIcon.appiconset.

Stdlib only (no Pillow). Shapes are signed distance functions, so every edge gets exact
analytic antialiasing at 1024 px (sharper than 4x supersampling and 16x cheaper); smaller
sizes are box-filtered down from the 1024 master in premultiplied alpha.

Layout follows the macOS (Big Sur and later) icon grid: 1024 canvas, 824 px body with
continuous-looking corners, soft drop shadow. Glyph: white cloud, magnifying glass with a
checkmark in the lens.

Run from the repo root:  python tools/make_icon.py
"""
import json
import math
import os
import struct
import zlib
from array import array

N = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Assets.xcassets", "AppIcon.appiconset")

# Body: 824 px square centred on the canvas. A p=3 superellipse corner with a larger radius
# approximates Apple's continuous corner (curvature ramps in instead of jumping like a circle).
HALF, CORNER, P = 412.0, 278.0, 3.0
TOP, BOTTOM = (0.29, 0.56, 1.00), (0.20, 0.14, 0.62)  # blue -> deep indigo

# Glyph, designed in its own coordinates, then scaled around its centre onto the body.
G_SCALE, G_CENTER, G_TARGET = 0.9, (545.0, 560.0), (512.0, 506.0)
LENS, R_OUT, R_IN, GAP = (650.0, 630.0), 130.0, 96.0, 22.0
U = math.sqrt(0.5)
# Handle starts at the ring's outer edge so its round cap stays inside the ring.
HX0, HY0 = LENS[0] + U * R_OUT, LENS[1] + U * R_OUT
HX1, HY1, HANDLE_W = LENS[0] + U * (R_OUT + 100), LENS[1] + U * (R_OUT + 100), 30.0
CHECK = [(LENS[0] - 44, LENS[1] + 4), (LENS[0] - 12, LENS[1] + 36), (LENS[0] + 48, LENS[1] - 30)]
CHECK_W = 16.0
CLOUD_TOP, CLOUD_BOTTOM = 280.0, 685.0


def cov(d):
    """Pixel coverage from a signed distance in pixels (negative = inside)."""
    return 0.0 if d >= 0.5 else 1.0 if d <= -0.5 else 0.5 - d


def seg(px, py, ax, ay, bx, by):
    """Distance from (px, py) to segment a-b."""
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def body_sdf(x, y):
    qx, qy = abs(x - 512.0) - (HALF - CORNER), abs(y - 512.0) - (HALF - CORNER)
    if qx > 0 and qy > 0:
        return (qx ** P + qy ** P) ** (1 / P) - CORNER
    return max(qx, qy) - CORNER


def cloud_sdf(x, y):
    return min(
        seg(x, y, 325, 590, 635, 590) - 95,
        math.hypot(x - 375, y - 500) - 115,
        math.hypot(x - 540, y - 440) - 160,
        math.hypot(x - 680, y - 530) - 105,
    )


def glyph(x, y):
    """Signed distances (in glyph units) for: cloud with a gap cut around the magnifier,
    lens ring, handle, lens interior, checkmark."""
    r = math.hypot(x - LENS[0], y - LENS[1])
    handle = seg(x, y, HX0, HY0, HX1, HY1) - HANDLE_W
    magnifier = min(r - R_OUT, handle)
    # Inside the magnifier the cloud is always cut away, so skip evaluating it.
    cloud = GAP - magnifier if magnifier < 0 else max(cloud_sdf(x, y), GAP - magnifier)
    ring = abs(r - (R_OUT + R_IN) / 2) - (R_OUT - R_IN) / 2
    check = 1e9 if r > R_IN else min(seg(x, y, *CHECK[0], *CHECK[1]), seg(x, y, *CHECK[1], *CHECK[2])) - CHECK_W
    return cloud, ring, handle, r - R_IN, check


def to_glyph(x, y):
    return ((x - G_TARGET[0]) / G_SCALE + G_CENTER[0], (y - G_TARGET[1]) / G_SCALE + G_CENTER[1])


def over(px, i, r, g, b, a):
    """Composite straight-alpha colour (r, g, b, a) over premultiplied pixel i."""
    k = 1.0 - a
    px[i] = r * a + px[i] * k
    px[i + 1] = g * a + px[i + 1] * k
    px[i + 2] = b * a + px[i + 2] * k
    px[i + 3] = a + px[i + 3] * k


def render():
    px = array("f", bytes(N * N * 16))
    union = array("f", [1e9]) * (N * N)        # glyph distance per pixel, reused for its shadow
    shadow_k = 1 / (14.0 * math.sqrt(2))       # body shadow: sigma 14 px, 10 px down, 32 %
    gshadow_k = 1 / (9.0 * math.sqrt(2))       # glyph shadow: sigma 9 px, 8 px down, 22 %
    for yi in range(N):
        y = yi + 0.5
        t = min(1.0, max(0.0, (y - 100) / 824))
        base = [TOP[c] + (BOTTOM[c] - TOP[c]) * t for c in range(3)]
        for xi in range(N):
            x = xi + 0.5
            i = (yi * N + xi) * 4
            d_body = body_sdf(x, y)
            if d_body > -1:
                a = 0.32 * 0.5 * math.erfc(body_sdf(x, y - 10) * shadow_k)
                if a > 1 / 1024:
                    over(px, i, 0.0, 0.0, 0.05, a)
            a = cov(d_body)
            if a == 0.0:
                continue
            # Soft light from the top of the body.
            glow = max(0.0, 1.0 - ((x - 512) ** 2 + (y - 120) ** 2) / 620.0 ** 2) * 0.16
            over(px, i, base[0] + (1 - base[0]) * glow, base[1] + (1 - base[1]) * glow,
                 base[2] + (1 - base[2]) * glow, a)
            if not (190 < x < 835 and 220 < y < 805):  # glyph + its shadow
                continue
            gx, gy = to_glyph(x, y)
            cloud, ring, handle, lens, check = glyph(gx, gy)
            union[i // 4] = min(cloud, ring, handle) * G_SCALE
            d_shadow = union[i // 4 - 8 * N]               # 8 px above casts onto here
            if d_shadow < 30:
                over(px, i, 0.08, 0.04, 0.25, 0.22 * 0.5 * math.erfc(d_shadow * gshadow_k))
            over(px, i, 1.0, 1.0, 1.0, 0.16 * cov(lens * G_SCALE))           # glass tint
            ct = min(1.0, max(0.0, (gy - CLOUD_TOP) / (CLOUD_BOTTOM - CLOUD_TOP)))
            over(px, i, 1.0 - 0.10 * ct, 1.0 - 0.07 * ct, 1.0, cov(cloud * G_SCALE))
            over(px, i, 1.0, 1.0, 1.0, cov(min(ring, handle, check) * G_SCALE))
    return px


def half(px, n):
    """2x2 box filter (premultiplied, so edges don't darken)."""
    m = n // 2
    out = array("f", bytes(m * m * 16))
    row = n * 4
    for y in range(m):
        r0 = 2 * y * row
        r1 = r0 + row
        o = y * m * 4
        for x in range(m):
            i, j, k = r0 + 8 * x, r1 + 8 * x, o + 4 * x
            for c in range(4):
                out[k + c] = (px[i + c] + px[i + 4 + c] + px[j + c] + px[j + 4 + c]) * 0.25
    return out


def write_png(path, px, n):
    raw = bytearray()
    for y in range(n):
        raw.append(0)  # filter: none
        for x in range(n):
            i = (y * n + x) * 4
            a = px[i + 3]
            if a < 1 / 512:
                raw += b"\0\0\0\0"
                continue
            raw += bytes(min(255, int(px[i + c] / a * 255 + 0.5)) for c in range(3))
            raw.append(min(255, int(a * 255 + 0.5)))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 6, 0, 0, 0)))
        f.write(chunk(b"sRGB", b"\0"))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def main():
    os.makedirs(OUT, exist_ok=True)
    images, by_size = [], {N: render()}
    n = N
    while n > 16:
        by_size[n // 2] = half(by_size[n], n)
        n //= 2
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
            write_png(os.path.join(OUT, name), by_size[pt * scale], pt * scale)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    with open(os.path.join(OUT, "Contents.json"), "w", newline="\n") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")
    print(f"wrote {len(images)} PNGs to {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
