#!/usr/bin/env python3
"""Original VAStation sounds; deterministic, dependency-free PCM synthesis.

Run from any directory. Only writes the eight WAVs beside the pack README.
Ambient uses integer Fourier bins and periodic modulation, not a crossfade.
"""

from array import array
import math
from pathlib import Path
import random
import sys
import time
import wave

RATE = 44100
TAU = 2 * math.pi
OUT = Path(__file__).resolve().parents[1] / 'launcher/themes/default/sounds'


def blank(seconds):
    return array('f', [0.0]) * round(seconds * RATE)


def bell(dst, start, frequency, gain, decay, attack=0.004, glide=0.0):
    """Soft FM fundamental and quiet, slightly inharmonic glass partials."""
    first = round(start * RATE)
    for i in range(first, len(dst)):
        t = (i - first) / RATE
        env = (1 - math.exp(-t / attack)) * math.exp(-t / decay)
        phase = TAU * (frequency * t + glide * decay * (t - decay * (1 - math.exp(-t / decay))))
        fm = 0.28 * math.exp(-t / 0.065) * math.sin(phase * 2.01)
        tone = (math.sin(phase + fm)
                + 0.19 * math.exp(-t / (decay * 0.65)) * math.sin(phase * 2.003)
                + 0.055 * math.exp(-t / (decay * 0.4)) * math.sin(phase * 3.97))
        dst[i] += gain * env * tone


def noise_swell(dst, rng, start, duration, gain):
    """Two gentle low-pass stages remove the brittle edge of white noise."""
    lo = smooth = 0.0
    first = round(start * RATE)
    count = min(round(duration * RATE), len(dst) - first)
    for j in range(count):
        u = j / max(1, count - 1)
        cutoff = 0.012 + 0.085 * u
        lo += cutoff * (rng.uniform(-1, 1) - lo)
        smooth += cutoff * (lo - smooth)
        dst[first + j] += gain * math.sin(math.pi * u) ** 2 * smooth


def reverb(dry, spread, wet, feedback):
    """Schroeder: three damped feedback combs into a short all-pass.

    Channel-specific delays give restrained width while retaining a centered
    dry signal. Feedback is always below unity; the low-pass darkens repeats.
    """
    channels = []
    for side in (0, 1):
        delays = [round(RATE * (d + side * spread)) for d in (0.0297, 0.0371, 0.0411)]
        buffers = [[0.0] * d for d in delays]
        positions = [0, 0, 0]
        damped = [0.0, 0.0, 0.0]
        ap = [0.0] * round(RATE * (0.005 + side * spread * 0.7))
        pos = 0
        channel = array('f')
        for value in dry:
            total = 0.0
            for k in range(3):
                p = positions[k]
                delayed = buffers[k][p]
                damped[k] += 0.22 * (delayed - damped[k])
                buffers[k][p] = value + feedback * damped[k]
                positions[k] = (p + 1) % delays[k]
                total += delayed / 3
            diffused = ap[pos] - 0.5 * total
            ap[pos] = total + 0.5 * diffused
            pos = (pos + 1) % len(ap)
            channel.append(value + wet * diffused)
        channels.append(channel)
    return channels


def one_shot(name, seconds):
    dry = blank(seconds)
    rng = random.Random(0x564153 + sum(map(ord, name)))
    wet, feedback = 0.25, 0.60
    if name == 'nav':
        bell(dry, 0, 1500, 0.5, 0.015, attack=0.0015)
        wet, feedback = 0.10, 0.25
    elif name == 'tab':
        bell(dry, 0, 720, 0.38, 0.040, glide=700)
        bell(dry, 0.065, 960, 0.32, 0.034)
        wet, feedback = 0.17, 0.35
    elif name == 'select':
        bell(dry, 0, 880, 0.42, 0.15)
        bell(dry, 0.090, 1320, 0.40, 0.17)
        bell(dry, 0.145, 2640, 0.045, 0.20, attack=0.020)
        wet, feedback = 0.40, 0.72
    elif name == 'back':
        bell(dry, 0, 880, 0.36, 0.070)
        bell(dry, 0.072, 586.6667, 0.40, 0.065)
        wet, feedback = 0.25, 0.48
    elif name == 'error':
        for start in (0, 0.17):
            first = round(start * RATE)
            for i in range(first, len(dry)):
                t = (i - first) / RATE
                env = (1 - math.exp(-t / 0.007)) * math.exp(-t / 0.045)
                phase = TAU * (115 * t + 2.4 * (1 - math.exp(-t / 0.025)))
                dry[i] += 0.5 * env * (math.sin(phase) + 0.17 * math.sin(phase * 2))
        wet, feedback = 0.14, 0.35
    elif name == 'launch':
        noise_swell(dry, rng, 0, 1.25, 0.75)
        bell(dry, 0.10, 330, 0.14, 0.38, attack=0.12, glide=500)
        for start, pitch, gain in ((0.63, 660, 0.33), (0.75, 990, 0.26), (0.88, 1320, 0.16)):
            bell(dry, start, pitch, gain, 0.36, attack=0.030)
        wet, feedback = 0.55, 0.82
    elif name == 'boot':
        for i in range(len(dry)):
            t = i / RATE
            swell = math.sin(math.pi * t / seconds) ** 2
            dry[i] = 0.16 * swell * (math.sin(TAU * 55 * t)
                                     + 0.35 * math.sin(TAU * 110 * t))
        noise_swell(dry, rng, 0.7, 5.9, 0.30)
        for start, pitch in ((2.0, 440), (2.45, 660), (2.9, 880)):
            bell(dry, start, pitch, 0.11, 0.80, attack=0.19)
        # A minor, open-voiced bloom centered on the logo at 4.2 seconds.
        for pitch, gain in ((220, 0.24), (330, 0.17), (523.251, 0.16), (880, 0.09)):
            bell(dry, 4.05, pitch, gain, 0.66, attack=0.13)
        wet, feedback = 0.65, 0.88
    left, right = reverb(dry, 0.0013, wet, feedback)
    fade = round(0.004 * RATE)
    # Longer musical release supplements the mandatory 4 ms edge fades.
    release = round(min(seconds * 0.24, 0.75) * RATE)
    for channel in (left, right):
        for j in range(release):
            channel[-release + j] *= 0.5 + 0.5 * math.cos(math.pi * j / (release - 1))
        for j in range(fade):
            factor = 0.5 - 0.5 * math.cos(math.pi * j / (fade - 1))
            channel[j] *= factor
            channel[-1 - j] *= factor
    return left, right


def ambient():
    """Four detuned voices: A2 / E3 / A3 / C4, exactly periodic in 30 s.

    Frequencies are integer multiples of 1/30 Hz. LFOs have periods of
    30, 15, 10 and 7.5 s. Sparse triangle partials stay soft on small speakers.
    No edge fade or one-shot reverb: either would interrupt a continuous pad.
    """
    left, right = array('f'), array('f')
    bins = (3300, 4944, 6603, 7849)
    gains = (0.40, 0.29, 0.22, 0.18)
    count = 30 * RATE
    for i in range(count):
        cycle = TAU * i / count
        mid = width = 0.0
        for k in range(4):
            phase = bins[k] * cycle
            tone = math.sin(phase) - 0.065 * math.sin(3 * phase) + 0.012 * math.sin(5 * phase)
            amplitude = gains[k] * (0.72 + 0.28 * math.cos((k + 1) * cycle + k * 0.7))
            voice = amplitude * tone
            mid += voice
            width += voice * 0.18 * math.cos((k + 1) * cycle + k * 1.3)
        left.append(mid + width)
        right.append(mid - width)
    return left, right


def write_wav(name, channels, target_db):
    peak = max(max(map(abs, channel)) for channel in channels)
    scale = 32767 * 10 ** (target_db / 20) / peak
    pcm = array('h')
    for l, r in zip(*channels):
        pcm.append(round(l * scale))
        pcm.append(round(r * scale))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())


def check(name, expected_seconds, target_db):
    # Read the written file, so verification covers PCM quantization/header.
    with wave.open(str(OUT / (name + '.wav')), 'rb') as wav:
        frames, rate, channels, width = (wav.getnframes(), wav.getframerate(),
                                         wav.getnchannels(), wav.getsampwidth())
        pcm = array('h')
        pcm.frombytes(wav.readframes(frames))
    if sys.byteorder != 'little':
        pcm.byteswap()
    peak_db = 20 * math.log10(max(map(abs, pcm)) / 32767)
    delta = (abs(pcm[-2] - pcm[0]), abs(pcm[-1] - pcm[1]))
    assert (frames, rate, channels, width) == (round(expected_seconds * RATE), RATE, 2, 2)
    assert abs(peak_db - target_db) < 0.01
    if name == 'ambient':
        # Compare seam step with normal adjacent-frame steps as well as ends.
        step = max(abs(pcm[i] - pcm[i - 2]) for i in range(2, len(pcm)))
        assert max(delta) <= step
        seam = f'{delta[0]}/{delta[1]} (max adjacent {step})'
    else:
        assert pcm[0] == pcm[1] == pcm[-2] == pcm[-1] == 0
        seam = '-'
    print(f'{name + ".wav":12} {frames / rate:8.3f} {channels:3} {peak_db:10.2f}  {seam}')


def main():
    started = time.monotonic()
    OUT.mkdir(parents=True, exist_ok=True)
    specs = [('nav', 0.09, -9), ('tab', 0.18, -9), ('select', 0.7, -3),
             ('back', 0.35, -3), ('error', 0.5, -3), ('launch', 2.2, -3),
             ('boot', 7.0, -3), ('ambient', 30.0, -18)]
    print('file          seconds  ch  peak dBFS  loop delta L/R (PCM counts)')
    for name, seconds, target_db in specs:
        channels = ambient() if name == 'ambient' else one_shot(name, seconds)
        write_wav(name, channels, target_db)
        check(name, seconds, target_db)
    print(f'Wrote eight WAVs to {OUT} in {time.monotonic() - started:.2f} s.')


if __name__ == '__main__':
    main()
