# 01 — Pixel Rendering Pipeline

**Depends on:** 14 (for what the assets are). **Blocks:** everything visual.

Build this first and prove it before anything is layered on top. Every pixel on
screen must be the same size — this is the single most important constraint in
the project and it drives most other technical decisions.

## Goal

A rendering foundation where art authored at a small fixed resolution appears at
a uniform, crisp pixel size on every supported device, including all in-scene
text.

## Hard rules (non-negotiable)

1. **Integer scale factors only** (×2, ×3, ×4…). Never scale a 16px sprite by
   3.5 — some source pixels become 3 screen-pixels wide and others 4. This is
   the classic "why does my pixel art look wrong" bug.
2. **Nearest-neighbor everywhere.** `texture.filteringMode = .nearest` on every
   SpriteKit texture; `.interpolation(.none)` on every SwiftUI `Image`. Default
   linear filtering blurs edges and must never be left in place.
3. **Snap positions to the grid.** Round every sprite position to a whole grid
   unit.
4. **No sub-pixel animation.** Animate movement in whole grid units, never 0.5px
   tweens. Sub-pixel motion shimmers during movement.

## Layout model

**Fixed tile size, flexible room dimensions.** The scene is a full-screen
top-down room (`06`), not a half-screen panel, so the canvas is sized from the
tile grid rather than from an arbitrary virtual resolution.

- **Tile size is 32×32, fixed** (`14`). Every in-world asset is authored at this
  size; the grid unit is one tile.
- **Baseline scale is ×2** — 1 art pixel = 2 points, so one tile = 64pt. On a
  393×852pt portrait iPhone that yields roughly **6 tiles wide × 13 tall**.
- **Room dimensions flex with the device; the tile size never does.** Compute how
  many whole tiles fit the available area at the chosen integer scale, and lay
  the room out to that. A larger phone sees slightly more room, not bigger
  pixels.
- Absorb any sub-tile remainder as **letterbox / wall margin at the room edges**,
  never by stretching the scene or picking a fractional scale.
- **Chrome:** decide "1 art pixel = N screen points" and let its grid vary per
  device, so UI fits every iPhone size.
- Work in the **point** coordinate space with integer scaling. The @2x/@3x device
  difference is a constant factor across the whole screen, so pixels stay uniform
  within a given device automatically.

> This replaces the earlier ~256×224 fixed-canvas plan. 256×224 is 8×7 tiles at
> 32px — smaller than the reference bakery layout, and it assumed a fixed-camera
> panel rather than a full-screen room.

### Flexible rooms need a layout that tolerates them

Because the room's tile dimensions vary by device, fixture placement must be
expressed relative to anchors (back wall, case row, door) rather than as absolute
tile coordinates. Hardcoding "the oven is at tile (3, 2)" breaks on the next
screen size. See `05`.

## Text rendering

Three tiers exist; v1 uses two of them and keeps them physically apart.

| Tier | Use | Why |
|---|---|---|
| **Bitmap font** (glyph atlas drawn as sprites) | **All in-scene text**: timer digits, coin counts, ♦ quantities, "baking…" tag | Text becomes literally the same pixels as the art. Guaranteed uniform. This is what real pixel games do. |
| **Pixel TTF** via `.font(.custom(...))` | **Chrome only**: settings, menus | Convenient, not grid-perfect. Acceptable off-scene. |
| Pixel TTF rendered to a texture at exact native size | Not used in v1 | Crisp only if you hit native size exactly; the bitmap font is strictly better here. |

- **Never place crisp bitmap text beside antialiased system labels.** System text
  (`Text`, `SKLabelNode`) antialiases and sub-pixel-positions glyphs; the
  mismatch next to bitmap numbers is jarring. Keep the two tiers physically
  separated on screen.
- Grid-critical text must **never** go through `SKLabelNode`.

## Deliverables

- A scene-scaling helper that resolves available size → integer scale + room tile
  dimensions + edge insets.
- A texture-loading path that sets `filteringMode = .nearest` at load, so no call
  site can forget it.
- A bitmap-font glyph atlas plus a small layout routine that renders a string as
  sprite nodes at grid-snapped positions. **The asset pack contains no font**
  (`14`) — this must be authored or sourced. Aseprite handles bitmap-font export.
- A bundled pixel TTF wired up for chrome — also not in the pack.
- Atlases stored as Xcode `.atlas` folders, sliced from the pack per `14`.
- A movement primitive that steps sprites in whole art pixels, so rule 4 has an
  implementation and not just a prohibition — `05`'s walk choreography is built
  on it.

## Acceptance criteria

- [x] A bitmap `00:00` renders crisply, with visibly uniform pixel size, on at
      least three device sizes spanning the smallest and largest supported
      iPhones — verified by screenshot inspection at native resolution.
- [x] No texture in the app renders with linear filtering. Verifiable by
      inspection: every load path sets `.nearest`.
- [x] Every SwiftUI `Image` displaying pixel art uses `.interpolation(.none)`.
- [x] Scale factor is always a whole number; edge margin absorbs the remainder.
- [x] One tile measures exactly 32 art pixels everywhere in the app; no 16×16 or
      48×48 asset is used (`14`).
- [x] A sprite animated across the scene shows no shimmer — movement lands on
      whole grid units every frame.
- [x] No `SKLabelNode` is used for timer digits, coin counts, or ♦ quantities.

### How the first and sixth were checked

Both are "verified by looking", so `PixelProofView` exists to be looked at —
launch with `-pixelProof` and it renders the resolved room, `00:00`, and a baker
walking, and nothing else. It is temporary; `06` replaces it.

Screenshots were taken at native resolution on the **iPhone SE (3rd gen)**
(750×1334, @2x), **iPhone 16** (1179×2556, @3x) and **iPhone 16 Pro Max**
(1320×2868, @3x) — the ends of the supported range plus a middle, and both
device scale factors.

Eyeballing a screenshot proves less than it looks like it does, so the images
were also measured. In every one, each run of glyph ink is an exact multiple of
the block size (8px on the SE, 12px on the @3x devices for `00:00`), on both
axes, and the only colours present are the two source colours — interpolation
would have invented intermediate shades along every edge, and a fractional scale
would have made some runs one pixel wider than others. A burst of frames taken
while the baker crossed the room put its leading edge on the art-pixel grid in
every single frame.

The screenshots themselves are deliberately **not** committed: they contain pack
art, and `14`'s licence forbids redistributing it.

## Gotchas

- Guard this pipeline first. Every later feature inherits its correctness, and
  retrofitting uniform pixels is far more expensive than establishing them.
- Watch for **text tier bleed**: an `SKLabelNode` or system `Text` accidentally
  sitting next to bitmap numbers. Re-check this whenever scene layout changes.
- The early HTML prototype's 16×16 sprites with tiny palettes read as 8-bit/NES.
  The pack's 32×32 set is the 16-bit-era read the project wants — which is
  exactly why `14` forbids dropping to the 16×16 variant for convenience.
- **Mixed tile sizes are the new sharpest edge.** The pack ships three
  resolutions side by side, so grabbing a 16×16 icon "just this once" is a single
  wrong `cd` away, and it violates the uniform-pixel rule at its most
  load-bearing point.

## Open questions

- ~~Deployment target, which bounds the device sizes this must be proven
  against.~~ **Resolved: iOS 17.0, iPhone only, portrait only.** That makes the
  range the iPhone SE (375×667pt) through the 16 Pro Max (440×956pt), which is
  the span the criteria above were proven across. Answered first because the
  other two questions are arithmetic over this set.
- ~~Whether scale ×2 holds across every supported device or larger devices step
  to ×3.~~ **Resolved: ×2 everywhere.** ×3 is not rejected by arithmetic — a Pro
  Max fits 4×9 whole tiles at ×3 — but by what those tiles have to hold. A room
  needs a back of house and a front of house with a case row between them (`05`),
  and `PixelGrid.smallestUsefulRoom` puts the floor at 5×8. Every supported
  iPhone fails that at ×3 and clears it at ×2, so the resolver never reaches for
  ×3 and the design call collapses into the layout constraint. The candidate
  scales stay in the resolver because the answer is a consequence of the device
  set, not a constant — a larger canvas would legitimately step up.
- ~~Chrome's "1 art pixel = N points" constant.~~ **Resolved: N = 2**, matching
  the room. Chrome is free to differ, since the system lays it out and the two
  tiers are kept physically apart anyway — but a chrome pixel and a room pixel
  being different physical sizes on the same screen is exactly the mismatch the
  text-tier rule is about, and there is no reason to invite it. The chrome
  *grid* still varies with the device, which is what makes UI fit; only the pixel
  size is pinned.
  - The knock-on is that chrome text is a fixed size rather than Dynamic Type,
    because a fractional point size puts glyph edges between pixels. `13` owns
    whether accessibility sizes override that. It is a real trade-off, and it is
    the one open question this spec hands forward rather than closes.
