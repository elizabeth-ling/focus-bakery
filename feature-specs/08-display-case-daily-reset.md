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
- Multiple bakes of the same recipe accumulate as quantities — shown with ★
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
  treat appearing instantly.
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

## Acceptance criteria

- [ ] Completing a session adds exactly one treat of the right recipe, visible in
      the case at the end of the deliver walk.
- [ ] Repeated bakes of one recipe display as a quantity, not duplicate entries.
- [ ] Tapping the case in the room opens today's bakes; the sheet count always
      matches the true tally, even when the case is visually full.
- [ ] Exceeding visible slot capacity neither drops a treat from the record nor
      spills sprites outside the case.
- [ ] Crossing midnight with no session: case is empty on next foreground, recipe
      book intact, coins intact, streak intact.
- [ ] Crossing midnight **with** a session in progress: session survives, case
      resets, and the treat lands in the new day on completion.
- [ ] Changing timezone across a day boundary resolves to one reset, not zero and
      not two.
- [ ] Backgrounding and foregrounding repeatedly within one day never resets the
      case.
- [ ] Display case data being unreadable never takes the recipe book with it.

## Gotchas

- The display-case daily reset must not clobber an in-flight bake **or** the
  recipe book. This is the most-cited failure mode for this feature.
- Resolve "is it a new day?" in one place. Two call sites with their own
  calendar math will disagree eventually, usually at a DST boundary.

- A midnight reset while the baker is mid-deliver-walk is a real interleaving.
  The treat belongs to the day it *completes* in — make sure the walk finishing
  after a rollover doesn't drop it or file it under yesterday.

## Open questions

- How many visible slots the case has, and what a visually full case does (see
  above). Gated on room dimensions (`05`).
- Whether the case is one wide unit or several smaller ones — the pack supports
  both, and several would let recipes group by type.
- Whether the animated cake-fridge variants (`14`) are used, or a static case
  with treat sprites layered on. Static is simpler to fill incrementally;
  animated is more alive.
- Is yesterday's case viewable anywhere? v1 has no history screen (deferred), so
  the default answer is no.
