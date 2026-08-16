#!/usr/bin/env python3
"""Authors the app's UI art into Resources/UI.atlas/.

The Modern Interiors pack ships no panels, frames or buttons (spec 14), so the
recipe-book modal's chrome (spec 10) and the main screen's overlay (spec 06) are
drawn here, pixel by pixel, in colours sampled from the pack's
Palettes/palette_interiors.png so they read as the same app. No pack pixels are
used or read -- the output is original art and is committed, unlike the
pack-derived atlases.

    python3 tools/ui/build_ui.py                # write Resources/UI.atlas/
    python3 tools/ui/build_ui.py --preview /tmp/ui.png

Requires Pillow. Deterministic: the same script always writes the same pixels.
"""

import argparse
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "Resources" / "UI.atlas"

# Every colour below was sampled from assets/Palettes/palette_interiors.png.
# Only the RGB values travel; the palette image itself is never read, so this
# script runs without the pack present.
PALETTE = {
    "K": (0x38, 0x1A, 0x08),  # darkest ink / outlines
    "k": (0x66, 0x45, 0x1E),  # warm ink for glyphs and page edges
    "P": (0xF0, 0xEF, 0xDE),  # paper
    "p": (0xEE, 0xE1, 0xB7),  # paper, aged
    "s": (0xE0, 0xD0, 0xB2),  # paper shade
    "d": (0xD0, 0xBE, 0x9C),  # paper deep shade
    "t": (0xB9, 0x9E, 0x86),  # thread / worn paper
    "L": (0x8E, 0x59, 0x5C),  # leather highlight
    "l": (0x84, 0x51, 0x56),  # leather
    "D": (0x6B, 0x38, 0x3B),  # leather dark (the cover)
    "G": (0xF8, 0xD2, 0x39),  # brass highlight
    "g": (0xF2, 0xB2, 0x2B),  # brass
    "o": (0xED, 0x93, 0x1E),  # brass shade
    "R": (0xD9, 0x32, 0x32),  # ribbon
    "r": (0xA8, 0x2B, 0x2D),  # ribbon shade
    # The tray's shadow on the room (06). The only translucent entries here, and
    # warm rather than neutral -- a grey shadow over the pack's floor art reads
    # as a rendering artefact rather than as something the tray is casting.
    "N": (0x38, 0x1A, 0x08, 0x8C),  # shadow, against the tray
    "n": (0x38, 0x1A, 0x08, 0x40),  # shadow, falling away
}


def rgba(key):
    if key == ".":
        return (0, 0, 0, 0)
    value = PALETTE[key]
    return value if len(value) == 4 else value + (255,)


class Canvas:
    def __init__(self, width, height):
        self.image = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    def put(self, x, y, key):
        if 0 <= x < self.image.width and 0 <= y < self.image.height:
            self.image.putpixel((x, y), rgba(key))

    def rect(self, x0, y0, x1, y1, key):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, key)

    def hline(self, x0, x1, y, key):
        self.rect(x0, y, x1, y, key)

    def vline(self, x, y0, y1, key):
        self.rect(x, y0, x, y1, key)

    def frame(self, x0, y0, x1, y1, key):
        self.hline(x0, x1, y0, key)
        self.hline(x0, x1, y1, key)
        self.vline(x0, y0, y1, key)
        self.vline(x1, y0, y1, key)

    def stamp(self, x, y, rows):
        for dy, row in enumerate(rows):
            for dx, key in enumerate(row):
                if key != ".":
                    self.put(x + dx, y + dy, key)


def rounded_panel(canvas, x0, y0, x1, y1, cut, outline, fill):
    """A rectangle with pixel-stepped corners: `cut` pixels are shaved off each
    corner row-by-row, which is how pixel art rounds without antialiasing."""
    for y in range(y0, y1 + 1):
        inset = 0
        if y - y0 < cut:
            inset = cut - (y - y0)
        if y1 - y < cut:
            inset = max(inset, cut - (y1 - y))
        canvas.hline(x0 + inset, x1 - inset, y, fill)
    # Outline traced along the same steps.
    for y in range(y0, y1 + 1):
        inset = 0
        if y - y0 < cut:
            inset = cut - (y - y0)
        if y1 - y < cut:
            inset = max(inset, cut - (y1 - y))
        canvas.put(x0 + inset, y, outline)
        canvas.put(x1 - inset, y, outline)
    canvas.hline(x0 + cut, x1 - cut, y0, outline)
    canvas.hline(x0 + cut, x1 - cut, y1, outline)


def plate(width=16, height=16):
    """The shared button plate: aged paper with an ink outline, the family every
    small control in the modal belongs to."""
    canvas = Canvas(width, height)
    rounded_panel(canvas, 0, 0, width - 1, height - 1, 2, "K", "p")
    # Top highlight and bottom shade, following the corner steps.
    canvas.hline(3, width - 4, 1, "P")
    canvas.put(2, 2, "P")
    canvas.put(width - 3, 2, "P")
    canvas.hline(3, width - 4, height - 2, "d")
    canvas.put(2, height - 3, "d")
    canvas.put(width - 3, height - 3, "d")
    return canvas


def glyph_minus(canvas):
    canvas.rect(5, 7, 10, 8, "k")


def glyph_plus(canvas):
    canvas.rect(5, 7, 10, 8, "k")
    canvas.rect(7, 5, 8, 10, "k")


def glyph_cross(canvas):
    for i in range(7):
        canvas.rect(4 + i, 4 + i, 5 + i, 5 + i, "k")
        canvas.rect(4 + i, 10 - i, 5 + i, 11 - i, "k")


def glyph_arrow(canvas, pointing_right):
    # A solid stepped triangle: flat edge behind, 2px tip in front.
    for i in range(6):
        inset = (i + 1) // 2
        x = 5 + i if pointing_right else 10 - i
        canvas.vline(x, 4 + inset, 11 - inset, "k")


# Eight teeth and a hole, drawn larger than the book's glyphs because this one
# sits over the room rather than on a page and has to read at a glance (06).
GEAR_ROWS = [
    "..kk..kk..",
    ".kkkkkkkk.",
    ".kkkkkkkk.",
    ".kkk..kkk.",
    "kkk....kkk",
    "kkk....kkk",
    ".kkk..kkk.",
    ".kkkkkkkk.",
    ".kkkkkkkk.",
    "..kk..kk..",
]


def glyph_gear(canvas):
    canvas.stamp(3, 3, GEAR_ROWS)


def build_icon(name, glyph):
    canvas = plate()
    glyph(canvas)
    return name, canvas


# The padlock that covers a locked recipe's treat, and the coin its price is
# quoted in (spec 10). Both are brass -- the same G/g/o the corner protectors
# use -- so the gold in the book is one metal. The pack has no lock or coin of
# its own, which is what settles where they come from.
LOCK_ROWS = [
    ".....KKKKKK.....",
    "....KGgoogGK....",
    "...KGgK..KgGK...",
    "...KGgK..KgGK...",
    "...KGgK..KgGK...",
    "...KGgK..KgGK...",
    "...KGgK..KgGK...",
    "..KKKKKKKKKKKK..",
    ".KGGGGGGGGGGgoK.",
    ".KGggggggggggoK.",
    ".KGgggKKKKgggoK.",
    ".KGgggKKKKgggoK.",
    ".KGggggKKggggoK.",
    ".KooooooooooooK.",
    "..KKKKKKKKKKKK..",
    "................",
]

COIN_ROWS = [
    "...KKKK...",
    "..KGGGGK..",
    ".KGGGGggK.",
    "KGGGgggggK",
    "KGGgggggoK",
    "KGggggggoK",
    "KGgggggooK",
    ".KggggooK.",
    "..KgoooK..",
    "...KKKK...",
]

# The streak (spec 09) beside the coin in the room's chrome (06). Fire rather
# than brass, so a day count and a coin count are never the same gold at a
# glance; the unlit state is the same sprite drained of colour, not a second
# asset, which is what keeps a streak of zero neutral rather than a scold (11).
FLAME_ROWS = [
    "....KK....",
    "...KRRK...",
    "..KRRRRK..",
    "..KRooRK..",
    ".KRooooRK.",
    ".KRoGGoRK.",
    "KRooGGooRK",
    "KRoGGGGoRK",
    "KRoGGGGoRK",
    "KRooGGooRK",
    ".KRooooRK.",
    "..KKKKKK..",
]


def build_stamped(name, rows):
    canvas = Canvas(len(rows[0]), len(rows))
    canvas.stamp(0, 0, rows)
    return name, canvas


def build_start_button():
    canvas = Canvas(112, 24)
    rounded_panel(canvas, 0, 0, 111, 23, 2, "K", "l")
    canvas.hline(3, 108, 1, "L")
    canvas.put(2, 2, "L")
    canvas.put(109, 2, "L")
    canvas.hline(3, 108, 22, "D")
    canvas.put(2, 21, "D")
    canvas.put(109, 21, "D")
    canvas.hline(2, 109, 21, "D")
    return "button_start", canvas


def build_buy_button():
    """The same plate as the start button, struck in brass: on a locked page the
    action is a purchase, and gold is what the lock and the coin are made of."""
    canvas = Canvas(112, 24)
    rounded_panel(canvas, 0, 0, 111, 23, 2, "K", "g")
    canvas.hline(3, 108, 1, "G")
    canvas.put(2, 2, "G")
    canvas.put(109, 2, "G")
    canvas.hline(3, 108, 22, "o")
    canvas.put(2, 21, "o")
    canvas.put(109, 21, "o")
    canvas.hline(2, 109, 21, "o")
    return "button_buy", canvas


def build_bake_button():
    """The room's one floating control (spec 06): the start button's leather cut
    round and stamped with a brass plus, so the thing that opens the recipe book
    is visibly the same object family as the button inside it."""
    canvas = Canvas(32, 32)
    rounded_panel(canvas, 0, 0, 31, 31, 5, "K", "l")

    # Bevel, following the corner steps: lit from above, shaded below.
    canvas.hline(6, 25, 1, "L")
    canvas.put(5, 2, "L")
    canvas.put(26, 2, "L")
    canvas.put(4, 3, "L")
    canvas.put(27, 3, "L")
    canvas.hline(6, 25, 30, "D")
    canvas.put(5, 29, "D")
    canvas.put(26, 29, "D")
    canvas.put(4, 28, "D")
    canvas.put(27, 28, "D")

    # The plus, in the same brass as the coin and the lock.
    canvas.rect(9, 14, 22, 17, "g")
    canvas.rect(14, 9, 17, 22, "g")
    canvas.hline(9, 22, 17, "o")
    canvas.vline(17, 9, 22, "o")
    canvas.hline(9, 22, 14, "G")
    canvas.vline(14, 9, 22, "G")
    return "button_bake", canvas


def build_stop_button():
    """The way out of a bake (spec 03), standing in the same slot as the "+".

    Paper rather than leather, and ink rather than brass: leaving a bake early
    is an escape hatch, not an invitation, and it must not compete with the oven
    for attention while a session runs."""
    canvas = Canvas(32, 32)
    rounded_panel(canvas, 0, 0, 31, 31, 5, "K", "p")
    canvas.hline(6, 25, 1, "P")
    canvas.put(5, 2, "P")
    canvas.put(26, 2, "P")
    canvas.hline(6, 25, 30, "d")
    canvas.put(5, 29, "d")
    canvas.put(26, 29, "d")
    for i in range(11):
        canvas.rect(9 + i, 9 + i, 12 + i, 12 + i, "k")
        canvas.rect(9 + i, 19 - i, 12 + i, 22 - i, "k")
    return "button_stop", canvas


def build_tray_edge():
    """The bottom edge of the tray that runs across the top of the screen (06).

    Only the edge is art. The tray's field is a flat fill, because the tray is
    as wide as the screen and a screen is not a whole number of art pixels
    across -- so the strip is stretched to fit, which is exact only because
    every column of it is identical. Read downwards: the leather catches the
    light as it rolls over the brass rail, an ink line finishes the tray, and
    two rows of shadow fall past it onto the room."""
    rows = ["L", "K", "G", "g", "g", "o", "K", "N", "n"]
    width = 8
    canvas = Canvas(width, len(rows))
    for y, key in enumerate(rows):
        canvas.hline(0, width - 1, y, key)
    return "tray_edge", canvas


def brass_corner(canvas, cx, cy, dx, dy):
    """A brass corner protector: an L of `size` px hugging the cover corner at
    (cx, cy), extending inwards along (dx, dy)."""
    size = 8
    for i in range(size):
        for j in range(size - i):
            x, y = cx + dx * j, cy + dy * i
            on_edge = i == 0 or j == 0
            tip = j == size - i - 1
            key = "o" if tip else ("G" if on_edge else "g")
            canvas.put(x, y, key)
    # Ink along the inner diagonal so the cap sits on the leather.
    for i in range(size):
        canvas.put(cx + dx * (size - i - 1), cy + dy * i, "K")


def build_book_page():
    width, height = 160, 240
    canvas = Canvas(width, height)

    # The cover: dark leather, pixel-rounded, with a bevel and an embossed line.
    rounded_panel(canvas, 0, 0, width - 1, height - 1, 3, "K", "D")
    canvas.hline(4, width - 5, 1, "L")
    canvas.vline(1, 4, height - 5, "L")
    canvas.frame(4, 4, width - 5, height - 5, "l")

    # Brass corner protectors, one per corner.
    brass_corner(canvas, 2, 2, 1, 1)
    brass_corner(canvas, width - 3, 2, -1, 1)
    brass_corner(canvas, 2, height - 3, 1, -1)
    brass_corner(canvas, width - 3, height - 3, -1, -1)

    # The stack of pages beneath the open one, peeking out bottom-right.
    page = (8, 8, 145, 223)
    canvas.vline(148, 12, 227, "s")
    canvas.hline(12, 148, 227, "s")
    canvas.vline(147, 10, 226, "p")
    canvas.hline(10, 147, 226, "p")

    # The page itself.
    canvas.rect(page[0], page[1], page[2], page[3], "P")
    canvas.frame(page[0], page[1], page[2], page[3], "k")

    # Binding: the page is stitched into the book along its left edge.
    for y in range(20, 216, 14):
        canvas.rect(11, y, 12, y + 3, "t")
        canvas.put(11, y + 4, "d")
        canvas.put(12, y - 1, "d")

    # Corner flourishes drawn in faded ink, inset from each page corner.
    for cx, dx in ((page[0] + 5, 1), (page[2] - 5, -1)):
        for cy, dy in ((page[1] + 5, 1), (page[3] - 5, -1)):
            canvas.hline(min(cx, cx + dx * 6), max(cx, cx + dx * 6), cy, "d")
            canvas.vline(cx, min(cy, cy + dy * 6), max(cy, cy + dy * 6), "d")
            canvas.put(cx + dx * 2, cy + dy * 2, "d")

    # A ribbon bookmark tucked under the top cover, hanging over the page.
    rx = 124
    canvas.rect(rx, 6, rx + 5, 29, "R")
    canvas.vline(rx, 6, 29, "r")
    canvas.hline(rx, rx + 5, 29, "r")
    # Forked tail: an inverted-V notch cut from the bottom.
    canvas.put(rx + 2, 29, ".")
    canvas.put(rx + 3, 29, ".")
    canvas.rect(rx + 2, 28, rx + 3, 28, ".")
    canvas.put(rx + 2, 27, "r")
    canvas.put(rx + 3, 27, "r")

    # Age spots, placed by hand where the eye expects wear: near edges, never
    # where content sits.
    for x, y in ((22, 30), (130, 200), (28, 208), (118, 26), (36, 118)):
        canvas.put(x, y, "p")
        canvas.put(x + 1, y, "p")
        canvas.put(x, y + 1, "s")

    return "book_page", canvas


def build_all():
    assets = [
        build_book_page(),
        build_icon("arrow_left", lambda c: glyph_arrow(c, False)),
        build_icon("arrow_right", lambda c: glyph_arrow(c, True)),
        build_icon("stepper_minus", glyph_minus),
        build_icon("stepper_plus", glyph_plus),
        build_icon("button_close", glyph_cross),
        build_icon("icon_gear", glyph_gear),
        build_start_button(),
        build_buy_button(),
        build_bake_button(),
        build_stop_button(),
        build_tray_edge(),
        build_stamped("lock_gold", LOCK_ROWS),
        build_stamped("coin", COIN_ROWS),
        build_stamped("icon_flame", FLAME_ROWS),
    ]
    return assets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", metavar="PATH", help="also write a contact sheet")
    args = parser.parse_args()

    OUTPUT.mkdir(parents=True, exist_ok=True)
    assets = build_all()
    for name, canvas in assets:
        canvas.image.save(OUTPUT / f"{name}.png")
        print(f"wrote {name}.png ({canvas.image.width}x{canvas.image.height})")

    if args.preview:
        scale = 3
        pad = 8
        width = max(c.image.width for _, c in assets) * scale + pad * 2
        height = sum(c.image.height * scale + pad for _, c in assets) + pad
        sheet = Image.new("RGBA", (width, height), (40, 40, 48, 255))
        y = pad
        for _, canvas in assets:
            scaled = canvas.image.resize(
                (canvas.image.width * scale, canvas.image.height * scale),
                Image.NEAREST,
            )
            sheet.alpha_composite(scaled, (pad, y))
            y += scaled.height + pad
        sheet.save(args.preview)
        print(f"wrote preview {args.preview}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
