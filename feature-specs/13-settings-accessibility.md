# 13 — Settings & Accessibility

**Depends on:** 04, 12. **Blocks:** nothing.

Part of the "not vibe-coded" layer.

## Goal

A small, honest settings screen, and an app that works for people who need
reduced motion, VoiceOver, or larger text.

## Settings

Keep it short. Every toggle is a decision the user shouldn't have had to make;
only ship the ones that genuinely matter.

- **Sound** on/off (`12`).
- **Haptics** on/off (`12`).
- **Daily reminder** on/off, plus its time (`04`).
- **Notification status** — if permission is denied, say so plainly and offer a
  link to system settings (`04`).
- Standard footer: version, privacy, support/contact, and **art attribution**.

**Attribution is a licence obligation, not a courtesy.** The asset pack requires
credit to `limezu.itch.io` (`14`). The settings footer is its home in-app; it
also belongs in App Store metadata. This ships in v1 — it is not a polish item to
defer.

Settings is SwiftUI chrome and uses the **pixel TTF** tier (`01`). It is off-scene
so grid-perfection isn't required — but it must still look like it belongs to the
same app.

## Accessibility

- **Reduced motion** — honor `accessibilityReduceMotion`. Sprite animation,
  transitions, and micro-animations must have a calmer path that still
  communicates state (`05`). Reduced motion must not mean "state changes become
  invisible."
- **VoiceOver** — every control labeled. Critically: the **bitmap text is not
  text** to the system. Timer digits, coin counts, and ★ quantities are sprites,
  so they need explicit accessibility labels and values, or they simply don't
  exist to a VoiceOver user.
- **The room is sprites too.** With the main screen now a top-down scene (`06`),
  almost nothing on it is a native control: the baker, the oven, and the display
  case are all `SKNode`s. The scene needs explicit accessibility elements —
  minimally the case (tappable, `08`) and a description of what the baker is
  doing, since "the baker is working" is state the sighted user reads at a glance
  and a VoiceOver user otherwise cannot reach at all.
- **In-world tap targets must meet minimum hit size.** A 32×32 sprite at ×2 is
  64pt, which clears it — but only if the tap region is the sprite's full extent
  and not a smaller inner rect.
- **Dynamic Type where it fits** — chrome should respond to text size. The pixel
  scene cannot scale fractionally (`01`), so it doesn't participate; make sure
  chrome that grows doesn't crowd or clip the scene.
- **Contrast** — the 16-bit palette must still clear contrast requirements for
  text and controls.
- Nothing conveyed by haptics or color alone (`12`).

## Acceptance criteria

- [ ] Every toggle takes effect immediately and persists across relaunch.
- [ ] With notifications denied, settings states this clearly and links to system
      settings.
- [ ] With reduce-motion enabled, the app remains fully usable and every session
      state change is still perceivable.
- [ ] VoiceOver can read the remaining time, the coin balance, the display case
      contents, and what the baker is currently doing.
- [ ] Every in-world tap target is reachable by VoiceOver and meets minimum hit
      size.
- [ ] `limezu.itch.io` attribution is present in the settings footer.
- [ ] Chrome at the largest supported Dynamic Type size does not clip or crowd
      the bakery scene.
- [ ] No control communicates its state through color alone.

## Open questions

- The full settings list — trim rather than grow.
- Whether onboarding can be replayed from here (`11`).
- Whether Dynamic Type support has an upper bound beyond which chrome
  reflows rather than scales.
- Deployment target, which determines the accessibility APIs available.
