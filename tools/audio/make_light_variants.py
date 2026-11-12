#!/usr/bin/env python3
"""Three 'light' 8-bit variants built on ONE hook taken from the user's hummed melody.

The hum's contour (repeated note x3, stepwise climb to the tonic, tonic repeated, step back down) is
scale degrees   5 5 5 6 b7 1' 1' b7 6 5   (minor)  /  5 5 5 6 7 1' 1' 7 6 5   (major).
Every variant states that hook in bars 1-2, repeats it with a new ending in bars 3-4, contrasts in bars 5-7
and ends on the dominant so the 8-bar loop pulls back to bar 1.

Usage: python3 tools/audio/make_light_variants.py [out_dir]
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_music.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
mm.OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "audio", "music")


def v1_alley_thief():
	"""Light 1 - 'Back-alley thief' (Kerning City mood): D minor, swung, sneaky walking bass, comping stabs."""
	s = mm.Song(108, 8, swing=0.85)
	lead = [
		"A4 - A4 - A4 - B4 - C5 - D5 - - - . .",   # 1 hook
		"C5 - B4 - A4 - . . A4 - A4 - B4 - C5 -",   # 2 answer + pickup
		"G4 - G4 - G4 - A4 - Bb4 - C5 - - - . .",   # 3 hook, moved up a step on Gm
		"C5 - Bb4 - A4 - . . C#5 - E5 - A5 - - -",  # 4 new ending: arpeggio leap to A5 (payoff)
		"D5 - . D5 - . F5 - D5 - . C5 - D5 - .",  # 5 contrast: 3+3+2 syncopation
		"Bb4 - . Bb4 - . D5 - Bb4 - . A4 - Bb4 - .",  # 6 same rhythm, down a third
		"G4 - . G4 - . Bb4 - G4 - A4 - C#5 - E5 -",  # 7 climbs into the dominant
		"D5 - C5 - B4 - A4 - - - - - . . . .",      # 8 hook falls and stops on A (dominant)
	]
	chords = [
		["D4", "F4", "A4"], ["D4", "F4", "A4"], ["G3", "Bb3", "D4"], ["A3", "C#4", "E4", "G4"],
		["D4", "F4", "A4"], ["Bb3", "D4", "F4"], ["G3", "Bb3", "D4"], ["A3", "C#4", "E4"],
	]
	walk = [
		"D2 . . . F2 . . . A2 . . . F2 . . .",
		"D2 . . . A2 . . . C3 . . . A2 . . .",
		"G2 . . . Bb2 . . . D3 . . . Bb2 . . .",
		"A2 . . . C#3 . . . E3 . . . C#3 . . .",
		"D2 . . . F2 . . . A2 . . . D3 . . .",
		"Bb1 . . . D2 . . . F2 . . . D2 . . .",
		"G2 . . . Bb2 . . . A2 . . . C#3 . . .",
		"A2 . . . E2 . . . A2 . . . C#3 . . .",
	]
	for b in range(8):
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.25, gain=0.30)
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.5, gain=0.05, octave_shift=-1)
		s.add_bass_pattern(b, "D2", walk[b], length=4, gain=0.42)
		s.add_stab(b, chords[b], steps=(4, 12), length=2, gain=0.08)
		s.add_drums(b, kicks=(0, 8), snares=(4, 12), hat_every=2, hat_gain=0.035)
	return s.mix()


def v2_wall_street():
	"""Light 2 - 'Wall Street open': E minor, 136 bpm, ticker-tape staccato, driving pulse bass, four-on-the-floor."""
	s = mm.Song(136, 8)
	lead = [
		"B4 B4 . B4 . B4 C5 . D5 . . . E5 - . .",   # 1 hook as ticker-tape 16ths
		"E5 . D5 . C5 . B4 . . B4 B4 . C5 . B4 .",   # 2 answer
		"D5 D5 . D5 . D5 E5 . F#5 . . . G5 - . .",   # 3 hook on G
		"G5 . F#5 . E5 . D5 . . F#5 F#5 . A5 - . .",  # 4 new ending: leap to A5
		"E5 - - E5 - - G5 - - G5 - - B5 - . .",      # 5 contrast: 3-3-3-3 hemiola against the 4/4 pulse
		"C6 - - C6 - - B5 - - B5 - - G5 - . .",      # 6
		"A5 - - A5 - - F#5 - - F#5 - - D5 - . .",    # 7
		"B4 B4 . B4 . D#5 E5 . F#5 . . . B5 - - -",  # 8 hook turns into B (dominant, D# = leading tone)
	]
	roots = ["E2", "C2", "G2", "D2", "E2", "C2", "D2", "B1"]
	chords = [
		["E4", "G4", "B4"], ["C4", "E4", "G4"], ["G4", "B4", "D5"], ["D4", "F#4", "A4"],
		["E4", "G4", "B4"], ["C4", "E4", "G4"], ["D4", "F#4", "A4"], ["B3", "D#4", "F#4"],
	]
	for b in range(8):
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.125, gain=0.30)
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.5, gain=0.07, octave_shift=-1)
		s.add_bass_pattern(b, roots[b], "1 . 1 . 8 . 1 . 1 . 1 . 8 . 5 .", length=2, gain=0.40)
		s.add_arp(b, chords[b], pattern=(0, 1, 2, 1), every=1, gain=0.045)
		s.add_drums(b, kicks=(0, 4, 8, 12), snares=(4, 12), hat_every=2, hat_gain=0.06)
	return s.mix()


def v3_casino():
	"""Light 3 - 'Casino floor' (Monopoly / money): C major, 124 bpm, ragtime oom-pah, coin-slot arpeggio runs."""
	s = mm.Song(124, 8)
	lead = [
		"G4 . . G4 . . A4 - B4 - C5 - - - . .",     # 1 hook, 3+3+2 bounce
		"C5 - B4 - A4 - G4 - . . G4 G4 A4 - B4 -",  # 2 answer + pickup
		"C5 . . C5 . . D5 - E5 - F5 - - - . .",     # 3 hook on F
		"F5 - E5 - D5 - B4 - . . D5 D5 E5 - D5 -",  # 4
		"C6 E6 G6 E6 C6 E6 G6 E6 G5 C6 E6 C6 G5 C6 E6 G6",   # 5 slot-machine coin cascade
		"A5 C6 E6 C6 A5 C6 E6 C6 A5 C6 E6 C6 E6 D6 C6 B5",   # 6
		"D6 F6 A6 F6 D6 F6 A6 F6 G5 B5 D6 B5 G5 B5 D6 F6",   # 7
		"C6 - B5 - A5 - G5 - . . . . G5 - - -",       # 8 hook falls to G (dominant) -> loops to bar 1
	]
	roots = ["C2", "C2", "F2", "G2", "C2", "A1", "D2", "G1"]
	chords = [
		["E4", "G4", "C5"], ["E4", "G4", "C5"], ["F4", "A4", "C5"], ["G4", "B4", "D5", "F5"],
		["E4", "G4", "C5"], ["E4", "A4", "C5"], ["F4", "A4", "D5"], ["G4", "B4", "D5"],
	]
	for b in range(8):
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.125 if b >= 4 else 0.25, gain=0.30)
		s.add_lead(b, mm.parse_bar(lead[b]), duty=0.5, gain=0.045, octave_shift=1)
		s.add_bass_pattern(b, roots[b], "1 . . . 5 . . . 1 . . . 5 . . .", length=3, gain=0.42)
		s.add_stab(b, chords[b], steps=(4, 12), length=2, gain=0.07)
		s.add_drums(b, kicks=(0, 8), snares=(4, 12), hat_every=4, hat_gain=0.04)
	return s.mix()


if __name__ == "__main__":
	mm.write_wav(v1_alley_thief(), "light1_alley_thief")
	mm.write_wav(v2_wall_street(), "light2_wall_street")
	mm.write_wav(v3_casino(), "light3_casino")
