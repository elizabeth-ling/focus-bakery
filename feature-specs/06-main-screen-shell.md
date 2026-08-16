# 06 — Main Screen Shell

**Depends on:** 01, 05, 08, 14. **Blocks:** 11.

## Goal

The home of the app: a single top-down view of your bakery that is equal parts
companion and progress.

## Layout — a tray, and one room in two zones

The screen is **a tray across the top and one top-down room filling the rest**
(`05`), not a split of scene and list. The identity of the screen is that you are
looking down into your bakery; the tray is a shelf across the front of it, not a
second half of the screen.

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

## Persistent chrome — the tray

The readouts live on a **tray across the top of the screen**: full width, leather
and brass, with the room laid out in everything below it.

- **Coin balance**, visible and updating on award (`07`).
- Entry to the **recipe book** (`07`) — permanent progression, conceptually
  separate from the display case in the room below.
- Entry to **settings** (`13`).
- **Streak indicator** (`09`).

> **The tray replaces a floating bar.** Chrome used to overlay a full-bleed room,
> which made "keep it sparse" a geometry problem rather than an editorial one:
> the oven hangs on the back wall at the leading edge, exactly where a status
> strip wants to go, and it is the room's whole "something is baking" signal
> (`05`). The bar had to start clear of the oven's trailing edge and live in what
> was left. A tray that *takes* the top of the screen cannot obscure anything —
> the criterion below stops being a placement to get right and becomes true by
> construction — and the readouts get a comfortable row instead of the gap beside
> the oven. The cost is real and is paid in room: the scene is four tile rows
> shorter on an iPhone 16. It still resolves ×2 and still seats back of house and
> front of house on every supported phone, which is asserted rather than assumed.

> **Built as three, not four.** The "+" *is* the entry to the recipe book — it
> opens the same modal (`10`), which is where progression is browsed and bought.
> The tray no longer costs bakery, so the old argument — a second control covering
> twice as much room — has expired; the list stays at three because a status strip
> is read at a glance or not at all, and because the "+" is already the way in.
> The consequence is unchanged and worth knowing: the book cannot be browsed
> mid-bake, because the "+" is gone then. Shopping is not what a focus session is
> for, and spec 10's page has exactly one action on it — a browse-only mode would
> be a second modal to earn its keep.

Chrome is SwiftUI and uses the pixel TTF tier (`01`). Coin count *inside* the
scene is bitmap text. Keep the two tiers physically apart — do not place a
SwiftUI coin label adjacent to bitmap digits. The tray makes overlap impossible,
but not adjacency: an in-scene string can still drift up against the tray's
bottom edge at a screen size nobody checked.

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

- [x] The room fills the screen below the tray on the smallest and largest
      supported iPhones without scaling fractionally, and both zones are visible
      without scrolling.
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
one in front of you. `ChromeLayoutTests` builds the chrome for the supported
span (SE through 16 Pro Max, with the safe areas each actually has) and requires
that neither the tray nor the "+" intersects the oven, the station, the case,
the door or the resting baker, that both stay inside the safe area, and that
both clear 44pt. `MainScreenTests` does the same for the tier rule — a whole
tile of clear floor between the tray and any bitmap string the room draws, with
the room made as busy as it ever gets — and drives `MainScreenAction` through
every row of the state table.

Three assertions are the tray's own, because it changed what can go wrong:

- **The tray hands the room the rest.** It spans the screen, its bottom edge is
  exactly where the scene begins, and the scene runs to the bottom of the phone.
  This is what makes the obscuring criterion structural rather than careful.
- **The room survives the tray.** It still resolves ×2 and still seats the
  smallest useful room (`01`) on every supported phone with the tray's height
  taken off. This is the criterion the tray could actually break.
- **An odd safe area is absorbed.** The inset is the one input here that is not
  ours and could arrive off the grid, and the tray's depth is what offsets every
  sprite in the scene, so it is rounded up to a whole chrome pixel and the room's
  origin is checked to still land on one.

The rest was watched on the simulator, on an iPhone 16 unless noted:

- **The tray, all three ends.** Shot on the SE (3rd gen), the 16 and the 16 Pro
  Max: the leather runs to the top edge under the status bar and the Dynamic
  Island rather than leaving a strip of nothing above it, the brass rail and its
  shadow land on the room, and the gear keeps its inset off the trailing edge on
  the widest phone. The readouts were shot at 0, 6, 10, 12, 248, 1207 — a lone
  `0` is worth looking at, since the streak's unlit state exists to avoid one.
- **The countdown against the tray.** With a 25-minute bake seeded, `24:55` and
  `baking…` sit well down in the open floor, the oven is lit, and the "×" stands
  where the "+" was. The two tiers are nowhere near each other.
- **The modal and the sheets over it.** The recipe book dims the tray along with
  the room, and settings and today's bakes still present over both.

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
reached by seeding files and by launch flags. The tray settles what the chrome's
contrast was waiting on — cream on the tray's leather is a fixed pair of colours,
not cream over whatever floor art `14` eventually lands, so it no longer depends
on the placeholder blocks being replaced. It is still unmeasured, and is `13`'s
to confirm along with Dynamic Type.

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
- **`ChromeLayout` (`Rendering/ChromeLayout.swift`) divides the screen**, rather
  than finding gaps in it. It takes the tray's depth off the top, hands the rest
  to the room as `scene`, and resolves the `RoomLayout` from *that* — so the
  scene's coordinates start at the tray's bottom edge and everything the layout
  publishes is in screen coordinates. The "+" is held above the door rather than
  at a fixed inset off the bottom, which is what keeps it off the door on a phone
  with no home indicator; it is snapped in the room's coordinates and only then
  moved down by the tray's depth, which is why that depth is a whole number of
  chrome pixels. `RoomPlan`'s `ovenRegion` and `stationRegion` still exist to
  check against, though the tray now clears them by construction.
- **Read the safe area outside `ignoresSafeArea` — and put the size back
  together.** A `GeometryReader` inside a view that has ignored the safe area
  reports insets of zero, and the first build of this screen put the coin balance
  neatly under the Dynamic Island. The reader outside it has the opposite half of
  the problem: it is proposed the *safe* size while the `ZStack` below then draws
  into the whole screen from its top-left corner. Handing that short size to
  `ChromeLayout` was a room ending 96pt above the bottom of the phone with white
  underneath. The size is reassembled from the insets before it is passed down.
- **No drop shadow on chrome text.** The usual way to hold text over busy art is
  a one-pixel ink shadow, and it was built that way first; the chrome font's
  counters are one or two pixels wide at this size, so the shadow shows through
  them and a `0` fills in to a blob. The tray settles it for good — flat leather
  is not busy art, and there is nothing left to hold the text over.
- **Authored art, not glyphs** (`tools/ui/build_ui.py`, `14`): a gear for
  settings, a flame for the streak, a leather plate with a brass plus for the
  "+", and a paper plate with an ink × for the way out of a bake — quieter on
  purpose, since an escape hatch should not compete with the oven.
- **The tray is a flat fill and one stretched strip.** It is as wide as the
  screen, and a screen is not a whole number of art pixels across, so it cannot
  be authored at a fixed width and magnified like everything else (`01` rule 1).
  The field is `PixelInk.leather` — the same `D` the book's cover is drawn in —
  and `tray_edge` is nine rows of identical columns that `StretchedPixelStrip`
  widens to fit. Stretching is exact because there is no horizontal detail in it
  to land a partial pixel on; the height is still a whole multiple. Its last two
  rows are the shadow, which is why the palette in `build_ui.py` now has two
  translucent entries and `rgba` no longer assumes every colour is opaque.
- **The status bar is pinned to light content** (`INFOPLIST_KEY_UIStatusBarStyle`).
  The tray's leather is dark, and the clock sits on it.
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
  chrome, now constrained by not covering the room.~~ **Settled twice.** First as
  a strip floating in the top safe area, starting clear of the oven, which is
  what "constrained by not covering the room" gets you: the only genuinely empty
  band over the room is the wall line the oven does not occupy, and the readouts
  had to fit in it. Now as **a tray that takes the top of the screen**, with the
  room laid out below it — coins then streak at its leading end, settings at its
  trailing end, and the one control still near the bottom, centred over
  front-of-house floor above the door. Removing the constraint rather than
  satisfying it is the better answer: chrome that is never over the room cannot
  cover it at any screen size, so "never obscures" stops being a placement to
  derive and becomes a fact about the layout. The "+" is still *derived* from
  `RoomPlan`, because it does still float over the room.
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
