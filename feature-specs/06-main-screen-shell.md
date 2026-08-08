# 06 — Main Screen Shell

**Depends on:** 01, 05, 08, 14. **Blocks:** 11.

## Goal

The home of the app: a single top-down view of your bakery that is equal parts
companion and progress.

## Layout — one room, two zones

The screen is **one full-bleed top-down room** (`05`), not a split of scene and
list. The identity of the screen is that you are looking down into your bakery.

- **Upper zone — back of house:** oven, prep counter, the baker at work.
- **Lower zone — front of house:** the display cases holding today's output
  (`08`), café seating, the door.
- **"+" button** floats over the room, near the bottom, and starts a new timer by
  opening the recipe-book modal (`10`).

The two zones are continuous space within one room — divided by a counter line or
floor change, never by a UI boundary. The baker walks between them, and the
completion payoff is that walk (`05`).

> This replaces the earlier "top half `SpriteView`, bottom half SwiftUI list"
> layout, which assumed side-on art. With a top-down pack, the display case is an
> **in-world object**, not a list beneath the scene.

The room letterboxes or extends its wall margin rather than distorting to fill
(`01`).

## States

| App state | Back of house | Front of house | "+" button |
|---|---|---|---|
| No session, empty case (fresh day) | Idle baker | Empty cases — *ready to open* (`11`) | Available |
| No session, case has treats | Idle baker | Cases holding today's treats | Available |
| Session in progress | Baker at station, oven animating, bitmap countdown | Today's treats so far | Hidden or disabled — one session at a time |
| Session just completed | Baker picks up the treat | Baker walks it over and places it; celebrate beat | Available after the beat |
| Session burned | Baker returns to idle | Unchanged — nothing added | Available |
| First open of the day | Ritual prompt precedes the screen (`09`) | — | — |

Only one session runs at a time (`02`), so the "+" affordance must clearly not
be available mid-bake rather than failing when tapped.

## Persistent chrome

Chrome overlays the room rather than sitting beside it, so it must be sparse —
every element covers part of the bakery.

- **Coin balance**, visible and updating on award (`07`).
- Entry to the **recipe book** (`07`) — permanent progression, conceptually
  separate from the display case in the room below.
- Entry to **settings** (`13`).
- **Streak indicator** (`09`).

Chrome is SwiftUI and uses the pixel TTF tier (`01`). Coin count *inside* the
scene is bitmap text. Keep the two tiers physically apart — do not place a
SwiftUI coin label adjacent to bitmap digits. With chrome now floating over the
scene, this is easier to violate than it was: an overlay label can drift next to
in-scene text at a screen size nobody checked.

## Ownership

SwiftUI owns navigation, chrome, modal presentation, `scenePhase`, persistence,
and notification scheduling. It passes state **down** into the scene, and the
scene passes **taps up** as events (`05`, `08`). See `05` for the boundary rule.

## Interactions

- Tapping "+" presents the recipe-book modal (`10`).
- Tapping the **display case** in the room opens today's bakes (`08`).
- Completing a session: the baker carries the treat to the case, coins increment
  visibly, sound + haptic fire (`12`). This is the payoff moment of the entire
  app — it deserves real attention, not a silent state swap.
- Cancelling an in-flight session requires confirmation (`03`).

## Acceptance criteria

- [ ] The room fills the screen on the smallest and largest supported iPhones
      without scaling fractionally, and both zones are visible without scrolling.
- [ ] The screen reflects every state in the table above.
- [ ] "+" is unavailable, and visibly so, while a session is in progress.
- [ ] Chrome never obscures the baker's station, the oven, or the display cases.
- [ ] Returning from background mid-session shows the correct remaining time
      immediately, with no visible catch-up or flicker.
- [ ] Returning from background after `endDate` shows the completed state with
      the treat in the case — without replaying the deliver walk out of context.
- [ ] The recipe book and display case are never presented as the same list.

## Gotchas

- The two collections must stay **conceptually separate in the UI**. The recipe
  book is permanent progression; the display case is today and resets each
  morning. Blurring them undermines both. The in-world case helps here — it is
  visibly a *place*, not a list.
- Both zones must fit on the smallest supported device without scrolling. A room
  too tall for the screen turns the main screen into a scroll view and loses the
  at-a-glance quality entirely.
- Keep views small — extract subviews when the body starts carrying too much
  state or layout logic.

## Open questions

- Exact placement of coin balance, streak, and settings entry within the chrome,
  now constrained by not covering the room.
- Whether the countdown appears in the scene (bitmap) only, or also in chrome.
  Prefer scene-only to avoid a second text tier next to it.
- Whether "+" is chrome or an in-world object (a bell on the counter, say). The
  in-world option is more charming and more discoverable-by-accident; it is also
  harder to make obvious to a first-time user (`11`).
