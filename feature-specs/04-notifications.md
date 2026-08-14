# 04 — Local Notifications

**Depends on:** 03. **Blocks:** 13.

Part of the "not vibe-coded" layer, and functionally essential: timers run
backgrounded, so without the completion notification the core loop breaks.

## Goal

Two local notifications, correctly scheduled and correctly cleaned up, with a
graceful path when permission is denied.

Uses `UNUserNotificationCenter`. No push, no server.

## The two notifications

### 1. Session complete (essential)
- Scheduled **at session start**, for the session's `endDate` (`03`).
- Fires even if the app is suspended or killed.
- Copy should be in voice — the bake is ready, not "Timer finished."
- Opening from the notification lands on the main screen with the completion
  celebration presented.

### 2. Daily "your bakery's ready to open" reminder (gentle)
- Serves the consistency thesis and the daily ritual (`09`).
- User-configurable time, and toggleable off (`13`).
- Repeats daily.
- Should not fire on a day the user has already opened the app / already
  qualified — a reminder to do something you've done is the fastest way to get
  notifications turned off.

## Permission

- **Do not request permission on first launch.** Request it in context, at a
  moment where the value is obvious — the natural point is starting the first
  session, where the completion alert is the payoff. Fold this into onboarding
  (`11`).
- **Denied is a fully supported state.** The app must work completely without
  notifications. Inform the user plainly that completion alerts will not fire,
  once, without nagging.
- Provide a path to system settings from `13` for users who change their mind.
- Handle provisional/limited authorization states without crashing or
  mis-reporting.

## Lifecycle rules

- Cancel the completion notification when a session ends early (burned or
  cancelled). A "your bake is ready!" alert for a bake that burned is the kind of
  detail that makes an app feel thrown together.
- Reschedule rather than duplicate: starting a new session must not leave a stale
  pending request from a previous one.
- Reconcile pending requests on foreground — the persisted session state is the
  truth, and pending notifications should match it.
- Clear delivered notifications for a session once its completion has been
  acknowledged in-app.

## Acceptance criteria

- [ ] Start a session, background the app, wait past `endDate` — the completion
      notification fires. **Verify on a real device**, not Simulator. *Still
      owed, and reworded on the way: as written this criterion cannot pass,
      because backgrounding with more than the grace left to run is a burn under
      `03`, and a burned bake must not be announced. What the device pass has to
      show is the alert firing for a departure taken **inside** the final grace,
      and no alert at all for one taken before it.*
- [x] Cancel a session before it completes — no completion notification fires.
- [x] Start, cancel, start again — exactly one pending completion request exists.
- [x] Deny permission — the app is fully usable, the user is told once that
      alerts are off, and no code path assumes a notification was delivered.
      *The system prompt itself is part of the device pass; everything behind it
      is unit-tested.*
- [x] The daily reminder respects its configured time and its off switch.
      *Scheduling only — delivery on the day belongs to the device pass.*
- [ ] Tapping the completion notification opens to the celebration, not a
      generic launch state. *Needs a delivered notification, so it needs a
      device. The path it lands on is exercised: returning to a resolved bake
      presents the celebration (`03`).*

## Gotchas

- **Local notifications are unreliable to fully validate on Simulator.** Delivery
  and background behavior must be verified on a real device.
- Never make completion *depend* on the notification. The notification informs
  the user; `03` resolves the session from persisted state.
- **Before permission is answered, a scheduled request does not show up as
  pending.** On Simulator, `add` returns no error while authorization is
  `.notDetermined`, and the request is still nowhere to be found in
  `getPendingNotificationRequests`. Do not read an empty pending list on a fresh
  install as a scheduling bug — grant permission first, then read it.

## How it is built

- `NotificationPlan` (`Models/NotificationPlan.swift`) is the whole policy:
  (persisted session, reminder preferences, now) → the set of requests that
  should be pending. Stating the desired set rather than a sequence of edits is
  what makes duplicates and stale requests unreachable — every caller reconciles
  towards the same answer, and none has to know what the last one did.
- **The burn policy is folded into scheduling.** The completion alert is planned
  only for a bake that is running now *and* that `03`'s resolver still calls
  `.completed` **at its own end date**. So the alert is withdrawn the moment the
  app is backgrounded with more than the grace left to run — at the `.background`
  edge, which is the last moment the app can act on a departure it may never
  return from. A bake burned by a force-quit while away therefore announces
  nothing, which is not otherwise reachable: the app is not running to cancel it.
- **What this means for the alert, stated plainly.** Under `03`'s resolved
  policy, any departure taken more than 30 seconds before the end burns the bake,
  so the completion alert has exactly two moments it can legitimately fire: the
  user sat through the bake, or left inside the final grace. In the first the app
  is on screen and suppresses its own banner, because it is already showing the
  celebration. That narrowness is a consequence of `03`, not a bug here — but it
  does mean this spec's "timers run backgrounded, so the notification is the core
  loop" framing is no longer quite true of v1. **Worth the owner's attention**:
  if the alert is meant to carry more weight than that, it is the burn policy
  that has to move, not this.
- `BakeryNotifications` (`App/`) is the only thing that touches
  `UNUserNotificationCenter`, and it decides nothing — `reconcile` brings the
  system into line with the plan. It is idempotent and state-derived, so it runs
  from four edges without any of them agreeing on whose job it is: launch, every
  foreground, backgrounding, and any change to the session. The last of those is
  a view modifier rather than something on the scene, because an `@Observable`
  dependency is registered by the view body pass that reads it — the same lesson
  `03` learned about presenting an outcome.
- The completion alert has one identifier for all time. Adding under an
  identifier that is already pending replaces it, so "exactly one pending
  request" is structural rather than a cancel somebody has to remember.
- The daily reminder is a rolling seven days of dated requests, refilled on every
  foreground and skipping any day already opened. A repeating trigger cannot skip
  a day the user has already shown up for, which is the whole point of the rule.
- `NotificationCenterClient` is a struct of closures around the center. It exists
  so tests can assert what *would* have been scheduled — the only part of this
  spec judgeable without a device in hand.
- Permission is requested from the start-a-bake action and nowhere else. A
  denial sets `denialNotice`, which the UI shows once and then acknowledges,
  mirroring `pendingOutcome`; the fact is persisted so "once" survives a
  relaunch. `deliversAlerts` treats a provisional grant as delivery, so quiet
  notifications are never reported as refused.
- There is deliberately no notification-tap handler. Opening from a notification
  makes the scene active, and `03` already resolves the bake from persisted state
  and presents the celebration on every foreground. A second path to the same
  place would be the beginning of completion depending on the notification.

### How they were checked

The policy is unit-tested as a pure function — the completion alert planned,
withheld from a doomed bake, kept for a departure inside the final grace, and
reused under one identifier across a cancel and a restart; the reminder window
respecting its time, its off switch, a day already opened, and a timezone move.
The adapter is tested through a fake center that models the one behaviour the
design leans on: adding under an existing identifier replaces rather than
duplicates.

The wiring no unit test reaches was driven on Simulator with a bake seeded
straight into the store, with the adapter temporarily logging every call it made.
Launch reconciled and scheduled one `bake.completion`; backgrounding withdrew it
before suspension; returning inside the grace put it back, one request throughout.

**Still owed: the real-device pass.** Delivery past `endDate` from a suspended
app, the permission prompt itself, and tapping a delivered alert into the
celebration are all device-only, and none of them has been run.

## Open questions

- ~~Default time for the daily reminder, and whether it is on or off by
  default.~~ **Resolved: 9am local, off by default.**
  - Nine in the morning because the reminder is the bakery *opening*; it wants
    the start of a day rather than the middle of one. It is a preference, so the
    cost of the default being wrong for someone is one trip to settings (`13`).
  - Off, because permission is asked for in context for the *completion* alert.
    Spending that grant on a daily nudge the user never asked for is exactly how
    an app teaches people to deny it. `09`'s ritual or `11`'s onboarding is the
    honest place to offer it.
- Exact copy for both notifications — still open, and deliberately so: `11`
  writes every string in the app in one voice, in one pass. Provisional strings
  are in place and held in one place each (`NotificationPlan.Copy`,
  `BakeryNotifications.Copy`) so that pass has somewhere to go.
