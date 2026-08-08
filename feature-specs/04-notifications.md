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
      notification fires. **Verify on a real device**, not Simulator.
- [ ] Cancel a session before it completes — no completion notification fires.
- [ ] Start, cancel, start again — exactly one pending completion request exists.
- [ ] Deny permission — the app is fully usable, the user is told once that
      alerts are off, and no code path assumes a notification was delivered.
- [ ] The daily reminder respects its configured time and its off switch.
- [ ] Tapping the completion notification opens to the celebration, not a
      generic launch state.

## Gotchas

- **Local notifications are unreliable to fully validate on Simulator.** Delivery
  and background behavior must be verified on a real device.
- Never make completion *depend* on the notification. The notification informs
  the user; `03` resolves the session from persisted state.

## Open questions

- Default time for the daily reminder, and whether it is on or off by default.
- Exact copy for both notifications — should be written in the app's voice
  alongside the rest of the onboarding/empty-state copy (`11`).
