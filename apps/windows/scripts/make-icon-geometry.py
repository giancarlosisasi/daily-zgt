#!/usr/bin/env python3
"""Write the WPF icon resource dictionary.

Reads the Phosphor (bold) SVGs of the macOS app and the crosshair mark from
apps/macos/DailyZGT/App/MenuBarIcon.swift, and writes one ResourceDictionary of
Geometry resources to apps/windows/src/DailyZGT/Theme/Icons.xaml. Copies the
Phosphor license next to the icon assets.

Every geometry uses a 256 x 256 view box and one filled path. Phosphor paths use
the non-zero fill rule. The crosshair is scaled from the 24 x 24 view box of
MenuBarIcon.swift and uses the even-odd rule. Draw one with the IconView
control.

Run: python apps/windows/scripts/make-icon-geometry.py
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ICONS = ROOT / "apps" / "macos" / "DailyZGT" / "Resources" / "Icons.xcassets"
LICENSE = ROOT / "apps" / "macos" / "DailyZGT" / "Resources" / "Phosphor-LICENSE.txt"
OUTPUT = ROOT / "apps" / "windows" / "src" / "DailyZGT" / "Theme" / "Icons.xaml"
LICENSE_OUTPUT = ROOT / "apps" / "windows" / "src" / "DailyZGT" / "Assets" / "Icons" / "Phosphor-LICENSE.txt"

# Icon.swift: the macOS asset name for each key.
PHOSPHOR = {
    "ArrowBack": "arrow-u-up-left-bold",
    "Bell": "bell-bold",
    "BellSlash": "bell-slash-bold",
    "Calendar": "calendar-blank-bold",
    "CaretLeft": "caret-left-bold",
    "CaretRight": "caret-right-bold",
    "Check": "check-bold",
    "Gear": "gear-bold",
    "Note": "note-bold",
    "Plus": "plus-bold",
    "Trash": "trash-bold",
    "Close": "x-bold",
}

# MenuBarIcon.swift: view box 24, two rings stroked 2 wide and a dot of radius
# 1.2 that is filled and stroked. Each ring is drawn as an outer and an inner
# circle (radius -/+ 1) for the even-odd fill rule.
CROSSHAIR_RADII = [10, 8, 6, 4, 2.2]
CROSSHAIR_VIEW_BOX = 24
VIEW_BOX = 256


def circle(radius):
    scale = VIEW_BOX / CROSSHAIR_VIEW_BOX
    cx = VIEW_BOX / 2
    r = f"{radius * scale:.3f}".rstrip("0").rstrip(".")
    left = f"{cx - radius * scale:.3f}".rstrip("0").rstrip(".")
    right = f"{cx + radius * scale:.3f}".rstrip("0").rstrip(".")
    return f"M{left},{cx:g} A{r},{r} 0 1 0 {right},{cx:g} A{r},{r} 0 1 0 {left},{cx:g} Z"


def phosphor_path(asset):
    svg = (ICONS / f"{asset}.imageset" / f"{asset}.svg").read_text(encoding="utf-8")
    paths = re.findall(r'<path[^>]*\sd="([^"]+)"', svg)
    if len(paths) != 1 or 'viewBox="0 0 256 256"' not in svg:
        raise SystemExit(f"{asset}.svg is not one path on a 256 view box")
    return paths[0]


def main():
    lines = [
        '<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"',
        '                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">',
        "    <!-- Written by apps/windows/scripts/make-icon-geometry.py. Do not edit.",
        "         Icons are Phosphor Icons (bold), MIT license: Assets/Icons/Phosphor-LICENSE.txt.",
        "         Every geometry uses a 256 view box. -->",
        "",
    ]
    for key, asset in PHOSPHOR.items():
        lines.append(f'    <Geometry x:Key="Icon.{key}">F1 {phosphor_path(asset)}</Geometry>')
    crosshair = " ".join(circle(radius) for radius in CROSSHAIR_RADII)
    lines.append(f'    <Geometry x:Key="Icon.Crosshair">F0 {crosshair}</Geometry>')
    lines.append("</ResourceDictionary>")
    OUTPUT.write_bytes(("\n".join(lines) + "\n").encode("utf-8"))
    LICENSE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(LICENSE, LICENSE_OUTPUT)
    print(f"Wrote {OUTPUT.relative_to(ROOT).as_posix()} ({len(PHOSPHOR) + 1} geometries).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
