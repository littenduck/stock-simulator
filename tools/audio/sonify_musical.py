#!/usr/bin/env python3
"""Musical sonification of a price series: the price decides the melody's *direction*, but harmony decides the notes.

Rules that keep it pleasant:
  1. A fixed chord progression (one chord per bar) is the skeleton.
  2. Strong beats (1 and 3 of each bar) may only use chord tones; weak beats may use the key's scale or chord tones.
  3. A leap penalty keeps motion mostly stepwise; the price line is smoothed first.
  4. Equal neighbouring notes are tied into one longer note (fewer, more singable notes).
  5. First and last notes are chord tones; the last bar ends on the dominant so the loop pulls back to bar 1.
Usage: python3 tools/audio/sonify_musical.py [out_dir]   (needs numpy, matplotlib)
"""
import datetime as dt
import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
	spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


st = _load("sonify_ticker")  # CLOSES, START, midi_name, plotting backend
mm = st.mm
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
mm.OUT = OUT
import matplotlib.pyplot as plt  # noqa: E402  (after the Agg backend was selected by sonify_ticker)
from matplotlib.patches import Rectangle  # noqa: E402

PER_BAR = 8  # eighth notes per bar (one chord per bar)


def pc(name):
	n = mm.NOTE_INDEX[name[0]]
	if name[1] == "#":
		n += 1
	elif name[1] == "b":
		n -= 1
	return n % 12


def make_melody(chords, key_pcs, lo, hi):
	"""chords: list of dicts with 'tones' (pitch classes). Returns midi note per slot and the target line."""
	n = len(chords) * PER_BAR
	prices = np.interp(np.linspace(0, len(st.CLOSES) - 1, n), np.arange(len(st.CLOSES)), st.CLOSES)
	sm = np.convolve(np.pad(prices, 1, mode="edge"), np.ones(3) / 3, mode="valid")
	target = lo + (sm - sm.min()) / (sm.max() - sm.min()) * (hi - lo)
	out, prev = [], None
	for i in range(n):
		tones = set(chords[i // PER_BAR]["tones"])
		pos = i % PER_BAR
		strong = pos in (0, 4) or i == 0 or i == n - 1
		allowed = tones if strong else (tones | set(key_pcs))
		best = None
		for m in range(lo - 3, hi + 4):
			if m % 12 not in allowed:
				continue
			cost = abs(m - target[i])
			if prev is not None:
				leap = abs(m - prev)
				cost += max(0, leap - 4) * 1.6 + (0.6 if leap == 0 else 0)
			if best is None or cost < best[0]:
				best = (cost, m)
		prev = best[1]
		out.append(prev)
	return out, prices, target


def tie(notes):
	"""[(slot, length_in_slots, midi)] merging equal neighbours inside a bar."""
	res = []
	for i, m in enumerate(notes):
		if res and res[-1][2] == m and i % PER_BAR != 0 and res[-1][0] + res[-1][1] == i:
			res[-1][1] += 1
		else:
			res.append([i, 1, m])
	return res


def draw(fname, title, subtitle, chords, notes, tied, prices, lo, hi):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	plt.rcParams["axes.unicode_minus"] = False
	n = len(notes)
	rlo, rhi = lo - 3, hi + 3
	fig = plt.figure(figsize=(15, 7.2), facecolor="#14161c")
	ax = fig.add_axes([0.085, 0.10, 0.84, 0.74], facecolor="#1b1e27")
	kb = fig.add_axes([0.03, 0.10, 0.055, 0.74], facecolor="#14161c")
	for m in range(rlo, rhi + 1):
		black = m % 12 in (1, 3, 6, 8, 10)
		ax.add_patch(Rectangle((-1, m - 0.5), n + 1, 1, color="#20242f" if black else "#262b38", lw=0, zorder=0))
		if m % 12 == 0:
			ax.axhline(m - 0.5, color="#3a4052", lw=0.8, zorder=1)
		kb.add_patch(Rectangle((0, m - 0.5), 0.55 if black else 1, 1, fc="#111" if black else "#f4f1e8", ec="#555", lw=0.4,
			zorder=2 if black else 1))
		if m % 12 == 0:
			kb.text(0.97, m, st.midi_name(m), ha="right", va="center", fontsize=8, color="#333", zorder=3)
	kb.set_xlim(0, 1)
	kb.set_ylim(rlo - 0.5, rhi + 0.5)
	kb.axis("off")
	# bar lines + chord names
	for b, c in enumerate(chords):
		ax.axvline(b * PER_BAR - 0.5, color="#3a4052", lw=0.8, zorder=1)
		ax.text(b * PER_BAR + PER_BAR / 2 - 0.5, rhi + 0.2, c["label"], color="#ffd166", ha="center", va="bottom", fontsize=12,
			fontweight="bold")
	# real price (linear map) as a guide line
	pl = lo + (prices - prices.min()) / (prices.max() - prices.min()) * (hi - lo)
	ax.plot(np.arange(n), pl, color="#ffd166", lw=1.4, alpha=0.75, zorder=3, label="真实价格走势")
	cm = plt.get_cmap("cool")
	for s, ln, m in tied:
		ax.add_patch(Rectangle((s - 0.42, m - 0.42), ln - 0.16, 0.84, fc=cm((m - lo) / (hi - lo + 1e-9)), ec="white", lw=0.4,
			zorder=4))
	ax.set_xlim(-1, n)
	ax.set_ylim(rlo - 0.5, rhi + 0.5)
	ticks = [b * PER_BAR for b in range(len(chords))]
	span = (len(st.CLOSES) - 1) / (n - 1)
	ax.set_xticks(ticks)
	ax.set_xticklabels([(st.START + dt.timedelta(weeks=t * span)).strftime("%y-%m") for t in ticks], color="#cbd0dc")
	ax.set_yticks([m for m in range(rlo, rhi + 1) if m % 12 == 0])
	ax.set_yticklabels([st.midi_name(m) for m in range(rlo, rhi + 1) if m % 12 == 0], color="#cbd0dc")
	pmin, pmax = prices.min(), prices.max()
	sec = ax.secondary_yaxis("right", functions=(lambda y: pmin + (y - lo) / (hi - lo) * (pmax - pmin),
		lambda p: lo + (p - pmin) / (pmax - pmin) * (hi - lo)))
	sec.tick_params(colors="#cbd0dc")
	sec.set_ylabel("价格 ($)", color="#cbd0dc")
	for sp in list(ax.spines.values()) + list(sec.spines.values()):
		sp.set_visible(False)
	ax.legend(loc="lower right", facecolor="#14161c", edgecolor="none", labelcolor="white")
	fig.suptitle(title, color="white", fontsize=16, y=0.965)
	fig.text(0.5, 0.025, subtitle, color="#9aa1b3", ha="center", fontsize=10)
	path = os.path.join(OUT, fname)
	fig.savefig(path, dpi=125, facecolor=fig.get_facecolor())
	plt.close(fig)
	print("wrote", path)


def build(spec):
	chords = []
	for label, bass, voicing in spec["chords"]:
		chords.append({"label": label, "bass": bass, "voicing": voicing, "tones": sorted({pc(x) for x in voicing})})
	notes, prices, _ = make_melody(chords, spec["key_pcs"], spec["lo"], spec["hi"])
	tied = tie(notes)
	s = mm.Song(spec["bpm"], len(chords))
	for s0, ln, m in tied:
		bar, pos = divmod(s0, PER_BAR)
		name = st.midi_name(m)
		s.add_lead(bar, [(pos * 2, ln * 2, name)], duty=spec["duty"], gain=spec["gain"])
		s.add_lead(bar, [(pos * 2, ln * 2, name)], duty=0.5, gain=0.04, octave_shift=-1)
	for b, c in enumerate(chords):
		s.add_bass_pattern(b, c["bass"], spec["bass_pattern"], length=spec["bass_len"], gain=0.42)
		s.add_arp(b, c["voicing"], pattern=spec["arp"], every=spec["arp_every"], gain=spec["arp_gain"])
		s.add_drums(b, kicks=spec["kicks"], snares=spec["snares"], hat_every=spec["hat_every"], hat_gain=spec["hat_gain"])
	mm.write_wav(s.mix(), spec["file"])
	draw(spec["file"] + ".png", spec["title"], spec["subtitle"], chords, notes, tied, prices, spec["lo"], spec["hi"])
	return notes, chords


D_MAJ = [2, 4, 6, 7, 9, 11, 1]
C_MAJ = [0, 2, 4, 5, 7, 9, 11]
A_MIN = [9, 11, 0, 2, 4, 5, 7]

SPECS = [
	{   # 1: Pachelbel-style canon
		"file": "tqqq_v1_canon", "bpm": 76, "lo": 62, "hi": 86, "key_pcs": D_MAJ, "duty": 0.5, "gain": 0.28,
		"title": "版本 1 · Canon 卡农风 (D 大调, D-A-Bm-F#m-G-D-G-A)",
		"subtitle": "每小节一个和弦:强拍只用和弦内音,走势只决定旋律上行或下行;配经典卡农低音与流动的琶音。仅为数据可听化,不是投资建议。",
		"chords": [("D", "D2", ["D4", "F#4", "A4"]), ("A", "A1", ["A3", "C#4", "E4"]), ("Bm", "B1", ["B3", "D4", "F#4"]),
			("F#m", "F#2", ["F#3", "A3", "C#4"]), ("G", "G2", ["G3", "B3", "D4"]), ("D", "D2", ["D4", "F#4", "A4"]),
			("G", "G2", ["G3", "B3", "D4"]), ("A", "A1", ["A3", "C#4", "E4"])],
		"bass_pattern": "1 . . . . . . . 5 . . . . . . .", "bass_len": 6, "arp": (0, 1, 2, 1), "arp_every": 1, "arp_gain": 0.035,
		"kicks": (0,), "snares": (), "hat_every": 8, "hat_gain": 0.02,
	},
	{   # 2: adventure game
		"file": "tqqq_v2_adventure", "bpm": 132, "lo": 64, "hi": 88, "key_pcs": C_MAJ, "duty": 0.25, "gain": 0.30,
		"title": "版本 2 · 冒险游戏风 (C 大调, C-G-Am-F-C-G-F-G)",
		"subtitle": "经典 I-V-vi-IV 进行,明亮的方波主旋律 + 弹跳低音 + 轻鼓点;最后一小节停在 G,循环时自然拉回开头。",
		"chords": [("C", "C2", ["C4", "E4", "G4"]), ("G", "G1", ["G3", "B3", "D4"]), ("Am", "A1", ["A3", "C4", "E4"]),
			("F", "F2", ["F3", "A3", "C4"]), ("C", "C2", ["C4", "E4", "G4"]), ("G", "G1", ["G3", "B3", "D4"]),
			("F", "F2", ["F3", "A3", "C4"]), ("G", "G1", ["G3", "B3", "D4"])],
		"bass_pattern": "1 . 8 . 1 . 8 . 1 . 8 . 1 . 5 .", "bass_len": 2, "arp": (0, 2, 1, 2), "arp_every": 2, "arp_gain": 0.05,
		"kicks": (0, 8), "snares": (4, 12), "hat_every": 2, "hat_gain": 0.05,
	},
	{   # 3: minor epic
		"file": "tqqq_v3_epic_minor", "bpm": 112, "lo": 57, "hi": 81, "key_pcs": A_MIN, "duty": 0.125, "gain": 0.30,
		"title": "版本 3 · 小调史诗风 (A 小调, Am-F-C-G-Am-F-Dm-E)",
		"subtitle": "i-VI-III-VII 进行带出紧张感,尾段 Dm → E 把张力推到最高;细脆的 12.5% 方波配十六分琶音,适合'暴跌'时刻。",
		"chords": [("Am", "A1", ["A3", "C4", "E4"]), ("F", "F2", ["F3", "A3", "C4"]), ("C", "C2", ["C4", "E4", "G4"]),
			("G", "G1", ["G3", "B3", "D4"]), ("Am", "A1", ["A3", "C4", "E4"]), ("F", "F2", ["F3", "A3", "C4"]),
			("Dm", "D2", ["D3", "F3", "A3"]), ("E", "E2", ["E3", "G#3", "B3"])],
		"bass_pattern": "1 . 1 . 8 . 1 . 1 . 1 . 8 . 5 .", "bass_len": 2, "arp": (0, 1, 2, 1), "arp_every": 1, "arp_gain": 0.04,
		"kicks": (0, 4, 8, 12), "snares": (4, 12), "hat_every": 2, "hat_gain": 0.05,
	},
]

if __name__ == "__main__":
	for spec in SPECS:
		notes, chords = build(spec)
		print(spec["file"], "->", " ".join(st.midi_name(m) for m in notes[:16]), "...")
