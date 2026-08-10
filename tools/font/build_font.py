#!/usr/bin/env python3
"""Build the FocusPixel bitmap atlas, its metrics, and the chrome TTF.

Spec 01 needs two text tiers and the art pack ships neither (14). Both come out
of glyphs.py here, so the in-scene bitmap text and the chrome font are the same
font by construction rather than by discipline.

    python3 tools/font/build_font.py                  # write all three outputs
    python3 tools/font/build_font.py --check          # validate, write nothing
    python3 tools/font/build_font.py --preview /tmp/f.png

Outputs (Resources/): Font.atlas/*.png, Font.json, FocusPixel.ttf.
Requires Pillow and fontTools.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from glyphs import ASCENT, DESCENT, GLYPHS, LEADING, TRACKING  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "Resources"

FAMILY = "FocusPixel"
POSTSCRIPT_NAME = "FocusPixel-Regular"
VERSION = "1.000"

# TTF units per art pixel. The em is the full 9-row cell, so a chrome font size
# of 9 x N points renders one art pixel as exactly N points.
UNITS_PER_PIXEL = 100
UPEM = (ASCENT + DESCENT) * UNITS_PER_PIXEL

INK = "#"
BLANK = "."


class BuildError(Exception):
    pass


def validate(char: str, rows: list[str]) -> int:
    if len(rows) not in (ASCENT, ASCENT + DESCENT):
        raise BuildError(
            f"{char!r}: {len(rows)} rows; expected {ASCENT}, or {ASCENT + DESCENT} to descend"
        )
    width = len(rows[0])
    if width == 0:
        raise BuildError(f"{char!r}: zero width")
    for i, row in enumerate(rows):
        if len(row) != width:
            raise BuildError(f"{char!r}: row {i} is {len(row)} wide, glyph is {width}")
        if set(row) - {INK, BLANK}:
            raise BuildError(f"{char!r}: row {i} has characters outside {INK!r}{BLANK!r}")
    return width


def padded(rows: list[str], width: int) -> list[str]:
    """Every glyph image is the full ascent+descent cell, so in-scene layout
    places them all from one common top edge."""
    return list(rows) + [BLANK * width] * (ASCENT + DESCENT - len(rows))


def glyph_image(rows: list[str], width: int) -> Image.Image:
    im = Image.new("RGBA", (width, ASCENT + DESCENT), (0, 0, 0, 0))
    pixels = im.load()
    for y, row in enumerate(padded(rows, width)):
        for x, cell in enumerate(row):
            if cell == INK:
                pixels[x, y] = (255, 255, 255, 255)
    return im


def sprite_name(char: str) -> str:
    # Hex codepoints, because the filesystem is case-insensitive: glyph_A.png
    # and glyph_a.png would be the same file and one letter would vanish.
    return f"glyph_{ord(char):04x}"


def runs(row: str) -> list[tuple[int, int]]:
    """Maximal horizontal ink runs, as (start, end-exclusive)."""
    out: list[tuple[int, int]] = []
    start = None
    for x, cell in enumerate(row):
        if cell == INK and start is None:
            start = x
        elif cell != INK and start is not None:
            out.append((start, x))
            start = None
    if start is not None:
        out.append((start, len(row)))
    return out


def build_ttf(metrics: list[dict], path: pathlib.Path) -> None:
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen

    def pen_for(rows: list[str], width: int) -> TTGlyphPen:
        pen = TTGlyphPen(None)
        for y, row in enumerate(padded(rows, width)):
            # Row 0 sits at the top of the ascent; the baseline is under row
            # ASCENT-1, so descender rows land below y=0 as they should.
            bottom = (ASCENT - y - 1) * UNITS_PER_PIXEL
            top = bottom + UNITS_PER_PIXEL
            for x0, x1 in runs(row):
                left, right = x0 * UNITS_PER_PIXEL, x1 * UNITS_PER_PIXEL
                # Clockwise, which is the filled direction for TrueType.
                pen.moveTo((left, bottom))
                pen.lineTo((left, top))
                pen.lineTo((right, top))
                pen.lineTo((right, bottom))
                pen.closePath()
        return pen

    order = [".notdef"]
    outlines = {".notdef": TTGlyphPen(None).glyph()}
    hmtx = {".notdef": (5 * UNITS_PER_PIXEL, 0)}
    cmap: dict[int, str] = {}

    for entry in metrics:
        char = entry["character"]
        name = f"uni{ord(char):04X}"
        order.append(name)
        outlines[name] = pen_for(GLYPHS[char], entry["width"]).glyph()
        hmtx[name] = (entry["advance"] * UNITS_PER_PIXEL, 0)
        cmap[ord(char)] = name

    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(outlines)
    fb.setupHorizontalMetrics(hmtx)
    fb.setupHorizontalHeader(
        ascent=ASCENT * UNITS_PER_PIXEL,
        descent=-DESCENT * UNITS_PER_PIXEL,
        lineGap=UNITS_PER_PIXEL,
    )
    fb.setupNameTable(
        {
            "familyName": FAMILY,
            "styleName": "Regular",
            "uniqueFontIdentifier": f"{FAMILY};{VERSION}",
            "fullName": FAMILY,
            "psName": POSTSCRIPT_NAME,
            "version": f"Version {VERSION}",
            "copyright": "Focus Bakery. Authored for this project.",
        }
    )
    fb.setupOS2(
        sTypoAscender=ASCENT * UNITS_PER_PIXEL,
        sTypoDescender=-DESCENT * UNITS_PER_PIXEL,
        sTypoLineGap=UNITS_PER_PIXEL,
        usWinAscent=ASCENT * UNITS_PER_PIXEL,
        usWinDescent=DESCENT * UNITS_PER_PIXEL,
        sxHeight=5 * UNITS_PER_PIXEL,
        sCapHeight=ASCENT * UNITS_PER_PIXEL,
        achVendID="FBKY",
    )
    fb.setupPost(isFixedPitch=0)
    fb.save(path)


def render_preview(lines: list[str], metrics: dict[str, dict], scale: int) -> Image.Image:
    cell = ASCENT + DESCENT + LEADING
    widths = [sum(metrics[c]["advance"] for c in line if c in metrics) for line in lines]
    im = Image.new("RGBA", (max(widths) or 1, cell * len(lines)), (24, 20, 32, 255))
    for row, line in enumerate(lines):
        x = 0
        for char in line:
            entry = metrics.get(char)
            if entry is None:
                continue
            if entry["sprite"]:
                im.alpha_composite(glyph_image(GLYPHS[char], entry["width"]), (x, row * cell))
            x += entry["advance"]
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--preview", type=pathlib.Path, help="render a sample sheet here")
    args = ap.parse_args()

    metrics = []
    try:
        for char, rows in GLYPHS.items():
            width = validate(char, rows)
            inked = any(INK in row for row in rows)
            metrics.append(
                {
                    "character": char,
                    "sprite": sprite_name(char) if inked else None,
                    "width": width,
                    "advance": width + TRACKING,
                }
            )
    except BuildError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    by_char = {m["character"]: m for m in metrics}
    if args.preview:
        render_preview(
            [
                "00:00  12:34  ★×9",
                "ABCDEFGHIJKLM",
                "NOPQRSTUVWXYZ",
                "abcdefghijklm",
                "nopqrstuvwxyz",
                "baking…",
                "★×3  +150 coins",
                "Chocolate Chip Cookie (60%)",
            ],
            by_char,
            scale=4,
        ).save(args.preview)
        print(f"preview: {args.preview}")

    if args.check:
        print(f"validated {len(metrics)} glyphs")
        return 0

    atlas_dir = OUT / "Font.atlas"
    if atlas_dir.exists():
        shutil.rmtree(atlas_dir)
    atlas_dir.mkdir(parents=True, exist_ok=True)
    for entry in metrics:
        if entry["sprite"]:
            glyph_image(GLYPHS[entry["character"]], entry["width"]).save(
                atlas_dir / f"{entry['sprite']}.png"
            )

    (OUT / "Font.json").write_text(
        json.dumps(
            {
                "$comment": "Generated by tools/font/build_font.py from glyphs.py. Do not hand-edit.",
                "atlas": "Font",
                "ascent": ASCENT,
                "descent": DESCENT,
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

    build_ttf(metrics, OUT / f"{FAMILY}.ttf")

    print(f"wrote {len(metrics)} glyphs to Font.atlas, Font.json, and {FAMILY}.ttf")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
