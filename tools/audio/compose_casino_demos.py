#!/usr/bin/env python3
"""Three melody-only demos (MIDI + a soft 8-bit triangle-wave render) for the slow, long "casino floor" gameplay loop.

The user's idea ("soul") is kept: every bar is a LONG chord tone plus a SHORT neighbour that swings next to it (a ladder that climbs
and falls with the chords). What changes: much slower tempo, swing/waltz/shuffle feel, 32-40 bars (about 1.5 minutes), and a last
note one step below the first note so the loop closes.

  casino1_lounge  C major, 72 BPM, 4/4 swung, jazz 7th chords, bell-like "slot machine" bars in the bridge
  casino2_waltz   C major, 76 BPM, 3/4 music-box waltz, 40 bars
  casino3_noir    A minor, 66 BPM, 4/4 shuffle, chromatic neighbours, smoky high-roller mood

Usage: python3 tools/audio/compose_casino_demos.py [out_dir]   (needs numpy, mido)
"""
import importlib.util
import os
import sys
import wave

import mido
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_music.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
NAMES = "C C# D D# E F F# G G# A A# B".split()
SOL = {"C": "do", "D": "re", "E": "mi", "F": "fa", "G": "so", "A": "la", "B": "si"}
C_MAJOR = {0, 2, 4, 5, 7, 9, 11}
A_MINOR_NAT = {9, 11, 0, 2, 4, 5, 7}
CHORDS = {  # pitch classes
	"Cmaj7": {0, 4, 7, 11}, "C": {0, 4, 7}, "A7": {9, 1, 4, 7}, "Am": {9, 0, 4}, "Am7": {9, 0, 4, 7}, "Dm": {2, 5, 9},
	"Dm7": {2, 5, 9, 0}, "G7": {7, 11, 2, 5}, "Em": {4, 7, 11}, "Em7": {4, 7, 11, 2}, "F": {5, 9, 0}, "Fmaj7": {5, 9, 0, 4},
	"Fm6": {5, 8, 0, 2}, "E7": {4, 8, 11, 2}, "Bm7b5": {11, 2, 5, 9}, "D7": {2, 6, 9, 0},
}
# templates: (start step, length in steps, role)  X = chord tone, Y = neighbour, Z = next chord tone above X
T44 = {  # quiet background: 2-3 notes per bar, long note + a short neighbour (the user's idea, slowed down)
	"CELL": [(0, 8, "X"), (8, 4, "Y"), (12, 4, "X")],
	"LAZY": [(0, 8, "X"), (8, 8, "Y")],
	"SYNC": [(0, 6, "X"), (6, 2, "Y"), (8, 8, "Z")],
	"BELL": [(0, 4, "X"), (6, 2, "Z"), (8, 8, "X")],                       # a soft chime, then a long note
	"RUN": [(0, 4, "X"), (4, 4, "Z"), (8, 8, "Y")],
	"TURN": [(0, 8, "X"), (8, 8, "Y")],
	"HOLD": [(0, 12, "X"), (12, 4, "R")],
}
T34 = {
	"WALTZ": [(0, 6, "X"), (6, 6, "Y")],
	"WALTZ2": [(0, 6, "X"), (6, 3, "Z"), (9, 3, "Y")],
	"SKIP": [(0, 4, "X"), (4, 8, "Z")],
	"WHOLE": [(0, 12, "X")],
}


def nearest(target, allowed):
	return min((m for m in range(target - 12, target + 13) if m % 12 in allowed), key=lambda m: (abs(m - target), -m))


def step_to(m, allowed, direction):
	m += direction
	while m % 12 not in allowed:
		m += direction
	return m


def bar_notes(chord, target, tpl, ydir, scale, chromatic, templates):
	allowed_nb = set(range(12)) if chromatic else scale | CHORDS[chord]
	x = nearest(target, CHORDS[chord])
	out = []
	for st, ln, role in templates[tpl]:
		if role == "R":
			continue
		m = x if role == "X" else step_to(x, allowed_nb, ydir) if role == "Y" else step_to(x, CHORDS[chord], 1)
		out.append((st, ln, m))
	return out


def build(bars, scale, chromatic, templates):
	return [bar_notes(c, t, tpl, yd, scale, chromatic, templates) for c, t, tpl, yd in bars]


def name(m):
	return NAMES[m % 12] + str(m // 12 - 1)


def render_wav(song, bpm, steps_per_bar, swing, path):
	step = 60.0 / bpm / 4
	n = int((len(song) * steps_per_bar + 8) * step * mm.SR)
	buf = np.zeros(n)
	for b, notes in enumerate(song):
		for st, ln, m in notes:
			pos = b * steps_per_bar + st + (swing * 0.67 if int(st) % 4 in (2, 3) else 0)
			k = int(ln * step * mm.SR * 0.97)
			sig = mm.triangle(440 * 2 ** ((m - 69) / 12), k)
			fin, fout = min(k, int(0.03 * mm.SR)), min(k, int(0.12 * mm.SR))
			sig[:fin] *= np.linspace(0, 1, fin)
			sig[-fout:] *= np.linspace(1, 0, fout)
			mm.add(buf, int(pos * step * mm.SR), sig, 0.22)
	pcm = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
	pcm = pcm[: int(len(song) * steps_per_bar * step * mm.SR)]  # exactly the loop length
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(mm.SR)
		w.writeframes(pcm.tobytes())
	return len(pcm) / mm.SR


def write_midi(song, bpm, steps_per_bar, swing, numer, path, title):
	TPS = 120
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("track_name", name=title, time=0))
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=numer, denominator=4, time=0))
	mid.tracks.append(meta)
	tr = mido.MidiTrack()
	tr.append(mido.MetaMessage("track_name", name="Lead (Square)", time=0))
	tr.append(mido.Message("program_change", channel=0, program=80, time=0))
	ev = []
	for b, notes in enumerate(song):
		for st, ln, m in notes:
			t0 = round((b * steps_per_bar + st + (swing * 0.67 if int(st) % 4 in (2, 3) else 0)) * TPS)
			t1 = round((b * steps_per_bar + st + ln * 0.94 + (swing * 0.67 if int(st) % 4 in (2, 3) else 0)) * TPS)
			ev.append((t0, 1, mido.Message("note_on", channel=0, note=m, velocity=62)))
			ev.append((t1, 0, mido.Message("note_off", channel=0, note=m, velocity=0)))
	ev.sort(key=lambda e: (e[0], e[1]))
	t = 0
	for tick, _, msg in ev:
		tr.append(msg.copy(time=tick - t))
		t = tick
	mid.tracks.append(tr)
	mid.save(path)


def lounge():
	bars = [  # (chord, target of the long note, template, direction of the neighbour)
		# A: the ladder climbs with the chords, then eases down
		("Cmaj7", 64, "CELL", 1), ("A7", 64, "CELL", 1), ("Dm7", 65, "CELL", 1), ("G7", 67, "CELL", 1),
		("Em7", 71, "LAZY", -1), ("A7", 69, "LAZY", -1), ("Dm7", 69, "SYNC", -1), ("G7", 67, "TURN", -1),
		# A': a step higher
		("Fmaj7", 69, "CELL", 1), ("Fm6", 68, "CELL", 1), ("Cmaj7", 72, "CELL", 1), ("A7", 73, "SYNC", -1),
		("Dm7", 74, "LAZY", -1), ("G7", 71, "SYNC", -1), ("Cmaj7", 72, "TURN", -1), ("G7", 67, "LAZY", 1),
		# B: bells (slot machine) in the high register
		("Em7", 79, "BELL", 1), ("A7", 76, "BELL", 1), ("Dm7", 77, "BELL", 1), ("G7", 74, "BELL", 1),
		("Em7", 79, "RUN", -1), ("A7", 76, "RUN", -1), ("Dm7", 74, "SYNC", -1), ("G7", 71, "TURN", -1),
		# A'': climbs again, then lands one step under the first note so the loop closes
		("Cmaj7", 67, "CELL", 1), ("A7", 69, "CELL", 1), ("Dm7", 72, "CELL", 1), ("G7", 74, "CELL", 1),
		("Cmaj7", 76, "LAZY", -1), ("Am7", 72, "LAZY", -1), ("Dm7", 69, "SYNC", -1), ("G7", 62, "HOLD", -1),
	]
	return 72, 16, 0.4, 4, build(bars, C_MAJOR, False, T44)


def waltz():
	P = lambda *rows: list(rows)
	bars = [
		("C", 72, "WALTZ", 1), ("Am", 69, "WALTZ", 1), ("Dm", 74, "WALTZ", -1), ("G7", 71, "WALTZ", 1),
		("C", 72, "WALTZ2", 1), ("Am", 69, "WALTZ2", -1), ("F", 69, "SKIP", 1), ("G7", 67, "WALTZ", 1),
		("Em", 76, "WALTZ", -1), ("Am", 72, "WALTZ", 1), ("Dm", 74, "WALTZ", 1), ("G7", 71, "WALTZ", -1),
		("C", 72, "SKIP", 1), ("A7", 73, "WALTZ", 1), ("Dm", 77, "WALTZ", -1), ("G7", 74, "WALTZ", -1),
		("C", 79, "WALTZ2", -1), ("Fmaj7", 77, "WALTZ2", -1), ("Bm7b5", 74, "WALTZ2", -1), ("E7", 76, "WALTZ2", -1),
		("Am", 72, "WALTZ2", 1), ("Dm", 74, "WALTZ2", 1), ("G7", 71, "WALTZ2", -1), ("C", 72, "WALTZ", 1),
		("F", 77, "WALTZ", -1), ("C", 76, "WALTZ", -1), ("Dm", 74, "WALTZ", -1), ("G7", 71, "WALTZ", -1),
		("Em", 72, "SKIP", 1), ("Am", 69, "WALTZ", 1), ("Dm", 69, "WALTZ", 1), ("G7", 71, "WALTZ", 1),
		("C", 72, "WALTZ", 1), ("Am", 69, "WALTZ", 1), ("F", 65, "WALTZ", 1), ("G7", 67, "WALTZ", 1),
		("C", 72, "WALTZ2", 1), ("F", 69, "WALTZ", -1), ("Dm", 62, "WALTZ", 1), ("G7", 71, "WHOLE", 1),
	]
	return 76, 12, 0.0, 3, build(bars, C_MAJOR, False, T34)


def noir():
	bars = [
		("Am7", 64, "LAZY", -1), ("Dm7", 62, "LAZY", -1), ("E7", 64, "SYNC", -1), ("Am7", 69, "TURN", -1),
		("Am7", 64, "CELL", 1), ("Dm7", 65, "CELL", 1), ("E7", 68, "SYNC", -1), ("E7", 71, "LAZY", -1),
		("F", 65, "LAZY", -1), ("Dm7", 65, "SYNC", -1), ("E7", 68, "CELL", 1), ("Am7", 69, "TURN", -1),
		("F", 72, "LAZY", -1), ("Dm7", 69, "SYNC", -1), ("E7", 71, "SYNC", -1), ("E7", 68, "HOLD", -1),
		("Dm7", 69, "BELL", 1), ("G7", 71, "BELL", 1), ("Cmaj7", 76, "BELL", -1), ("Cmaj7", 72, "LAZY", -1),
		("Bm7b5", 71, "RUN", -1), ("E7", 68, "RUN", -1), ("Am7", 69, "SYNC", -1), ("Am7", 64, "HOLD", -1),
		("Am7", 69, "CELL", 1), ("Dm7", 69, "CELL", 1), ("E7", 71, "CELL", 1), ("Am7", 72, "CELL", 1),
		("F", 72, "LAZY", -1), ("Bm7b5", 71, "SYNC", -1), ("E7", 68, "SYNC", -1), ("E7", 62, "HOLD", 1),
	]
	return 66, 16, 0.5, 4, build(bars, A_MINOR_NAT, True, T44)


if __name__ == "__main__":
	for key, fn, title in (("casino1_lounge", lounge, "Casino 1 - lounge swing"), ("casino2_waltz", waltz, "Casino 2 - music-box waltz"),
			("casino3_noir", noir, "Casino 3 - smoky shuffle")):
		bpm, spb, swing, numer, song = fn()
		secs = render_wav(song, bpm, spb, swing, os.path.join(OUT, key + ".wav"))
		write_midi(song, bpm, spb, swing, numer, os.path.join(OUT, key + ".mid"), title)
		first = song[0][0][2]
		last = [n for n in song[-1]][-1][2] if song[-1] else None
		lastnote = max(song[-1], key=lambda n: n[0])[2]
		print(f"{key}: {len(song)} bars, {bpm} BPM, {secs:.1f}s | first note {name(first)} ({SOL[NAMES[first % 12][0]]}), last note {name(lastnote)} ({SOL[NAMES[lastnote % 12][0]]}), gap {abs(lastnote - first)} semitones")
