"""Generates the tiling fur and hide textures used by the Blender creatures.

Run with any Python 3 (no third-party modules):
  py assets/models/creatures/make_creature_textures.py

Outputs two 256 px RGB atlases next to the other surface textures:

* `assets/textures/wolf_fur.png`  - charcoal guard hairs over a dark undercoat.
* `assets/textures/boar_hide.png` - coarse, muddy bristle hide.

Everything is drawn procedurally so the project owns every pixel. The meshes
are UV-unwrapped with Blender's Smart UV Project and the GLB embeds a copy of
the texture, so the runtime does not have to load these files directly.
"""

import math
import os
import random
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
TEXTURES = os.path.normpath(os.path.join(HERE, "..", "..", "textures"))
SIZE = 256
random.seed(77123)


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def smoothstep(value):
    return value * value * (3.0 - 2.0 * value)


def hash2(x, y, seed):
    value = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    value = (value ^ (value >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((value ^ (value >> 16)) & 0xFFFFFF) / float(0xFFFFFF)


def grid_value(ix, iy, cx, cy, seed):
    return hash2(ix % cx, iy % cy, seed)


def value_noise(u, v, cx, cy, seed):
    """Tiling value noise with independent horizontal/vertical cell counts."""
    fx = u * cx
    fy = v * cy
    ix = int(math.floor(fx))
    iy = int(math.floor(fy))
    tx = smoothstep(fx - ix)
    ty = smoothstep(fy - iy)
    n00 = grid_value(ix, iy, cx, cy, seed)
    n10 = grid_value(ix + 1, iy, cx, cy, seed)
    n01 = grid_value(ix, iy + 1, cx, cy, seed)
    n11 = grid_value(ix + 1, iy + 1, cx, cy, seed)
    top = n00 + (n10 - n00) * tx
    bottom = n01 + (n11 - n01) * tx
    return top + (bottom - top) * ty


def fbm(u, v, seed):
    total = 0.0
    amplitude = 0.55
    weight = 0.0
    for index, cells in enumerate((3, 7, 15, 31)):
        total += amplitude * value_noise(u, v, cells, cells, seed + index * 41)
        weight += amplitude
        amplitude *= 0.5
    return total / weight


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def draw_strands(pixels, seed):
    """Overlays thin vertical guard hairs on the finished atlas.

    The noise layers give the pelt its colour; these one-pixel strands are what
    read as individual hairs when the camera gets close. Vertical strokes match
    the stretched fibre noise, and the tapered brightness makes each strand
    look lit at the root and lost in shadow at the tip.
    """
    rng = random.Random(seed + 991)
    for _ in range(1500):
        x = rng.randrange(SIZE)
        start = rng.randrange(-40, SIZE)
        length_value = rng.randint(6, 26)
        width = 2 if rng.random() < 0.22 else 1
        light = rng.uniform(-0.048, 0.062)
        drift = rng.uniform(-0.10, 0.10)
        for step in range(length_value):
            py = (start + step) % SIZE
            px = (x + int(round(drift * step))) % SIZE
            taper = 1.0 - (float(step) / float(length_value)) * 0.55
            for offset_x in range(width):
                index = ((py * SIZE) + ((px + offset_x) % SIZE)) * 3
                for channel in range(3):
                    value = pixels[index + channel] + light * taper * 255.0
                    pixels[index + channel] = int(clamp(value, 0.0, 255.0))


def creature_texture(palette, seed):
    dark, base, light, pale = palette
    pixels = []
    for y in range(SIZE):
        v = y / float(SIZE)
        for x in range(SIZE):
            u = x / float(SIZE)
            blotch = fbm(u, v, seed)
            # Near-isotropic fine fibre: long stretched cells turned the pelt
            # into wood grain once Smart UV Project laid the islands out.
            fiber = value_noise(u, v, 61, 47, seed + 733)
            fine = hash2(x, y, seed + 1201)
            shade = clamp(0.34 + blotch * 0.56 + fiber * 0.16 + fine * 0.10)
            if shade < 0.44:
                color = mix(dark, base, shade / 0.44)
            elif shade < 0.78:
                color = mix(base, light, (shade - 0.44) / 0.34)
            else:
                color = mix(light, pale, (shade - 0.78) / 0.22)
            # A few scattered pale guard hairs and near-black roots break the
            # smooth gradient at close range.
            if fine > 0.994:
                color = mix(color, pale, 0.45)
            pixels.extend((
                int(clamp(color[0]) * 255),
                int(clamp(color[1]) * 255),
                int(clamp(color[2]) * 255),
            ))
    draw_strands(pixels, seed)
    return bytes(pixels)


def write_png(path, raw, width=SIZE, height=SIZE, channels=3):
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(
            ">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    rows = bytearray()
    stride = width * channels
    for y in range(height):
        rows.append(0)
        rows.extend(raw[y * stride:(y + 1) * stride])
    color_type = 6 if channels == 4 else 2
    header = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(png)
    print("WROTE", path, len(png), "bytes")


def fur_card_texture(seed):
    """A clump of hair on a transparent card.

    The creature bodies are smooth remeshed skin; this card is what gives them
    a shaggy silhouette. It is deliberately neutral grey so the runtime can tint
    one texture into a wolf pelt or a boar hide, and the strands taper to
    nothing at the top so an alpha-scissor edge dissolves instead of cutting a
    hard rectangle.
    """
    size = 256
    rng = random.Random(seed)
    alpha = [0.0] * (size * size)
    shade = [0.72] * (size * size)

    def plot(x, y, value, tone):
        if 0 <= x < size and 0 <= y < size:
            index = y * size + x
            if value > alpha[index]:
                alpha[index] = value
                shade[index] = tone

    for _ in range(30):
        base_x = rng.uniform(-14.0, size + 14.0)
        base_half = rng.uniform(7.0, 17.0)
        height_value = rng.uniform(150.0, 252.0)
        tip_x = base_x + rng.uniform(-46.0, 46.0)
        tone = rng.uniform(0.60, 0.96)
        for step in range(int(height_value)):
            t = float(step) / height_value
            y = size - 1 - step
            half = base_half * (1.0 - t) ** 0.72 + 0.6
            center = base_x + (tip_x - base_x) * t + math.sin(t * 4.4 + base_x) * 1.4
            taper = min(1.0, 4.0 * (1.0 - t) + 0.08)
            left = int(round(center - half))
            right = int(round(center + half))
            for x in range(left, right + 1):
                plot(x, y, taper, tone)
    # A handful of loose guard hairs over the mass so the edge is not a clean
    # polygon silhouette.
    for _ in range(90):
        base_x = rng.uniform(-8.0, size + 8.0)
        base_w = rng.uniform(1.4, 3.0)
        height_value = rng.uniform(140.0, 256.0)
        drift = rng.uniform(-34.0, 34.0)
        tone = rng.uniform(0.55, 1.0)
        for step in range(int(height_value)):
            t = float(step) / height_value
            y = size - 1 - step
            width_value = base_w * (1.0 - t) ** 0.55 + 0.6
            center = base_x + drift * t + math.sin(t * 6.0 + base_x) * 2.2
            taper = min(1.0, 5.0 * (1.0 - t) + 0.06)
            span = int(width_value) + 1
            for offset in range(-span, span + 1):
                edge = 1.0 - min(abs(float(offset)) / max(width_value, 0.55), 1.0)
                plot(int(round(center)) + offset, y, taper * edge, tone)
    # A soft opaque root so no light leaks between the card and the skin.
    for y in range(size - 26, size):
        depth = float(y - (size - 26)) / 25.0
        for x in range(size):
            jitter = 0.55 + 0.45 * hash2(x, y, seed + 31)
            plot(x, y, min(1.0, 0.45 + depth) * jitter, 0.80)
    pixels = bytearray()
    for index, value in enumerate(alpha):
        tone = int(clamp(shade[index]) * 255)
        pixels.extend((tone, tone, tone, int(clamp(value) * 255)))
    return bytes(pixels)


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    wolf = creature_texture(
        ((0.105, 0.100, 0.090), (0.225, 0.215, 0.198), (0.315, 0.300, 0.272), (0.395, 0.372, 0.330)),
        9137,
    )
    write_png(os.path.join(TEXTURES, "wolf_fur.png"), wolf)
    boar = creature_texture(
        ((0.135, 0.092, 0.062), (0.245, 0.170, 0.115), (0.330, 0.238, 0.158), (0.410, 0.305, 0.205)),
        4519,
    )
    write_png(os.path.join(TEXTURES, "boar_hide.png"), boar)
    card = fur_card_texture(6103)
    write_png(os.path.join(TEXTURES, "fur_card.png"), card, channels=4)


if __name__ == "__main__":
    main()
