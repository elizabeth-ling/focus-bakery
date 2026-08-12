#!/usr/bin/env python3
"""Build the bitmap atlas and its metrics, and stage the chrome TTF.

Spec 01 needs two text tiers and the art pack ships neither (14). Both come out
of one file in the Ultimate Oldschool PC Font Pack: the in-scene atlas is
rasterized from it and the chrome tier *is* it, so the two tiers are the same
font by construction rather than by discipline.

    python3 tools/font/build_font.py                  # write all three outputs
    python3 tools/font/build_font.py --check          # validate, write nothing
    python3 tools/font/build_font.py --preview /tmp/f.png

Outputs (Resources/): Font.atlas/*.png, Font.json, PxPlus_IBM_CGA.ttf.
Requires Pillow and fontTools.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "Resources"
SOURCE = REPO / "assets/7_Fonts/ttf - Px (pixel outline)/PxPlus_IBM_CGA.ttf"

# Px fonts are pixel outlines: one art pixel is exactly 100 font units and the
# em is the full cell, so rasterizing at ppem = upem/100 is bit-exact rather
# than a resampling. Everything below is derived from the file, not asserted
# about it -- swapping SOURCE for another Px font is meant to just work.
UNITS_PER_PIXEL = 100

# The pack has no star at any size (checked across all 361 Px fonts), so ♦
# stands in for ★ quantities. Every other character the app draws is present.
CHARS = (
    " 0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    ".,:!?'-+/%()×♦…"
)

# The cell is monospaced and already carries its own right-hand gap, so a line
# of text needs no extra tracking on top of it.
TRACKING = 0
LEADING = 2


class BuildError(Exception):
    pass


class Source:
    """The pack font, reduced to the handful of numbers the build needs."""

    def __init__(self, path: pathlib.Path):
        if not path.exists():
            raise BuildError(f"{path.relative_to(REPO)} is missing")
        tt = TTFont(path)
        head, hhea = tt["head"], tt["hhea"]

        if head.unitsPerEm % UNITS_PER_PIXEL:
            raise BuildError(
                f"{path.name}: {head.unitsPerEm} units/em is not a whole number of "
                f"art pixels -- is this an Ac (aspect-corrected) font?"
            )

        self.path = path
        self.ascent = hhea.ascent // UNITS_PER_PIXEL
        self.descent = -hhea.descent // UNITS_PER_PIXEL
        self.cell_height = head.unitsPerEm // UNITS_PER_PIXEL

        cmap = tt.getBestCmap()
        missing = [c for c in CHARS if ord(c) not in cmap]
        if missing:
            raise BuildError(f"{path.name}: no glyph for {''.join(missing)!r}")

        widths = {tt["hmtx"][cmap[ord(c)]][0] for c in CHARS}
        if len(widths) != 1:
            raise BuildError(
                f"{path.name}: advances vary ({sorted(widths)}); the layout in "
                f"BitmapTextNode has no left-bearing and assumes one cell width"
            )
        self.cell_width = widths.pop() // UNITS_PER_PIXEL

        if self.ascent + self.descent != self.cell_height:
            raise BuildError(
                f"{path.name}: ascent {self.ascent} + descent {self.descent} "
                f"is not the {self.cell_height}-row em"
            )

        self.font = ImageFont.truetype(str(path), self.cell_height)

    def glyph_image(self, char: str) -> Image.Image:
        """One full cell. Rendering the whole cell keeps each glyph's own
        position inside it, which is what makes the monospaced grid line up."""
        im = Image.new("RGBA", (self.cell_width, self.cell_height), (0, 0, 0, 0))
        ImageDraw.Draw(im).text((0, 0), char, font=self.font, fill=(255, 255, 255, 255))
        return im


def has_ink(im: Image.Image) -> bool:
    return im.getbbox() is not None


def sprite_name(char: str) -> str:
    # Hex codepoints, because the filesystem is case-insensitive: glyph_A.png
    # and glyph_a.png would be the same file and one letter would vanish.
    return f"glyph_{ord(char):04x}"


def render_preview(lines: list[str], src: Source, images: dict[str, Image.Image], scale: int) -> Image.Image:
    cell = src.cell_height + LEADING
    advance = src.cell_width + TRACKING
    width = max(len(line) for line in lines) * advance
    im = Image.new("RGBA", (width or 1, cell * len(lines)), (24, 20, 32, 255))
    for row, line in enumerate(lines):
        for column, char in enumerate(line):
            glyph = images.get(char)
            if glyph is not None:
                im.alpha_composite(glyph, (column * advance, row * cell))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--preview", type=pathlib.Path, help="render a sample sheet here")
    args = ap.parse_args()

    try:
        src = Source(SOURCE)
    except BuildError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    images = {char: src.glyph_image(char) for char in CHARS}
    metrics = [
        {
            "character": char,
            "sprite": sprite_name(char) if has_ink(images[char]) else None,
            "width": src.cell_width,
            "advance": src.cell_width + TRACKING,
        }
        for char in CHARS
    ]

    if args.preview:
        render_preview(
            [
                "00:00  12:34  ♦×9",
                "ABCDEFGHIJKLM",
                "NOPQRSTUVWXYZ",
                "abcdefghijklm",
                "nopqrstuvwxyz",
                "baking…",
                "♦×3  +150 coins",
                "Chocolate Chip (60%)",
            ],
            src,
            images,
            scale=4,
        ).save(args.preview)
        print(f"preview: {args.preview}")

    if args.check:
        print(
            f"validated {len(metrics)} glyphs from {SOURCE.name} "
            f"({src.cell_width}x{src.cell_height} cell)"
        )
        return 0

    atlas_dir = OUT / "Font.atlas"
    if atlas_dir.exists():
        shutil.rmtree(atlas_dir)
    atlas_dir.mkdir(parents=True, exist_ok=True)
    for entry in metrics:
        if entry["sprite"]:
            images[entry["character"]].save(atlas_dir / f"{entry['sprite']}.png")

    (OUT / "Font.json").write_text(
        json.dumps(
            {
                "$comment": f"Generated by tools/font/build_font.py from {SOURCE.name}. Do not hand-edit.",
                "atlas": "Font",
                "ascent": src.ascent,
                "descent": src.descent,
                "tracking": TRACKING,
                "leading": LEADING,
                "glyphs": metrics,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    # The chrome tier is the pack file itself -- no second build step to drift.
    shutil.copyfile(SOURCE, OUT / SOURCE.name)

    print(
        f"wrote {len(metrics)} glyphs to Font.atlas, Font.json, and {SOURCE.name} "
        f"({src.cell_width}x{src.cell_height} cell)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
