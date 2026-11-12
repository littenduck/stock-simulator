#!/usr/bin/env python3
"""Draws the SOXL melody, the edited ladder and the start-menu theme side by side, and prints how much they overlap.

  row 1  SOXL weekly closes turned into a melody by sonify_musical.py / sonify_adventure.py (the "adventure" version)
  row 2  that opening edited into the long-short ladder  mi fa x3 | so fa x3 | la si x3 | do re x3   (compose_soxl_story.py)
  row 3  the same four bars read back out of the finished Suno track (startmenu_extracted_melody.json)

Usage: python3 tools/audio/notes/make_correspondence.py [out.png]      (needs numpy, matplotlib)
"""
import importlib.util
import json
import os
import sys

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(HERE, "..")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "soxl_to_startmenu.png")
sys.argv = sys.argv[:1] + [os.path.join("/tmp", "_unused_output")]  # keep the imported scripts from writing into the project


def load(name):
	spec = importlib.util.spec_from_file_location(name, os.path.join(AUDIO, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


sm, ad, story = load("sonify_musical"), load("sonify_adventure"), load("compose_soxl_story")
NAMES = "C C# D D# E F F# G G# A A# B".split()
SOL = {"C": "do", "D": "re", "E": "mi", "F": "fa", "G": "so", "A": "la", "B": "si"}
LET = {"C": 0, "D": 1, "E": 2, "F": 3, "G": 4, "A": 5, "B": 6}
NB = 4


def nm(m):
	return NAMES[m % 12] + str(m // 12 - 1)


# row 1: SOXL data -> melody (the same code path that made soxl_adventure.wav)
start, closes = ad.SERIES["SOXL"]
sm.st.CLOSES, sm.st.START = closes, start
spec = sm.SPECS[1]
chords = [{"label": c[0], "tones": sorted({sm.pc(x) for x in c[2]})} for c in spec["chords"]]
notes, _, _ = sm.make_melody(chords, spec["key_pcs"], spec["lo"], spec["hi"])
row1 = [[] for _ in range(NB)]
for slot, ln, m in sm.tie(notes[: NB * 8]):
	row1[slot // 8].append(((slot % 8) * 2, ln * 2, m))
# row 2: the edited ladder
row2 = [[(s, ln, story.to_midi(n)) for s, ln, n in story.mm.parse_bar(story.expand(story.BARS[b][4]))] for b in range(NB)]
# row 3: extracted from the finished track
data = json.load(open(os.path.join(HERE, "startmenu_extracted_melody.json")))
row3 = [[(n["start"], n["len"], n["midi"]) for n in bar if n["midi"]] for bar in data["bars"][:NB]]


def at_slots(row):  # pitch at each eighth-note slot (None = rest)
	out = []
	for bar in row:
		slots = [None] * 8
		for s, ln, m in bar:
			for k in range(s // 2, min(8, (s + ln + 1) // 2)):
				slots[k] = m
		out += slots
	return out


a1, a2, a3 = at_slots(row1), at_slots(row2), at_slots(row3)
agree = lambda x, y, r: sum(1 for i in r if x[i] is not None and x[i] == y[i])
print("pitch agreement per eighth-note slot (same MIDI note):")
print("  SOXL melody vs edited ladder, bars 1-2: %d / 16   bars 1-4: %d / 32" % (agree(a1, a2, range(16)), agree(a1, a2, range(32))))
print("  edited ladder vs read back from the Suno track, bars 1-4: %d / 32 (the rest are transcription artefacts)" % agree(a2, a3, range(32)))
print("  pitch classes used by the SOXL opening (bars 1-2):", sorted({nm(m) for m in a1[:16] if m}))


def ypos(m):
	n = NAMES[m % 12]
	return ((m // 12 - 1) * 7 + LET[n[0]] - (4 * 7 + 2)) * 0.5


def staff(ax, y0, rows_notes, title, expected=None):
	for l in range(5):
		ax.plot([0, 4 * 17 + 2], [y0 + l, y0 + l], color="k", lw=0.8)
	ax.text(0.2, y0 + 0.6, "\U0001D11E", fontsize=44, va="center", family=["Apple Symbols", "DejaVu Sans"])
	ax.text(3, y0 + 6.3, title, fontsize=12.5, fontweight="bold", va="bottom")
	for b in range(NB + 1):
		ax.plot([3 + b * 16.5] * 2, [y0, y0 + 4], color="k", lw=1)
	for b, bar in enumerate(rows_notes):
		for k, (s, ln, m) in enumerate(bar):
			x = 3 + b * 16.5 + (s + 0.5) * 0.95
			y = y0 + ypos(m)
			bad = expected is not None and expected[b][k] is not None and expected[b][k] != m
			col = "#c0392b" if bad else "k"
			if y - y0 > 4.5:
				for ly in range(5, int(np.floor(y - y0 + 0.01)) + 1):
					ax.plot([x - 0.9, x + 0.9], [y0 + ly, y0 + ly], color="k", lw=0.8)
			if y - y0 < -0.5:
				for ly in range(-1, int(np.ceil(y - y0 - 0.01)) - 1, -1):
					ax.plot([x - 0.9, x + 0.9], [y0 + ly, y0 + ly], color="k", lw=0.8)
			ax.add_patch(Ellipse((x, y), 1.25, 0.9, angle=20, fc=col, ec=col, zorder=4))
			up = (y - y0) < 2
			sx = x + 0.58 if up else x - 0.58
			ax.plot([sx, sx], [y, y + (3 if up else -3)], color=col, lw=1.2)
			if ln < 4:
				ty = y + (3 if up else -3)
				ax.plot([sx, sx + 1.0], [ty, ty - (1.0 if up else -1.0)], color=col, lw=2)
			if "#" in nm(m):
				ax.text(x - 1.4, y, "♯", fontsize=15, ha="center", va="center", color=col)
			ax.text(x, y0 - 1.8, SOL[NAMES[m % 12][0]], ha="center", fontsize=9.5, color=col)
			ax.text(x, y0 - 2.8, nm(m), ha="center", fontsize=7.5, color=col)
	for b in range(NB):
		ax.text(3 + b * 16.5, y0 + 5.0, str(b + 1), fontsize=9, color="#666")


fig = plt.figure(figsize=(17, 12.5), facecolor="white")
ax = fig.add_axes([0.01, 0.02, 0.98, 0.93])
ax.axis("off")
expected = [[m for _, _, m in bar] for bar in row2]
staff(ax, 24, row1, "1  SOXL weekly closes turned into a melody (E, F and G swinging up and down)")
staff(ax, 12, row2, "2  Edited into a long-short ladder: mi fa x3 | so fa x3 | la si x3 | do re x3   (the 4-bar theme given to Suno)")
staff(ax, 0, row3, "3  Read back out of startmenu.ogg (the Suno result): same ladder; red = notes that break the pattern (transcription noise)", expected)
ax.set_xlim(0, 4 * 16.5 + 5)
ax.set_ylim(-5.5, 33)
fig.suptitle("From the SOXL melody to the start-menu theme", fontsize=16, y=0.99)
fig.savefig(OUT, dpi=100, facecolor="white")
print("wrote", OUT)
