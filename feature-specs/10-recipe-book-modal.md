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
> pack's palette. The locked pages added the padlock, the coin and the brass
> buy plate to it. The atlas is committed (it is original art, not pack
> pixels), so the app builds without Python. What remains of the art budget is
> settings chrome (`13`) and the app icon.

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

- Cycles through **all** recipes (`07`), locked and unlocked, so the arrows are
  always present — even on a fresh install with only chocolate-chip cookie
  unlocked (`11`), the other pages are there to browse.
- **Locked recipes** show their treat art slightly greyed out/darkened, with a
  **gold lock symbol** covering it.
- On a locked recipe's page, the duration number and "−"/"+" buttons are
  **replaced by a purchase button** showing the recipe's price beside a coin
  icon/art. Buying unlocks the recipe (`07`) and the page becomes a normal
  startable one.
- Starting a session is only ever possible on an unlocked recipe; the store's
  refusal of a locked recipe (already tested) stays as the backstop.

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
- [x] Arrows cycle through **all** recipes, locked and unlocked, and are always
      visible.
- [x] Locked recipes show greyed/darkened treat art under a gold lock symbol.
- [x] Locked recipes replace the duration and "−"/"+" controls with a purchase
      button showing the price and a coin icon.
- [x] Purchasing from the modal unlocks the recipe and the page becomes
      startable in place.
- [x] Duration cannot be set below the minimum or above the maximum.
- [x] Starting creates exactly one `.inProgress` session with the chosen recipe
      and duration, schedules the completion notification (`04`), and returns to
      the main screen with the sprite working.
- [x] The modal cannot be opened while a session is in progress (`06`).
- [x] Text within the modal uses a single text tier.

### How they were checked

> **Revised 2026-08-15:** the locked-recipe decision below was reversed — the
> modal now cycles all recipes, with locked ones greyed under a gold lock and a
> purchase button in place of the stepper. Built and re-verified the same day;
> the record below is the whole book, not the unlocked-only version.

The logic is unit-tested (`RecipeBookModalTests`, `BakeDurationTests`): cycling
wraps at both ends, walks every page of the catalogue and comes home rather
than drifting, and never leaves the book whatever page it is asked from; a
locked entry carries the price and the shortfall the buy button and its sheet
read; clamping bounds and snaps every value; starting creates exactly one
`.inProgress` session with the chosen recipe and duration, refuses a second
while one is in flight, and refuses a locked recipe even if the input layer
were to send one. Buying in place is proven at the store: the page the modal
is holding is locked and unstartable, and after the purchase the same page is
unlocked and starts. Scheduling and the working sprite are not re-proven here
because the modal adds no path to them: starting is just the session changing,
which is what `NotificationSync` (`04`) and the scene sync (`05`) already key
off, and both have their own tests.

The screen itself was verified by screenshot on the iPhone 16 and the iPhone
SE (3rd gen) — the book fits both with margin — across every page state: an
unlocked page (stepper, payout, start), a locked page nobody can afford yet
("70 more to go" on a fresh install, "275 more to go" against 180 coins), and
a locked page the balance covers ("You have 600 coins"). The greying was
checked against a colourful treat as well as a dark one, since a chocolate
donut hides a filter that a fruit tart shows. Both confirmation sheets were
seen too — "Buy this recipe?" with its buy, and "Not enough coins" with the
shortfall arithmetic right (840 − 600 = 240, 70 − 0 = 70) — by defaulting the
confirmation state to true in a throwaway build, which is also what caught the
sheet saying "1000" beside a page saying "1,000".

`-bakeryRoom -recipeBook` opens the book at startup and `-recipeBookLocked`
opens it on the first locked page, since this machine still has no simulator
tap tooling (the spec 07 gap). **Still owed the same manual pass as 07's
sheets:** nobody has yet tapped the arrows, steppers, buy or start on a device
— every state above was reached by launching into it, so the by-hand flow end
to end, and the page visibly flipping from price to stepper under the user's
own finger, are unwitnessed.

Single tier holds by inspection: every string in the modal is `ChromeFont`
TTF, and the modal contains no bitmap text to clash with. The duration digits
sit on SwiftUI chrome, which is the tier the table below this spec's Text
section prescribes for that case.

## How it is built

- `App/RecipeBookModalView.swift` is a pure view: the caller hands it the book
  (`BakeryStore.recipeBook` — the whole catalogue, each entry priced against
  the balance), the balance, and where to open, and gets back one start, one
  purchase or one dismissal. It never touches the store.
- Which is what makes a bought page startable in place: `BakeryRoomView` reads
  the book in its body pass, so a purchase re-derives the entry the modal is
  showing while the modal keeps its own recipe in `@State`. Nothing reopens
  and nothing is synced.
- The locked and unlocked bottom blocks are laid into a frame of the same
  height, so turning to a locked page swaps stepper-and-start for buy-and-price
  without moving the treat above them.
- It is presented as an overlay in `BakeryRoomView` (the spec 06 shell will
  inherit this), over the dimmed room rather than in a system sheet — sheet
  chrome around a drawn book is exactly the "generic picker with a skin" this
  spec forbids. The scaffold "+" replaces the scaffold bake buttons and only
  exists while nothing is baking.
- The page art is a fixed 320×480 pt image from the authored `UI.atlas`
  (`tools/ui/`), not a 9-slice, so its hand-placed details never stretch. The
  treat is the pack sprite at ×8 — a whole factor, per `01`.
- The `-recipeBook` launch argument opens the book at startup and
  `-recipeBookLocked` opens it on the first locked page, joining `-pixelProof`
  and `-bakeryRoom` as screenshot scaffolding.

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
  recipe book.~~ **Resolved: only in the book** (the spec's original default),
  then **reversed 2026-08-15: visible here.** The modal cycles every recipe;
  locked pages show greyed/darkened art under a gold lock, with a purchase
  button (price + coin icon) where the duration stepper would be. Browsing and
  buying now happen in the same place you start a bake, so the arrows never
  disappear and the one-recipe invitation caption is superseded.
- ~~What the purchase button does when the user cannot afford the recipe —
  disabled, or tappable with a shortfall explanation.~~ **Resolved: tappable,
  and explained.** Spec 07 had already settled the pattern for the scaffold's
  rows — a buy is confirmed rather than done on the first tap, and an
  unaffordable one opens that *same* sheet with the shortfall spelt out and no
  buy button — so the modal uses it rather than inventing a second answer. The
  page itself carries the shortfall under the button ("275 more to go"), which
  is the number a disabled control would have withheld.
- ~~Where the gold lock and coin art come from — the pack, or authored into
  `UI.atlas` alongside the rest of the book chrome.~~ **Resolved: authored.**
  The pack has neither; `4_User_Interface_Elements/` is emotes and speech
  bubbles (`14`). `tools/ui/build_ui.py` now draws `lock_gold`, `coin` and
  `button_buy` in the same brass as the cover's corner protectors, so the gold
  in the book is one metal — and the buy button is the start button's plate
  struck in that brass, which is how a locked page's action reads as gold
  where an unlocked one's reads as leather.
- ~~Whether recipes have suggested/native durations, which would tie the two
  controls together.~~ **Resolved: no.** The two controls stay independent;
  what ties duration to anything is the payout line — the modal writes the
  coins the chosen duration earns on the page, which is the legibility debt
  the banded curve left with this spec (`07`).
