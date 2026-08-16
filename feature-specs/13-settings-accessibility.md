# 13 — Settings & Accessibility

**Depends on:** 04, 12. **Blocks:** nothing.

Part of the "not vibe-coded" layer.

## Goal

A small, honest settings screen, and an app that works for people who need
reduced motion, VoiceOver, or larger text.

## Settings

Keep it short. Every toggle is a decision the user shouldn't have had to make;
only ship the ones that genuinely matter.

- **Sound** on/off (`12`).
- **Haptics** on/off (`12`).
- **Daily reminder** on/off, plus its time (`04`).
- **Notification status** — if permission is denied, say so plainly and offer a
  link to system settings (`04`).
- Standard footer: version, privacy, support/contact, and **art attribution**.

**Attribution is a licence obligation, not a courtesy.** The asset pack requires
credit to `limezu.itch.io` (`14`). The settings footer is its home in-app; it
also belongs in App Store metadata. This ships in v1 — it is not a polish item to
defer.

Settings is SwiftUI chrome and uses the **pixel TTF** tier (`01`). It is off-scene
so grid-perfection isn't required — but it must still look like it belongs to the
same app.

## Accessibility

- **Reduced motion** — honor `accessibilityReduceMotion`. Sprite animation,
  transitions, and micro-animations must have a calmer path that still
  communicates state (`05`). Reduced motion must not mean "state changes become
  invisible."
- **VoiceOver** — every control labeled. Critically: the **bitmap text is not
  text** to the system. Timer digits, coin counts, and ♦ quantities are sprites,
  so they need explicit accessibility labels and values, or they simply don't
  exist to a VoiceOver user.
- **The room is sprites too.** With the main screen now a top-down scene (`06`),
  almost nothing on it is a native control: the baker, the oven, and the display
  case are all `SKNode`s. The scene needs explicit accessibility elements —
  minimally the case (tappable, `08`) and a description of what the baker is
  doing, since "the baker is working" is state the sighted user reads at a glance
  and a VoiceOver user otherwise cannot reach at all.
- **In-world tap targets must meet minimum hit size.** A single 16×16 tile at ×2
  is 32pt, which does **not** clear the 44pt minimum — so a tap region can no
  longer be one tile. It must span the fixture's full extent, and where that is
  still under 44pt in either axis, be padded out beyond the sprite. The display
  case's region already spans the whole counter line and three tiles of height,
  so it clears; anything tappable added later has to be checked, not assumed.
- **Dynamic Type where it fits** — chrome should respond to text size. The pixel
  scene cannot scale fractionally (`01`), so it doesn't participate; make sure
  chrome that grows doesn't crowd or clip the scene.
- **Contrast** — the 16-bit palette must still clear contrast requirements for
  text and controls.
- Nothing conveyed by haptics or color alone (`12`).

## Acceptance criteria

- [x] Every toggle takes effect immediately and persists across relaunch.
      Immediacy is asserted where it is felt — the hum and the cues in `12`'s
      tests, the reminder in `04`'s. The relaunch half is `SettingsTests`, and
      the case worth having it for is a default-on toggle switched *off*:
      `bool(forKey:)` cannot tell that from "never set", so sound turned off
      would come back on at every launch.
- [x] With notifications denied, settings states this clearly and links to system
      settings. Stated once, where the user came looking, saying what stops
      working and no more (`04`).
- [x] With reduce-motion enabled, the app remains fully usable and every session
      state change is still perceivable. `05` already proved every state is
      *reachable*; the criterion here is the harder one, since two reachable
      states can still look identical once the animation between them is gone.
      Asserted by comparing what a still frame of the room says — oven,
      countdown, counter — across every phase, and what the narration says.
      How the calm path *feels* is still a device pass, as `05` noted.
- [x] VoiceOver can read the remaining time, the coin balance, the display case
      contents, and what the baker is currently doing. Coins were moved into
      chrome by `06`; the other three are `RoomNarration` read out by explicit
      elements over the scene.
- [x] Every in-world tap target is reachable by VoiceOver and meets minimum hit
      size. Checked as geometry on every supported iPhone, in both directions —
      that the case clears 44pt unaided, and that a one-tile region does not,
      so the padding cannot quietly start covering for a shrinking fixture.
- [x] `limezu.itch.io` attribution is present in the settings footer, alongside
      VileR's, which the font's ShareAlike requires (`01`, `NOTICE.md`).
- [x] Chrome at the largest supported Dynamic Type size does not clip or crowd
      the bakery scene. Structural rather than placed: `ChromeLayout` takes a
      size and two safe-area insets and *no text size at all*, so the room's
      geometry cannot depend on one. The tray is authored deep enough and wide
      enough to hold the largest step without growing, which is measured against
      the real glyph widths on the narrowest phone.
- [x] No control communicates its state through color alone. Audited: a locked
      recipe carries a padlock as well as its drained colour (`10`); a stepper
      at its bound is `disabled` as well as dimmed; a streak of nothing loses
      its *number*, not just its saturation; the switches are system switches
      with a knob position. The one thing that failed the spirit of it was the
      inverse — links in the settings footer signalling that they were controls
      by nothing whatsoever — and they are underlined now.

## How it is built

- **The settings screen** (`App/SettingsTrayView.swift`) is spec 06's entry,
  finished. The list is deliberately the same length it was: sound, haptics, the
  reminder and its time, the permission notice, and the footer. Every toggle
  writes straight through to `Settings` and asks the app layer to reconcile what
  it affects, because scheduling and audio never belong to a view (`04`, `12`).
- **It is a side tray, not a sheet** (`ChromeLayout.settingsTray`): the whole
  height of the viewport, most of its width, presented as an overlay in
  `MainScreenView` the way the recipe book is. A column of switches over a
  footer wants height, which is the one thing a bottom sheet cannot give it —
  at the `.medium` detent the footer was below the fold and the reminder's time
  picker landed on the grabber. It comes in from the **leading** edge, the end
  of the chrome tray the gear sits at (`06`), so the drawer opens out from under
  its own control; it stops short of the trailing edge so a strip of room stays
  visible beside it and the tray reads as pulled over the bakery rather than
  navigated to. Covering the viewport means covering the status bar, so it caps
  its own top band in `PixelInk.leather`: the clock is pinned to light content
  because it sits on the chrome tray (`06`), and cream under white glyphs is the
  one place that pinning would come out unreadable.
- **The footer** gained privacy and support. Privacy is a *statement* rather than
  a link because there is nothing to link to — the app has no networking code at
  all, and every byte it keeps is the JSON in Application Support and the
  preferences on this screen (`02`). A page saying that would say less than the
  sentence does.
- **`RoomNarration`** (`App/RoomNarration.swift`) is where this spec's sharpest
  point lands: the bitmap text is not text, and the room is sprites, so nothing
  on the main screen exists to the system unless it is written out. One pure
  function per fact, mapped out of the phase the app layer already owns — the
  same shape as `BakerDirector`, and for the same reason: what the app *says* is
  then assertable in a test rather than only off a device with VoiceOver on.
  The countdown is spelled as units rather than passed through as `24:30`, which
  is read as punctuation or as a time of day.
- **The room's elements** are a SwiftUI overlay in `MainScreenView`, sized from
  `RoomPlan` and hit-testing disabled so the scene keeps the actual tap and
  stays the single path to `.caseTapped`. Three of them, which is what the
  criteria name: the oven carries the remaining time, the baker carries what it
  is doing, and the case carries today's contents and the way into the sheet.
  The baker's position comes from the *phase*, not from the sprite — the app
  layer may not reach into the scene's nodes (`05`), and the phase already says
  which fixture the walk ends at.
- **`grown(toAtLeast:within:)`** is the minimum-target rule as arithmetic. A
  16×16 tile at ×2 is 32pt, so no in-world region can be one tile; a fixture's
  full extent usually clears it and the baker's never does. It pads out past the
  sprite rather than moving it, and pushes back inside the room rather than
  running off the edge — the display case stands at column 0, which is the case
  that would otherwise pad itself off screen.
- **Dynamic Type** is `ChromeFont.magnification`, and it steps rather than
  scales — see the open question below.
- **Contrast** is measured rather than judged (`PaletteContrastTests`). The app
  is deliberately low-contrast in mood, warm ink on warm paper, which is exactly
  the aesthetic that drifts into unreadable one shade at a time. Every pair
  `PixelInk` puts on screen clears AAA today, and the bar is set there rather
  than at AA for the same reason.
- Chrome text also picked up the **leading** the in-scene tier already had, from
  the same metrics: the TTF's line height is the bare 8-row cell, so every
  wrapped note on the settings sheet was setting solid, with one line's
  descenders in the next line's ascenders. It showed up the moment the footer
  gave the sheet more than one paragraph to wrap.

## Open questions

- ~~The full settings list — trim rather than grow.~~ **Resolved: it stayed the
  length it already was.** Nothing was added but the footer the spec asks for,
  and the honest reason is that no further toggle had a user behind it — every
  one considered was a decision the app should be making itself.
- ~~Whether onboarding can be replayed from here (`11`).~~ **Deferred to `11`,
  and not as a dodge:** there is no onboarding to replay yet, so a control for it
  would be the one thing on this screen that did nothing. It is the only
  candidate left for the list when `11` lands.
- ~~Whether Dynamic Type support has an upper bound beyond which chrome reflows
  rather than scales.~~ **Resolved: it has a bound, and it is one step.** The
  pixel tier can only magnify by whole numbers (`01`), so responding to text size
  means stepping the magnification, not scaling it — and there is exactly one
  step available. At ×3 the tray's readouts still fit their row on the SE; at ×4
  they do not, and the grid offers nothing in between. Both directions are
  asserted against the real glyph widths, so the bound is a measurement rather
  than a preference, and it moves by itself if the tray ever gets roomier.
  - This also closes `01`'s handover. At the default text size a chrome pixel and
    a room pixel are still the same physical size; above it, spec 13 overrides
    that for **text only**, because that is the thing the reader asked to be
    bigger. Icons keep the room's magnification.
  - The honest limitation: half again is real support and is also less than a
    reader asking for AX5 wants. Going further means the recipe book, which is
    the binding constraint — its page is authored art at a fixed 320×480 with
    its text printed on it, and `Start baking` alone outgrows the content column
    at the next whole step. Lifting the bound means a page that is laid out
    rather than drawn, which is `10`'s decision and not this one's.
- ~~Deployment target, which determines the accessibility APIs available.~~
  **iOS 17**, which was already the project's and puts everything used here well
  inside range.
- **A support contact that outlives one person's inbox.** The footer mails
  `elizabeth.ling@uwaterloo.ca` with the version in the subject. That is a real
  address and ships, but it is a personal one, and App Store metadata will want
  the same answer.
- **The device pass.** Everything above is asserted headlessly or shot in the
  simulator. What no test here judges is VoiceOver's actual *traversal order*
  through three overlapping elements floating over a scene, or whether the calm
  path under reduced motion reads as calm rather than as broken. Both need a
  phone in your hand.
