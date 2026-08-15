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

## Resolution — 16×16, decided

The pack ships at 16×16, 32×32, and 48×48. **The project standardizes on
16×16.** Do not mix resolutions; every atlas, every sprite, one tile size.

- 48×48 leaves only ~4 tiles across a portrait iPhone at ×2 — too cramped for a
  room with both a kitchen and a shop floor.
- 32×32 was the original choice and was **reversed**: at ×2 the fixtures read too
  large, and integer scaling gave no step between a 64pt tile and a 32pt one. The
  16×16 tier reaches the same 32pt tile at ×2 while keeping 48pt and 64pt
  available, so the room's size is tunable without breaking the uniform-pixel
  rule.
- Little real detail was given up. The 32×32 tier is largely the 16×16 art
  upscaled 2× with a light touch-up pass: the industrial oven strip is
  pixel-identical to a nearest-neighbour 2× of its 16×16 source, and the
  characters and treat singles differ by only 5–11% of their pixels.
- 16×16 does read chunkier, closer to the 8-bit look `01` warns against. That is
  the accepted cost of the smaller room.

At 16×16 with integer scale ×2 (1 art px = 2pt, tile = 32pt), a 393×852pt
portrait iPhone shows roughly **12 tiles wide × 26 tall**. That is a much larger
grid than the 6×13 the 32×32 build produced, so `05`'s fixture list — a 2-tile
oven, a prep counter, two seats — now sits in a noticeably emptier room. Filling
it out is open work, not a regression in the scaling helper.

Exact room dimensions and the scale factor per device class are resolved by the
scaling helper in `01`, not hardcoded here.

## Sheet layouts

Frame geometry is derived from image dimensions; these are measured, not assumed.

- **Character sheets** — `2_Characters/Character_Generator/**/16x16/`. Each sheet
  is 896×656, but the frames are **16 wide × 32 tall** — a character is one
  tile wide and two tall. That is a **56 × 20** frame grid filling the top
  896×640, plus a trailing 16px empty strip. **Slicing these at 16×16 cuts
  every character in half at the waist.** Row meanings are documented in
  `Spritesheet_animations_GUIDE.png`; read it before slicing.
  - Row 0 is a 4-frame standing pose, one per direction; rows 1–19 are the
    animations in guide order (idle, walk, sleep, sit, sit, phone, book, push
    cart, pick up, gift, lift, throw, then the combat set).
  - Each animation row is four equal column blocks running **right, up, left,
    down** — counter-clockwise from east. Verified against the gift row, where
    the held box sits right of the body in block 0 and left in block 2. Using
    the wrong order silently mirrors the baker.
  - Frames per direction vary by animation (idle and walk 6, pick up 12, lift
    and throw 14), so it is per-animation data, not a constant.
  - **Not every generator layer shares the sheet width.** The nine `Bodies`
    sheets and the four `Accessory_19_Party_Cone` sheets are 927 wide — not a
    multiple of 16 — while the premades and every other layer are a clean 896.
    Compositing across that mismatch misaligns the grid.
- **Animated objects** — horizontal frame strips whose frame size is the object's
  footprint, not one tile. Frame count = image width ÷ footprint width. Measured
  examples:
  - `animated_grocery_store_bakery_industrial_oven_up.png` — 128×48 =
    **4 frames of 32×48** (2 tiles wide, 3 tall).
  - `animated_canteen_fridge_cake_2.png` — 192×48 = **12 frames of 16×48**.
- **The 16×16 tier is missing some spritesheets the 32×32 tier ships.**
  `animated_canteen_fridge_cake_1` exists only as a GIF here, so the display case
  uses the `_2` variant — the same cabinet and frame count with a different cake
  inside. Check for a PNG before assuming a 32×32 filename has a 16×16 twin.
- Some animated-object filenames encode their loop range, e.g.
  `..._3-10 loop.png` means frames 3–10 are the loop and the earlier frames
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

**Resolved: the baker is a premade plus the chef hat.** The pack has no chef or
apron *outfit*, but it does have `Accessories/16x16/Accessory_18_Chef` — so a
premade alone never reads as a baker, and the full five-layer composite is not
needed either. A premade collapses BODY→EYES→OUTFIT→HAIRSTYLE, and the chef hat
lays over it on the same 896×656 grid. That makes the baker a **two-layer
composite**, listed in order in the atlas manifest and flattened at build time.

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
- **Resolved: use Shadowless.** The room is top-down and lit uniformly, depth
  comes from y-sorted `zPosition` (`05`), and treats composite into the display
  case (`08`) without a baked shadow darkening the shelf beneath them. Mixing
  shadow treatments in one room is immediately visible, so this is not a
  per-sprite call.
- **The variant is not a flag you can flip later.** Default and Shadowless share
  sprite numbering, but **Black_Shadow does not** — the grocery theme has
  489/490/483 singles across the three, and `Kitchen_..._214` is a bread loaf in
  two variants and carrots in the third. Moving to Black_Shadow means re-picking
  every sprite by eye, so the choice is made once, up front.
- Slicing is reproducible: `tools/atlas/build_atlases.py` regenerates every atlas
  from `assets/` against a declarative `manifest.json`. Hand-cropped PNGs pasted
  into the project would not survive the revisiting this slice will need.

## Licensing — binding constraints

From `assets/LICENSE.txt`:

- **Permitted:** edit and use the asset in any commercial or non-commercial
  project.
- **Prohibited:** reselling or distributing the asset to others, edited or not.
- **Required:** credit to `limezu.itch.io`.

Consequences for this repo:

- `assets/` is **gitignored and must stay that way.** Committing the pack to
  a public repo is redistribution.
- **Generated atlases are gitignored too.** An earlier draft of this spec said
  derived atlases were fine to commit; that reads against the licence text, which
  prohibits distributing the asset *"edited or not"* — a sliced atlas is still
  the asset. Shipping those pixels compiled into the app is ordinary permitted
  use; committing them as PNGs to a repo is closer to redistribution. Since the
  slice is reproducible anyway, treating `Resources/*.atlas/` as build artifacts
  costs nothing and removes the question. What is committed is
  `tools/atlas/manifest.json`, which holds coordinates and no pixels.
- Attribution must appear **in the shipped app** — the settings footer (`13`) is
  the natural home — and in App Store metadata.
- Anyone cloning this repo needs their own licensed copy of the pack. Say so in
  the README when one exists.

## Acceptance criteria

- [ ] Every in-world sprite in the app traces to a 16×16 pack asset or to art
      authored deliberately to fill one of the three named gaps.
- [ ] No 32×32 or 48×48 asset ships.
- [ ] Animated objects with an encoded loop range loop only that range.
- [ ] The baker is one pre-composited atlas, not runtime-layered.
- [ ] `assets/` is absent from `git ls-files`, and so is every generated atlas.
- [ ] `limezu.itch.io` attribution is present in-app and in store metadata.
- [x] Atlas generation is reproducible from the source pack —
      `tools/atlas/build_atlases.py`, driven by `manifest.json`.
- [x] Character frames are sliced at 16×32 on the 56×20 grid, with direction
      blocks in right/up/left/down order.

## Gotchas

- **The pack's `Singles` folders are per-object PNGs** (hundreds per theme) while
  `Theme_Sorter` sheets are packed grids. Singles are far easier to work with for
  fixtures; the packed sheets are better for floors and walls. Use both, and
  don't hand-crop from a packed sheet when a single already exists.
- Reaching for 32×32 "just for this one icon" breaks the uniform-pixel rule in
  `01` at its most load-bearing point. It is the likeliest slip here, because the
  32×32 tier was the project's original standard and older notes still name it.
- The pack being large invites browsing instead of building. The room layout is
  already solved by the ice-cream-shop reference — start there. Use
  `tools/atlas/contact_sheet.py` to find a sprite rather than opening folders;
  the singles are numbered, not named.
- **The reference layout does not fit the target aspect.** The ice-cream shop is
  12 tiles wide × 10 tall, but `01`'s ×2 scale on a portrait iPhone gives roughly
  12 wide × 26 tall. The width now matches; the depth does not. It is the right
  *composition* — prep at the back, case mid-room, seating at the front — but it
  has to be re-proportioned into a deeper room, not copied.
- The pack has no clean single chocolate-chip cookie, which `07` mandates as the
  starter recipe. The closest are the Christmas theme's cookie plates
  (`Christmas_SIngles_Shadowless_120..122` — the capital I is the pack's typo,
  and singles keep their numbering across resolution tiers). Worth a look before the
  recipe list is fixed.

## Open questions

- Which specific fixtures compose the final bakery room (a layout task, gated on
  the room dimensions from `01`).
- Which pack sprites represent the 5–6 recipes (`07`). `Treats.atlas` currently
  carries seven provisional picks; the set is not final.
- ~~Whether the baker is a premade character or a generated composite.~~
  Resolved: premade + chef-hat accessory, flattened at build time.
- ~~Whether atlas slicing is scripted or a one-time manual pass.~~ Resolved:
  scripted, in `tools/atlas/`.
