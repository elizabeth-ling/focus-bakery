#!/usr/bin/env python3
"""Regenerate the app's Xcode .atlas folders from the vendored Modern Interiors pack.

The pack is licensed and gitignored, so this reads from a local copy and writes
build artifacts that are themselves gitignored. Both the slice list and the
geometry live in manifest.json; nothing here hardcodes a sprite.

    python3 tools/atlas/build_atlases.py            # build everything
    python3 tools/atlas/build_atlases.py --check    # validate without writing
    python3 tools/atlas/build_atlases.py --only Baker
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import sys

from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = pathlib.Path(__file__).resolve().parent / "manifest.json"

# 14 standardizes on 32x32. The pack ships 16 and 48 next to it, so a wrong
# path is one character away and would silently break the uniform-pixel rule.
FORBIDDEN_RES = re.compile(r"(?:^|[/_])(16x16|48x48)(?:[/_.]|$)")

# Some animated objects encode their loop range in the filename. Both spellings
# occur in the pack: "..._3-10 loop_32x32.png" and "..._4_10_loop_32x32.png".
LOOP_PATTERNS = [
    re.compile(r"_(\d+)-(\d+)\s+loop_"),
    re.compile(r"_(\d+)_(\d+)_loop_"),
]


class BuildError(Exception):
    pass


def parse_loop_range(name: str) -> tuple[int, int] | None:
    for pat in LOOP_PATTERNS:
        m = pat.search(name)
        if m:
            return int(m.group(1)), int(m.group(2))
    return None


def load_source(pack_root: pathlib.Path, rel: str) -> Image.Image:
    if FORBIDDEN_RES.search(rel):
        raise BuildError(f"{rel}: 16x16/48x48 source rejected; the project is 32x32 only")
    path = pack_root / rel
    if not path.is_file():
        raise BuildError(f"missing source: {rel}")
    return Image.open(path).convert("RGBA")


def build_character(spec: dict, pack_root: pathlib.Path, tile: int) -> dict[str, Image.Image]:
    fw, fh = spec["frame"]
    if fw % tile or fh % tile:
        raise BuildError(f"frame {fw}x{fh} is not a whole number of {tile}px tiles")

    layers = [load_source(pack_root, rel) for rel in spec["layers"]]
    base = layers[0]
    sheet = Image.new("RGBA", base.size)
    for layer in layers:
        if layer.size != base.size:
            # Generator layers are not all the same width (some Bodies and the
            # Party_Cone accessory run 1854 wide against the usual 1792), so a
            # mismatch here means the layers do not share a frame grid.
            raise BuildError(
                f"layer size mismatch: {base.size} vs {layer.size}; layers must share one grid"
            )
        sheet.alpha_composite(layer)

    cols, rows = spec["grid"]
    if sheet.width < cols * fw or sheet.height < rows * fh:
        raise BuildError(
            f"sheet {sheet.size} too small for grid {cols}x{rows} of {fw}x{fh}"
        )

    dirs = spec["directions"]
    out: dict[str, Image.Image] = {}
    for anim, a in spec["animations"].items():
        row, per = a["row"], a["frames_per_direction"]
        if row >= rows:
            raise BuildError(f"{anim}: row {row} outside grid of {rows} rows")
        if per * len(dirs) > cols:
            raise BuildError(
                f"{anim}: {len(dirs)}x{per} frames exceed {cols} columns"
            )
        for d_i, direction in enumerate(dirs):
            for f in range(per):
                col = d_i * per + f
                box = (col * fw, row * fh, col * fw + fw, row * fh + fh)
                out[f"baker_{anim}_{direction}_{f:02d}"] = sheet.crop(box)
    return out


def build_strips(spec: dict, pack_root: pathlib.Path, tile: int) -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for name, entry in spec["entries"].items():
        rel = entry["path"]
        fw, fh = entry["frame"]
        im = load_source(pack_root, rel)
        if fw % tile or fh % tile:
            raise BuildError(f"{name}: frame {fw}x{fh} is not a whole number of {tile}px tiles")
        if im.width % fw or im.height != fh:
            raise BuildError(
                f"{name}: sheet {im.size} does not divide into {fw}x{fh} frames"
            )
        count = im.width // fw

        loop = entry.get("loop") or parse_loop_range(pathlib.PurePath(rel).name)
        if loop:
            start, end = loop
            # Filename ranges are 1-based and inclusive; earlier frames are a
            # one-shot intro. Looping the whole strip replays the intro forever.
            if not (1 <= start <= end <= count):
                raise BuildError(f"{name}: loop range {start}-{end} outside 1..{count}")
            indices = range(start - 1, end)
        else:
            indices = range(count)

        for out_i, src_i in enumerate(indices):
            box = (src_i * fw, 0, src_i * fw + fw, fh)
            out[f"{name}_{out_i:02d}"] = im.crop(box)
    return out


def build_singles(spec: dict, pack_root: pathlib.Path, tile: int) -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for name, rel in spec["entries"].items():
        im = load_source(pack_root, rel)
        if im.width % tile or im.height % tile:
            raise BuildError(
                f"{name}: {im.size} is not a whole number of {tile}px tiles"
            )
        out[name] = im
    return out


BUILDERS = {"character": build_character, "strips": build_strips, "singles": build_singles}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="validate only, write nothing")
    ap.add_argument("--only", action="append", help="build just this atlas (repeatable)")
    ap.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
    args = ap.parse_args()

    manifest = json.loads(args.manifest.read_text())
    pack_root = REPO / manifest["pack_root"]
    out_root = REPO / manifest["output_root"]
    tile = manifest["tile"]

    if not pack_root.is_dir():
        print(
            f"error: pack not found at {pack_root}\n"
            "The Modern Interiors pack is licensed and cannot be committed. Obtain\n"
            "your own copy from https://limezu.itch.io/moderninteriors and unpack the\n"
            f"full version into {pack_root}/.",
            file=sys.stderr,
        )
        return 2

    wanted = set(args.only) if args.only else None
    total = 0
    for name, spec in manifest["atlases"].items():
        if wanted and name not in wanted:
            continue
        builder = BUILDERS.get(spec["kind"])
        if builder is None:
            print(f"error: {name}: unknown kind {spec['kind']!r}", file=sys.stderr)
            return 1
        try:
            sprites = builder(spec, pack_root, tile)
        except BuildError as e:
            print(f"error: {name}: {e}", file=sys.stderr)
            return 1

        if args.check:
            print(f"  {name}.atlas  {len(sprites)} sprites (not written)")
        else:
            atlas_dir = out_root / f"{name}.atlas"
            if atlas_dir.exists():
                shutil.rmtree(atlas_dir)
            atlas_dir.mkdir(parents=True)
            for sprite_name, im in sorted(sprites.items()):
                im.save(atlas_dir / f"{sprite_name}.png")
            print(f"  {name}.atlas  {len(sprites)} sprites")
        total += len(sprites)

    verb = "validated" if args.check else "wrote"
    print(f"{verb} {total} sprites")
    if not args.check:
        print(
            "Generated atlases are build artifacts and are gitignored -- the pack's\n"
            "licence forbids redistributing the asset, edited or not."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
