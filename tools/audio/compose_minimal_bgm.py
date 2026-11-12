#!/usr/bin/env python3
"""A deliberately minimal gameplay background: ONE soft lead (at most 2 notes per bar) + ONE soft bass note per bar. F major, 80 BPM, 40 bars = 2:00.

Chords (one per bar, 4-bar loop): F C Dm Bb, repeated 10 times with the melody drifting up and back down. The last note (G4) sits one step
below the first (A4), so the loop closes. Also renders a 2-bar "easter egg" (the theme's long-short ladder) in this key and tempo.
Usage: python3 tools/audio/compose_minimal_bgm.py [out_dir]   (needs numpy, mido)
"""
import importlib.util
import os
import sys
import wave

import mido
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("cd", os.path.join(HERE, "compose_casino_demos.py"))
cd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cd)
mm = cd.mm
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
F_MAJOR = {5, 7, 9, 10, 0, 2, 4}
cd.CHORDS.update({"Bb": {10, 2, 5}, "Bb6": {10, 2, 5, 7}})
BPM, SPB = 80, 16
STEP = 60.0 / BPM / 4
BASS = {"F": 41, "C": 48, "Dm": 50, "Bb": 46, "Bb6": 46}
LOOP = ["F", "C", "Dm", "Bb"]
TPL = ["LAZY", "HOLD", "LAZY", "TURN"]
DIR = [1, 1, -1, -1]
BASE = [69, 67, 65, 65]
DRIFT = [0, 0, 3, 3, 5, 5, 2, 2, 0, 0]  # the melody climbs a little, then comes back


def build():
	bars, chords = [], []
	for k, drift in enumerate(DRIFT):
		for i in range(4):
			chord = LOOP[i]
			tpl = TPL[i]
			if k == len(DRIFT) - 1 and i == 3:
				chord, tpl = "Bb6", "HOLD"  # the final note G4 (so the loop returns to A4)
				bars.append((chord, 67, tpl, -1))
			else:
				bars.append((chord, BASE[i] + drift, tpl, DIR[i]))
			chords.append(chord)
	return cd.build(bars, F_MAJOR, False, cd.T44), chords


def fade(sig, a=0.04, r=0.18):
	k = len(sig)
	fa, fr = min(k, int(a * mm.SR)), min(k, int(r * mm.SR))
	sig[:fa] *= np.linspace(0, 1, fa)
	sig[-fr:] *= np.linspace(1, 0, fr)
	return sig


def render(song, chords, path, lead_gain=0.12, bass_gain=0.15):
	n = int((len(song) * SPB + 4) * STEP * mm.SR)
	buf = np.zeros(n)
	for b, notes in enumerate(song):
		for st, ln, m in notes:
			k = int(ln * STEP * mm.SR * 0.97)
			mm.add(buf, int((b * SPB + st) * STEP * mm.SR), fade(mm.pulse(440 * 2 ** ((m - 69) / 12), k, 0.5)), lead_gain)
		bm = BASS[chords[b]]
		k = int(14 * STEP * mm.SR)
		mm.add(buf, int(b * SPB * STEP * mm.SR), fade(mm.triangle(440 * 2 ** ((bm - 69) / 12), k), 0.05, 0.25), bass_gain)
	pcm = (np.clip(buf[: int(len(song) * SPB * STEP * mm.SR)], -1, 1) * 32767).astype(np.int16)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(mm.SR)
		w.writeframes(pcm.tobytes())
	return len(pcm) / mm.SR


def write_midi(song, chords, path):
	TPS = 120
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
	mid.tracks.append(meta)
	for name, ch, prog, events in (
			("Lead (soft square)", 0, 80, [(b * SPB + st, ln, m) for b, ns in enumerate(song) for st, ln, m in ns]),
			("Bass (triangle)", 1, 38, [(b * SPB, 14, BASS[chords[b]]) for b in range(len(song))])):
		tr = mido.MidiTrack()
		tr.append(mido.MetaMessage("track_name", name=name, time=0))
		tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
		ev = []
		for s0, ln, m in events:
			ev.append((s0 * TPS, 1, mido.Message("note_on", channel=ch, note=m, velocity=55)))
			ev.append((round((s0 + ln * 0.97) * TPS), 0, mido.Message("note_off", channel=ch, note=m, velocity=0)))
		ev.sort(key=lambda e: (e[0], e[1]))
		t = 0
		for tick, _, msg in ev:
			tr.append(msg.copy(time=tick - t))
			t = tick
		mid.tracks.append(tr)
	mid.save(path)


if __name__ == "__main__":
	song, chords = build()
	secs = render(song, chords, os.path.join(OUT, "minimal_bgm.wav"))
	write_midi(song, chords, os.path.join(OUT, "minimal_bgm.mid"))
	notes_per_bar = sum(len(b) for b in song) / len(song)
	first, last = song[0][0][2], max(song[-1], key=lambda n: n[0])[2]
	print(f"minimal_bgm: {len(song)} bars, {BPM} BPM, {secs:.1f}s, {notes_per_bar:.1f} lead notes per bar, first {cd.name(first)}, last {cd.name(last)}")
	# the 2-bar easter egg in this key and tempo: the theme's long-short ladder, mi-fa then so-fa (do = F)
	egg = [[(0, 4, 69), (4, 2, 70), (6, 4, 69), (10, 2, 70), (12, 2, 69), (14, 2, 70)],
		[(0, 4, 72), (4, 2, 70), (6, 4, 72), (10, 2, 70), (12, 2, 72), (14, 2, 70)]]
	render(egg, ["F", "C"], os.path.join(OUT, "easter_egg_80bpm.wav"))
