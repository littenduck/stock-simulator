#!/usr/bin/env python3
"""Bars 1-5 of the SOXL story stay as they are; bar 6 gets three alternatives (plus the current one for A/B).

Why bar 6 felt rough: bar 5 ends on la (A4); the old bar 6 opens on mi (E4) = a falling fourth, and E is not in the G chord underneath.
All three variants start next to A4 (stepwise) and keep every long note a chord tone of the bar's chord.
Usage: python3 tools/audio/soxl_bar6_variants.py [out_dir]
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("cs", os.path.join(HERE, "compose_soxl_story.py"))
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

SOL = {"C": "do", "D": "re", "E": "mi", "F": "fa", "G": "so", "A": "la", "B": "si"}
HEAD = list(cs.BARS[:5])
VARIANTS = [
	("v0_current", "当前:mi re (Am)", cs.BARS[5]),
	("v1_stepdown", "变体1 步步回落:so fa mi re do re (C)",
		("再回落", "C", "C2", ["C4", "E4", "G4"], "G4:2 F4:1 E4:2 D4:1 C4:1 D4:1", 0.30)),
	("v2_sola_drop", "变体2 延续 so la,最后一拍落下:so la so la fa re (G)",
		("再回落", "G", "G1", ["G3", "B3", "D4"], "G4:2 A4:1 G4:2 A4:1 F4:1 D4:1", 0.30)),
	("v3_fami", "变体3 下邻音摇摆:fa mi fa mi re mi (Dm)",
		("再回落", "Dm", "D2", ["D3", "F3", "A3"], "F4:2 E4:1 F4:2 E4:1 D4:1 E4:1", 0.30)),
]


def solfege(bar):
	return " ".join(SOL[n[0]] for _, _, n in cs.mm.parse_bar(cs.expand(bar)))


def compare_figure(path):
	plt.rcParams["font.sans-serif"] = ["PingFang SC", "Arial Unicode MS", "Heiti SC", "DejaVu Sans"]
	fig, axes = plt.subplots(len(VARIANTS), 1, figsize=(12, 9), facecolor="#14161c", sharex=True)
	lo, hi = 57, 79
	for ax, (_k, title, bar6) in zip(axes, VARIANTS):
		ax.set_facecolor("#1b1e27")
		for m in range(lo, hi + 1):
			black = m % 12 in (1, 3, 6, 8, 10)
			ax.add_patch(Rectangle((0, m - 0.5), 32, 1, color="#20242f" if black else "#262b38", lw=0, zorder=0))
		for i, (x0, bar, col) in enumerate(((0, HEAD[4][4], "#3aa0ff"), (16, bar6[4], "#ffb703"))):
			for s0, ln, name in cs.mm.parse_bar(cs.expand(bar)):
				m = cs.to_midi(name)
				ax.add_patch(Rectangle((x0 + s0 + 0.05, m - 0.42), ln - 0.1, 0.84, fc=col, ec="white", lw=0.4, zorder=4))
		ax.axvline(16, color="#ffd166", lw=1.2, zorder=3)
		ax.text(8, hi + 0.3, "第 5 小节 (C)  " + solfege(HEAD[4][4]), color="#9aa1b3", ha="center", fontsize=10)
		ax.text(24, hi + 0.3, f"第 6 小节 ({bar6[1]})  " + solfege(bar6[4]), color="#ffd166", ha="center", fontsize=10)
		ax.set_xlim(0, 32)
		ax.set_ylim(lo - 0.5, hi + 1.6)
		ax.set_yticks([60, 72])
		ax.set_yticklabels(["C4", "C5"], color="#cbd0dc")
		ax.set_xticks([])
		ax.set_ylabel(title.split(":")[0], color="white", rotation=0, ha="right", va="center", fontsize=11)
		for sp in ax.spines.values():
			sp.set_visible(False)
	fig.suptitle("第 6 小节:当前 vs 三个变体(蓝 = 第 5 小节,金 = 第 6 小节)", color="white", fontsize=15)
	fig.savefig(path, dpi=120, facecolor=fig.get_facecolor(), bbox_inches="tight")
	print("wrote", os.path.normpath(path))


if __name__ == "__main__":
	cs.SPARSE_LAST = False  # keep bar 6's drums as in the full song
	for key, title, bar6 in VARIANTS:
		cs.BARS = HEAD + [bar6]
		name = f"soxl6_{key}"
		cs.build(name)
		cs.export_midi(os.path.join(cs.OUT, name + ".mid"))
		print("  ", title, "| bar 6 =", solfege(bar6[4]))
	compare_figure(os.path.join(cs.OUT, "soxl6_compare.png"))
