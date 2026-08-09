# 02 — Data Model & Persistence

**Depends on:** nothing. **Blocks:** 03, 07, 08, 09.

## Goal

A small, explicit, local data model that survives app termination and captures
exactly what v1 needs — no more.

The dataset is small. **Do not over-engineer.** SwiftData *or* a `Codable` struct
saved to disk both qualify; UserDefaults is fine for a few counters. Pick one
approach and keep it consistent.

## The two collections are separate

This is a product rule, not just a data one. Keep them separate in **data and
UI**:

- **Recipe book** = *permanent* progression. Unlocked with coins, kept forever.
- **Display case** = *today's output*. Fills as you bake, resets each morning.

A daily reset must never touch the recipe book.

## Entities

### `Recipe`
Static catalogue plus unlock state.
- `id` — stable identifier, safe to persist.
- `name`, `spriteName`
- `price` — coin cost to unlock. Chocolate-chip cookie is `0` / pre-unlocked.
- `isUnlocked` — only chocolate-chip cookie starts unlocked.

The 5–6 recipe definitions themselves are static app content, not user data.
Only unlock state is persisted.

### `BakeSession`
One focus session.
- `id`
- `recipeID`
- `startDate`, `endDate` — `endDate` is the **target** end, stored absolutely.
  See `03`; this is the timer's source of truth.
- `durationMinutes`
- `outcome` — `.inProgress`, `.completed`, `.burned`

At most one session may be `.inProgress` at a time.

### `DisplayCaseDay`
Today's output.
- `date` — the day key (see day-boundary rules below).
- `treats` — recipe IDs with quantities, in completion order.
- Cleared/rolled over at the daily reset.

### `Wallet`
- `coinBalance`

### `StreakState`
- `currentStreak`, `longestStreak`
- `lastQualifyingDate`
- `graceDaysAvailable`, `graceDayUsedOn`

Do **not** hardcode what qualifies a day — see `09`.

### `DailyRitual`
- `date`
- `intentionText` — the morning "what are you focusing on today?" answer.
- `reflectionText` — the evening reflection.
- `openedAt`, `closedAt`

### `Settings` / counters
Notification preferences, sound/haptics toggles, onboarding-completed flag.
UserDefaults is appropriate here.

## Day boundary rules

- A "day" is defined in the **user's current local calendar**, not UTC.
- Derive the day key from the calendar, and recompute it when the app returns to
  the foreground — the timezone may have changed while backgrounded.
- The display case resets at the first app open on or after the new local day.
  There is no background job; the reset is lazy and evaluated on foreground.
- A reset must **not** clobber an in-flight bake. If a session is `.inProgress`
  across midnight, the session survives; only the display case rolls over. See
  `08`.

## Persistence rules

- All state is **local only** in v1. No iCloud sync (deferred).
- Write on meaningful state change, not on every tick. Timer ticks are derived
  from a stored `Date` and never need to be persisted per-second.
- The app must launch correctly from a cold start with an in-flight session,
  reconstructing remaining time from the stored `endDate`.
- Corrupt or missing store: fail soft into a clean first-run state rather than
  crashing. Never lose the recipe book if the display case data is unreadable —
  another reason to keep the two separable.

## Acceptance criteria

- [x] Killing and relaunching the app preserves coins, unlocks, streak, today's
      display case, and any in-flight session.
- [x] A daily reset clears the display case and leaves recipe unlocks untouched.
- [x] Day keys follow the local calendar and are re-derived on foreground.
- [x] At most one `.inProgress` session exists at any time.
- [x] Coin earn rates and recipe prices live in **one** place, not scattered as
      magic numbers (see `07`).

## How it is built

- `DayKey` + `WallClock` (`Models/DayKey.swift`) are the single day-boundary
  authority `08` and `09` are both required to share.
- Three separate JSON files, each falling back to a clean value on its own:
  `progress.json` (wallet, unlocks, streak), `today.json` (display case,
  ritual), `session.json` (the in-flight bake).
- `BakeryStore` owns every write. `refreshForCurrentDay()` is the lazy reset,
  called on launch and on each foreground.
- `Economy.swift` holds every earn rate and price.

## Open questions

- ~~SwiftData vs. `Codable`-to-disk.~~ **Resolved: `Codable` to disk**, as
  separate JSON files in Application Support.
  - The blast-radius rule above is the deciding factor. "Never lose the recipe
    book if the display case data is unreadable" is one file per concern in
    `Codable`; in SwiftData both live in one store file, and isolating partial
    corruption means fighting the framework.
  - `03` and `09` both require resolution to be a pure function of (persisted
    state, current date). Plain values are trivial to construct in a test;
    SwiftData wants a `ModelContainer` per case.
  - The dataset is a coin count, six unlock flags, one day of treats, a streak
    record and two strings. None of SwiftData's relational querying, migration
    tooling or sync applies, and iCloud sync is deferred.
- ~~Whether completed sessions are retained beyond the current day.~~
  **Resolved: not retained.** A finished session is folded into today's totals
  and the slot is cleared. `TodayState.focusMinutes` plus the treat count plus
  `ritual.openedAt` cover all three candidate streak conditions in `09` — a
  minutes target, one completed session, or simply opening the app — so none of
  them needs session history. The rollover hands the outgoing day's totals back
  as a `RetiredDay` so `09` can evaluate the day the reset just cleared.
  Revisit only if the deferred history/stats screen is pulled into scope.
