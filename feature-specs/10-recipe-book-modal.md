# 10 — Recipe-Book Timer Modal

**Depends on:** 01, 07, 14. **Blocks:** nothing.

The entry point to every session, and one of the two places the craft bar is most
visible.

> **This screen is now the largest remaining art task in the project.** The asset
> pack covers the bakery world but contains **no UI panels, frames, or buttons** —
> `4_User_Interface_Elements/` is emotes and speech bubbles (`14`). The recipe
> book's cover, page, arrows, and stepper controls must all be authored, in the
> pack's palette so they read as the same app. Budget for it: with world art
> solved, this and the font (`01`) are what's left.
>
> **Authored.** `tools/ui/build_ui.py` draws the book — leather cover, brass
> corner protectors, stitched page, ribbon bookmark — and the arrow/stepper/
> button family into `Resources/UI.atlas/`, every colour sampled from the
> pack's palette. The atlas is committed (it is original art, not pack pixels),
> so the app builds without Python. What remains of the art budget is settings
> chrome (`13`) and the app icon.

## Goal

Tapping "+" opens a modal **styled as an old grandma's recipe book**, where you
pick a recipe and set a duration, then start baking.

## Layout

- Presented from the "+" button on the main screen (`06`).
- **Left / right arrows beside the baked-good image** to choose a recipe.
- **Below it, a duration number with "−" and "+" buttons.**
- A clear start action that dismisses the modal and returns to the main screen
  with the sprite now working (`05`).

The recipe-book styling is the point — this is not a generic picker sheet with a
skin. The arrows-around-an-image pattern is deliberate and should feel like
turning pages.

The baked-good images themselves are pack treat sprites (`07`, `14`), shown at an
integer scale like everything else (`01`). A 16×16 treat is very small for a hero
image — scale it up by a whole factor rather than reaching for a different
resolution from the pack. Expect to need a larger multiple here than the room's
×2; ×6 or ×8 is still uniform pixels.

## Recipe selection

- Cycles through the user's **unlocked** recipes (`07`).
- Locked recipes: whether they appear here (greyed, with price) or only in the
  recipe book proper is an open question. Defaulting to unlocked-only keeps the
  start-a-session flow uncluttered.
- With only chocolate-chip cookie unlocked (fresh install), the arrows must
  degrade gracefully rather than appearing broken — see `11`.

## Duration

- "−" / "+" step the duration by a fixed increment.
- Constrain min and max **here**, at the input layer. The timer (`03`) should
  never receive an absurd duration.
- Duration drives coins earned (`07`), so the relationship should be legible to
  the user, at least implicitly.
- Remembering the last-used duration is likely the right default. Not decided.

## Text

- Duration digits are grid-critical. If they sit inside the pixel-art frame, they
  use the **bitmap font** (`01`). If the modal is SwiftUI chrome, the pixel TTF
  tier applies.
- Do **not** mix the two tiers within the modal. Pick one and keep it consistent,
  because a bitmap duration next to a TTF label is exactly the jarring mismatch
  `01` forbids.

## Acceptance criteria

- [x] "+" opens the modal; the modal can be dismissed without starting a session.
- [x] Arrows cycle only through unlocked recipes.
- [x] With one unlocked recipe, the control reads as intentional, not broken.
- [x] Duration cannot be set below the minimum or above the maximum.
- [x] Starting creates exactly one `.inProgress` session with the chosen recipe
      and duration, schedules the completion notification (`04`), and returns to
      the main screen with the sprite working.
- [x] The modal cannot be opened while a session is in progress (`06`).
- [x] Text within the modal uses a single text tier.

### How they were checked

The logic is unit-tested (`RecipeBookModalTests`, `BakeDurationTests`): cycling
wraps, never leaves the unlocked set whatever it is asked from, and stays put
with one recipe; clamping bounds and snaps every value; starting creates
exactly one `.inProgress` session with the chosen recipe and duration, refuses
a second while one is in flight, and refuses a locked recipe even if the input
layer were to send one. Scheduling and the working sprite are not re-proven
here because the modal adds no path to them: starting is just the session
changing, which is what `NotificationSync` (`04`) and the scene sync (`05`)
already key off, and both have their own tests.

The screen itself was verified by screenshot on the iPhone 16 and the iPhone
SE (3rd gen) — the book fits both with margin — in both states: one unlocked
recipe (no arrows, invitation caption) and three (arrows, "Page 1 of 3").
Launching with `-bakeryRoom -recipeBook` opens the book at startup for
exactly this purpose, since this machine still has no simulator tap tooling
(the spec 07 gap). **Still owed the same manual pass as 07's sheets:** nobody
has yet tapped the arrows, steppers, or start on a device — the by-hand flow
end to end.

Single tier holds by inspection: every string in the modal is `ChromeFont`
TTF, and the modal contains no bitmap text to clash with. The duration digits
sit on SwiftUI chrome, which is the tier the table below this spec's Text
section prescribes for that case.

## How it is built

- `App/RecipeBookModalView.swift` is a pure view: the caller hands it the
  unlocked recipes and where to open, and gets back one start or one
  dismissal. It never touches the store.
- It is presented as an overlay in `BakeryRoomView` (the spec 06 shell will
  inherit this), over the dimmed room rather than in a system sheet — sheet
  chrome around a drawn book is exactly the "generic picker with a skin" this
  spec forbids. The scaffold "+" replaces the scaffold bake buttons and only
  exists while nothing is baking.
- The page art is a fixed 320×480 pt image from the authored `UI.atlas`
  (`tools/ui/`), not a 9-slice, so its hand-placed details never stretch. The
  treat is the pack sprite at ×8 — a whole factor, per `01`.
- The `-recipeBook` launch argument opens the book at startup, joining
  `-pixelProof` and `-bakeryRoom` as screenshot scaffolding.

## Open questions

- ~~Duration min, max, and step increment.~~ **Resolved: 5–120 minutes in
  steps of 5, defaulting to 25.** Below five minutes a bake is a tap, not a
  commitment, and the burn mechanic has nothing to protect; past two hours one
  bake stops being one sitting. `BakeDuration` owns the numbers — they are
  interaction constraints, not economy values, so they live beside the input
  rather than in `Economy`. The steppers can only move to a clamped value,
  and they visibly die at the bounds rather than no-opping.
- ~~Whether the last-used duration and recipe are remembered.~~ **Resolved:
  both**, in `Settings` (UserDefaults — a preference, not game state), written
  when a bake starts. Values are clamped on the way out, and a remembered
  recipe that is somehow not unlocked falls back to the starter.
- ~~Whether locked recipes are visible here with their prices, or only in the
  recipe book.~~ **Resolved: only in the book.** The spec's own default —
  starting a session should be uncluttered, and the aspirational browsing job
  already has a home where the shortfall can be explained and spent (`07`).
  The modal still nods to what is missing: with one recipe unlocked the
  caption reads as an invitation rather than leaving a bare page.
- ~~Whether recipes have suggested/native durations, which would tie the two
  controls together.~~ **Resolved: no.** The two controls stay independent;
  what ties duration to anything is the payout line — the modal writes the
  coins the chosen duration earns on the page, which is the legibility debt
  the banded curve left with this spec (`07`).
