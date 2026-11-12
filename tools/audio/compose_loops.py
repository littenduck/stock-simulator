#!/usr/bin/env python3
"""Three short, seamlessly looping game-music cues. Only the user's first four bars are kept (mi fa / so fa / la si / do re);
everything after is new. Each loop keeps the "suddenly rushes up" element and ends one step away from bar 1's first note (E4),
so the tail connects to the head.

Usage: python3 tools/audio/compose_loops.py [out_dir]   (needs numpy, matplotlib, mido)
"""
import importlib.util
import os
import sys

import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("prog", os.path.join(HERE, "compose_soxl_progressive.py"))
prog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prog)
cs, mm = prog.cs, prog.mm
prog.CH["E"] = ("E2", ["E3", "G#3", "B3"])
B, CELL, plan = prog.B, prog.CELL, prog.plan
HEAD = prog.soul()[:4]  # C G Am F : mi fa / so fa / la si / do re


def loop1():
	"""Sprint, 8 bars (14.5 s): ladder up, rush straight off the ladder's top, high wobble, step-wise descent back to bar 1."""
	return "loop1_sprint", HEAD + [
		B("冲上去", "G", "D5 E5 G5 A5 B5 D6 E6 F6 G6 A6 B6 C7 - - - -", 0.26),
		B("高位浮动", "C", CELL.format(x="G5", y="A5"), 0.26),
		B("高位浮动", "Am", CELL.format(x="E5", y="F5").replace("E5:1 F5:1", "E5:1 D5:1"), 0.26),
		B("连接", "G", "B4:2 A4:1 G4:2 F4:1 D4:2", 0.28),
	]


def loop2():
	"""Question and answer, 10 bars (18.2 s): ladder up, ladder walked down, a held low note (air gap), rush from it, high answer."""
	return "loop2_answer", HEAD + [
		B("下楼梯", "Am", CELL.format(x="C5", y="B4")),
		B("下楼梯", "F", CELL.format(x="A4", y="G4")),
		B("换气", "G", "D4:8", 0.20),
		B("冲上去", "C", "E4 G4 C5 E5 G5 C6 D6 E6 G6 A6 B6 C7 - - - -", 0.26),
		B("高位呼应", "F", CELL.format(x="C6", y="D6"), 0.25),
		B("连接", "G", "D5:2 B4:1 G4:2 A4:1 F4:2", 0.28),
	]


def loop3():
	"""Contrary motion, 12 bars (21.8 s): melody climbs (do re, re mi, fa so, #so la) while the bass walks down A-G-F-E, then the rush."""
	return "loop3_contrary", HEAD + [
		B("反向爬", "Am", CELL.format(x="C5", y="D5")),
		B("反向爬", "G", CELL.format(x="D5", y="E5")),
		B("反向爬", "F", CELL.format(x="F5", y="G5")),
		B("反向爬", "E", CELL.format(x="G#5", y="A5"), 0.27),
		B("冲上去", "Am", "E4 A4 C5 E5 A5 C6 D6 E6 A6 B6 C7 - - - - -", 0.26),
		B("高位呼应", "C", CELL.format(x="G5", y="A5"), 0.26),
		B("高位呼应", "F", "C6:2 D6:1 C6:2 D6:1 C6:1 A5:1", 0.25),
		B("连接", "G", "D5:2 C5:1 B4:2 A4:1 F4:2", 0.28),
	]


def plans_for(bars):
	out = []
	for b in bars:
		if b["sec"] == "换气":
			out.append(plan(lead=0.7, dbl=0, bass=0.8))
		elif b["sec"] == "冲上去":
			out.append(plan(bass=1, arp=1, drums=4))
		else:
			out.append(plan(bass=1, arp=1, drums=3))
	return out


def export_midi(bars, plans, path):
	import mido
	TPS = 120
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(132), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
	mid.tracks.append(meta)

	def track(name, ch, program, events):
		tr = mido.MidiTrack()
		tr.append(mido.MetaMessage("track_name", name=name, time=0))
		if ch != 9:
			tr.append(mido.Message("program_change", channel=ch, program=program, time=0))
		ev = []
		for st, ln, note, vel in events:
			ev.append((st * TPS, 1, mido.Message("note_on", channel=ch, note=note, velocity=vel)))
			ev.append(((st + ln) * TPS, 0, mido.Message("note_off", channel=ch, note=note, velocity=0)))
		ev.sort(key=lambda e: (e[0], e[1]))
		t = 0
		for tick, _, msg in ev:
			tr.append(msg.copy(time=tick - t))
			t = tick
		mid.tracks.append(tr)

	lead, bass, arp, drums = [], [], [], []
	for b, (bar, pl) in enumerate(zip(bars, plans)):
		base = b * 16
		for s0, ln, name in mm.parse_bar(cs.expand(bar["lead"])):
			lead.append((base + s0, ln, cs.to_midi(name), 100))
		rootm = cs.to_midi(bar["bass"])
		if pl["bass"]:
			if bar["lead"].endswith(":8"):
				bass.append((base, 14, rootm, 90))
			else:
				for i, tok in enumerate("1 . 8 . 1 . 8 . 1 . 8 . 1 . 5 .".split()):
					if tok != ".":
						bass.append((base + i, 2, rootm + {"1": 0, "8": 12, "5": 7}[tok], 90))
		if pl["arp"]:
			for j, i in enumerate(range(0, 16, 2)):
				arp.append((base + i, 2, cs.to_midi(bar["voicing"][(0, 2, 1, 2)[j % 4]]), 55))
		lvl = pl["drums"]
		kicks, snares = {0: ((), ()), 1: ((), ()), 2: ((0, 8), ()), 3: ((0, 8), (4, 12)), 4: ((0, 8), (4, 8, 10, 12, 13, 14, 15))}[lvl]
		for i in kicks:
			drums.append((base + i, 1, 36, 110))
		for i in snares:
			drums.append((base + i, 1, 38, 100))
		if lvl:
			for i in range(0, 16, 2):
				drums.append((base + i, 1, 42, 60))
	track("Lead (Square)", 0, 80, lead)
	track("Bass", 1, 38, bass)
	track("Arpeggio", 2, 81, arp)
	track("Drums", 9, 0, drums)
	mid.save(path)


def draw(items, path):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	fig, axes = plt.subplots(len(items), 1, figsize=(14, 3.6 * len(items)), facecolor="#14161c")
	colors = {"低位浮动": "#2ec4ff", "稍微抬高": "#5b8cff", "冲上去": "#ff4fd8", "高位浮动": "#c04bff", "高位呼应": "#d17bff",
		"下楼梯": "#3ad6a0", "换气": "#999999", "连接": "#6f8fff", "反向爬": "#ffd166"}
	for ax, (title, bars) in zip(axes, items):
		ax.set_facecolor("#1b1e27")
		allm = [cs.to_midi(n) for bar in bars for _, _, n in mm.parse_bar(cs.expand(bar["lead"]))]
		lo, hi = min(allm) - 2, max(allm) + 3
		for m in range(lo, hi + 1):
			black = m % 12 in (1, 3, 6, 8, 10)
			ax.add_patch(Rectangle((0, m - 0.5), len(bars) * 16, 1, color="#20242f" if black else "#262b38", lw=0, zorder=0))
		for i, bar in enumerate(bars):
			ax.axvline(i * 16, color="#3a4052", lw=0.8)
			ax.text(i * 16 + 8, hi + 0.2, bar["label"], color="#ffd166", ha="center", fontsize=11, fontweight="bold")
			for s0, ln, name in mm.parse_bar(cs.expand(bar["lead"])):
				m = cs.to_midi(name)
				ax.add_patch(Rectangle((i * 16 + s0 + 0.05, m - 0.42), ln - 0.1, 0.84, fc=colors.get(bar["sec"], "#aaa"), ec="white",
					lw=0.4, zorder=4))
		ax.annotate("", xy=(len(bars) * 16, cs.to_midi("E4")), xytext=(len(bars) * 16 - 2, cs.to_midi("F4")),
			arrowprops=dict(arrowstyle="->", color="#ffd166"))
		ax.set_xlim(0, len(bars) * 16)
		ax.set_ylim(lo - 0.5, hi + 1.2)
		ax.set_yticks([m for m in range(lo, hi + 1) if m % 12 == 0])
		ax.set_yticklabels([f"C{m // 12 - 1}" for m in range(lo, hi + 1) if m % 12 == 0], color="#cbd0dc")
		ax.set_xticks([i * 16 for i in range(len(bars))])
		ax.set_xticklabels([str(i + 1) for i in range(len(bars))], color="#cbd0dc")
		ax.set_title(title, color="white", fontsize=13, loc="left")
		for sp in ax.spines.values():
			sp.set_visible(False)
	fig.tight_layout()
	fig.savefig(path, dpi=110, facecolor=fig.get_facecolor())
	print("wrote", os.path.normpath(path))


if __name__ == "__main__":
	items = []
	titles = {"loop1_sprint": "循环 1 · 冲刺(8 小节,14.5 秒):爬梯 → 直接冲 → 高位浮动 → 台阶下行接回开头",
		"loop2_answer": "循环 2 · 问答(10 小节,18.2 秒):爬梯 → 下楼梯 → 低音换气 → 冲上去 → 高位应答",
		"loop3_contrary": "循环 3 · 反向(12 小节,21.8 秒):旋律上爬 + 低音下走(A-G-F-E)→ 冲上去 → 应答"}
	for fn in (loop1, loop2, loop3):
		name, bars = fn()
		plans = plans_for(bars)
		prog.render(bars, plans, name)
		export_midi(bars, plans, os.path.join(cs.OUT, name + ".mid"))
		items.append((titles[name], bars))
	draw(items, os.path.join(cs.OUT, "loops_overview.png"))
