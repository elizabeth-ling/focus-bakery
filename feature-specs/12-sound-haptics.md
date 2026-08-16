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
not because the app scolds. ~~Exact treatment is open.~~

**Settled: an oven door, then two notes falling.** A low thump with a breath of
air behind it, then F4 down to C4 — muted, two partials, no brightness on it at
all. Quieter than the completion ding by design, and paired with a *soft* impact
haptic rather than the notification-weight `.warning`. A warning buzz is the
system's vocabulary for "you have done something wrong", which is the app
scolding; a thud is the loss landing.

It fires on both ways of losing a bake, including the deliberate one. Throwing a
bake out reaches no alert — the user just confirmed it — so the confirmation is
the only place it can be felt at all.

## Acceptance criteria

- [ ] Starting a session with music playing does not interrupt, duck, or stop it.
      The app asks for `AVAudioSession.Category.ambient`, which is asserted, and
      that is the whole of the app's side: ambient is the one category that
      neither ducks nor interrupts. What the system then does with it is a
      device question and this owes that pass.
- [ ] The silent switch silences the app's audio. Same category, same assertion,
      same pass owed — and it can only be owed to a device, because the
      simulator has no silent switch to fail on.
- [x] Ambient audio stops on backgrounding and resumes on return. The rule the
      hum follows — it runs iff the app is foreground *and* sound is on — is
      unit-tested in both directions, including the case that looks like a bug
      until you see it: turning sound on while the app is in the background must
      not start it humming from nowhere. The `scenePhase` edge it hangs off is
      the same `.background` branch that starts the burn grace, which spec 03
      already proved gets hit by driving the app with `simctl`.
- [x] Completion fires ding + haptic together, exactly once per completed session,
      synchronized with the treat landing in the case rather than with the timer
      reaching zero. The synchronisation is structural rather than timed: the cue
      fires on the scene's `.treatPlaced` event, which `placeTreat()` emits in
      the same call that puts the sprite on the counter, so there is no interval
      to drift. Exactly-once is asserted against three announcements of the same
      bake. Whether it *lands* right is an ear judgement and belongs to the
      device pass.
- [x] Completion resolved on foreground return (`03`) still gets its moment — it
      is not silently applied. It has no walk to land on, so its alert is the
      moment instead. The two paths are exclusive per bake by construction —
      `deliverOwed` picks one — and `announce` holds exactly-once anyway.
- [x] Sound and haptics toggles in settings take effect immediately. Cues read
      the settings as they play, so there is nothing to keep in sync; the hum is
      the one thing already running, and the sheet asks the app layer to bring it
      into line the same way it does for the reminder (04).
- [x] With both toggles off, the app is fully usable and nothing is silently
      broken. Asserted, including the part that is easy to get wrong: a bake
      announced while muted has still spent its moment, so turning the sound back
      on afterwards must not ring for news the user has already been shown.

## How it is built

- `BakeryCue` (`Models/BakeryCue.swift`) is the entire vocabulary, closed and
  pure. The hard part of this spec is restraint, and restraint is only
  inspectable if the whole list fits on one screen — a feeling the app wants to
  give and cannot name here has not been thought about yet. The spec's table
  lists a coin award and a treat landing as ticks of their own; both are folded
  into `completion`, because coins are only ever earned by a bake finishing and
  the treat landing *is* the instant the completion cue is defined to fire on.
  Three cues inside one second is the noise the restraint rule is about.
- `BakeryFeedback` (`App/BakeryFeedback.swift`) is the one point of contact with
  the speaker and the Taptic Engine, and owns the two rules above. `announce` is
  where exactly-once lives: the two call sites are mutually exclusive per bake,
  but that is a property of the callers, and the criterion is *exactly once* — so
  the guard is one id comparison in one place, which also covers the case no
  caller can see. A scene rebuilt mid-walk (a size change, the keyboard) settles
  straight back into delivering and places the treat a second time.
- It lives in the app layer and not in `SKScene`, which settles `05`'s open
  question the way `05` guessed it would go. The scene is thrown away and rebuilt
  on every size change; a hum that restarted with it would have a seam in it
  after all.
- `FeedbackClient` is the injection point, the same shape and for the same reason
  as `NotificationCenterClient`: what the app *asked* for can be asserted, while
  what a speaker and a Taptic Engine actually did cannot be judged off a device.
- The audio is placeholder-first, exactly as the room was (`05`).
  `tools/audio/build_audio.py` synthesises the hum and four cues from the
  standard library, deterministically; the output is original so it is committed,
  and a cue whose file is missing is silence and never a crash, so they can be
  re-recorded one at a time. `tools/audio/README.md` carries the two decisions
  worth keeping if they are redone — no pitch anywhere in the hum, and no
  transients in it.

## Open questions

- ~~Whether ambient audio should continue while a session runs and the app is
  backgrounded.~~ **Resolved as the spec assumed: no.** Backgrounding mid-bake is
  the burn trigger (`03`), so the case barely exists — and the app going quiet
  when the user leaves is the same promise as the app not interrupting them.
- ~~Treatment for the burned-session moment.~~ **Resolved** — see *Burned
  session* above.
- All actual audio assets — **placeholders in, recordings still unmade**. What is
  there has the right shape, length and relative level, and the mix between them
  is tuned: the hum sits under everything, the ding is the loudest thing the app
  does, the step tick is barely there. What it does not have is a room in it.
- Whether a distant clatter belongs in the hum. It is the first thing a recorded
  loop would want and the reason the placeholder has none: on a four-second bed
  any transient becomes a metronome. It needs either a loop long enough to hide
  the period, or to be a one-shot on a randomised timer — not baked into the bed.
