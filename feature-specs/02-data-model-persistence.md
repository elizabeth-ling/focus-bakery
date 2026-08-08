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

- [ ] Killing and relaunching the app preserves coins, unlocks, streak, today's
      display case, and any in-flight session.
- [ ] A daily reset clears the display case and leaves recipe unlocks untouched.
- [ ] Day keys follow the local calendar and are re-derived on foreground.
- [ ] At most one `.inProgress` session exists at any time.
- [ ] Coin earn rates and recipe prices live in **one** place, not scattered as
      magic numbers (see `07`).

## Open questions

- SwiftData vs. `Codable`-to-disk. Either is acceptable; decide once, early, and
  record the decision here.
- Whether completed sessions are retained beyond the current day. v1 has no
  history/stats screen (deferred), so retention is only needed if streak
  evaluation requires it — which depends on the unresolved streak condition.
