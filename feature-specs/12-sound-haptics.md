# 12 — Sound & Haptics

**Depends on:** 03, 05. **Blocks:** nothing.

**Treat as core, not polish.** This is huge for the Stardew feel and it is a
named part of the "not vibe-coded" layer. Protect it from schedule compression.

## Goal

The app sounds and feels like a place, and the completion moment is satisfying.

## Sound

| Sound | When | Notes |
|---|---|---|
| **Ambient bakery hum** | While the app is open, especially during a session | The "working alongside someone" texture. Loops without an audible seam. |
| **Completion ding** | Session completes | The payoff. Satisfying, not shrill. |
| UI ticks | Recipe arrows, duration ±, coin award, treat lands in case | Small, restrained, consistent. |

The completion moment is now a **sequence**, not an instant: the baker picks up
the treat, carries it to the case, and places it (`05`). Sound and haptics should
land on the *placement*, at the end of the walk — not when the timer numerically
hits zero. Firing the ding at zero and showing the treat land three seconds later
is the kind of mismatch that reads as broken.

Rules:

- **Respect the silent switch.** Configure the audio session so ambient audio
  does not play through silent mode.
- **Never interrupt other audio.** People focus with music and podcasts on;
  ducking or stopping their audio would be a fatal flaw for a focus app. Use an
  ambient, non-mixing-hostile session category.
- Audio survives scene teardown — drive it from the app layer, not from inside
  `SKScene` (`05`).
- Stop or fade ambient audio on backgrounding. The app should not be audible
  while the user is elsewhere.
- All of it is toggleable (`13`).

## Haptics

| Haptic | When |
|---|---|
| **Completion haptic** | Session completes, paired with the ding |
| Light feedback | Coin award, treat landing, recipe/duration steps, purchase |

Rules:

- Restrained. Haptics on every tap becomes noise and drains the effect where it
  matters.
- Toggleable (`13`).
- Never the only channel for information — anything haptics convey must also be
  visible.

## Burned session

A burned bake needs its own audio/haptic treatment — distinct from the
completion ding, and not punitive. The mechanic works because the loss is felt,
not because the app scolds. Exact treatment is open.

## Acceptance criteria

- [ ] Starting a session with music playing does not interrupt, duck, or stop it.
- [ ] The silent switch silences the app's audio.
- [ ] Ambient audio stops on backgrounding and resumes on return.
- [ ] Completion fires ding + haptic together, exactly once per completed session,
      synchronized with the treat landing in the case rather than with the timer
      reaching zero.
- [ ] Completion resolved on foreground return (`03`) still gets its moment — it
      is not silently applied.
- [ ] Sound and haptics toggles in settings take effect immediately.
- [ ] With both toggles off, the app is fully usable and nothing is silently
      broken.

## Open questions

- Whether ambient audio should continue while a session runs and the app is
  backgrounded. Default assumption: no — v1 has no background audio mode, and
  adding one is scope.
- Treatment for the burned-session moment.
- All actual audio assets — unmade.
