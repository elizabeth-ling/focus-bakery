#!/usr/bin/env python3
"""Synthesises the app's placeholder audio into Resources/.

Spec 12 lists every actual audio asset as unmade, and the Modern Interiors pack
ships no sound at all (spec 14), so the bakery's hum and its cues are generated
here -- the same placeholder-first move the room made with coloured blocks (05).
These are stand-ins with the right shape, length and weight, not final assets:
they exist so the feature is a real feature rather than a silent code path, and
so the mix, the timing and the silent-switch behaviour can be judged on a
device today.

    python3 tools/audio/build_audio.py            # write Resources/*.wav
    python3 tools/audio/build_audio.py --output /tmp/audio

Requires nothing but the standard library. Deterministic: every random value is
drawn from a seeded generator, so the same script always writes the same
samples.
"""

import argparse
import array
import math
import pathlib
import random
import wave

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "Resources"

CUE_RATE = 44100
# The hum is a low bed with nothing above a few kHz in it, so half the rate
# costs it nothing audible and halves what the repository carries.
AMBIENT_RATE = 22050
AMBIENT_SECONDS = 4.0


class Track:
    """A mono buffer of floats in -1..1, addressed in seconds."""

    def __init__(self, seconds, rate):
        self.rate = rate
        self.samples = array.array("d", bytes(8 * int(seconds * rate)))

    def add(self, at, values):
        start = int(at * self.rate)
        for offset, value in enumerate(values):
            index = start + offset
            if index >= len(self.samples):
                break
            self.samples[index] += value

    def normalised(self, peak):
        loudest = max((abs(value) for value in self.samples), default=0.0)
        if loudest == 0:
            return self.samples
        gain = peak / loudest
        return array.array("d", (value * gain for value in self.samples))


def envelope(length, rate, attack, decay):
    """Soft attack, exponential decay. The attack is what keeps a cue from
    clicking: a tone that starts at full amplitude has a step in it, and a step
    is a click no matter how pretty the tone after it."""
    attack_samples = max(1, int(attack * rate))
    for index in range(length):
        rise = min(1.0, index / attack_samples)
        yield rise * math.exp(-index / (decay * rate))


def tone(freq, seconds, rate, partials, attack=0.004, decay=0.25):
    """A struck tone: partials over a shared envelope, the higher ones fading
    faster, which is what a bell, a wooden spoon and a coin all have in common
    and a plain sine does not."""
    length = int(seconds * rate)
    shape = list(envelope(length, rate, attack, decay))
    out = array.array("d", bytes(8 * length))
    step = 2 * math.pi / rate
    for ratio, level, damping in partials:
        angle = 0.0
        advance = freq * ratio * step
        for index in range(length):
            out[index] += level * shape[index] ** damping * math.sin(angle)
            angle += advance
    return out


def white(seconds, rate, rng):
    return array.array("d", (rng.uniform(-1, 1) for _ in range(int(seconds * rate))))


def lowpass(values, rate, cutoff, poles=1):
    """One-pole low-pass, cascaded. Cheap, and the only shaping any of this
    needs: nothing here is a filter sweep, it is all "take the top off"."""
    coefficient = math.exp(-2 * math.pi * cutoff / rate)
    out = array.array("d", values)
    for _ in range(poles):
        value = 0.0
        for index, sample in enumerate(out):
            value = coefficient * value + (1 - coefficient) * sample
            out[index] = value
    return out


def highpass(values, rate, cutoff):
    return array.array("d", (a - b for a, b in zip(values, lowpass(values, rate, cutoff))))


def noise(seconds, rate, rng, cutoff):
    """Low-passed white noise -- a puff of air rather than a hiss."""
    return lowpass(white(seconds, rate, rng), rate, cutoff)


def faded(values, rate, seconds):
    """Fades a buffer's tail to nothing so it cannot end on a step."""
    fade = int(seconds * rate)
    for offset in range(min(fade, len(values))):
        values[len(values) - 1 - offset] *= offset / fade
    return values


def write(path, samples, rate):
    frames = array.array("h", (int(max(-1.0, min(1.0, value)) * 32767) for value in samples))
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(rate)
        file.writeframes(frames.tobytes())
    return path


# --- The hum -----------------------------------------------------------------


def looped(values, length, fade):
    """Closes a buffer into a seamless loop.

    The buffer is generated `fade` samples longer than the loop needs, and that
    overhang is mixed back over the opening under an equal-power crossfade. The
    loop's last sample is then followed by material that genuinely preceded it,
    so there is no step at the seam and no dip in level across it either --
    which a straight linear fade between two uncorrelated pieces of noise
    would have, audibly, once every pass.

    Tonal beds can be built to close by themselves, by giving every partial a
    whole number of cycles in the loop. Noise cannot, and this hum is noise:
    a tonal bed under a focus app is a drone competing with the user's own
    music, which is the one thing spec 12 rules out absolutely."""
    out = array.array("d", values[:length])
    for index in range(fade):
        position = index / fade
        out[index] = (
            out[index] * math.sqrt(position)
            + values[length + index] * math.sqrt(1 - position)
        )
    return out


def ambient():
    """The bakery, heard from the next room: oven rumble, a thin band of room
    air above it, and a slow breathing so it reads as a place rather than as a
    machine left running.

    Nothing in it is tonal and nothing in it is a transient. Both are
    deliberate -- a pitch would sit against whatever the user is listening to,
    and a clatter on a four-second loop stops being a bakery and becomes a
    metronome."""
    rate = AMBIENT_RATE
    length = int(AMBIENT_SECONDS * rate)
    fade = int(0.75 * rate)
    overrun = AMBIENT_SECONDS + 0.75
    rng = random.Random(1204)

    # Three poles at 240 Hz: a steep enough roll-off that what is left is felt
    # more than heard, which is what an oven two rooms away sounds like.
    rumble = lowpass(white(overrun, rate, rng), rate, 240, poles=3)
    loudest = max(abs(value) for value in rumble)
    air = highpass(lowpass(white(overrun, rate, rng), rate, 3400), rate, 1200)

    bed = array.array("d", (r / loudest + 0.05 * a for r, a in zip(rumble, air)))
    # Cascaded one-poles leave a small standing offset behind. On a one-shot
    # cue it is inaudible; on a bed that loops for an hour it is a DC bias
    # eating headroom, so it comes off before anything else is measured.
    centre = sum(bed) / len(bed)
    bed = array.array("d", (value - centre for value in bed))

    track = Track(AMBIENT_SECONDS, rate)
    track.add(0, looped(bed, length, fade))

    # Breathing, at whole multiples of the loop's own frequency so the wobble
    # closes its cycle exactly where the loop does.
    for index in range(length):
        phase = 2 * math.pi * index / length
        track.samples[index] *= 1 + 0.10 * math.sin(phase) + 0.05 * math.sin(3 * phase)

    return track.normalised(0.30), rate


# --- The cues ----------------------------------------------------------------


def completion():
    """The payoff (05, 12). A rising major triad on a soft bell, landing rather
    than announcing -- the sound is the treat reaching the case, so it wants to
    be warm and over quickly, not a fanfare the user hears eight times a day."""
    track = Track(1.6, CUE_RATE)
    bell = [(1, 1.0, 1.0), (2, 0.45, 1.6), (3, 0.18, 2.4), (4.2, 0.08, 3.0)]
    for at, freq, level in ((0.0, 783.99, 1.0), (0.10, 1046.50, 0.9), (0.20, 1318.51, 0.75)):
        voice = tone(freq, 1.3, CUE_RATE, bell, attack=0.005, decay=0.30)
        track.add(at, (value * level for value in voice))
    return faded(track.normalised(0.62), CUE_RATE, 0.05), CUE_RATE


def burned():
    """A bake lost (03, 12). Distinct from the ding and deliberately not a
    buzzer: the oven door closing, and two notes falling. Quieter than the
    completion cue, because the mechanic works by the loss being felt and not
    by the app raising its voice."""
    track = Track(1.5, CUE_RATE)
    rng = random.Random(77)

    thump = tone(88, 0.5, CUE_RATE, [(1, 1.0, 1.0), (2, 0.25, 2.0)], attack=0.002, decay=0.10)
    track.add(0.0, thump)
    track.add(0.0, (value * 0.35 for value in noise(0.18, CUE_RATE, rng, 900)))

    # Muted: two partials and no more. A falling figure with a bright spectrum
    # over it starts to sound like an error tone.
    sigh = [(1, 1.0, 1.0), (2, 0.14, 2.2)]
    for at, freq, level in ((0.06, 349.23, 0.85), (0.30, 261.63, 0.7)):
        voice = tone(freq, 1.1, CUE_RATE, sigh, attack=0.02, decay=0.34)
        track.add(at, (value * level for value in voice))
    return faded(track.normalised(0.40), CUE_RATE, 0.06), CUE_RATE


def step():
    """Recipe arrows and the duration stepper (10). Wood, brief, and well under
    the cues that mean something: this one fires while the user is deciding,
    and anything with a tail turns paging through the book into a racket."""
    track = Track(0.09, CUE_RATE)
    rng = random.Random(31)
    track.add(0.0, tone(940, 0.08, CUE_RATE, [(1, 1.0, 1.0), (2.1, 0.30, 2.0)], attack=0.001, decay=0.018))
    track.add(0.0, (value * 0.25 for value in noise(0.008, CUE_RATE, rng, 3000)))
    return faded(track.normalised(0.26), CUE_RATE, 0.01), CUE_RATE


def purchase():
    """A recipe bought (07). Two coins meeting -- brighter and shorter than the
    completion bell, so spending never outshines earning."""
    track = Track(0.4, CUE_RATE)
    clink = [(1, 1.0, 1.0), (2.7, 0.55, 1.8), (5.1, 0.22, 2.6)]
    for at, freq, level in ((0.0, 2093.0, 1.0), (0.045, 2637.0, 0.8)):
        voice = tone(freq, 0.3, CUE_RATE, clink, attack=0.001, decay=0.045)
        track.add(at, (value * level for value in voice))
    return faded(track.normalised(0.38), CUE_RATE, 0.02), CUE_RATE


SOUNDS = {
    "bakery_ambient": ambient,
    "cue_completion": completion,
    "cue_burned": burned,
    "cue_step": step,
    "cue_purchase": purchase,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, default=OUTPUT)
    arguments = parser.parse_args()
    arguments.output.mkdir(parents=True, exist_ok=True)

    for name, build in SOUNDS.items():
        samples, rate = build()
        path = write(arguments.output / f"{name}.wav", samples, rate)
        print(f"{path.name}: {len(samples) / rate:.2f}s at {rate} Hz")


if __name__ == "__main__":
    main()
