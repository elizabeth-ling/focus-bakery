# FocusPixel

The project's font. The Modern Interiors pack ships none (`14`) and spec `01`
needs two text tiers, so both are generated from one hand-authored source.

```sh
python3 tools/font/build_font.py                    # write all three outputs
python3 tools/font/build_font.py --check            # validate, write nothing
python3 tools/font/build_font.py --preview /tmp/f.png
```

Requires Pillow and fontTools.

| Output | Tier | Used by |
|---|---|---|
| `Resources/Font.atlas/glyph_*.png` | Bitmap | All in-scene text — timer, coins, ★ counts |
| `Resources/Font.json` | Bitmap | Glyph widths and advances |
| `Resources/FocusPixel.ttf` | Pixel TTF | SwiftUI chrome only |

One source means the two tiers cannot drift. Spec `01` keeps them physically
apart on screen, not because they differ in shape, but because the chrome tier
is laid out by the system and is not grid-perfect.

## Shape

5 wide × 7 tall above the baseline, plus two descender rows — a 9-row cell.
Uppercase and digits fill all seven rows; lowercase has a five-row x-height
starting at row 2. Glyph widths vary (`i` is 1, `★` is 7), **except digits,
which are all 5**: a timer whose digits change width jitters as it counts.

Every glyph PNG is the full 9-row cell, so in-scene layout aligns them all from
one common top edge instead of tracking a per-glyph offset.

## Why it is committed when the other atlases are not

`Resources/*.atlas/` is gitignored because slicing the licensed pack and
committing the result would be redistribution. This font contains none of
LimeZu's pixels — it is authored here — so `.gitignore` re-includes
`Font.atlas` explicitly. That also keeps the app buildable without Python.

## The TTF

`build_font.py` traces each glyph's ink into rectangles and writes a real
TrueType file with fontTools. One art pixel is 100 units and the em is the
whole 9-row cell (900 units), so a font size of **9 × N points renders one art
pixel as exactly N points** — which is what lets chrome pick a whole-number
scale the same way the room does. `ChromeFont` registers the file at runtime;
there is no `UIAppFonts` entry to keep in sync.
