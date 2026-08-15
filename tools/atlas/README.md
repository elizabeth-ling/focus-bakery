# Atlas pipeline

Slices the vendored Modern Interiors pack into Xcode `.atlas` folders.

```sh
python3 tools/atlas/build_atlases.py           # write Resources/*.atlas
python3 tools/atlas/build_atlases.py --check   # validate geometry, write nothing
python3 tools/atlas/build_atlases.py --only Baker
```

Requires Pillow. What gets sliced lives in `manifest.json`; the script hardcodes
no sprite.

## Why the output is gitignored

The pack licence forbids distributing the asset "edited or not". A sliced atlas
is still the asset, so committing `Resources/*.atlas/` to a repo would be
redistribution. Shipping those same pixels compiled into the app is fine — that
is ordinary use, which the licence permits.

So the atlases are build artifacts. `manifest.json` holds only paths and
coordinates, no pixels, which is what makes the slice reproducible without
redistributing anything. Anyone building this app needs their own licensed copy
of the pack from <https://limezu.itch.io/moderninteriors>, unpacked to `assets/`.

## Measured geometry

Everything below was measured from the pack at **16×16**, the tier the project
standardizes on. Every number here halved when the project moved off 32×32. Two of
these contradict what `feature-specs/14-art-asset-pipeline.md` originally said;
both are now corrected there.

### Character sheets are 16×32, not 16×16

A sheet is 896×656, but the frames are **16 wide × 32 tall** — a character is
one tile wide and two tall. That gives a **56 × 20** frame grid filling the top
896×640, plus a trailing 16px empty strip. Slicing at 16×16 cuts every
character in half at the waist.

Row 0 is a 4-frame standing pose, one per direction. Rows 1–19 are the
animations, in the order drawn in `Spritesheet_animations_GUIDE.png`: idle, walk,
sleep, sit, sit, phone, book, push cart, pick up, gift, lift, throw, hit, punch,
stab, grab gun, gun idle, shoot, hurt.

### Direction blocks run right, up, left, down

Each animation row is four equal column blocks, counter-clockwise from east:
**right, up, left, down** — not the spec's original "down, up, left, right".

Verified with the gift row, where the held box sits on the right of the body in
block 0 and the left in block 2; block 1 is the only back-of-head view and block
3 the only two-eyed frontal one. Getting this wrong silently mirrors the baker.

Frames per direction vary by animation — idle and walk are 6, pick up is 12,
lift and throw are 14 — so it is per-animation data in the manifest, not a
constant.

### Generator layers do not all share the sheet width

Most layers are 896 wide, but the nine `Bodies` sheets and the four
`Accessory_19_Party_Cone` sheets are **927** — not a multiple of 16, carrying
two extra frames past the 56-column grid. The premade characters are all a clean
896. The builder rejects a layer whose size differs from the base rather than
compositing a misaligned grid.

### Animated objects are frame strips of the object's footprint

Frame size is the object's footprint, not one tile, and it is not derivable from
the filename — so the manifest states it and the builder checks that the sheet
divides evenly.

| Sheet | Size | Frames |
|---|---|---|
| `..._bakery_industrial_oven_up.png` | 128×48 | 4 × 32×48 |
| `..._canteen_fridge_cake_2.png` | 192×48 | 12 × 16×48 |

Some filenames encode a loop range — `..._3-10 loop.png` means frames 3–10
loop and the earlier ones are a one-shot intro. Both spellings occur (`3-10 loop`
with a space and a dash, `4_10_loop` with underscores) and the builder parses
each. **No sprite currently in the manifest uses one**; every loop-range file in
the pack is a bathroom fixture. The support is there so the rule is not
rediscovered later.

The 16×16 tier does not ship every spritesheet the 32×32 tier does.
`animated_canteen_fridge_cake_1` exists here only as a GIF, which the builder
does not read, so the display case slices the `_2` variant — same cabinet, same
12 frames, different cake. Check for a PNG before assuming a sheet has a 16×16
twin.

## Shadow variants are not interchangeable

The pack ships each theme as default, `Black_Shadow`, and `Shadowless`. The
project uses **Shadowless**: the room is top-down and lit uniformly, depth comes
from y-sorted `zPosition` (`05`), and treats composite into the display case
(`08`) without a baked shadow darkening the shelf under them.

This is not a flag you can flip later. Default and Shadowless share sprite
numbering, but **Black_Shadow does not** — grocery has 489/490/483 singles across
the three, and `Kitchen_..._214` is a bread loaf in two variants and carrots in
the third. Switching to Black_Shadow means re-picking every sprite by eye.

Directory naming is also inconsistent between variants, so glob carefully:
`12_Kitchen_Singles_Shadowless` vs `12_Kitchen_Black_Shadow_Singles` (word order
swaps), files inside the latter are prefixed `Kitchen_Shadow_Singles_` (not
`Kitchen_Black_Shadow_Singles_`), and several folders are typo'd `SIngles`.
The 16×16 tier also drops the `_16x16` suffix the 32×32 tier puts on every
directory and filename, so a path cannot be converted between tiers by
search-and-replace.

## Browsing the pack

`contact_sheet.py` renders a labelled grid of a directory so sprites can be
chosen by eye. The singles have no semantic names — they are numbered — so this
is the only practical way to find a specific object.

```sh
python3 tools/atlas/contact_sheet.py \
  "assets/1_Interiors/16x16/Theme_Sorter_Shadowless_Singles/12_Kitchen_Singles_Shadowless" \
  -o /tmp/kitchen.png --cols 16 --start 0 --limit 200
```

Its labels are positions in the listing, not the numbers in the filenames. Map
back before putting a path in the manifest.
