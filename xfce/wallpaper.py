#!/usr/bin/env python3
"""Render the Solarized dusk wallpaper: a striped sun setting behind layered ridges.

Colors match the darkened Solarized palette used by tmux, bash and the XFCE theme.
The scene is seeded, so every run produces the same image.

Usage: wallpaper.py <output.png> [<width> <height>]
"""

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

BG, BG_HIGHLIGHT = "#070d15", "#0f1b29"     # darkened base03 / base02
BASE1, BASE2 = "#93a1a1", "#eee8d5"
YELLOW, ORANGE, RED, MAGENTA = "#b58900", "#cb4b16", "#dc322f", "#d33682"
VIOLET, BLUE, CYAN = "#6c71c4", "#268bd2", "#2aa198"

HORIZON = 0.70   # fraction of the height
SEED = 1983


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(rgb(a) if isinstance(a, str) else a,
                                                       rgb(b) if isinstance(b, str) else b))


def vertical_gradient(size, stops):
    """stops: [(position 0..1, color)] -> image filled top to bottom."""
    w, h = size
    column = []
    for y in range(h):
        t = y / (h - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if t <= p1:
                column.append(mix(c0, c1, (t - p0) / (p1 - p0)))
                break
        else:
            column.append(rgb(stops[-1][1]))
    strip = Image.new("RGB", (1, h))
    strip.putdata(column)
    return strip.resize((w, h), Image.NEAREST)


def glow(size, center, radii, color, opacity, blur):
    w, h = size
    layer = Image.new("L", size, 0)
    cx, cy = center
    rx, ry = radii
    ImageDraw.Draw(layer).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=round(255 * opacity))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    return Image.new("RGB", size, rgb(color)), layer


def stars(img, rng):
    w, h = img.size
    draw = ImageDraw.Draw(img)
    for _ in range(w * h // 9000):
        x = rng.uniform(0, w)
        y = h * HORIZON * rng.random() ** 1.6       # denser toward the top
        r = rng.choice((0.6, 0.8, 1.0, 1.0, 1.4)) * w / 1920
        tint = rng.choice((BASE1, BASE1, BASE2, BLUE, CYAN))
        fade = 0.25 + 0.75 * rng.random() * (1 - y / (h * HORIZON))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=mix(BG, tint, fade))


def sun(img, center, radius):
    """Retro sun: Solarized yellow -> magenta, cut by stripes that widen downward."""
    w, h = img.size
    cx, cy = center
    scale = 2
    box = (round(cx - radius), round(cy - radius))
    size = round(radius * 2)

    fill = vertical_gradient((size, size), [(0, YELLOW), (0.4, ORANGE), (0.7, RED), (1, MAGENTA)])
    mask = Image.new("L", (size * scale, size * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    for i in range(7):
        t = 0.48 + i * 0.075
        gap = (0.006 + i * 0.006) * size * scale
        y = t * size * scale
        draw.rectangle((0, y, size * scale, y + gap), fill=0)
    mask = mask.resize((size, size), Image.LANCZOS)
    img.paste(fill, box, mask)


def ridge(rng, width, base, amplitude, roughness):
    waves = [(rng.uniform(0.5, 1.0) * (2 ** k), rng.uniform(0, 2 * math.pi), 0.55 ** k)
             for k in range(roughness)]
    points = []
    for i in range(0, width + 8, 8):
        x = i / width
        v = sum(a * (1 - abs(math.sin(f * math.pi * x * 2 + p))) for f, p, a in waves)
        points.append((i, base - amplitude * v / sum(a for _, _, a in waves)))
    return points


def mountains(img, rng, rim_color):
    w, h = img.size
    scale = 2
    layers = [  # base (fraction of height), amplitude, roughness, color
        (HORIZON + 0.02, 0.20, 6, mix(BG_HIGHLIGHT, VIOLET, 0.22)),
        (HORIZON + 0.08, 0.17, 6, mix(BG_HIGHLIGHT, BG, 0.15)),
        (HORIZON + 0.16, 0.15, 5, mix(BG_HIGHLIGHT, BG, 0.55)),
        (HORIZON + 0.26, 0.13, 5, mix(BG, "#000000", 0.45)),
    ]
    for n, (base, amplitude, roughness, color) in enumerate(layers):
        points = ridge(rng, w * scale, base * h * scale, amplitude * h * scale, roughness)
        mask = Image.new("L", (w * scale, h * scale), 0)
        ImageDraw.Draw(mask).polygon(points + [(w * scale, h * scale), (0, h * scale)], fill=255)
        mask = mask.resize((w, h), Image.LANCZOS)
        if n == 0:   # sunlight catching the far ridge
            rim = ImageChops.subtract(mask, mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -3)))
            img.paste(Image.new("RGB", img.size, rim_color),
                      (0, 0), rim.point(lambda v: v * 0.55))
        img.paste(Image.new("RGB", img.size, color), (0, 0), mask)


def render(width, height):
    rng = random.Random(SEED)
    size = (width, height)
    horizon = height * HORIZON

    img = vertical_gradient(size, [
        (0.0, mix(BG, "#000000", 0.35)),
        (0.45, BG),
        (HORIZON, mix(BG_HIGHLIGHT, VIOLET, 0.30)),
        (1.0, BG),
    ])
    stars(img, rng)

    sun_center = (width * 0.5, horizon - height * 0.07)
    sun_radius = height * 0.17
    for color, radii, opacity, blur in (
        (MAGENTA, (width * 0.55, height * 0.10), 0.22, height * 0.08),
        (ORANGE, (sun_radius * 1.7, sun_radius * 1.7), 0.30, height * 0.09),
    ):
        layer, mask = glow(size, sun_center, radii, color, opacity, blur)
        img.paste(layer, (0, 0), mask)
    sun(img, sun_center, sun_radius)

    mountains(img, rng, rim_color=mix(ORANGE, YELLOW, 0.3))

    # Light dithering keeps the dark gradients from banding
    noise = Image.effect_noise(size, 2.5).convert("L")
    channels = [ImageChops.add(c, noise, 1, -128) for c in img.split()]
    return Image.merge("RGB", channels)


def main():
    if len(sys.argv) not in (2, 4):
        sys.exit(__doc__)
    out = Path(sys.argv[1]).expanduser()
    width, height = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) == 4 else (3840, 2160)
    out.parent.mkdir(parents=True, exist_ok=True)
    render(width, height).save(out, optimize=True)
    print(f"[INFO] Rendered {width}x{height} wallpaper to {out}")


if __name__ == "__main__":
    main()
