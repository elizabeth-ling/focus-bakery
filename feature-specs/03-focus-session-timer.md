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
- Backgrounding mid-session is the burn trigger, with a **30-second grace** (see
  open questions, now resolved). `.inactive` is not a departure: an incoming
  call, Control Centre, the app switcher and a Face ID sheet all land there, and
  the user has not gone anywhere.
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

- [x] Start a session, be away across `endDate` **within policy**, return — the
      session resolves as completed with correct coins and treat, exactly once.
      *Reworded.* The original read "background the app for longer than the
      duration", which the resolved burn policy contradicts: a departure that
      outlasts the bake is the definition of a burn, so as written this
      criterion could only pass by gutting the mechanic. What it was really
      testing is the lazy path — a bake whose `endDate` passed while the app was
      suspended must resolve on return rather than on a live tick — and that is
      what is now asserted, both here and from a cold launch. The literal
      scenario is pinned too, as a burn.
- [x] Start a session, force-quit, relaunch — state matches the burn/complete
      policy; no double-award, no lost session.
- [x] Start a session before midnight, return after — the session is intact and
      the display case has reset correctly.
- [x] Change the device timezone mid-session — remaining time is unchanged.
- [ ] With notifications denied, a full session still completes and awards
      correctly. **Belongs to `04`** — nothing here imports `UserNotifications`,
      and completion is resolved from persisted state by construction, so there
      is no code path to deny yet. Re-check when `04` schedules anything.
- [x] Coins and treats are awarded exactly once per completed session, even if
      completion is evaluated by both the live path and the foreground path.

### How they were checked

The wall-clock cases are unit tests over an injectable clock — the table above
plus the criteria, driven forwards, backwards and sideways into another timezone
without sleeping.

The `scenePhase` wiring is the part no unit test reaches, so it was exercised on
the simulator by seeding a bake straight into the store and driving the app with
`simctl`: leave, outstay the grace, return — burned, no coins, no treat, alert
shown; leave with less than the grace left to run and return two minutes later —
completed, one treat, coins awarded once; leave and return inside 15 seconds —
still baking, with the departure spent rather than banked.

That pass earned its keep. It found two bugs the unit tests could not see: the
display tick kept running for a moment after backgrounding and cleared the
departure mark before the app suspended, making a burn unreachable; and the
outcome alert read its value only inside a `Binding` closure, which registers no
`@Observable` dependency, so a bake resolved at launch never reached the screen.

## Testability

- Keep the "now" source injectable so tests can drive wall-clock scenarios
  without sleeping. This is one of the few places extra indirection earns its
  keep; do not generalize it further than the timer needs.
- Session resolution should be a pure function of (persisted session, current
  date) so all the table cases above are unit-testable.

## How it is built

- `SessionResolution` (`Models/SessionResolution.swift`) is the whole timer:
  `(persisted session, current date) → idle | baking | completed | burned`. No
  counter exists anywhere in the app to drift or die.
- `SessionState.leftForegroundAt` persists the departure alongside the bake. It
  is the only evidence a user who force-quits while away ever left, so it has to
  survive on disk, and it is cleared with the bake it belongs to.
- `BurnPolicy.backgroundGrace` is the single constant behind the mechanic.
- `BakeryStore.noteLeftForeground()` and `noteReturnedToForeground()` are the two
  `scenePhase` edges; `resolveInFlightSession()` is the shared resolution both
  they and the display tick go through. Awarding is exactly-once because it runs
  through `finishActiveSession`, and whichever caller arrives second finds an
  empty slot.
- The countdown is a display: it re-reads the store each second and renders what
  it finds.
- Scheduling the completion notification at start time is left to `04`, which
  depends on this spec. Nothing here assumes a notification was delivered.

## Open questions

- ~~**Burn policy specifics:** is there a grace period for backgrounding, and how
  long? Does a phone call or a system alert count as leaving? Does locking the
  screen count?~~ **Resolved: a 30-second grace on `.background` only.**
  - Thirty seconds absorbs a mis-swipe or a glance at a banner without being
    long enough to go and do something else. It is spent per departure and never
    banked, so leaving repeatedly cannot be used to farm it.
  - **A call or a system alert does not count.** Those leave the scene
    `.inactive`, which is never treated as leaving — the distinction is free,
    since iOS already draws it.
  - **Locking the screen does count**, and this is the unsatisfying half. No
    public API reliably tells a lock apart from a swipe home: the app is
    backgrounded either way, and the usual signals (protected-data
    availability, screen brightness) need a passcode set and a background task
    to sample, then still guess wrong for some users. A rule that is strict is
    better than one that silently fails, so a lock burns like any other
    departure. Worth revisiting if `13` ever wants a "phone face down" mode,
    which would be the honest way to serve this.
- ~~Whether a session can be paused at all.~~ **Resolved: no pause**, confirming
  the earlier planning. A pause button is an escape hatch that undercuts
  burn-on-quit, and it would cost the property this spec is built on: remaining
  time could no longer be `endDate - now`, because `endDate` would have to be
  pushed forward on resume and the notification rescheduled with it.
