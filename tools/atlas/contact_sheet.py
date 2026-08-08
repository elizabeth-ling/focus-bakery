#!/usr/bin/env python3
"""Render a labelled contact sheet of pack singles so sprites can be chosen by eye.

Browsing aid only — nothing it writes is shipped. See tools/atlas/README.md.
"""
import argparse
import pathlib
import re
import sys

from PIL import Image, ImageDraw

BG = (58, 58, 68, 255)
GRID = (90, 90, 105, 255)
LABEL = (235, 235, 240, 255)


def natural_key(p: pathlib.Path):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", p.name)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("directory", type=pathlib.Path)
    ap.add_argument("-o", "--out", type=pathlib.Path, required=True)
    ap.add_argument("--cols", type=int, default=16)
    ap.add_argument("--cell", type=int, default=64, help="cell size in source px")
    ap.add_argument("--scale", type=int, default=2)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    files = sorted(
        (p for p in args.directory.iterdir() if p.suffix.lower() == ".png"),
        key=natural_key,
    )
    if args.limit:
        files = files[args.start : args.start + args.limit]
    else:
        files = files[args.start :]
    if not files:
        print(f"no PNGs in {args.directory}", file=sys.stderr)
        return 1

    cell, cols = args.cell, args.cols
    pad = 12  # room for the index label under each cell
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + pad)), BG)
    draw = ImageDraw.Draw(sheet)

    for i, f in enumerate(files):
        cx, cy = (i % cols) * cell, (i // cols) * (cell + pad)
        draw.rectangle([cx, cy, cx + cell - 1, cy + cell - 1], outline=GRID)
        im = Image.open(f).convert("RGBA")
        if im.width > cell or im.height > cell:
            im.thumbnail((cell, cell), Image.NEAREST)
        # bottom-centre anchor: these are top-down objects standing on the floor
        sheet.alpha_composite(im, (cx + (cell - im.width) // 2, cy + cell - im.height))
        draw.text((cx + 2, cy + cell), str(args.start + i), fill=LABEL)

    sheet = sheet.resize(
        (sheet.width * args.scale, sheet.height * args.scale), Image.NEAREST
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print(f"{args.out}  {sheet.size[0]}x{sheet.size[1]}  {len(files)} sprites "
          f"(index {args.start}..{args.start + len(files) - 1})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
