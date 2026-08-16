# The audio

Synthesised placeholder sound for spec `12`. The Modern Interiors pack ships no
audio at all, so — like the bitmap font, the UI chrome and the app icon — this
is a gap `14` names and the repository has to fill itself.

```sh
python3 tools/audio/build_audio.py            # write Resources/*.wav
python3 tools/audio/build_audio.py --output /tmp/audio
```

Standard library only, and deterministic: every random value comes from a seeded
generator, so the same script always writes the same samples. The output is
original, so `Resources/*.wav` is committed and the app makes sound without
Python or the pack.

| File | Length | Rate | What it is |
|---|---|---|---|
| `bakery_ambient` | 4.00s loop | 22.05 kHz | The hum. Filtered noise: oven rumble, a thin band of room air, breathing on top |
| `cue_completion` | 1.60s | 44.1 kHz | The payoff. A rising major triad on a soft bell |
| `cue_burned` | 1.50s | 44.1 kHz | A bake lost. The oven door, then two notes falling |
| `cue_step` | 0.09s | 44.1 kHz | Recipe arrows and the duration stepper |
| `cue_purchase` | 0.40s | 44.1 kHz | Two coins meeting |

## These are placeholders

They have the right shape, length and weight, and the mix between them is tuned:
the hum sits under everything, the ding is the loudest thing the app does, the
step tick is barely there, and the burn is quieter than the completion because
the mechanic works by the loss being *felt* and not by the app raising its voice.

What they are not is recorded, or characterful. A real bakery hum has a room in
it. Replacing any one of them is dropping a `.wav` of the same name into
`Resources/` — nothing in the app names a duration, a rate or a level, and a
missing file is a silent cue rather than a crash, so they can be replaced one at
a time.

## Two decisions worth keeping if the assets are redone

**The hum is tonal-free.** No pitch, anywhere in it. A drone has a key, and a
key sits against whatever the user is listening to — and people focus with music
on, which spec `12` protects absolutely.

**The hum has no transients.** A distant clatter would be lovely and is the
first thing a recorded loop would want. On a four-second loop it is a metronome.
Any clatter needs either a loop long enough to hide the period, or to be a
separate one-shot fired on a randomised timer — not baked into the bed.

## Looping

The bed is noise, so it cannot be built to close by itself the way a tonal loop
can (give every partial a whole number of cycles and the ends meet). Instead the
buffer is generated three quarters of a second longer than the loop, and that
overhang is mixed back over the opening under an **equal-power** crossfade — the
loop's last sample is then followed by material that genuinely preceded it. A
straight linear fade between two uncorrelated pieces of noise dips in level in
the middle of the crossfade, audibly, once every pass.

The join is checkable rather than a matter of faith: the step across the seam
sits at the 86th percentile of the loop's own sample-to-sample transitions, so
it is an ordinary step in the noise and not a discontinuity.
