# 08 — Display Case & Daily Reset

**Depends on:** 02, 03, 05, 14. **Blocks:** 06, 09.

## Goal

Today's output, visible and accumulating — and gone tomorrow morning.

## The reset is intentional

The display case is *today's output*. It fills as you bake and **resets each
morning**. This is deliberate: a fresh bakery each day reinforces the consistency
thesis. It is not data loss and should never be framed to the user as such.

Contrast with the recipe book (`07`), which is permanent progression. **Keep the
two collections separate in data and UI.**

## The case is an object in the room

The display case is a **glass case standing in the front of house** (`05`,
`06`) — not a list below the scene. Treats appear as sprites inside it, and the
baker physically carries each one over from the oven on completion.

Tapping the case opens a SwiftUI sheet listing today's bakes with quantities.
This keeps the world immersive while staying readable when the case is full and
accessible to VoiceOver (`13`).

The pack provides the case art directly: `24_Ice_Cream_Shop` and
`16_Grocery_store` include glass cases with per-slot contents, and
`3_Animated_objects` includes animated variants that fill with cake (`14`).

## Behavior

- A completed session adds its treat to the case, in completion order (`02`).
- The treat becomes visible **at the end of the baker's deliver walk** (`05`),
  not at the instant the timer fires.
- Multiple bakes of the same recipe accumulate as quantities — shown with ♦
  quantities in bitmap text where in-scene (`01`), and as counts in the sheet.
- A burned session adds nothing, and the baker skips the deliver walk entirely.

## Daily reset rules

- The reset is **lazy**: evaluated when the app comes to the foreground (or
  launches), not by a background job.
- The day key is the **local calendar day** (`02`), re-derived on foreground so a
  timezone change is picked up.
- On detecting a new day: clear the case, and run the day-open ritual (`09`).

### The reset must not clobber an in-flight bake

This is the sharp edge. If a session is `.inProgress` across midnight:

- The **session survives**. Its `endDate` is absolute and unaffected.
- The display case rolls over.
- When the session completes, its treat lands in the **new** day's case — it was
  finished today.
- The recipe book is untouched, always.

## Presentation

- Filling the case is a payoff moment: the baker carries the treat over and
  places it (`05`), with sound and haptic (`12`). Do not shortcut this into the
  treat appearing instantly. The walk and the placement are built; the sound and
  the haptic are not, and wait on `12` — the scene already raises `treatPlaced`
  at the exact frame they belong on, so they are a handler, not a rebuild.
- Empty state (a fresh morning, an empty case) is a place cozy apps prove they're
  crafted — see `11`. It should read as *a bakery ready to open*, not as absence.
  An empty glass case in a lit room does this well on its own.
- The tap sheet is chrome and uses the pixel TTF tier (`01`).

### Visual capacity vs. logical capacity

The case has a **fixed number of visible slots** — however many the case sprite
and room width allow. Bakes within a day are not logically capped by that.

Decide what a full case does *before* building it: stop adding sprites while
still counting, or swap to a "stacked/abundant" case sprite. Either is fine; what
must not happen is treats overflowing into the room or silently vanishing with no
record. The sheet always shows the true count regardless of what the case
displays.

> **Settled.** A slot is spent per *recipe*, not per bake, so the shelf needs
> only as many slots as the catalogue has entries — six — against the eight it
> has on the smallest room `RoomLayout` will resolve and ten on an iPhone 16. A
> visually full case is therefore unreachable, and neither branch above had to
> be chosen. `BakerySceneTests` asserts the catalogue still fits the shelf on
> every room size; should recipes ever outgrow it, the shelf stops adding
> sprites while the sheet goes on counting.

## Acceptance criteria

- [x] Completing a session adds exactly one treat of the right recipe, visible in
      the case at the end of the deliver walk.
- [x] Repeated bakes of one recipe display as a quantity, not duplicate entries.
- [x] Tapping the case in the room opens today's bakes; the sheet count always
      matches the true tally, even when the case is visually full.
- [x] Exceeding visible slot capacity neither drops a treat from the record nor
      spills sprites outside the case.
- [x] Crossing midnight with no session: case is empty on next foreground, recipe
      book intact, coins intact, streak intact.
- [x] Crossing midnight **with** a session in progress: session survives, case
      resets, and the treat lands in the new day on completion.
- [x] Changing timezone across a day boundary resolves to one reset, not zero and
      not two.
- [x] Backgrounding and foregrounding repeatedly within one day never resets the
      case.
- [x] Display case data being unreadable never takes the recipe book with it.

### How they were checked

The reset half was built and proven with spec 02's persistence work and is
unchanged here: `BakeryStoreTests` covers the rollover clearing the case while
the recipe book, wallet and streak sit in another file and another slice, a
reset never clobbering an in-flight bake, a bake crossing midnight filing its
treat under the day it *finished* in, and repeated foregrounding within one day
never resetting anything; `TimeZoneRolloverTests` covers flying east rolling
the day exactly once and flying west not clearing a case still being filled;
`FailSoftPersistenceTests` covers unreadable display-case data costing the day
and nothing else. Rollover lives in one place — `BakeryStore.rollOverIfNeeded`
— which is what stops two call sites disagreeing at a DST boundary, and
`finishActiveSession` settles the day *before* crediting, which is the
mid-deliver-walk interleaving the gotchas warn about.

The case itself is unit-tested (`DisplayCaseTests`, `BakerySceneTests`):
quantities accumulate in first-baked order so the counter does not reshuffle as
counts climb, the tally the room draws is derived by the same
`TreatTally.tallied` the sheet lists, a forty-bake day keeps all forty in the
record while the shelf shows six, and the tap region clears spec 13's 44pt
floor on every room size. The overflow criterion is checked as geometry rather
than by eye: every drawn slot's accumulated frame must sit inside the case
region on three screen sizes.

Verified by screenshot on the iPhone 16, seeding a twelve-bake day into
`today.json` in the simulator's container: the room shows six treats on the
counter with ♦4, ♦3 and ♦2 over the repeats, nothing outside the case, and the
sheet lists all six recipes with matching counts under a header reading "12
treats today" — the true tally, above the fold, while the room shows six. The
empty case was shot too, and reads as a bakery about to open rather than as
anything lost.

**Still owed a manual pass, the same debt specs 07 and 10 carry:** nobody has
tapped the case on a device. `-bakeryRoom -displayCase` opens the sheet at
launch, which is how it was shot, so the `.caseTapped` path from an actual
finger is unwitnessed — as is the deliver walk placing a treat that raises a ♦
count from 1 to 2, which needs a real timer to reach. The case's VoiceOver
element was written against spec 13's requirement but has not been driven with
VoiceOver running.

## Gotchas

- The display-case daily reset must not clobber an in-flight bake **or** the
  recipe book. This is the most-cited failure mode for this feature.
- Resolve "is it a new day?" in one place. Two call sites with their own
  calendar math will disagree eventually, usually at a DST boundary.

- A midnight reset while the baker is mid-deliver-walk is a real interleaving.
  The treat belongs to the day it *completes* in — make sure the walk finishing
  after a rollover doesn't drop it or file it under yesterday.

## Open questions

- ~~How many visible slots the case has, and what a visually full case does.~~
  **Settled:** the counter line is the shelf, so the slot count is
  `RoomPlan.shelfColumns` — eight on the smallest room the layout resolves, ten
  on an iPhone 16. Per-recipe slots put that permanently ahead of the
  catalogue, so a full case is unreachable and neither fallback was needed (see
  above).
- ~~Whether the case is one wide unit or several smaller ones.~~ **Settled by
  `05`:** one case fixture at the left end of a continuous counter line, with
  the counter acting as the shelf beside it. Grouping recipes by type would
  need several units and a rule for which treat goes where; quantities made the
  grouping unnecessary, since each recipe already has exactly one place to be.
- ~~Whether the animated cake-fridge variants (`14`) are used.~~ **Settled:**
  static case, treat sprites layered on the counter. Incremental filling is the
  whole payoff — the baker carries a treat over and it appears where he puts it
  — and an animated fixture that fills with cake on its own schedule fights
  that rather than helping it.
- Is yesterday's case viewable anywhere? **No**, unchanged: v1 has no history
  screen. The reset is the feature, and a way to go look at yesterday would
  quietly argue the opposite.
