#!/usr/bin/env python3
"""Turns a weekly price series into an 8-bit melody and a piano-roll picture (data sonification).

Price -> pitch: min close = C4, max close = C7, snapped to the C major pentatonic scale so any path sounds consonant.
One week = one note. Usage: python3 tools/audio/sonify_ticker.py [out_dir]   (needs numpy, matplotlib)
"""
import datetime as dt
import importlib.util
import os
import sys

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_music.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
mm.OUT = OUT

SYMBOL = "TQQQ"
START = dt.date(2025, 7, 28)
CLOSES = [
	41.46, 46.08, 46.63, 45.19, 44.68, 45.91, 48.38, 51.49, 50.625, 52.35, 48.535, 51.995, 55.28, 58.36, 52.89, 52.37,
	47.48, 54.54, 56.15, 52.82, 53.52, 55.31, 52.35, 55.76, 54.14, 54.38, 54.00, 50.59, 48.47, 50.06, 49.52, 47.54,
	45.93, 43.08, 38.78, 43.33, 49.17, 58.59, 62.56, 65.30, 76.28, 75.34, 77.84, 84.56, 73.05, 77.52, 82.87, 71.83,
	73.35, 77.03, 67.53, 64.00, 64.62, 74.47, 76.79, 71.17, 71.85, 72.37, 70.98, 72.64, 79.60, 81.01, 81.28, 68.21,
	66.29, 62.01, 52.25,
]
NAMES = "C C# D D# E F F# G G# A A# B".split()
LOW, HIGH = 60, 96  # C4 .. C7
PENTA = {0, 2, 4, 7, 9}
SCALE = [m for m in range(LOW, HIGH + 1) if m % 12 in PENTA]


def midi_name(m):
	return f"{NAMES[m % 12]}{m // 12 - 1}"


def to_midi(price):
	lo, hi = min(CLOSES), max(CLOSES)
	raw = LOW + (price - lo) / (hi - lo) * (HIGH - LOW)
	return min(SCALE, key=lambda m: abs(m - raw)), raw


def build_audio():
	notes = [to_midi(p)[0] for p in CLOSES]
	s = mm.Song(120, 9)  # 2 steps (an 8th) per week
	for i, m in enumerate(notes):
		bar, step = divmod(i * 2, 16)
		s.add_lead(bar, [(step, 2, midi_name(m))], duty=0.25, gain=0.30)
	roots = ["C2", "A1", "F2", "G2"]
	for b in range(9):
		s.add_bass_pattern(b, roots[b % 4], "1 . . . 5 . . . 1 . . . 5 . . .", length=3, gain=0.40)
		s.add_drums(b, kicks=(0, 8), snares=(4, 12), hat_every=4, hat_gain=0.04)
	mm.write_wav(s.mix(), "tqqq_melody")
	return notes


def draw(notes):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	plt.rcParams["axes.unicode_minus"] = False
	n = len(CLOSES)
	fig = plt.figure(figsize=(15, 8.5), facecolor="#14161c")
	ax = fig.add_axes([0.085, 0.09, 0.87, 0.80], facecolor="#1b1e27")
	kb = fig.add_axes([0.03, 0.09, 0.055, 0.80], facecolor="#14161c")
	lo, hi = min(CLOSES), max(CLOSES)
	# piano roll rows
	for m in range(LOW, HIGH + 1):
		black = m % 12 in (1, 3, 6, 8, 10)
		ax.add_patch(Rectangle((-1, m - 0.5), n + 1, 1, color="#20242f" if black else "#262b38", lw=0, zorder=0))
		if m % 12 == 0:
			ax.axhline(m - 0.5, color="#3a4052", lw=0.8, zorder=1)
		# keyboard
		kb.add_patch(Rectangle((0, m - 0.5), 0.55 if black else 1, 1, fc="#111" if black else "#f4f1e8",
			ec="#555", lw=0.4, zorder=2 if black else 1))
		if m % 12 == 0:
			kb.text(0.97, m, midi_name(m), ha="right", va="center", fontsize=8, color="#333", zorder=3)
	kb.set_xlim(0, 1)
	kb.set_ylim(LOW - 0.5, HIGH + 0.5)
	kb.axis("off")
	# price line mapped onto the same axis
	xs = np.arange(n)
	ys = [LOW + (p - lo) / (hi - lo) * (HIGH - LOW) for p in CLOSES]
	ax.plot(xs, ys, color="#ffd166", lw=1.6, alpha=0.9, zorder=3, label="真实价格 (线性映射)")
	# notes
	cm = plt.get_cmap("cool")
	for i, m in enumerate(notes):
		ax.add_patch(Rectangle((i - 0.38, m - 0.42), 0.76, 0.84, fc=cm((m - LOW) / (HIGH - LOW)), ec="white", lw=0.4, zorder=4))
	# highlights
	hi_i, lo_i = CLOSES.index(hi), CLOSES.index(lo)
	for i, label, dx, dy in ((lo_i, "最低点", 5, 3.5), (hi_i, "最高点", -7, -3.5), (n - 1, "最新", -4, -4.5)):
		ax.annotate(f"{label}\n${CLOSES[i]:.2f} → {midi_name(notes[i])}", (i, notes[i]), xytext=(i + dx, notes[i] + dy),
			color="white", fontsize=9, ha="center", arrowprops=dict(arrowstyle="-", color="#aaa", lw=0.8), zorder=6)
	ax.set_xlim(-1, n)
	ax.set_ylim(LOW - 0.5, HIGH + 0.5)
	ticks = list(range(0, n, 8))
	ax.set_xticks(ticks)
	ax.set_xticklabels([(START + dt.timedelta(weeks=t)).strftime("%y-%m") for t in ticks], color="#cbd0dc")
	ax.set_yticks([m for m in range(LOW, HIGH + 1) if m % 12 == 0])
	ax.set_yticklabels([midi_name(m) for m in range(LOW, HIGH + 1) if m % 12 == 0], color="#cbd0dc")
	ax2 = ax.twinx()
	ax2.set_ylim(lo - (hi - lo) * 0.5 / (HIGH - LOW), hi + (hi - lo) * 0.5 / (HIGH - LOW))
	ax2.tick_params(colors="#cbd0dc")
	ax2.set_ylabel("周收盘价 ($)", color="#cbd0dc")
	for sp in list(ax.spines.values()) + list(ax2.spines.values()):
		sp.set_visible(False)
	ax.legend(loc="upper left", facecolor="#14161c", edgecolor="none", labelcolor="white")
	fig.suptitle(f"{SYMBOL} 周线 → 8-bit 旋律 (C 大调五声音阶, 每周一个音)", color="white", fontsize=16, y=0.96)
	fig.text(0.5, 0.025, "价格越高音越高:最低价 = C4,最高价 = C7;键盘在左侧,方块 = 当周弹奏的音。仅为数据可听化,不是投资建议。",
		color="#9aa1b3", ha="center", fontsize=10)
	path = os.path.join(OUT, "tqqq_piano_roll.png")
	fig.savefig(path, dpi=130, facecolor=fig.get_facecolor())
	print("wrote", path)


if __name__ == "__main__":
	assert len(CLOSES) == 67 or len(CLOSES) == 66, len(CLOSES)
	n = build_audio()
	draw(n)
	print(len(CLOSES), "weeks;", " ".join(midi_name(m) for m in n[:16]), "...")
