"""Generates the alpha foliage cards used by the tree assets.

Run with any Python 3 (no third-party modules):
  py assets/models/trees/make_foliage_textures.py

The output is two 256 px RGBA atlases:

* `assets/textures/leaf_card.png`   - a broadleaf cluster on a transparent card.
* `assets/textures/needle_card.png` - a fir sprig on a transparent card.

These are drawn procedurally so the project owns every pixel; nothing is
downloaded. The Blender tree generator maps one card quad to each texture and
Godot renders them with alpha scissor + a light backlight so the canopy reads
as leaves instead of painted spheres.
"""

import math
import os
import random
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.normpath(os.path.join(HERE, "..", "..", "textures"))
SIZE = 256
random.seed(90210)


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smoothstep(edge0, edge1, value):
    if abs(edge1 - edge0) < 1e-6:
        return 0.0
    t = clamp((value - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def new_canvas():
    return [[0.0, 0.0, 0.0, 0.0] for _ in range(SIZE * SIZE)]


def over(buf, index, rgb, alpha):
    if alpha <= 0.0:
        return
    dst = buf[index]
    out_alpha = alpha + dst[3] * (1.0 - alpha)
    if out_alpha <= 1e-6:
        buf[index] = [0.0, 0.0, 0.0, 0.0]
        return
    inv = dst[3] * (1.0 - alpha)
    buf[index] = [
        (rgb[0] * alpha + dst[0] * inv) / out_alpha,
        (rgb[1] * alpha + dst[1] * inv) / out_alpha,
        (rgb[2] * alpha + dst[2] * inv) / out_alpha,
        out_alpha,
    ]


def draw_line(buf, ax, ay, bx, by, width, rgb, alpha=1.0):
    half = max(width * 0.5, 0.2)
    pad = half + 2.0
    min_x = max(0, int(math.floor(min(ax, bx) - pad)))
    max_x = min(SIZE - 1, int(math.ceil(max(ax, bx) + pad)))
    min_y = max(0, int(math.floor(min(ay, by) - pad)))
    max_y = min(SIZE - 1, int(math.ceil(max(ay, by) + pad)))
    dx = bx - ax
    dy = by - ay
    length_sq = dx * dx + dy * dy
    for y in range(min_y, max_y + 1):
        py = y + 0.5
        for x in range(min_x, max_x + 1):
            px = x + 0.5
            if length_sq <= 1e-6:
                t = 0.0
            else:
                t = clamp(((px - ax) * dx + (py - ay) * dy) / length_sq)
            cx = ax + dx * t
            cy = ay + dy * t
            dist = math.hypot(px - cx, py - cy)
            cover = smoothstep(half + 0.7, half - 0.7, dist)
            if cover > 0.0:
                shade = 0.86 + 0.14 * t
                over(buf, y * SIZE + x,
                     (rgb[0] * shade, rgb[1] * shade, rgb[2] * shade),
                     cover * alpha)


def draw_leaf(buf, cx, cy, length, width, angle, rgb):
    rx = max(length * 0.5, 1.0)
    ry = max(width * 0.5, 1.0)
    ca = math.cos(angle)
    sa = math.sin(angle)
    pad = rx + 3.0
    min_x = max(0, int(math.floor(cx - pad)))
    max_x = min(SIZE - 1, int(math.ceil(cx + pad)))
    min_y = max(0, int(math.floor(cy - pad)))
    max_y = min(SIZE - 1, int(math.ceil(cy + pad)))
    for y in range(min_y, max_y + 1):
        py = y + 0.5 - cy
        for x in range(min_x, max_x + 1):
            px = x + 0.5 - cx
            u = (px * ca + py * sa) / rx
            v = (-px * sa + py * ca) / ry
            if u < -1.15 or u > 1.15:
                continue
            # A pointed tip: the leaf narrows towards +u.
            taper = 1.0 - 0.34 * clamp(u, 0.0, 1.0)
            v_scaled = v / max(taper, 0.35)
            d = u * u + v_scaled * v_scaled
            cover = smoothstep(1.06, 0.90, d)
            if cover <= 0.0:
                continue
            # Darker at the base, brighter towards the tip; a lighter mid rib
            # gives the card structure at close range without extra geometry.
            light = 0.80 + 0.30 * clamp((u + 1.0) * 0.5)
            shade = [rgb[0] * light, rgb[1] * light, rgb[2] * light]
            if abs(v_scaled) < 0.075 and u < 0.92:
                shade[0] = min(1.0, shade[0] * 1.20 + 0.02)
                shade[1] = min(1.0, shade[1] * 1.18 + 0.02)
                shade[2] = min(1.0, shade[2] * 1.12 + 0.01)
            over(buf, y * SIZE + x, shade, cover)


def leaf_palette(index):
    base = [
        (0.16, 0.30, 0.10),
        (0.21, 0.37, 0.12),
        (0.25, 0.42, 0.15),
        (0.30, 0.46, 0.17),
        (0.34, 0.49, 0.20),
        (0.22, 0.40, 0.18),
    ][index % 6]
    jitter = random.uniform(-0.02, 0.03)
    return (
        clamp(base[0] + jitter),
        clamp(base[1] + jitter * 1.2),
        clamp(base[2] + jitter * 0.6),
    )


def build_leaf_card():
    buf = new_canvas()
    root_x = SIZE * 0.5
    root_y = SIZE * 0.94
    branches = [
        (-0.72, 112.0),
        (-0.30, 128.0),
        (0.10, 132.0),
        (0.48, 118.0),
        (0.82, 92.0),
    ]
    stem = (0.30, 0.23, 0.10)
    for branch_index, (angle, length) in enumerate(branches):
        # A gentle curve keeps the cluster from looking like a starfish.
        bend = random.uniform(-0.16, 0.16)
        steps = 7
        previous = (root_x + random.uniform(-4.0, 4.0), root_y)
        for step in range(1, steps + 1):
            t = step / steps
            a = angle + bend * t
            x = root_x + math.sin(a) * length * t
            y = root_y - math.cos(a) * length * t
            draw_line(buf, previous[0], previous[1], x, y, 4.2 - t * 2.0, stem)
            previous = (x, y)
        leaf_index = branch_index * 4
        for step in range(4):
            t = 0.34 + step * 0.19 + random.uniform(-0.025, 0.025)
            a = angle + bend * t
            bx = root_x + math.sin(a) * length * t
            by = root_y - math.cos(a) * length * t
            side = -1.0 if step % 2 == 0 else 1.0
            leaf_angle = a + side * random.uniform(0.85, 1.20)
            leaf_len = random.uniform(38.0, 52.0) * (1.10 - t * 0.28)
            leaf_wid = leaf_len * random.uniform(0.48, 0.60)
            lx = bx + math.sin(leaf_angle) * leaf_len * 0.34
            ly = by - math.cos(leaf_angle) * leaf_len * 0.34
            draw_leaf(buf, lx, ly, leaf_len, leaf_wid, leaf_angle,
                      leaf_palette(leaf_index))
            leaf_index += 1
        # Terminal leaf along the branch.
        tip_angle = angle + bend
        tx = root_x + math.sin(tip_angle) * length * 1.02
        ty = root_y - math.cos(tip_angle) * length * 1.02
        leaf_len = random.uniform(44.0, 58.0)
        draw_leaf(buf, tx, ty, leaf_len, leaf_len * 0.54, tip_angle,
                  leaf_palette(leaf_index + 2))
    # Fill the upper shell with extra leaves so a canopy card is dense across
    # most of its square, not a bouquet in the bottom half.
    for index in range(9):
        angle = -1.05 + index * 0.26 + random.uniform(-0.08, 0.08)
        distance = random.uniform(58.0, 102.0)
        lx = root_x + math.sin(angle) * distance
        ly = root_y - math.cos(angle) * distance * 0.92
        length = random.uniform(36.0, 52.0)
        draw_leaf(buf, lx, ly, length, length * random.uniform(0.46, 0.58),
                  angle, leaf_palette(index + 3))
    # Fill the lower corners with a few leaves so the card does not read as a
    # flat bouquet when seen edge-on.
    for index in range(4):
        angle = -1.25 + index * 0.75 + random.uniform(-0.1, 0.1)
        length = random.uniform(70.0, 96.0)
        lx = root_x + math.sin(angle) * length * 0.55
        ly = root_y - math.cos(angle) * length * 0.55
        draw_leaf(buf, lx, ly, random.uniform(42.0, 52.0),
                  random.uniform(23.0, 30.0), angle, leaf_palette(index + 1))
    return buf


def build_needle_card():
    """A dense fir frond: a central spine with needles reaching the card edge.

    The previous version was a thin horizontal sprig, so 70% of every card was
    transparent and pine crowns looked hollow. Needle length now tapers from
    the trunk end to the tip and spans most of the texture height, which makes
    each card a solid green feather.
    """
    buf = new_canvas()
    start = (SIZE * 0.01, SIZE * 0.5)
    end = (SIZE * 0.99, SIZE * 0.5)
    stem = (0.25, 0.17, 0.09)
    draw_line(buf, start[0], start[1], end[0], end[1], 5.5, stem)
    dark = (0.075, 0.185, 0.10)
    mid = (0.115, 0.265, 0.145)
    light = (0.175, 0.350, 0.185)
    count = 210
    for index in range(count):
        t = float(index) / float(count - 1)
        bx = start[0] + (end[0] - start[0]) * t
        by = start[1] + math.sin(t * math.pi) * 3.0
        side = -1.0 if index % 2 == 0 else 1.0
        # A wide fan, not a comb: angles vary so the card has no straight edge.
        angle = side * random.uniform(1.02, 1.42) - 0.06
        length = (16.0 + 112.0 * (1.0 - t) ** 0.58) * random.uniform(0.82, 1.06)
        tx = bx + math.cos(angle) * length
        ty = by + math.sin(angle) * length
        color = mid if index % 3 else (light if index % 2 else dark)
        draw_line(buf, bx, by, tx, ty, random.uniform(1.7, 2.8), color, 0.97)
        # A shorter inner needle fills the gaps between the long ones.
        if index % 2 == 0:
            short = length * random.uniform(0.35, 0.55)
            draw_line(buf, bx, by, bx + math.cos(angle) * short,
                      by + math.sin(angle) * short, 1.6, mid, 0.95)
    # A few side twigs near the trunk end break the wedge silhouette.
    for twig_index in range(4):
        base_t = 0.08 + twig_index * 0.10
        bx = start[0] + (end[0] - start[0]) * base_t
        by = start[1]
        for needle_index in range(10):
            t = float(needle_index) / 9.0
            side = -1.0 if needle_index % 2 == 0 else 1.0
            tx = bx + 34.0 * t
            ty = by + side * (18.0 + 38.0 * t) + random.uniform(-4.0, 4.0)
            draw_line(buf, bx + 34.0 * t, by, tx, ty, 1.6, mid, 0.95)
    return buf


def write_png(path, buf):
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter: none
        for x in range(SIZE):
            pixel = buf[y * SIZE + x]
            rows.append(int(clamp(pixel[0]) * 255.0 + 0.5))
            rows.append(int(clamp(pixel[1]) * 255.0 + 0.5))
            rows.append(int(clamp(pixel[2]) * 255.0 + 0.5))
            rows.append(int(clamp(pixel[3]) * 255.0 + 0.5))

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(png)
    print("WROTE", path, len(png), "bytes")


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    write_png(os.path.join(TEXTURES, "leaf_card.png"), build_leaf_card())
    write_png(os.path.join(TEXTURES, "needle_card.png"), build_needle_card())


if __name__ == "__main__":
    main()
