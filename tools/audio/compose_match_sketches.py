#!/usr/bin/env python3
"""Three 16-bar sketches for the in-game background: LIGHT and LIVELY, with a "match" feel, but only three elements each
(short staccato lead, bouncy bass, a very light tick). Keys differ from the menu theme (C major).

  match1_ticker   G major, 104 BPM: stock-ticker staccato (Wall Street), upward spikes at the end of phrases
  match2_cards    D major, 100 BPM, light swing: dealing-cards plucks with a soft flip noise on the last 16th
  match3_duel     F major, 108 BPM: call and response between two voices, like two players trading moves

Usage: python3 tools/audio/compose_match_sketches.py [out_dir]   (needs numpy)
"""
import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_music.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
mm.OUT = OUT
SR = mm.SR


def tick_drums(s, bar, kick=(), snare=(), hat_every=2, kick_g=0.20, snare_g=0.07, hat_g=0.035, flip=None):
	for st in kick:
		mm.add(s.drum, s.at(bar, st), mm.kick(), kick_g)
	for st in snare:
		mm.add(s.drum, s.at(bar, st), mm.noise(int(0.08 * SR), 0.03), snare_g)
	for st in range(0, 16, hat_every):
		mm.add(s.drum, s.at(bar, st), mm.noise(int(0.025 * SR), 0.006), hat_g)
	if flip is not None:  # a soft "card flip" noise burst
		mm.add(s.drum, s.at(bar, flip), mm.noise(int(0.05 * SR), 0.02), 0.06)


def finish(s, name):
	mix = s.mix()
	mm.write_wav(mix, name)
	rms = 20 * np.log10(np.sqrt((mix ** 2).mean()))
	print(f"{name}: {s.bars} bars, {len(mix) / SR:.1f}s, rms {rms:.1f} dB, peak {abs(mix).max():.2f}")


def ticker():
	s = mm.Song(104, 16, swing=0.0)
	roots = ["G2", "D2", "E2", "C2"]
	lead = [  # staccato eighths: a long-short swing between a chord tone and its neighbour, then a spike
		"B4 . C5 . B4 . C5 . B4 . C5 . D5 . C5 .", "A4 . B4 . A4 . B4 . A4 . B4 . C#5 . B4 .",
		"G4 . A4 . G4 . A4 . G4 . A4 . B4 . A4 .", "E5 . D5 . E5 . D5 . C5 . E5 . G5 . C6 .",
		"D5 . B4 . D5 . B4 . G4 . B4 . D5 . B4 .", "F#5 . D5 . F#5 . D5 . A4 . D5 . F#5 . D5 .",
		"E5 . B4 . E5 . B4 . G4 . B4 . E5 . B4 .", "G5 . E5 . G5 . E5 . C5 . E5 . D5 . B4 .",
	]
	lead += lead[:3] + ["E5 . D5 . E5 . D5 . C5 . E5 . G5 . A5 ."] + lead[4:7] + ["G5 . E5 . G5 . E5 . C5 . E5 . D5 . C5 ."]
	for b in range(16):
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.25, gain=0.22)
		s.add_bass_pattern(b, roots[b % 4], "1 . 1 . 5 . 1 . 1 . 1 . 5 . 1 .", length=1, gain=0.26)
		tick_drums(s, b, kick=(0, 8) if b >= 4 else (), snare=(4, 12) if b >= 8 else ())
	finish(s, "match1_ticker")


def cards():
	s = mm.Song(100, 16, swing=0.35)
	roots = ["D2", "A1", "B1", "G1"]
	lead = [
		"F#5 G5 . . F#5 G5 . . F#5 G5 . . A5 . F#5 .", "E5 F#5 . . E5 F#5 . . E5 F#5 . . A5 . E5 .",
		"D5 E5 . . D5 E5 . . D5 E5 . . F#5 . D5 .", "B4 D5 . . B4 D5 . . B4 D5 . . G5 . D5 .",
		"A5 . . . F#5 . . . D5 . . . F#5 . A5 .", "A5 . . . E5 . . . C#5 . . . E5 . A5 .",
		"F#5 . . . D5 . . . B4 . . . D5 . F#5 .", "G5 . . . D5 . . . B4 . . . D5 . G5 .",
	]
	lead += lead[:3] + ["B4 D5 . . B4 D5 . . B4 D5 . . G5 . A5 ."] + lead[4:7] + ["G5 . . . D5 . . . B4 . . . A4 . C#5 ."]
	for b in range(16):
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.25, gain=0.21)
		s.add_bass_pattern(b, roots[b % 4], "1 . . . 5 . . . 1 . . . 5 . . .", length=2, gain=0.28)
		tick_drums(s, b, kick=(0, 8) if b >= 4 else (), snare=(4, 12) if b >= 8 else (), hat_every=4, flip=15)
	finish(s, "match2_cards")


def duel():
	s = mm.Song(108, 16, swing=0.0)
	roots = ["F2", "A#1", "C2", "F2"]
	call = [  # voice A (bright, high) asks
		"A5 . . A5 . . G5 . A5 . C6 . . . . .", "A#5 . . A#5 . . A5 . A#5 . D6 . . . . .",
		"G5 . . G5 . . E5 . G5 . C6 . . . . .", "A5 . . A5 . . F5 . A5 . C6 . . . . .",
	]
	resp = [  # voice B (rounder, lower) answers
		". . . . . . . . F5 . . A5 . . C6 .", ". . . . . . . . D5 . . F5 . . A#5 .",
		". . . . . . . . E5 . . G5 . . C6 .", ". . . . . . . . C5 . . F5 . . A5 .",
	]
	for b in range(16):
		k = b % 4
		turn_a = (b // 2) % 2 == 0
		a = call[k] if turn_a else resp[k]
		bt = resp[k] if turn_a else call[k]
		s.add_lead(b, mm.parse_bar(a), duty=0.25, gain=0.21)
		s.add_lead(b, mm.parse_bar(bt), duty=0.5, gain=0.15, octave_shift=-1)
		s.add_bass_pattern(b, roots[k], "1 . . 1 . . 5 . 1 . . 1 . 5 . .", length=1, gain=0.26)
		tick_drums(s, b, kick=(0, 8), snare=(4, 12) if b >= 4 else (), hat_every=4)
	finish(s, "match3_duel")


if __name__ == "__main__":
	ticker()
	cards()
	duel()
