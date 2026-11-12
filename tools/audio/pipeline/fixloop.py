#!/usr/bin/env python3
"""Small clean-up for the gameplay loop: lifts the weak first note and fades the very last 8 ms so the loop does not click.

Reads <dir>/gp_trim.wav (gameplay cut at the loop point, 44.1 kHz), writes <dir>/gp_fixed.wav.
Usage: python3 tools/audio/pipeline/fixloop.py dir       (needs numpy, soundfile)
"""
import sys

import numpy as np
import soundfile as sf

d = sys.argv[1]
x, sr = sf.read(d + "/gp_trim.wav", always_2d=True)
t = np.arange(len(x)) / sr
# first note: about +12 dB in the first 30 ms, +4 dB after that, eased back to 0 dB inside the gap before the next note
g_db = np.zeros(len(x))
head = t < 0.20
a = np.clip(t[head] / 0.030, 0, 1)
g = 12 * (1 - a) + 4 * a
g *= 1 - np.clip((t[head] - 0.17) / 0.03, 0, 1)
g_db[head] = g
y = x * (10 ** (g_db / 20))[:, None]
n = int(0.008 * sr)
y[-n:] *= np.linspace(1, 0, n)[:, None]  # the loop seam
sf.write(d + "/gp_fixed.wav", np.clip(y, -1, 1), sr, subtype="PCM_16")
m = y.mean(axis=1)
rms = lambda a, b: 20 * np.log10(np.sqrt((m[int(a * sr):int(b * sr)] ** 2).mean()) + 1e-9)
print("first note RMS %.1f dB, jump between the last and first sample %.3f" % (rms(0, 0.16), abs(m[0] - m[-1])))
