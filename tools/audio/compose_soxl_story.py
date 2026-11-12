#!/usr/bin/env python3
"""A composed (not data-fitted) 'rally' story in the adventure style: wobble low, lift, dip, rush up, wobble high, dip, settle.

Rhythm cell, used everywhere for regularity: the eighth-note 3+3+2 grouping of the SOXL adventure opening
(long, short, long, short, short, short). The long notes are always chord tones of the bar's chord.
Usage: python3 tools/audio/compose_soxl_story.py [out_dir]   (needs numpy, matplotlib)
"""
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "audio", "music")
mm.OUT = OUT

# Eighth-note grid, 8 slots per bar, grouped 3+3+2 exactly like the opening of the SOXL adventure version:
#   "X:2 Y:1 X:2 Y:1 X:1 Y:1"  = long, short, long, short, short, short  (X = chord tone, Y = neighbour).
# A bar without ':' is raw 16th-step tokens (used for the rush).
CELL = "{x}:2 {y}:1 {x}:2 {y}:1 {x}:1 {y}:1"
# (section, chord label, bass root, chord voicing, lead bar, lead gain)
BARS = [
	# ---- phrase A (bars 1-4): the "ladder": each bar swings between a chord tone and its neighbour, then steps up
	("低位浮动", "C", "C2", ["C4", "E4", "G4"], CELL.format(x="E4", y="F4"), 0.30),    # mi fa
	("低位浮动", "G", "G1", ["G3", "B3", "D4"], CELL.format(x="G4", y="F4"), 0.30),    # so fa
	("稍微抬高", "Am", "A1", ["A3", "C4", "E4"], CELL.format(x="A4", y="B4"), 0.30),   # la si
	("稍微抬高", "F", "F2", ["F3", "A3", "C4"], CELL.format(x="C5", y="D5"), 0.30),    # do re
	# ---- phrase B (bars 5-8)
	("再回落", "C", "C2", ["C4", "E4", "G4"], CELL.format(x="G4", y="A4"), 0.30),      # so la
	("再回落", "C", "C2", ["C4", "E4", "G4"], "G4:2 F4:1 E4:2 D4:1 C4:1 D4:1", 0.30),  # so fa mi re do re  (chosen variant 1)
	("冲上去", "F", "F2", ["F3", "A3", "C4"], "D4 F4 A4 C5 F5 A5 C6 D6 F6 G6 A6 B6 C7 - - -", 0.26),  # continues up from bar 6's D4
	("高位浮动", "C", "C2", ["C4", "E4", "G4"], CELL.format(x="G5", y="A5"), 0.26),
	# ---- phrase C (bars 9-12)
	("高位浮动", "G", "G1", ["G3", "B3", "D4"], CELL.format(x="B5", y="C6"), 0.26),
	("稍微低一点", "Am", "A1", ["A3", "C4", "E4"], CELL.format(x="A5", y="B5"), 0.26),
	("稍微低一点", "F", "F2", ["F3", "A3", "C4"], CELL.format(x="F5", y="G5"), 0.28),
	("小跌", "G", "G1", ["G3", "B3", "D4"], "G5:2 A5:1 G5:2 F5:1 D5:2", 0.28),
	# ---- phrase D (bars 13-16): NEW. The ladder walked DOWN, swinging on the lower neighbour: C5 -> A4 -> F4 -> E4
	("下楼梯", "Am", "A1", ["A3", "C4", "E4"], CELL.format(x="C5", y="B4"), 0.30),     # do ti
	("下楼梯", "F", "F2", ["F3", "A3", "C4"], CELL.format(x="A4", y="G4"), 0.30),      # la so
	("下楼梯", "Dm", "D2", ["D3", "F3", "A3"], CELL.format(x="F4", y="E4"), 0.30),     # fa mi
	("下楼梯", "C", "C2", ["C4", "E4", "G4"], "E4:2 F4:1 E4:2 D4:1 C4:1 D4:1", 0.30),  # mi fa (bar 1 callback) ... do re
	# ---- phrase E (bars 17-20): NEW. A climb in THIRDS: the short note now swings a third above (do-mi, mi-so, so-ti, ti-re)
	("三度爬梯", "C", "C2", ["C4", "E4", "G4"], CELL.format(x="C4", y="E4"), 0.30),
	("三度爬梯", "Am", "A1", ["A3", "C4", "E4"], CELL.format(x="E4", y="G4"), 0.30),
	("三度爬梯", "C", "C2", ["C4", "E4", "G4"], CELL.format(x="G4", y="B4"), 0.30),
	("三度爬梯", "G", "G1", ["G3", "B3", "D4"], CELL.format(x="B4", y="D5"), 0.30),
	# ---- phrase F (bars 21-24): NEW. The big rush from bar 20's D5, high callbacks to bars 4 and 6, then a gentle fall
	("冲上去", "F", "F2", ["F3", "A3", "C4"], "D5 F5 A5 C6 F6 G6 A6 B6 C7 - - - - - . .", 0.26),
	("高位呼应", "Am", "A1", ["A3", "C4", "E4"], CELL.format(x="C6", y="D6"), 0.24),   # bar 4's "do re", an octave up
	("高位回落", "C", "C2", ["C4", "E4", "G4"], "G5:2 F5:1 E5:2 D5:1 C5:1 D5:1", 0.26),  # bar 6's descent, an octave up
	("收尾", "G", "G1", ["G3", "B3", "D4"], "B4:2 C5:1 B4:2 A4:1 G4:2", 0.28),        # si do si la so: settles on the dominant
]


def expand(bar):
	"""'E4:2 F4:1 ...' (name:eighth-slots) -> 16 sixteenth-step tokens."""
	if ":" not in bar:
		return bar
	out = []
	for item in bar.split():
		name, slots = item.split(":")
		out += [name] + ["-"] * (int(slots) * 2 - 1)
	return " ".join(out)


SPARSE_LAST = True  # the final bar uses a lighter drum part (turn off for short clips)
SECTION_COLORS = {"低位浮动": "#2ec4ff", "稍微抬高": "#5b8cff", "再回落": "#3aa0ff", "冲上去": "#ff4fd8",
	"高位浮动": "#c04bff", "稍微低一点": "#9a6bff", "小跌": "#6f8fff", "下楼梯": "#3ad6a0", "三度爬梯": "#ffd166", "高位呼应": "#d17bff", "高位回落": "#8f7bff", "收尾": "#6f8fff"}
NAMES = "C C# D D# E F F# G G# A A# B".split()


def to_midi(name):
	n = mm.NOTE_INDEX[name[0]]
	i = 1
	if name[i] == "#":
		n += 1
		i += 1
	elif name[i] == "b":
		n -= 1
		i += 1
	return 12 * (int(name[i:]) + 1) + n


def build(name="soxl_story"):
	s = mm.Song(132, len(BARS))
	notes = []
	for b, (_sec, _lab, root, voicing, bar, gain) in enumerate(BARS):
		toks = mm.parse_bar(expand(bar))
		notes.append(toks)
		s.add_lead(b, toks, duty=0.25, gain=gain)
		s.add_lead(b, toks, duty=0.5, gain=0.04, octave_shift=-1)
		s.add_bass_pattern(b, root, "1 . 8 . 1 . 8 . 1 . 8 . 1 . 5 .", length=2, gain=0.42)
		s.add_arp(b, voicing, pattern=(0, 2, 1, 2), every=2, gain=0.05)
		if BARS[b][0] == "冲上去":  # the rush: snare roll
			s.add_drums(b, kicks=(0, 8), snares=(4, 8, 10, 12, 13, 14, 15), hat_every=2, hat_gain=0.05)
		elif SPARSE_LAST and b == len(BARS) - 1:
			s.add_drums(b, kicks=(0,), snares=(8,), hat_every=4, hat_gain=0.03)
		else:
			s.add_drums(b, kicks=(0, 8), snares=(4, 12), hat_every=2, hat_gain=0.05)
	mm.write_wav(s.mix(), name)
	return notes


def draw(notes):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	plt.rcParams["axes.unicode_minus"] = False
	nb = len(BARS)
	allm = [to_midi(n) for bar in notes for _, _, n in bar]
	rlo, rhi = min(allm) - 3, max(allm) + 3
	fig = plt.figure(figsize=(15, 7.2), facecolor="#14161c")
	ax = fig.add_axes([0.085, 0.10, 0.88, 0.74], facecolor="#1b1e27")
	kb = fig.add_axes([0.03, 0.10, 0.055, 0.74], facecolor="#14161c")
	for m in range(rlo, rhi + 1):
		black = m % 12 in (1, 3, 6, 8, 10)
		ax.add_patch(Rectangle((0, m - 0.5), nb * 16, 1, color="#20242f" if black else "#262b38", lw=0, zorder=0))
		kb.add_patch(Rectangle((0, m - 0.5), 0.55 if black else 1, 1, fc="#111" if black else "#f4f1e8", ec="#555", lw=0.4,
			zorder=2 if black else 1))
		if m % 12 == 0:
			ax.axhline(m - 0.5, color="#3a4052", lw=0.8, zorder=1)
			kb.text(0.97, m, f"C{m // 12 - 1}", ha="right", va="center", fontsize=8, color="#333", zorder=3)
	kb.set_xlim(0, 1)
	kb.set_ylim(rlo - 0.5, rhi + 0.5)
	kb.axis("off")
	means = []
	for b, bar in enumerate(notes):
		sec, label = BARS[b][0], BARS[b][1]
		col = SECTION_COLORS[sec]
		ax.axvline(b * 16, color="#3a4052", lw=0.8, zorder=1)
		ax.text(b * 16 + 8, rhi + 0.3, label, color="#ffd166", ha="center", va="bottom", fontsize=12, fontweight="bold")
		ms = []
		for s0, ln, name in bar:
			m = to_midi(name)
			ms.append(m)
			ax.add_patch(Rectangle((b * 16 + s0 + 0.05, m - 0.42), ln - 0.1, 0.84, fc=col, ec="white", lw=0.4, zorder=4))
		means.append(float(np.mean(ms)))
	# story line: average pitch of each bar
	xs = [b * 16 + 8 for b in range(nb)]
	ax.plot(xs, means, color="#ffd166", lw=2.0, marker="o", ms=4, zorder=5, label="故事线(每小节平均音高)")
	# section bands
	start = 0
	for b in range(1, nb + 1):
		if b == nb or BARS[b][0] != BARS[start][0]:
			ax.text((start + b) * 8, rlo - 0.1, BARS[start][0], color=SECTION_COLORS[BARS[start][0]], ha="center", va="bottom",
				fontsize=11, fontweight="bold")
			start = b
	ax.set_xlim(0, nb * 16)
	ax.set_ylim(rlo - 0.5, rhi + 0.9)
	ax.set_xticks([b * 16 for b in range(nb)])
	ax.set_xticklabels([str(b + 1) for b in range(nb)], color="#cbd0dc")
	ax.set_xlabel("小节", color="#cbd0dc")
	ax.set_yticks([m for m in range(rlo, rhi + 1) if m % 12 == 0])
	ax.set_yticklabels([f"C{m // 12 - 1}" for m in range(rlo, rhi + 1) if m % 12 == 0], color="#cbd0dc")
	for sp in ax.spines.values():
		sp.set_visible(False)
	ax.legend(loc="upper left", facecolor="#14161c", edgecolor="none", labelcolor="white")
	fig.suptitle("SOXL 风格 · 叙事版 v4(24 小节 = 6 段 × 4 小节,后 12 小节全新)", color="white", fontsize=16, y=0.965)
	fig.text(0.5, 0.025, "全程同一个八分音符 3+3+2 '长-短'格子(与原版 SOXL 开头一致);长音都是和弦内音;每 4 小节一段,第 7、21 小节是冲上去;13–24 小节为新写。", color="#9aa1b3",
		ha="center", fontsize=10)
	path = os.path.join(OUT, "soxl_story.png")
	fig.savefig(path, dpi=125, facecolor=fig.get_facecolor())
	print("wrote", os.path.normpath(path))


def export_midi(path):
	"""Writes the same song as a 4-track MIDI file (lead, bass, arpeggio, drums) for editing in GarageBand etc."""
	import mido
	TPS = 120  # ticks per sixteenth (480 per beat)
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("track_name", name="SOXL story", time=0))
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(132), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
	mid.tracks.append(meta)

	def track(name, channel, program, events):
		tr = mido.MidiTrack()
		tr.append(mido.MetaMessage("track_name", name=name, time=0))
		if channel != 9:
			tr.append(mido.Message("program_change", channel=channel, program=program, time=0))
		ev = []
		for start, length, note, vel in events:
			ev.append((start * TPS, 1, mido.Message("note_on", channel=channel, note=note, velocity=vel)))
			ev.append(((start + length) * TPS, 0, mido.Message("note_off", channel=channel, note=note, velocity=0)))
		ev.sort(key=lambda e: (e[0], e[1]))
		t = 0
		for tick, _, msg in ev:
			tr.append(msg.copy(time=tick - t))
			t = tick
		mid.tracks.append(tr)

	lead, bass, arp, drums = [], [], [], []
	for b, (_sec, _lab, root, voicing, bar, _gain) in enumerate(BARS):
		base = b * 16
		for s0, ln, name in mm.parse_bar(expand(bar)):
			lead.append((base + s0, ln, to_midi(name), 100))
		for i, tok in enumerate("1 . 8 . 1 . 8 . 1 . 8 . 1 . 5 .".split()):
			if tok != ".":
				bass.append((base + i, 2, to_midi(root) + {"1": 0, "8": 12, "5": 7}[tok], 90))
		for j, i in enumerate(range(0, 16, 2)):
			arp.append((base + i, 2, to_midi(voicing[(0, 2, 1, 2)[j % 4]]), 55))
		if BARS[b][0] == "冲上去":
			kicks, snares = (0, 8), (4, 8, 10, 12, 13, 14, 15)
		elif SPARSE_LAST and b == len(BARS) - 1:
			kicks, snares = (0,), (8,)
		else:
			kicks, snares = (0, 8), (4, 12)
		for i in kicks:
			drums.append((base + i, 1, 36, 110))
		for i in snares:
			drums.append((base + i, 1, 38, 100))
		for i in range(0, 16, 4 if (SPARSE_LAST and b == len(BARS) - 1) else 2):
			drums.append((base + i, 1, 42, 60))
	track("Lead (Square)", 0, 80, lead)
	track("Bass", 1, 38, bass)
	track("Arpeggio", 2, 81, arp)
	track("Drums", 9, 0, drums)
	mid.save(path)
	print("wrote", os.path.normpath(path), f"({len(lead)} lead notes)")


if __name__ == "__main__":
	draw(build())
	export_midi(os.path.join(OUT, "soxl_story.mid"))
