# 03 — Focus Session Timer

**Depends on:** 02. **Blocks:** 04, 05, 07, 08.

The timer is the product's spine and its edge cases are fiddlier than they look.
Get this exactly right before layering art on it.

## Goal

A focus session that runs accurately across backgrounding, app termination,
midnight, and timezone changes, and that carries a soft commitment: leave and
your bake burns.

## Correctness rules (non-negotiable)

1. **Store the target end `Date`.** Compute remaining as `endDate - Date()` on
   each tick, from wall-clock.
2. **Never rely on a running in-memory clock or counter.** It drifts, and it dies
   when the app is backgrounded or killed.
3. **Schedule the completion local notification at start time** (see `04`), so it
   fires even if the app is suspended or killed.
4. The on-screen countdown is a *display* derived from the stored `Date`. A
   display refresh timer is fine; it must never be the source of truth.

## Session lifecycle

```
idle ──start(recipe, duration)──▶ inProgress ──endDate reached──▶ completed
                                     │
                                     └──user quits / abandons──▶ burned
```

- **start** — persist a `BakeSession` with `startDate`, computed `endDate`,
  `recipeID`, `durationMinutes`, outcome `.inProgress`. Schedule the completion
  notification. Move the sprite to its working state (`05`).
- **completed** — award coins (`07`), add the treat to the display case (`08`),
  play the completion beat + sound/haptic (`05`, `12`), update streak inputs
  (`09`).
- **burned** — no coins, no treat. The session is recorded as `.burned`.

Completion must be evaluated **lazily on foreground** as well as live, because
the app may have been suspended when `endDate` passed. Returning to a session
whose `endDate` is in the past resolves it as completed immediately, with the
celebration presented on return.

## Soft commitment — "burn on quit"

v1 uses **soft commitment only**. There is no app blocker, no Family Controls, no
entitlement.

- Detect leaving via SwiftUI **`scenePhase`**.
- Backgrounding mid-session is the burn trigger. Define the exact policy before
  implementing — see open questions; a brief grace period is likely wanted so
  that an accidental swipe or an incoming call doesn't destroy a 50-minute
  session.
- Quitting/killing the app mid-session must resolve on next launch: if the
  session was abandoned per policy, it is `.burned`; if `endDate` has passed
  within policy, it is `.completed`.
- The user may also cancel deliberately. Confirm before destroying an in-flight
  bake — this is a destructive action and the whole mechanic depends on it
  feeling weighty, not accidental.

## Edge cases — handle and test explicitly

| Case | Required behavior |
|---|---|
| **Backgrounding mid-session** | Recompute remaining from wall-clock on return. Never resume a paused counter. |
| **App killed mid-session** | Reconstruct from persisted `endDate` on cold launch. |
| **Midnight day rollover** | The session survives. The display case resets (`08`) without losing the in-flight bake. |
| **Timezone / clock change** | Remaining time follows the stored absolute `Date`, not a local elapsed count. Re-derive the day key on foreground (`02`). |
| **Device clock moved backwards** | Do not award completion for a session whose `endDate` has not genuinely passed; guard against negative-elapsed nonsense rather than crashing. |
| **Denied notification permission** | The timer still works fully and the user is informed that completion alerts will not fire (`04`, `13`). |
| **Duration of zero / absurd** | Constrain duration at the input layer (`10`), not here. |

## Acceptance criteria

- [ ] Start a session, background the app for longer than the duration, return —
      the session resolves as completed with correct coins and treat, exactly
      once.
- [ ] Start a session, force-quit, relaunch — state matches the burn/complete
      policy; no double-award, no lost session.
- [ ] Start a session before midnight, return after — the session is intact and
      the display case has reset correctly.
- [ ] Change the device timezone mid-session — remaining time is unchanged.
- [ ] With notifications denied, a full session still completes and awards
      correctly.
- [ ] Coins and treats are awarded exactly once per completed session, even if
      completion is evaluated by both the live path and the foreground path.

## Testability

- Keep the "now" source injectable so tests can drive wall-clock scenarios
  without sleeping. This is one of the few places extra indirection earns its
  keep; do not generalize it further than the timer needs.
- Session resolution should be a pure function of (persisted session, current
  date) so all the table cases above are unit-testable.

## Open questions

- **Burn policy specifics:** is there a grace period for backgrounding, and how
  long? Does a phone call or a system alert count as leaving? Does locking the
  screen count? These materially change how the mechanic feels and are not yet
  decided.
- Whether a session can be paused at all. Earlier planning implied no pause;
  confirm.
