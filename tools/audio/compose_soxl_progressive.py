#!/usr/bin/env python3
"""Three 'progressive' versions of the SOXL story. Bars 1-12 (the user's melody) never change; bars 13+ are new per version.

Techniques taken from the analysed reference (a chiptune track, 152 bpm, G major, ~104 bars):
  1. Slow swell: the start is quiet/sparse and the level rises a few dB over the first ~10 bars; each later section is a touch louder.
  2. One chord per bar, 4-bar chord loops, re-ordered (vi-IV-I-V / I-V-vi-IV / IV-V-I-vi) instead of new chords.
  3. A steady eighth-note engine underneath (8 onsets per bar), so the melody can breathe.
  4. A one-bar "air gap" (nearly empty bar) before a new section.
  5. A subtractive breakdown: bass and kick drop out for ~8 bars (mid range only), then everything re-enters.
  6. A quieter outro that thins out.
Usage: python3 tools/audio/compose_soxl_progressive.py [out_dir]   (needs numpy, matplotlib)
"""
import importlib.util
import os
import sys

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("cs", os.path.join(HERE, "compose_soxl_story.py"))
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)
mm, CELL, expand, to_midi = cs.mm, cs.CELL, cs.expand, cs.to_midi
NOTE_NAMES = "C C# D D# E F F# G G# A A# B".split()
C_MAJOR = [0, 2, 4, 5, 7, 9, 11]


def midi_name(m):
	return f"{NOTE_NAMES[m % 12]}{m // 12 - 1}"


def shift_name(name, semis):
	return midi_name(to_midi(name) + semis)


def shift_tokens(bar, semis):
	toks = expand(bar).split()
	return " ".join(t if t in ("-", ".") else shift_name(t, semis) for t in toks)


def diatonic_shift(m, steps):
	"""Moves a C-major note by scale steps (negative = down); out-of-scale notes fall back to semitones."""
	pc = m % 12
	if pc not in C_MAJOR:
		return m + round(steps * 12 / 7)
	idx = (m // 12) * 7 + C_MAJOR.index(pc) + steps
	return (idx // 7) * 12 + C_MAJOR[idx % 7]


CH = {
	"C": ("C2", ["C4", "E4", "G4"]), "G": ("G1", ["G3", "B3", "D4"]), "Am": ("A1", ["A3", "C4", "E4"]),
	"F": ("F2", ["F3", "A3", "C4"]), "Dm": ("D2", ["D3", "F3", "A3"]), "Em": ("E2", ["E3", "G3", "B3"]),
	"A": ("A1", ["A3", "C#4", "E4"]), "D": ("D2", ["D3", "F#3", "A3"]),
}
RUSH_C = "D5 F5 A5 C6 F6 G6 A6 B6 C7 - - - - - . ."


def B(sec, label, lead, gain=0.30, shift=0):
	root, voicing = CH[label]
	return {"sec": sec, "label": label, "bass": root, "voicing": voicing, "lead": lead, "gain": gain, "shift": shift}


def soul():
	return [{"sec": s, "label": l, "bass": r, "voicing": v, "lead": ld, "gain": g, "shift": 0}
		for s, l, r, v, ld, g in cs.BARS[:12]]


def plan(**kw):
	d = dict(lead=1.0, bass=0.0, arp=0.0, drums=0, dbl=1.0, counter=0.0, master=1.0)
	d.update(kw)
	return d


def render(bars, plans, name, bpm=132):
	s = mm.Song(bpm, len(bars))
	for b, (bar, pl) in enumerate(zip(bars, plans)):
		sh, m = bar["shift"], pl["master"]
		lead_str = shift_tokens(bar["lead"], sh)
		toks = mm.parse_bar(lead_str)
		duty = 0.25
		s.add_lead(b, toks, duty=duty, gain=bar["gain"] * pl["lead"] * m)
		if pl["dbl"]:
			s.add_lead(b, toks, duty=0.5, gain=0.04 * pl["dbl"] * m, octave_shift=-1)
		if pl["counter"]:  # canon: the same line a diatonic sixth below, half a bar later
			base = mm.parse_bar(expand(bar["lead"]))
			ctr = [(st + 8, ln, midi_name(diatonic_shift(to_midi(n), -5))) for st, ln, n in base]
			s.add_lead(b, ctr, duty=0.5, gain=0.13 * pl["counter"] * m)
		root = shift_name(bar["bass"], sh)
		voicing = [shift_name(v, sh) for v in bar["voicing"]]
		if pl["bass"]:
			held = bar["lead"].endswith(":8")
			pat = "1 . . . . . . . . . . . . . . ." if held else "1 . 8 . 1 . 8 . 1 . 8 . 1 . 5 ."
			s.add_bass_pattern(b, root, pat, length=14 if held else 2, gain=0.42 * pl["bass"] * m)
		if pl["arp"]:
			s.add_arp(b, voicing, pattern=(0, 2, 1, 2), every=2, gain=0.05 * pl["arp"] * m)
		lvl = pl["drums"]
		kicks, snares, hat_every, hat = {
			0: ((), (), 2, 0.0), 1: ((), (), 2, 0.04), 2: ((0, 8), (), 2, 0.05), 3: ((0, 8), (4, 12), 2, 0.05),
			4: ((0, 8), (4, 8, 10, 12, 13, 14, 15), 2, 0.05), 5: ((0,), (8,), 4, 0.03)}[lvl]
		s.add_drums(b, kicks, snares, hat_every=hat_every, hat_gain=hat * m)
	mm.write_wav(s.mix(), name)


def version1():
	"""Swell -> gap -> bass-out slow-motion ladder -> big re-entry -> fade (C major)."""
	bars = soul()
	bars += [  # 13-24: the new phrases of v4 (down-stairs, thirds, rush, high callbacks)
		B("下楼梯", "Am", CELL.format(x="C5", y="B4")), B("下楼梯", "F", CELL.format(x="A4", y="G4")),
		B("下楼梯", "Dm", CELL.format(x="F4", y="E4")), B("下楼梯", "C", "E4:2 F4:1 E4:2 D4:1 C4:1 D4:1"),
		B("三度爬梯", "C", CELL.format(x="C4", y="E4")), B("三度爬梯", "Am", CELL.format(x="E4", y="G4")),
		B("三度爬梯", "C", CELL.format(x="G4", y="B4")), B("三度爬梯", "G", CELL.format(x="B4", y="D5")),
		B("冲上去", "F", RUSH_C, 0.26), B("高位呼应", "Am", CELL.format(x="C6", y="D6"), 0.24),
		B("高位回落", "C", "G5:2 F5:1 E5:2 D5:1 C5:1 D5:1", 0.26), B("收尾", "G", "B4:2 C5:1 B4:2 A4:1 G4:2", 0.28),
		B("换气", "C", "D5:8", 0.20),  # 25: the air gap
	]
	slow = [("C", "E4:4 F4:2 E4:2"), ("G", "G4:4 F4:2 G4:2"), ("Am", "A4:4 B4:2 A4:2"), ("F", "C5:4 D5:2 C5:2"),
		("C", "E5:4 F5:2 E5:2"), ("G", "G5:4 F5:2 G5:2"), ("Am", "A5:4 B5:2 C6:2"), ("F", "C6:4 D6:2 E6:2")]
	bars += [B("慢动作爬梯", c, ld, 0.26) for c, ld in slow]  # 26-33: bass-out breakdown
	bars += [  # 34-41: re-entry, the ladder up high, third rush
		B("高位爬梯", "C", CELL.format(x="E5", y="F5"), 0.27), B("高位爬梯", "G", CELL.format(x="G5", y="F5"), 0.27),
		B("高位爬梯", "Am", CELL.format(x="A5", y="B5"), 0.26), B("高位爬梯", "F", CELL.format(x="C6", y="D6"), 0.25),
		B("高位爬梯", "C", CELL.format(x="G5", y="A5"), 0.26), B("高位回落", "C", "G5:2 F5:1 E5:2 D5:1 C5:1 D5:1", 0.26),
		B("冲上去", "F", "D4 F4 A4 C5 F5 A5 C6 D6 F6 G6 A6 B6 C7 - - -", 0.26), B("小跌", "G", "G5:2 A5:1 G5:2 F5:1 D5:2", 0.28),
		B("尾声", "F", "A5:2 G5:1 F5:2 E5:1 D5:2", 0.28), B("尾声", "G", "D5:2 E5:1 D5:2 B4:1 G4:2", 0.28),
		B("尾声", "C", "C5:8", 0.26),
	]
	pl = []
	for i in range(1, len(bars) + 1):
		if i <= 2: p = plan(bass=0.6)
		elif i <= 4: p = plan(bass=0.6, arp=0.6)
		elif i <= 6: p = plan(bass=1, arp=1, drums=1, master=0.95)
		elif i == 7: p = plan(bass=1, arp=1, drums=4, master=0.98)
		elif i <= 24: p = plan(bass=1, arp=1, drums=4 if i == 21 else 3, master=1.0 if i <= 12 else 1.02)
		elif i == 25: p = plan(lead=0.6, dbl=0)
		elif i <= 33: p = plan(arp=0.8, master=0.92)
		elif i <= 41: p = plan(bass=1, arp=1, drums=4 if i == 40 else 3, master=1.1)
		elif i == 42: p = plan(bass=1, arp=1, drums=2, master=0.95)
		elif i == 43: p = plan(bass=1, arp=0.8, drums=1, master=0.82)
		else: p = plan(bass=1, master=0.8)
		pl.append(p)
	render(bars, pl, "soxl_prog1_swell")
	return bars, pl


def version2():
	"""Bare start -> retrograde ladder -> gap -> minor-colour breakdown -> double-time quickening in a lifted key (D major)."""
	bars = soul()
	bars += [  # 13-16: phrase A walked backwards (do re / la si / so fa / mi fa)
		B("镜像爬梯", "F", CELL.format(x="C5", y="D5")), B("镜像爬梯", "Am", CELL.format(x="A4", y="B4")),
		B("镜像爬梯", "G", CELL.format(x="G4", y="F4")), B("镜像爬梯", "C", CELL.format(x="E4", y="F4")),
		B("换气", "G", "G4:8", 0.20),  # 17
	]
	down = [("Am", "E5:4 D5:2 E5:2"), ("F", "C5:4 A4:2 C5:2"), ("C", "G4:4 E4:2 G4:2"), ("G", "D5:4 B4:2 D5:2"),
		("Am", "E5:4 D5:2 E5:2"), ("F", "C5:4 A4:2 C5:2"), ("Dm", "D5:4 F5:2 D5:2"), ("G", "B4:4 D5:2 G5:2")]
	bars += [B("下沉", c, ld, 0.27) for c, ld in down]  # 18-25: bass-out breakdown
	lift = [("C", CELL.format(x="E4", y="F4")), ("G", CELL.format(x="G4", y="F4")), ("Am", CELL.format(x="A4", y="B4")),
		("F", CELL.format(x="C5", y="D5"))]
	bars += [B("升调爬梯", c, ld, 0.30, shift=2) for c, ld in lift]  # 26-29: phrase A, a whole step up
	fast = [("C", "G4 A4 G4 A4 G4 A4 G4 A4 E5 F5 E5 F5 E5 F5 E5 F5"), ("G", "D5 E5 D5 E5 D5 E5 D5 E5 B5 C6 B5 C6 B5 C6 B5 C6"),
		("Am", "C5 D5 C5 D5 C5 D5 C5 D5 A5 B5 A5 B5 A5 B5 A5 B5"), ("F", "C5 D5 C5 D5 C5 D5 C5 D5 C6 D6 C6 D6 C6 D6 C6 D6")]
	bars += [B("加速爬梯", c, ld, 0.24, shift=2) for c, ld in fast]  # 30-33: double time (16ths), same ladder idea
	bars += [  # 34-37: rush, cadence and a held tonic, written directly in D major
		B("冲上去", "G", "D4 G4 B4 D5 G5 B5 D6 E6 G6 A6 B6 - - - - -", 0.26),
		B("高位", "A", CELL.format(x="A5", y="B5"), 0.26), B("高位", "G", "B5:2 A5:1 G5:2 F#5:1 E5:2", 0.26),
		B("尾声", "D", "D5:8", 0.26),
	]
	pl = []
	for i in range(1, len(bars) + 1):
		if i <= 4: p = plan()
		elif i <= 6: p = plan(bass=0.8, arp=0.8)
		elif i == 7: p = plan(bass=1, arp=1, drums=4)
		elif i <= 16: p = plan(bass=1, arp=1, drums=3, master=1.0 if i <= 12 else 1.02)
		elif i == 17: p = plan(lead=0.6, dbl=0)
		elif i <= 25: p = plan(arp=0.8, master=0.92)
		elif i <= 33: p = plan(bass=1, arp=1, drums=3, master=1.08)
		elif i == 34: p = plan(bass=1, arp=1, drums=4, master=1.12)
		elif i <= 36: p = plan(bass=1, arp=1, drums=3, master=1.12)
		else: p = plan(bass=1, master=0.85)
		pl.append(p)
	render(bars, pl, "soxl_prog2_keylift")
	return bars, pl


def version3():
	"""Canon: from bar 8 on a second voice (a sixth below, half a bar later) answers the melody; chord loops from the reference."""
	bars = soul()
	bars += [  # 13-16 (vi-IV-I-V): third-swings walking down then back up
		B("三度摇摆", "Am", CELL.format(x="E5", y="C5")), B("三度摇摆", "F", CELL.format(x="C5", y="A4")),
		B("三度摇摆", "C", CELL.format(x="G4", y="E4")), B("三度摇摆", "G", CELL.format(x="B4", y="G4")),
		# 17-20 (IV-V-I-vi): do re / re mi / so la / la si, climbing
		B("再爬", "F", CELL.format(x="C5", y="D5")), B("再爬", "G", CELL.format(x="D5", y="E5")),
		B("再爬", "C", CELL.format(x="G5", y="A5"), 0.27), B("再爬", "Am", CELL.format(x="A5", y="B5"), 0.27),
		B("换气", "C", "E5:8", 0.20),  # 21
	]
	canon = [("C", "G5:4 F5:2 E5:2"), ("C", "D5:4 C5:2 D5:2"), ("Am", "C5:4 B4:2 A4:2"), ("Am", "B4:4 A4:2 B4:2"),
		("F", "A4:4 G4:2 F4:2"), ("F", "G4:4 F4:2 G4:2"), ("G", "B4:4 A4:2 G4:2"), ("G", "A4:4 D5:2 B4:2")]
	bars += [B("双声部", c, ld, 0.27) for c, ld in canon]  # 22-29: bass/drums out, two voices only
	bars += [  # 30-37: re-entry (I-V-vi-IV x2), rush, cadence
		B("再入", "C", CELL.format(x="E5", y="F5"), 0.27), B("再入", "G", CELL.format(x="G5", y="F5"), 0.27),
		B("再入", "Am", CELL.format(x="A5", y="B5"), 0.26), B("再入", "F", CELL.format(x="C6", y="D6"), 0.25),
		B("再入", "C", CELL.format(x="G5", y="A5"), 0.26), B("再入", "C", "G5:2 F5:1 E5:2 D5:1 C5:1 D5:1", 0.26),
		B("冲上去", "F", RUSH_C, 0.26), B("小跌", "G", "G5:2 A5:1 G5:2 F5:1 D5:2", 0.28),
	]
	pl = []
	for i in range(1, len(bars) + 1):
		if i <= 4: p = plan(arp=0.6)
		elif i <= 6: p = plan(bass=0.8, arp=0.9, drums=1)
		elif i == 7: p = plan(bass=1, arp=1, drums=4)
		elif i <= 20: p = plan(bass=1, arp=1, drums=3, counter=1.0 if i >= 8 else 0, master=1.0 if i <= 12 else 1.03)
		elif i == 21: p = plan(lead=0.6, dbl=0)
		elif i <= 29: p = plan(counter=1.3, master=0.95)
		else: p = plan(bass=1, arp=1, drums=4 if i == 36 else 3, counter=1.0, master=1.1)
		pl.append(p)
	render(bars, pl, "soxl_prog3_canon")
	return bars, pl


def timeline(results, path):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	fig, axes = plt.subplots(len(results), 1, figsize=(15, 3.2 * len(results)), facecolor="#14161c")
	rows = [("旋律", "lead"), ("低音", "bass"), ("琶音", "arp"), ("鼓", "drums"), ("副旋律", "counter")]
	for ax, (title, (bars, pl)) in zip(axes, results):
		M = np.array([[(p[k] / 4 if k == "drums" else p[k]) * p["master"] for p in pl] for _, k in rows])
		ax.imshow(M, aspect="auto", cmap="magma", vmin=0, vmax=1.3, interpolation="nearest")
		ax.set_yticks(range(len(rows)))
		ax.set_yticklabels([r[0] for r in rows], color="#cbd0dc")
		ax.set_xticks(range(0, len(bars), 4))
		ax.set_xticklabels([str(i + 1) for i in range(0, len(bars), 4)], color="#cbd0dc")
		ax.set_title(title, color="white", fontsize=13, loc="left")
		for i, b in enumerate(bars):
			if b["sec"] in ("换气", "冲上去"):
				ax.text(i, -0.75, "换气" if b["sec"] == "换气" else "冲", color="#ffd166", ha="center", fontsize=9)
	fig.tight_layout()
	fig.savefig(path, dpi=110, facecolor=fig.get_facecolor())
	print("wrote", os.path.normpath(path))


if __name__ == "__main__":
	res = [("版本 1 · 渐强升温:慢慢加层 → 换气 → 拿掉低音和鼓 → 重新进入 → 淡出", version1()),
		("版本 2 · 升调:光秃秃开头 → 镜像爬梯 → 下沉 → 升高一个全音 + 双倍速", version2()),
		("版本 3 · 卡农:第 8 小节起出现下方六度、晚半小节的第二声部", version3())]
	timeline(res, os.path.join(cs.OUT, "soxl_prog_timeline.png"))
