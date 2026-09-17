#!/usr/bin/env python3
"""Render a palette-coloured wallpaper.

Called by scripts/theme.sh. Switching palettes has to move the wallpaper too,
or the retheme stops at the window borders and a Catppuccin-purple gradient
sits behind the new grey bar -- which is the single most visible thing on the
screen.

Writes PNG bytes directly with zlib and struct. That is more code than
`magick -size ... gradient:`, but neither ImageMagick nor Pillow is installed
on this machine, and adding either as a dependency to generate two flat
gradients is not a trade worth making. Everything used here is stdlib.

Usage: make-wallpaper.py <palette.env> <output-dir>
"""

import math
import re
import struct
import sys
import zlib
from pathlib import Path

# Half the 2560x1440 the monitors actually run at (see hardware.lua).
# hyprpaper's fit_mode = cover and the greeter's background-size: cover both
# scale to fit regardless, and a gradient this smooth upscales without a
# visible artefact -- while rendering at native resolution would mean 11M
# per-pixel operations in pure Python per image, which is the difference
# between this script taking under a second and taking most of a minute.
#
# The portrait variant is kept because the repo has always shipped one, even
# though neither display is rotated at the moment.
SIZES = {"landscape": (1280, 720), "portrait": (720, 1280)}

KV = re.compile(r'^([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"')

# 8x8 Bayer matrix, normalised to (-0.5, +0.5). Ordered rather than random
# dither on purpose: it is deterministic, so re-running the script byte-for-byte
# reproduces the same PNG and a palette that has not changed shows no diff.
_BAYER_8 = [
    [0, 32, 8, 40, 2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
]
BAYER = [[(v + 0.5) / 64.0 - 0.5 for v in row] for row in _BAYER_8]


def clamp(v: float) -> int:
    return 0 if v < 0 else (255 if v > 255 else round(v))


def read_palette(path: Path) -> dict[str, str]:
    colors = {}
    for line in path.read_text().splitlines():
        m = KV.match(line.strip())
        if m:
            colors[m.group(1)] = m.group(2)
    return colors


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    v = value.lstrip("#")
    return int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16)


def render(width: int, height: int, dark: tuple, light: tuple) -> bytes:
    """A very low-contrast radial falloff from just off-centre.

    Deliberately close to flat. A wallpaper with any structure in it competes
    with a translucent bar and with window borders that are only 1px wide --
    the whole point of the scheme is that the brightest thing on screen is the
    focused window, and a busy background takes that away. The two endpoints
    are ~10 RGB steps apart, which is enough to stop the screen looking like a
    dead pixel field and not enough to notice as a gradient.
    """
    cx, cy = width * 0.5, height * 0.38
    # Normalising by the distance to the furthest corner keeps the falloff
    # identical in shape whether the image is landscape or portrait.
    max_d = math.hypot(max(cx, width - cx), max(cy, height - cy))

    dx2 = [(x - cx) ** 2 for x in range(width)]
    lr, lg, lb = light
    dr, dg, db = dark

    rows = bytearray()
    for y in range(height):
        # Filter byte 0 (None) per scanline -- required by the PNG spec even
        # when no filtering is applied.
        rows.append(0)
        dy2 = (y - cy) ** 2
        brow = BAYER[y & 7]
        for x, d in enumerate(dx2):
            t = math.sqrt(d + dy2) / max_d
            # Squared falloff: keeps the lighter area small and the edges
            # settled at the base colour rather than tinting the whole frame.
            t = min(1.0, t) ** 2
            # Ordered dither, applied before rounding. Without it the image
            # bands into visible concentric rings: the two endpoints are only
            # ~22 RGB steps apart spread over 1280px, so each 8-bit step covers
            # a wide band of the gradient and the eye reads the boundaries as
            # contour lines. A sub-1-LSB jitter breaks them into noise instead,
            # which at this amplitude is invisible on its own.
            j = brow[x & 7]
            rows.append(clamp(lr + (dr - lr) * t + j))
            rows.append(clamp(lg + (dg - lg) * t + j))
            rows.append(clamp(lb + (db - lb) * t + j))
    return bytes(rows)


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, width: int, height: int, raw: bytes) -> None:
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit truecolour
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 1

    palette_file = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)

    colors = read_palette(palette_file)
    name = colors.get("name", palette_file.stem)

    try:
        dark = hex_to_rgb(colors["bg"])
        light = hex_to_rgb(colors["surface_hi"])
    except KeyError as e:
        print(f"{palette_file}: missing key {e}", file=sys.stderr)
        return 1

    for variant, (w, h) in SIZES.items():
        out = out_dir / f"{name}-{variant}.png"
        write_png(out, w, h, render(w, h, dark, light))
        print(f"    wallpapers/{out.name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
