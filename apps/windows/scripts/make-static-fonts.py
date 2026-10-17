#!/usr/bin/env python3
"""Cut static TTF instances from the macOS variable fonts.

WPF does not pick a variable font axis by FontWeight. This script reads the
families, weights and width from packages/design-tokens/tecla.json, cuts one
static TTF per weight with fontTools varLib.instancer, and rewrites the name
and OS/2 tables so that every weight of a family groups under one family name
and WPF picks the face by FontWeight.

Run: python apps/windows/scripts/make-static-fonts.py
Needs: pip install fonttools brotli
"""
import json
import shutil
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[3]
TOKENS = ROOT / "packages" / "design-tokens" / "tecla.json"
SOURCE_DIR = ROOT / "apps" / "macos" / "DailyZGT" / "Resources" / "Fonts"
OUTPUT_DIR = ROOT / "apps" / "windows" / "src" / "DailyZGT" / "Assets" / "Fonts"

WEIGHT_NAMES = {
    100: "Thin",
    200: "ExtraLight",
    300: "Light",
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
    900: "Black",
}

# OS/2 usWidthClass for the width axis value (percent of normal).
WIDTH_CLASSES = {50: 1, 62.5: 2, 75: 3, 87.5: 4, 100: 5, 112.5: 6, 125: 7, 150: 8, 200: 9}

MAC_NAME_IDS = (1, 2, 3, 4, 6, 16, 17, 21, 22, 25)


def set_name(font, name_id, value):
    table = font["name"]
    table.removeNames(nameID=name_id)
    if value is not None:
        table.setName(value, name_id, 3, 1, 0x409)
        table.setName(value, name_id, 1, 0, 0)


def style_names(family_name, weight):
    """Name IDs 1, 2, 16 and 17 as Google Fonts writes static families.

    Regular and Bold are the two RIBBI weights and use the legacy pair
    (family, Regular|Bold). The other weights carry the weight in ID 1 and the
    shared family in ID 16, so every weight still groups under one family.
    """
    style = WEIGHT_NAMES[weight]
    if weight == 400:
        return family_name, "Regular", None, None
    if weight == 700:
        return family_name, "Bold", None, None
    return f"{family_name} {style}", "Regular", family_name, style


def rename(font, family_name, weight, width_class):
    legacy_family, legacy_style, typo_family, typo_style = style_names(family_name, weight)
    style = WEIGHT_NAMES[weight]
    compact = family_name.replace(" ", "")
    full = f"{family_name} {style}"
    version = font["head"].fontRevision

    for name_id in MAC_NAME_IDS:
        set_name(font, name_id, None)
    set_name(font, 1, legacy_family)
    set_name(font, 2, legacy_style)
    set_name(font, 3, f"{version:.3f};{compact}-{style};static")
    set_name(font, 4, full)
    set_name(font, 6, f"{compact}-{style}")
    if typo_family:
        set_name(font, 16, typo_family)
        set_name(font, 17, typo_style)

    os2 = font["OS/2"]
    os2.usWeightClass = weight
    os2.usWidthClass = width_class
    selection = os2.fsSelection & ~(0x01 | 0x20 | 0x40)
    selection |= 0x20 if weight == 700 else 0x40
    os2.fsSelection = selection
    font["head"].macStyle = 0x01 if weight == 700 else 0


def cut(source, family_name, weight, width, target):
    font = TTFont(source)
    axes = {"wght": float(weight)}
    if width is not None and any(axis.axisTag == "wdth" for axis in font["fvar"].axes):
        axes["wdth"] = float(width)
    limits = {axis.axisTag: axis for axis in font["fvar"].axes}
    for tag, value in axes.items():
        if not limits[tag].minValue <= value <= limits[tag].maxValue:
            raise SystemExit(f"{source.name}: {tag}={value} is outside the axis range")
    static = instancer.instantiateVariableFont(font, axes, inplace=False)
    for table in ("STAT", "avar", "MVAR", "HVAR", "VVAR", "gvar", "fvar", "cvar"):
        if table in static:
            del static[table]
    width_class = WIDTH_CLASSES.get(width if width is not None else 100, 5)
    rename(static, family_name, weight, width_class)
    static.save(target)


def main():
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    written = []
    for family in tokens["font"].values():
        source = SOURCE_DIR / family["file"]
        if not source.exists():
            raise SystemExit(f"missing {source}")
        name = family["family"]
        compact = name.replace(" ", "")
        for weight in family["weights"]:
            target = OUTPUT_DIR / f"{compact}-{WEIGHT_NAMES[weight]}.ttf"
            cut(source, name, weight, family.get("width"), target)
            written.append(target)
        license_file = SOURCE_DIR / f"{compact}-OFL.txt"
        shutil.copyfile(license_file, OUTPUT_DIR / license_file.name)
    for target in written:
        print(f"{target.relative_to(ROOT).as_posix()}  {target.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
