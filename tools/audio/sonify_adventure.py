#!/usr/bin/env python3
"""Adventure-style (C major, I-V-vi-IV) sonification of SOXL and DRAM weekly closes.

Reuses sonify_musical.py; only the data and file names change.
DRAM only started trading in the last week of March 2026, so the earlier bars (flat 27.00, flagged interpolated) are dropped.
Usage: python3 tools/audio/sonify_adventure.py [out_dir]
"""
import copy
import datetime as dt
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("sm", os.path.join(HERE, "sonify_musical.py"))
sm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sm)

SERIES = {
	"SOXL": (dt.date(2025, 7, 28), [
		24.08, 25.71, 27.37, 27.45, 26.04, 26.45, 29.30, 33.02, 34.02, 38.23, 34.21, 40.29, 43.14, 47.78, 41.74, 38.86,
		31.73, 41.26, 46.50, 41.71, 41.72, 44.21, 47.24, 53.95, 60.75, 61.60, 61.79, 61.75, 64.59, 67.11, 62.77, 47.89,
		50.72, 51.14, 46.61, 52.75, 76.39, 94.68, 128.32, 130.40, 176.94, 164.18, 190.56, 224.34, 182.54, 234.68, 279.29,
		215.60, 181.47, 192.26, 135.47, 136.81, 114.72, 140.25, 144.95, 120.60, 111.34, 117.28, 121.82, 123.67, 151.45,
		163.71, 139.76, 93.67, 83.56, 77.05, 45.97]),
	"DRAM": (dt.date(2026, 3, 30), [
		27.76, 32.43, 35.59, 37.20, 40.41, 52.80, 51.10, 52.82, 63.20, 55.79, 65.01, 76.71, 71.88, 60.63, 63.04, 52.72,
		53.20, 50.37, 50.60, 57.32, 57.68, 55.83, 59.69, 59.10, 59.61, 61.91, 61.78, 57.19, 46.45, 47.06, 48.01, 39.29]),
}

if __name__ == "__main__":
	base = sm.SPECS[1]  # the adventure spec
	for sym, (start, closes) in SERIES.items():
		sm.st.CLOSES = closes
		sm.st.START = start
		s = copy.deepcopy(base)
		s["file"] = f"{sym.lower()}_adventure"
		s["title"] = f"{sym} 周线 → 冒险游戏风 (C 大调, C-G-Am-F-C-G-F-G)"
		s["subtitle"] = (f"{len(closes)} 周真实收盘价 → 64 个音;走势只决定旋律方向,强拍只用和弦内音。"
			"仅为数据可听化,不是投资建议。")
		notes, _ = sm.build(s)
		print(sym, len(closes), "weeks ->", " ".join(sm.st.midi_name(m) for m in notes[:16]), "...")
