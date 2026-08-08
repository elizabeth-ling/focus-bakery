# 11 — Onboarding & Empty States

**Depends on:** 06, 09. **Blocks:** nothing.

Part of the "not vibe-coded" layer. **Protect this work** — when the schedule
slips, do not raid the polish phase to feed art scope. Flag the tradeoff instead.

## Goal

First run teaches the loop and sets the tone; every empty state proves the app
is crafted.

## Onboarding

Teach exactly one thing: **your focus time is bake time.** Start a recipe, the
baker works alongside you, finish and collect a treat and coins.

Requirements:

- Short. The loop is simple; a long tutorial contradicts the product.
- Sets the **tone** as much as it explains — the companion feeling starts here.
- Ends by landing the user in the real loop, ideally starting their first bake,
  not on an empty main screen.
- **The room needs one moment of orientation.** A top-down bakery has in-world
  affordances a list doesn't — the display case is tappable (`08`), and "+" may
  itself be in-world (`06`). A first-time user should not have to discover that
  the case responds to touch. One light touch is enough; do not turn this into a
  tour of the room.
- Request notification permission **in context** during the first session start,
  where the payoff is obvious (`04`). Not on cold launch.
- The first-day ritual prompt (`09`) should feel like part of the arrival, not a
  second, competing intro.
- Completion is persisted (`02`) — onboarding never runs twice.

## Empty states

Empty states are where cozy apps prove they're crafted. Each of these needs
deliberate art and copy, not a centered grey label.

| State | Context | Should convey |
|---|---|---|
| **Day one** | Brand new install | Invitation. The bakery is yours and it's opening. |
| **Empty display case** | Fresh morning, nothing baked yet | *Ready to open* — not absence, not failure. The daily reset is intentional (`08`). The case is an object in the room, so this is a clean, lit, empty case — not a blank panel. |
| **Recipe book with one recipe** | Before any unlock | The locked recipes are visible goals, with prices (`07`). This state should motivate, not read as broken. |
| **Single unlocked recipe in the timer modal** | Fresh install (`10`) | The arrows must look intentional rather than non-functional. |
| **No streak yet** | Day one | Neutral and inviting, never a zero that reads as a scold. |
| **Notifications denied** | After a denial (`04`) | Plainly informs, once, that completion alerts won't fire. Not a nag. |

## Voice

The app is a companion, not a utility. Every string here — onboarding, empty
states, ritual prompts (`09`), notification copy (`04`) — should be written
together, in one pass, by one voice. Copy written per-screen ends up sounding
like different products.

## Acceptance criteria

- [ ] Onboarding runs exactly once and is persisted.
- [ ] Notification permission is requested in context, never on cold launch.
- [ ] Every state in the table above has intentional art and copy — none falls
      back to an unstyled default.
- [ ] A brand-new install can reach a completed first bake without confusion and
      without hitting a dead-end empty state.
- [ ] Onboarding does not collide with the day-one ritual prompt.

## Open questions

- Whether onboarding is a sequence of screens or a guided first bake. The guided
  first bake fits the product better but costs more.
- All copy — unwritten.
- Whether onboarding can be replayed from settings (`13`).
