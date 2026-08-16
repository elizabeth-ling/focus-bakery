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

> **Built as three, not four.** The "+" *is* the entry to the recipe book — it
> opens the same modal (`10`), which is where progression is browsed and bought.
> A second chrome control opening one modal would cover twice as much bakery for
> nothing, against a section whose whole rule is that every element costs room.
> The consequence is deliberate and worth knowing: the book cannot be browsed
> mid-bake, because the "+" is gone then. Shopping is not what a focus session is
> for, and spec 10's page has exactly one action on it — a browse-only mode would
> be a second modal to earn its keep.

Chrome is SwiftUI and uses the pixel TTF tier (`01`). Coin count *inside* the
scene is bitmap text. Keep the two tiers physically apart — do not place a
SwiftUI coin label adjacent to bitmap digits. With chrome now floating over the
scene, this is easier to violate than it was: an overlay label can drift next to
in-scene text at a screen size nobody checked.

> **Settled by moving it.** There is no coin count inside the scene any more: the
> balance is chrome. In-scene it was bitmap text hung a tile and a half below the
> room's top edge, which in a full-bleed room is under the Dynamic Island, and
> sprite digits do not exist to VoiceOver at all (`13`). One number, one tier, one
> place — and the tier rule is now a geometry assertion rather than a warning.

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

- [x] The room fills the screen on the smallest and largest supported iPhones
      without scaling fractionally, and both zones are visible without scrolling.
- [ ] The screen reflects every state in the table above. Five of the six rows
      are built and were watched on the simulator; the sixth — the first open of
      the day — is `09`'s ritual prompt, which does not exist yet. Nothing in
      the shell blocks it: it precedes this screen rather than living in it.
- [x] "+" is unavailable, and visibly so, while a session is in progress.
- [x] Chrome never obscures the baker's station, the oven, or the display cases.
- [x] Returning from background mid-session shows the correct remaining time
      immediately, with no visible catch-up or flicker.
- [x] Returning from background after `endDate` shows the completed state with
      the treat in the case — without replaying the deliver walk out of context.
- [x] The recipe book and display case are never presented as the same list.

### How they were checked

The two geometric criteria are asserted rather than eyeballed, because "chrome
never obscures the room" is a claim about every screen size and not about the
one in front of you. `ChromeLayoutTests` builds both chrome slots for the
supported span (SE through 16 Pro Max, with the safe areas each actually has)
and requires that neither intersects the oven, the station, the case, the door
or the resting baker, that both stay inside the safe area, and that both clear
44pt. `MainScreenTests` does the same for the tier rule — a whole tile of clear
floor between the overlay and any bitmap string the room draws, with the room
made as busy as it ever gets — and drives `MainScreenAction` through every row
of the state table.

The rest was watched on the simulator, on an iPhone 16 unless noted:

- **The room, both ends.** Shot on the iPhone SE (3rd gen) and the 16 Pro Max as
  well: back of house and front of house both visible without scrolling, the
  margin absorbed at the room edges, no fractional scale (`01` resolves ×2 on
  every one of them). This also pays off `05`'s owed layout screenshots.
- **The payoff, frame by frame.** Seeded a bake ending twenty seconds after
  launch and shot it every four seconds: oven → "ready" → the baker picks the
  treat up → carries it down the corridor → places it on the counter, at which
  point the ♦ count climbs, the coin balance has already gone 248 → 249, and the
  "+" comes back. The "+" is absent for the whole walk, which is the state
  table's "available after the beat".
- **Coming back to a finished bake, both ways.** Seeded a session whose
  `endDate` was five minutes gone: with the departure inside the grace it reads
  "Your bake is ready", the cake is already in the case and the baker is at
  rest — no walk replayed. With the departure before it, "Your bake burned",
  nothing added, no celebration.
- **Coming back mid-bake.** Backgrounded to Safari for twelve seconds at 21:57
  and came back: the countdown read 21:45, correct during the transition
  itself, with no 0:00 or catch-up frame.
- **The sheets.** Today's bakes and settings, both over the room. The
  "alerts are off" branch of settings was forced to render (the condition
  inverted in a throwaway build) because both simulators here were granted
  notification permission during earlier specs.

**Owed a device.** Nobody has tapped any of this with a finger: the states were
reached by seeding files and by launch flags. The chrome's contrast over the
*final* floor art is also unmeasured, and cannot be until `14` replaces the
placeholder floor blocks — the cream text sits on the room's darkest band today,
which is `13`'s to confirm along with Dynamic Type.

## How it is built

- `MainScreenView` (`App/MainScreenView.swift`) is the shell and the app's root.
  It is `BakeryRoomView` grown up: same one-way boundary — the store's state
  derived into a `BakeryScene.Model` each second and on each session edge, scene
  events translated back — now carrying the chrome, the modals, the outcome
  alert, the cancel confirmation and the one-time "alerts are off" notice, which
  moved here from the retired persistence scaffold because this is where the
  user was when permission was refused.
- **The state table is `MainScreenAction`**, a pure function of the session
  resolution plus "is the payoff playing", the same shape as `05`'s
  `BakerDirector`. `.stop` mid-bake, `.none` for the deliver walk and for a bake
  that has ended but not yet settled, `.start` otherwise. The "+" is *replaced*
  rather than disabled, so the one-session rule (`02`) is visible rather than
  discovered by tapping.
- **`ChromeLayout` (`Rendering/ChromeLayout.swift`) decides where chrome may
  sit**, from the same `RoomLayout` the scene lays the room out with. The bar
  starts clear of the oven's trailing edge — the oven hangs on the back wall at
  the leading edge, exactly where a status strip wants to be — and the "+" is
  held above the door rather than at a fixed inset off the bottom, which is what
  keeps it off the door on a phone with no home indicator. `RoomPlan` grew
  `ovenRegion` and `stationRegion` to check against, beside the case region it
  already had.
- **Read the safe area outside `ignoresSafeArea`.** A `GeometryReader` inside a
  view that has ignored the safe area reports insets of zero, and the first
  build of this screen put the coin balance neatly under the Dynamic Island. The
  insets are captured by the outer reader and passed down.
- **No drop shadow on chrome text.** The usual way to hold text over busy art is
  a one-pixel ink shadow, and it was built that way first; the chrome font's
  counters are one or two pixels wide at this size, so the shadow shows through
  them and a `0` fills in to a blob. Cream, unshadowed, over the room's darkest
  band instead.
- **Authored art, not glyphs** (`tools/ui/build_ui.py`, `14`): a gear for
  settings, a flame for the streak, a leather plate with a brass plus for the
  "+", and a paper plate with an ink × for the way out of a bake — quieter on
  purpose, since an escape hatch should not compete with the oven.
- **`SettingsSheetView` is `13`'s screen, started.** Only what already works:
  the daily reminder and its time (`04`), the permission state with a link into
  iOS Settings, and the licence attribution (`14`, `NOTICE.md`). Sound and
  haptics land with `12`.
- The screenshot flags survive the move and gain `-settings`; `-pixelProof` and
  `-bakeryRoom` are gone with the scaffolds they launched.

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

- ~~Exact placement of coin balance, streak, and settings entry within the
  chrome, now constrained by not covering the room.~~ **Settled: a single strip
  in the top safe area**, starting clear of the oven — coins then streak at its
  leading end, settings at its trailing end — and the one control near the
  bottom, centred over front-of-house floor above the door. Placement is
  *derived* from `RoomPlan` rather than chosen per device (see above), which is
  what makes "never obscures" checkable instead of a promise. The top strip won
  over a bottom one because front of house is where the case fills, the baker
  rests and the door is: the only genuinely empty band in the room is the wall
  line the oven does not occupy.
- ~~Whether the countdown appears in the scene (bitmap) only, or also in
  chrome.~~ **Settled: scene-only**, as the spec preferred — and the coin
  balance went the other way, out of the scene and into chrome, for the safe
  area and for VoiceOver. Each number now exists exactly once, in one tier, and
  the countdown moved a tile further down the room so a whole tile of floor
  separates the tiers.
- ~~Whether "+" is chrome or an in-world object (a bell on the counter, say).~~
  **Settled for v1: chrome.** Three things decided it. It must be *visibly*
  unavailable mid-bake, and a bell that vanishes from the counter makes the room
  look broken rather than busy. It must be reachable by VoiceOver with a label,
  which a fixture in a sprite scene is not without `13`'s full room pass. And
  its discoverability cannot lean on onboarding that does not exist yet (`11`) —
  the in-world version is the more charming answer and is worth revisiting when
  `11` can teach it, at which point this is one view swapping for a scene node
  and the same event.

## Still open, and owned elsewhere

- The **streak indicator reads real state and nothing yet writes it**: `09` has
  not been built, so the flame is unlit and numberless on every device today.
  That is the day-one empty state either way (`11` — never a zero that scolds),
  so it is honest rather than a placeholder, but the first thing `09` should do
  is confirm the count appears when it starts incrementing.
- The **first-open ritual row of the state table** is `09`'s, as above.
- **Contrast and Dynamic Type** for the chrome text are `13`'s, and cannot be
  judged until `14` puts the final floor under it.
