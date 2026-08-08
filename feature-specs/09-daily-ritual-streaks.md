# 09 — Daily Ritual & Streaks

**Depends on:** 02, 08. **Blocks:** 11.

This is the wedge. The daily open/close ritual plus the "working alongside your
clone" feeling is what a plain timer doesn't have. **Do not cut it.**

## Part A — The daily ritual

### Opening the bakery
The first time the app is opened each local day, it's like opening the bakery:
shutters up, with a prompt:

> *"What are you focusing on today?"*

- Presented once per day, before the main screen.
- The answer is stored as the day's **intention** (`02`).
- **"Shutters up" can now be literal.** The main screen is a top-down room with a
  door (`06`), and the pack includes animated doors and lighting variants (`14`).
  Opening the bakery as an in-world beat — the room lighting up, the door
  unlocking — is far stronger than a modal over a static screen, and the art for
  it already exists. Worth doing if the schedule allows; not a v1 blocker.
- Must be skippable. A ritual that blocks you from starting work is a ritual
  people delete the app over.
- The intention should remain visible or recallable during the day — it's the
  reason it was asked.

### Closing the bakery
At day's end, a **reflection** prompt.

- Also skippable, also stored (`02`).
- The trigger is an open question — see below.

### Tone
Both prompts carry the app's voice. This is the moment the "companion, not
utility" positioning either lands or doesn't. Copy quality here matters as much
as the code.

## Part B — Streaks

### The streak condition is UNRESOLVED — do not hardcode it

What maintains a streak is **not decided**: a daily focus-minutes target? one
completed session? just opening the app?

Requirements:

- Express the qualifying condition as a **single configurable definition** in one
  place.
- No streak or economy code may embed an assumption about the rule.
- Flag the decision rather than picking one silently.

This is the backbone of the whole promise — it must be lockable later without a
refactor.

### Grace day

Duolingo-style streak freeze. Without it, one missed day makes people rage-quit
the habit you're building. Cheap, high retention impact.

- A defined number of grace days available (count and replenishment: open).
- Consuming a grace day preserves the streak across a missed day.
- The user should understand it was used — a silently-preserved streak teaches
  nothing.

### Evaluation rules

- Evaluate on foreground, against the local calendar day (`02`), alongside the
  display-case reset (`08`).
- A day qualifies at most once.
- Multiple days missed beyond available grace days ends the streak.
- Timezone changes must not award or destroy a streak day spuriously — the day
  key is derived once, in one place.
- Track `currentStreak` and `longestStreak`.

## Acceptance criteria

- [ ] The intention prompt appears exactly once per local day, on first open.
- [ ] Both prompts are skippable and skipping never blocks the core loop.
- [ ] Intention and reflection persist and survive relaunch.
- [ ] The qualifying condition is defined in exactly one place and can be changed
      without touching streak-evaluation, economy, or UI code.
- [ ] A qualifying day increments the streak once, not per session.
- [ ] A missed day with grace available preserves the streak and visibly consumes
      the grace day.
- [ ] A missed day without grace resets `currentStreak` and leaves `longestStreak`
      intact.
- [ ] Crossing a timezone boundary does not create or destroy a streak day.
- [ ] Streak state survives cold start with an in-flight session.

## Gotchas

- Streak and day-rollover edge cases are a named schedule risk. They are fiddlier
  than they look — budget test time, and keep evaluation a pure function of
  (persisted state, current date) so the cases are unit-testable.
- Share the day-boundary logic with `08`. Two implementations will diverge.

## Open questions

- **What exactly is the daily goal, and what maintains the streak?** Lock before
  building any streak or economy code.
- Grace day count, and how/whether it replenishes.
- What triggers the close-of-day reflection: a time of day, the daily reminder
  notification, backgrounding after a qualifying session, or an explicit "close
  the bakery" action? An explicit action fits the ritual framing best but has not
  been decided.
- Whether the reflection is required for the day to qualify. Default assumption:
  no.
