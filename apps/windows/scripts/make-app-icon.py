#!/usr/bin/env python3
"""Draw the app icon as a multi-size ICO.

Mirrors apps/macos/scripts/generate-app-icon.swift: a violet key with a side,
a soft shadow, and the crosshair mark in white with a yellow dot. The colors
come from packages/design-tokens/tecla.json. Each size is drawn on its own with
the same mark proportions as the macOS script, so 16 and 24 px stay legible.

Run: python apps/windows/scripts/make-app-icon.py
Needs: pip install pillow
"""
import json
import struct
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
TOKENS = ROOT / "packages" / "design-tokens" / "tecla.json"
OUTPUT = ROOT / "apps" / "windows" / "src" / "DailyZGT" / "Assets" / "AppIcon.ico"

CANVAS = 1024
MARGIN = 100
CORNER_RADIUS = 185
SIDE_HEIGHT = 56
SHADOW_OFFSET = 12
SHADOW_BLUR = 28
SUPERSAMPLE = 4
SIZES = [16, 24, 32, 48, 64, 128, 256]


def rgba(token, alpha=None):
    digits = token["hex"].lstrip("#")
    red, green, blue = (int(digits[i : i + 2], 16) for i in (0, 2, 4))
    return red, green, blue, round((token["alpha"] if alpha is None else alpha) * 255)


def mark_for(pixels):
    if pixels < 24:
        return 30, [8], 3.4, 3
    if pixels < 48:
        return 27, [9, 4.7], 2.3, 1.7
    return 25, [9, 5], 2, 2.2


def key_box(top):
    side = CANVAS - MARGIN * 2
    return (MARGIN, top, MARGIN + side, top + side - SIDE_HEIGHT)


def render(pixels, colors, shadow):
    scale = pixels * SUPERSAMPLE / CANVAS
    size = pixels * SUPERSAMPLE

    def box(rect):
        return tuple(value * scale for value in rect)

    def shape(top):
        layer = Image.new("L", (size, size), 0)
        ImageDraw.Draw(layer).rounded_rectangle(box(key_box(top)), CORNER_RADIUS * scale, fill=255)
        return layer

    side_top = MARGIN + SIDE_HEIGHT
    side_mask = shape(side_top)
    face_mask = shape(MARGIN)

    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow_mask = ImageChops.offset(side_mask, 0, round(SHADOW_OFFSET * scale)).filter(
        ImageFilter.GaussianBlur(SHADOW_BLUR * scale / 2)
    )
    shadow_alpha = shadow_mask.point(lambda value: round(value * shadow[3] / 255))
    image.paste(Image.new("RGBA", (size, size), shadow[:3] + (255,)), (0, 0), shadow_alpha)
    image.paste(Image.new("RGBA", (size, size), colors["fillSide"]), (0, 0), side_mask)
    image.paste(Image.new("RGBA", (size, size), colors["fill"]), (0, 0), face_mask)

    unit, rings, stroke, dot = mark_for(pixels)
    center = CANVAS / 2
    face_center_y = MARGIN + (CANVAS - MARGIN * 2 - SIDE_HEIGHT) / 2
    draw = ImageDraw.Draw(image)
    half = stroke * unit / 2
    for ring in rings:
        radius = ring * unit
        outer = box((center - radius - half, face_center_y - radius - half, center + radius + half, face_center_y + radius + half))
        inner = box((center - radius + half, face_center_y - radius + half, center + radius - half, face_center_y + radius - half))
        ring_mask = Image.new("L", (size, size), 0)
        ring_draw = ImageDraw.Draw(ring_mask)
        ring_draw.ellipse(outer, fill=255)
        ring_draw.ellipse(inner, fill=0)
        image.paste(Image.new("RGBA", (size, size), colors["onFill"]), (0, 0), ring_mask)
    radius = dot * unit
    draw.ellipse(
        box((center - radius, face_center_y - radius, center + radius, face_center_y + radius)),
        fill=colors["accent"],
    )
    return image.resize((pixels, pixels), Image.LANCZOS)


def png_bytes(image):
    buffer = BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def write_ico(images, target):
    blobs = [png_bytes(image) for image in images]
    header = struct.pack("<HHH", 0, 1, len(blobs))
    offset = len(header) + 16 * len(blobs)
    entries = b""
    for image, blob in zip(images, blobs):
        dimension = image.width if image.width < 256 else 0
        entries += struct.pack("<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(header + entries + b"".join(blobs))


def main():
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))
    colors = {name: rgba(tokens["color"][name]) for name in ("fill", "fillSide", "onFill", "accent")}
    shadow = rgba(tokens["shadow"]["alert"][0]["color"])
    images = [render(pixels, colors, shadow) for pixels in SIZES]
    write_ico(images, OUTPUT)
    print(f"Wrote {OUTPUT.relative_to(ROOT).as_posix()} with sizes {SIZES}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
