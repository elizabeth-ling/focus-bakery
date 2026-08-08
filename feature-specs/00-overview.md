# 00 — Product Overview & Spec Index

## What we're building

Focus Bakery is a cozy **16-bit pixel-art bakery focus timer** for iOS. Focus time
is "bake time": you start a recipe, a baker sprite works alongside you, and
finishing the timer yields a treat and coins.

The wedge is **companion / daily consistency** — a start-of-day and end-of-day
ritual plus streaks. Closest comparables are Finch and Spirit City: Lofi
Sessions, *not* Forest.

**North star:** it must feel crafted, Stardew Valley level — explicitly not
"vibe-coded, thrown together in a day." This bar is also the scoping tool: if a
change doesn't make v1 *feel* better, it's a candidate to cut.

## Art: the Modern Interiors pack

In-world art comes from the licensed **Modern Interiors** pack by LimeZu,
vendored (gitignored) at `assets/`. See `14` for the full pipeline,
licensing, and constraints.

This changed the shape of the project in three ways, and they propagate through
most of the specs below:

1. **The pack is top-down**, so the main screen is a **single top-down room**
   rather than a side-on workbench above a list. Back of house (oven, baker) sits
   above front of house (display cases, seating) within one continuous space.
2. **The display case is an in-world object**, not a SwiftUI list. The baker
   physically carries each finished treat from the oven to the case.
3. **Art is no longer the critical path.** What remains to author is the font
   (`01`), UI chrome and the recipe-book modal (`10`), and the app icon.

Attribution to `limezu.itch.io` is a **licence obligation** and ships in v1
(`13`). The pack must never be committed to the repo (`14`).

## Tech stack

Native **Swift**, Apple-only. Do **not** build a web/WKWebView wrapper.

| Layer | Choice | Owns |
|---|---|---|
| App shell | SwiftUI | Navigation, chrome, menus, settings, modals, lists, `scenePhase`, persistence, notification scheduling |
| Animated scene | SpriteKit via `SpriteView` | The top-down bakery room, baker sprite and walk choreography, animated fixtures, in-scene bitmap text, per-frame updates |
| In-world art | Modern Interiors (LimeZu), 32×32 | Room, fixtures, baker, treats — see `14` |
| Persistence | SwiftData *or* `Codable` to disk | Small dataset — do not over-engineer. UserDefaults is fine for a few counters |
| Notifications | `UNUserNotificationCenter` | Session-complete and daily reminder |

**Boundary rule (strict):** data flows one way, app state → scene. The `SKScene`
renders state; it does not own timer or persistence logic. Taps inside the room
travel back up to the app layer as events; the scene never presents UI itself.

**Target OS:** iOS. Environment as of Aug 2026 — iOS 26 current, Xcode 26.x,
year-based versioning. Exact deployment target is **TODO — unresolved**.

## v1.0 scope — "The Bakery Opens"

Full-screen top-down bakery room; baker with idle / walk / working / deliver /
celebrate states driven by session state, plus animated oven and display case;
"+" → recipe-book modal; correct timer + completion notification +
burn-on-quit; minutes → coins; 5–6 recipes with chocolate-chip cookie as the
only starter; in-world display case that fills and resets daily; open-intention /
close-reflection ritual; streak + grace day; sound, haptics, onboarding, empty
states, local persistence.

## Explicitly deferred — do NOT implement in v1

- **App blocker / Family Controls / DeviceActivity / ManagedSettings.** v1 uses
  **soft commitment only**: "leave and your bake burns" plus backgrounding
  detection via `scenePhase` (no entitlement needed). Do not add the Family
  Controls entitlement or block-related APIs to v1.
- Live Activity / Dynamic Island / Lock Screen widget.
- Player-controlled movement, pathfinding, or tap-to-walk. The baker moves on
  fixed authored routes driven by session state only (`05`).
- Character customization. The baker is one pre-composited sprite (`14`).
- Ambient room animations beyond what session state requires.
- History/stats heatmap, iCloud sync, workspace customization, seasonal
  collections.

Do not pad the recipe list past 5–6. A thinner-but-perfect launch beats a padded
one.

> Note: earlier planning was self-contradictory about Live Activity — recommended
> as an "early" win in one place, listed as a v1.1 fast-follow in another. Treated
> here as **deferred (v1.1)**. Confirm with the owner if it should be pulled into
> v1.

## Open decisions — do not hardcode

These are unresolved. Surface the decision rather than guessing:

1. **Daily goal & streak condition** — focus-minutes target? one session? just
   opening the app? Keep it a single configurable definition (see `09`).
2. **Monetization model** — coins-earned-only with a premium unlock vs.
   seasonal-collection IAPs. Do not wire an assumption into the coin economy.
3. **Coin economy balance** — earn rates vs. prices will be tuned iteratively.
   Keep values in one place, never scattered as magic numbers (see `07`).

## Spec index

| # | Spec | Depends on |
|---|---|---|
| 14 | [Art asset pipeline](14-art-asset-pipeline.md) | — |
| 01 | [Pixel rendering pipeline](01-pixel-rendering-pipeline.md) | 14 |
| 02 | [Data model & persistence](02-data-model-persistence.md) | — |
| 03 | [Focus session timer](03-focus-session-timer.md) | 02 |
| 04 | [Notifications](04-notifications.md) | 03 |
| 05 | [Bakery scene & baker sprite](05-bakery-scene-sprite.md) | 01, 03, 14 |
| 06 | [Main screen shell](06-main-screen-shell.md) | 01, 05, 08, 14 |
| 07 | [Recipe book & coin economy](07-recipe-book-economy.md) | 02, 03 |
| 08 | [Display case & daily reset](08-display-case-daily-reset.md) | 02, 03, 05, 14 |
| 09 | [Daily ritual & streaks](09-daily-ritual-streaks.md) | 02, 08 |
| 10 | [Recipe-book timer modal](10-recipe-book-modal.md) | 01, 07, 14 |
| 11 | [Onboarding & empty states](11-onboarding-empty-states.md) | 06, 09 |
| 12 | [Sound & haptics](12-sound-haptics.md) | 03, 05 |
| 13 | [Settings & accessibility](13-settings-accessibility.md) | 04, 12 |

## Build order

`14` is listed first in the index because it precedes `01` in dependency order,
despite its number — it was added after the pack was adopted, and renumbering
thirteen files of cross-references wasn't worth it.

Build `14`, `01`, and `02` first and **prove the pixel pipeline before building
on top of it** — a crisp bitmap `00:00` at integer scale on multiple device
sizes, plus one pack sprite rendering at the right tile size. Then the core loop
(`03`, `04`, `07`, `10`) on placeholder colored blocks, validating the loop feels
right *before* wiring real art. Then daily systems (`08`, `09`), then the scene
and its choreography (`05`, `06`), then the "not-vibe-coded" layer (`11`, `12`,
`13`).

Art moved off the critical path when the pack was adopted, so the old
art-production phase is now a much shorter atlas-slicing and room-layout task —
plus the font and UI chrome, which are genuinely still to author.

## Admin track

Long-lead items with external approval times. Start them early so they never
become the thing blocking a build:

- Enroll in the Apple Developer Program.
- Reserve the app name in App Store Connect.
- **Submit the Family Controls entitlement request during the daily-systems
  phase**, even though the blocker is a v1.1 feature. Approval time is variable
  and you want it granted before building v1.1.

## Conventions

No Xcode project exists yet. These are intended conventions — align with real
code once it lands.

- Standard Swift API Design Guidelines; SwiftUI-idiomatic views; keep views
  small and state out of `SKScene`.
- Folders (proposed, TODO to confirm): `App/`, `Scene/`, `Models/`, `Timer/`,
  `Views/`, `Resources/`.
- Naming: views `…View`, SpriteKit nodes `…Node`, the scene `BakeryScene`.
- Build/run/test commands are **TODO** until the Xcode project exists. Expect
  `xcodebuild -scheme <name> …`; the scheme name is not yet decided.

## Device-only constraints

- **Local notifications** are unreliable to fully validate on Simulator. Verify
  completion notifications and background delivery on a **real device**.
- Family Controls (v1.1) is device-only and needs an Apple entitlement. Not
  relevant to v1; noted so nobody tries to test it in Simulator.

## Top risks

- **Art scope creep**, in its new form. The pack removed the "draw everything"
  risk and replaced it with "browse everything." The pack is large and the room
  layout is already solved by its ice-cream-shop reference (`14`) — start there
  rather than exploring. Custom animations, character customization, and ambient
  fixtures are all out of scope for v1 and all tempting.
- **Mixed tile sizes.** The pack ships 16/32/48 side by side; using more than one
  breaks the uniform-pixel rule at its most load-bearing point (`01`, `14`).
- **Protect the polish phase.** When behind, do not raid `11`/`12`/`13`. Flag the
  tradeoff instead.
- The scene state machine (`05`) must be interruptible from any state. Walk
  choreography that assumes animations run to completion will strand the baker
  mid-room on cancel or on foregrounding into an already-finished session.
- Timer edge cases (background return, midnight rollover, timezone shifts,
  denied notification permission) are fiddlier than they look.
- Economy tuning running long.
- **Licence compliance** is binary, not best-effort: no pack files in the repo,
  attribution shipped in-app and in store metadata (`14`).
