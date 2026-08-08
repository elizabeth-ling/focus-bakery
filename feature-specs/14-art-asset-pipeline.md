# 14 — Art Asset Pipeline

**Depends on:** nothing. **Blocks:** 01, 05, 06, 08, 10.

Foundational alongside `01`. Read both before writing any rendering code — `01`
governs *how* pixels are scaled, this spec governs *what* pixels exist and where
they come from.

## The pack

All in-world art comes from **Modern Interiors** by **LimeZu** (full version),
vendored at `assets/`. This replaces the original plan of authoring the
bakery art from scratch, and it is the single biggest change to the project's
shape: **art is no longer the critical path.**

The pack is top-down, which is why the main screen is now a single top-down room
rather than a side-on workbench scene (`06`).

| Directory | Contents | Used for |
|---|---|---|
| `1_Interiors/` | Tilesheets + `Room_Builder` (walls, floors); `Theme_Sorter` splits by theme | Room construction, fixtures |
| `2_Characters/` | Layered character generator + 20 premades | The baker sprite |
| `3_Animated_objects/` | Frame-strip spritesheets + gif previews | Ovens, display cases, ambience |
| `4_User_Interface_Elements/` | Emotes, speech bubbles, arrows | In-world emotes only — **not** a UI kit |
| `6_Home_Designs/` | Finished room layouts, layered | Reference / starting layouts |
| `Palettes/` | The pack's palette | Any art authored to match |

### Directly relevant themes

`Theme_Sorter` includes `12_Kitchen`, `16_Grocery_store`, and
`24_Ice_Cream_Shop`. Between them they cover the entire bakery: ovens, prep
counters, glass display cases with fillable slots, pastries, and café seating.

`6_Home_Designs/Ice-Cream_Shop_Designs/` is a finished 12×10-tile shop —
prep/oven area at the back, glass case mid-room, seating at the front. **Use it
as the layout reference for the bakery.** It is nearly the target composition
already.

## Resolution — 32×32, decided

The pack ships at 16×16, 32×32, and 48×48. **The project standardizes on
32×32.** Do not mix resolutions; every atlas, every sprite, one tile size.

- 16×16 reads as 8-bit/NES, which `01` explicitly warns against.
- 48×48 leaves only ~4 tiles across a portrait iPhone at ×2 — too cramped for a
  room with both a kitchen and a shop floor.

At 32×32 with integer scale ×2 (1 art px = 2pt, tile = 64pt), a 393×852pt
portrait iPhone shows roughly **6 tiles wide × 13 tall** — a narrow, deep
bakery, which suits the back-of-house / front-of-house split (`06`).

Exact room dimensions and the scale factor per device class are resolved by the
scaling helper in `01`, not hardcoded here.

## Sheet layouts

Frame geometry is derived from image dimensions; these are measured, not assumed.

- **Character sheets** — `2_Characters/Character_Generator/**/32x32/`. Each sheet
  is 1792×1312 = **56 × 41 frames of 32×32**. Row meanings are documented in
  `Spritesheet_animations_GUIDE.png`; read it before slicing. Each animation runs
  4 directions (down, up, left, right).
- **Animated objects** — horizontal frame strips whose frame size is the object's
  footprint, not one tile. Frame count = image width ÷ footprint width. Measured
  examples:
  - `animated_grocery_store_bakery_industrial_oven_up_32x32.png` — 256×96 =
    **4 frames of 64×96** (2 tiles wide, 3 tall).
  - `animated_canteen_fridge_cake_1_32x32.png` — 384×96 = **12 frames of 32×96**.
- Some animated-object filenames encode their loop range, e.g.
  `..._3-10 loop_32x32.png` means frames 3–10 are the loop and the earlier frames
  are a one-shot intro. **Honor this** — looping the whole strip plays the intro
  on repeat and looks wrong. Note the space in those filenames.

## The baker sprite

Composite from `2_Characters/Character_Generator/` in this exact order (from
`CHARACTER_GENERATOR.txt`):

**BODY → EYES → OUTFIT → HAIRSTYLE → ACCESSORY**

For v1, a **single pre-composited baker** is sufficient — flatten one character
to an atlas at build time rather than compositing five layers at runtime. Player
character customization is out of scope; if it ever lands, the layer order above
is what makes it possible, so do not flatten in a way that discards it.

### There is no baking animation — plan around it

The character sheets contain: idle, walk, sleep, sit (two variants), phone, read,
push cart, pick up, gift, lift, throw, and a set of combat animations. **There is
no mixing, kneading, or cooking animation**, and the combat set is unusable for
this product.

This invalidates the original "working / mixing" sprite state. The resolution
(detailed in `05`): **the animated objects carry the baking motion** — the oven
strip runs while a session is in progress — and the baker plays a loop assembled
from `pick up` / `lift` / `walk` at the station. The room animates, not just the
sprite, which reads better than a single looping character anyway.

Do not commission or author a custom mixing animation for v1. If the loop feels
thin in testing, that is a finding to raise, not a licence to open an art
project.

## What the pack does NOT provide

Three gaps. Everything here still has to be authored or sourced, and this is now
the *entire* art budget for v1:

1. **A font.** There is no TTF or bitmap font anywhere in the pack. `01`'s
   bitmap-font atlas and the chrome pixel TTF are both still to-do.
2. **UI chrome.** `4_User_Interface_Elements/` is emotes, speech bubbles, and
   pointer arrows — there are no panels, frames, buttons, or 9-slice borders. The
   recipe-book modal (`10`), settings (`13`), and all chrome need their own art.
3. **App icon and marketing assets.**

Anything authored to fill these gaps must match `Palettes/palette_interiors.png`
so it doesn't read as bolted on.

## Atlas & build conventions

- Slice from the pack into **Xcode `.atlas` folders** grouped by purpose
  (`Baker.atlas`, `Bakery.atlas`, `Treats.atlas`, `Font.atlas`), not by pack
  directory. The pack's organization is a source layout, not a runtime one.
- Ship only the sprites actually used. The pack is large; bundling it wholesale
  bloats the app for no benefit.
- Every texture loads through the single `.nearest` path from `01`. No
  exceptions, no call site opting out.
- Prefer the **Shadowless** or **Black_Shadow** theme variants consistently —
  mixing shadow treatments in one room is immediately visible.
- Slicing should be reproducible. A script that regenerates atlases from
  `assets/` beats hand-cropped PNGs pasted into the project, because the
  slice will need revisiting.

## Licensing — binding constraints

From `assets/LICENSE.txt`:

- **Permitted:** edit and use the asset in any commercial or non-commercial
  project.
- **Prohibited:** reselling or distributing the asset to others, edited or not.
- **Required:** credit to `limezu.itch.io`.

Consequences for this repo:

- `assets/` is **gitignored and must stay that way.** Committing the pack to
  a public repo is redistribution. Sliced, derived atlases used by the app are
  fine; the source pack is not.
- Attribution must appear **in the shipped app** — the settings footer (`13`) is
  the natural home — and in App Store metadata.
- Anyone cloning this repo needs their own licensed copy of the pack. Say so in
  the README when one exists.

## Acceptance criteria

- [ ] Every in-world sprite in the app traces to a 32×32 pack asset or to art
      authored deliberately to fill one of the three named gaps.
- [ ] No 16×16 or 48×48 asset ships.
- [ ] Animated objects with an encoded loop range loop only that range.
- [ ] The baker is one pre-composited atlas, not runtime-layered.
- [ ] `assets/` is absent from `git ls-files`.
- [ ] `limezu.itch.io` attribution is present in-app and in store metadata.
- [ ] Atlas generation is reproducible from the source pack.

## Gotchas

- **The pack's `Singles` folders are per-object PNGs** (hundreds per theme) while
  `Theme_Sorter` sheets are packed grids. Singles are far easier to work with for
  fixtures; the packed sheets are better for floors and walls. Use both, and
  don't hand-crop from a packed sheet when a single already exists.
- Reaching for 16×16 "just for this one icon" breaks the uniform-pixel rule in
  `01` at its most load-bearing point.
- The pack being large invites browsing instead of building. The room layout is
  already solved by the ice-cream-shop reference — start there.

## Open questions

- Which specific fixtures compose the final bakery room (a layout task, gated on
  the room dimensions from `01`).
- Which pack sprites represent the 5–6 recipes (`07`).
- Whether the baker is a premade character or a generated composite.
- Whether atlas slicing is scripted or a one-time manual pass — scripted is
  preferred above, but the cost hasn't been assessed.
