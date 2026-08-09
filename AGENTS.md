---
alwaysApply: true
---

## Definition

- The app's name is Focus Bakery.
- Focus Bakery is a cozy pixel-art bakery focus timer for iOS. The main screen is
  a **single top-down room**: back of house (oven, baker) above, front of house
  (display cases, seating) below.
- Specs live in `feature-specs/`. Start at `00-overview.md`; it indexes the rest.

## Art assets

- In-world art comes from the licensed **Modern Interiors** pack by LimeZu,
  vendored at `assets/`. `feature-specs/14-art-asset-pipeline.md` is
  authoritative for how it is used.
- **`assets/` is gitignored and must stay that way.** The pack's licence
  prohibits redistribution, so committing it — even partially — is a licence
  violation. Do not add exceptions to `.gitignore` for it.
- **Use the 32×32 assets only.** The pack also ships 16×16 and 48×48; mixing tile
  sizes breaks the project's uniform-pixel rule.
- Credit to `limezu.itch.io` is required, ships in the app's settings footer, and
  is not optional.
- Do not author custom in-world art when the pack covers it. The remaining art
  gaps are the bitmap font, UI chrome / the recipe-book modal, and the app icon.

## Commit Discipline

- Commit after every discrete action. Each meaningful change, such as adding a feature, fixing a bug, refactoring, updating docs, or adding a test, must be committed individually before moving on.
- Commit messages must use the intent as the title and a concise summary of what was done as the description or body.
- Do not batch unrelated changes into a single commit.
- If a task involves multiple steps, commit after each step rather than at the end.

## Comments

- By default, avoid writing comments at all.
- If you write one, it should explain why, not what.

## General

- Avoid creating unnecessary types, protocols, or helpers when the logic is only used in one place.
- Keep APIs small, explicit, and easy to inspect.
- Keep commits small and reviewable.
- Build with `xcodebuild` after Swift changes to verify the app still compiles. There is no SwiftPM package here, so `swift build` and `swift test` do not apply.
- Run the test suite via `xcodebuild test` before committing meaningful code changes.
- Build: `xcodebuild build -scheme FocusBakery -destination 'platform=iOS Simulator,name=iPhone 16'`
- Test: `xcodebuild test -scheme FocusBakery -destination 'platform=iOS Simulator,name=iPhone 16'`
- `App/`, `Models/` and `FocusBakeryTests/` are file-system-synchronized groups, so new files in them need no `.xcodeproj` edit.
- Fix warnings before committing.

## Swift

- Prefer Swift concurrency with `async` and `await` over callback-based code.
- Prefer value types such as `struct` and `enum` unless identity semantics are required.
- Avoid force-unwrapping and force-casting outside tests and previews.
- Keep SwiftUI views small. Extract subviews when a view body starts carrying too much state or layout logic.
- Prefer straightforward state flow over custom abstractions.
- Do not add Combine, coordinators, or extra indirection unless the problem actually requires it.

## SwiftUI

- Keep view code declarative and local.
- Prefer a small number of observable models with explicit responsibilities.
- Derive view state where possible instead of syncing duplicated state.
- Reuse shared styling only when there is a real repeated pattern. Do not build a design system for isolated screens.

## SpriteKit

- **Data flows one way: app state → scene.** The `SKScene` renders state; it never owns timer, persistence, notification, or navigation logic.
- Taps inside the scene travel back up to the app layer as events. The scene does not present sheets or mutate model state.
- Every texture loads through the single `filteringMode = .nearest` path. No call site opts out.
- Snap sprite positions to whole grid units and animate in whole grid units. Sub-pixel motion shimmers.
- Never use `SKLabelNode` for timer digits, coin counts, or ★ quantities — those are bitmap-font sprites.

