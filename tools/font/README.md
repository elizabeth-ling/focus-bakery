# The font

The project's text. The Modern Interiors pack ships none (`14`) and spec `01`
needs two text tiers, so both come from one file in the
[Ultimate Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/):
**PxPlus IBM CGA**, an 8×8 pixel-outline TTF.

```sh
python3 tools/font/build_font.py                    # write all three outputs
python3 tools/font/build_font.py --check            # validate, write nothing
python3 tools/font/build_font.py --preview /tmp/f.png
```

Requires Pillow and fontTools, plus the pack unpacked to `assets/7_Fonts/`.

| Output | Tier | Used by |
|---|---|---|
| `Resources/Font.atlas/glyph_*.png` | Bitmap | All in-scene text — timer, coins, ♦ counts |
| `Resources/Font.json` | Bitmap | Glyph widths and advances |
| `Resources/PxPlus_IBM_CGA.ttf` | Pixel TTF | SwiftUI chrome only |

The chrome tier is a straight copy of the source file and the bitmap tier is
rasterized from that same file, so the two tiers cannot drift.

## Shape

An 8×8 cell: 7 rows above the baseline plus one descender row. **Monospaced** —
every glyph advances the full 8-pixel cell, which is what keeps a counting timer
from jittering, and it needs no tracking on top because the cell carries its own
right-hand gap.

Every glyph PNG is the full cell rather than trimmed ink. `BitmapTextNode` lays
glyphs out at `pen * scale` with no left-bearing, so trimming would shift any
glyph the font centres in its cell (`1`, `.`, `:`).

## Why ♦ and not ★

The pack has no star at any size — no U+2605, U+2606, U+2736 or U+2217 in any of
its 361 pixel-outline fonts. `♦` stands in for ★ quantities. Every other
character the app draws is present.

## Why `PxPlus_` and not `Px437_`

`Px437_*` is code page 437 only and is missing `×`, `…` **and** `★`. `PxPlus_*`
is the extended charset (781 codepoints) and covers everything the app needs bar
the star.

## Why the Px set and not the bitmap folders

The pack's actual bitmap formats are dead ends on Apple platforms: `.FON` is a
Windows NE executable, `.otb` is X11 bitmap-only OpenType with no outlines, and
`.woff` is web-only — CoreText loads none of them. `ttf - Mx` carries real
`EBDT`/`EBLC` strikes but CoreText won't use monochrome ones, so it renders as
its outlines anyway in a larger file. `ttf - Ac` is aspect-corrected: non-square
pixels (`A` advances 6.66px), which breaks the whole-pixel grid outright.

None of that costs anything, because the `Px` outlines are drawn as literal
pixel rectangles — one art pixel is exactly 100 font units and the em is the
full cell, so rasterizing at `ppem = unitsPerEm/100` is bit-exact rather than a
resampling. It comes out pure 1-bit, no antialiasing.

That same convention is why a chrome font size of **8 × N points renders one art
pixel as exactly N points**, which is what lets chrome pick a whole-number scale
the way the room does. `ChromeFont` registers the file at runtime; there is no
`UIAppFonts` entry to keep in sync.

`build_font.py` derives all of this from the file rather than hardcoding it, so
pointing `SOURCE` at another `Px` font should just work — it will refuse one
whose em is not a whole number of pixels, or whose advances vary.

## Licensing

CC BY-SA 4.0, which permits redistribution with attribution — so unlike the art
pack, the font and its atlas **are** committed. The atlas is an adaptation and
carries the same licence. See `NOTICE.md`.
