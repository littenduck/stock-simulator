#!/usr/bin/env python3
"""Re-synthesises a transcribed track (note events from Basic Pitch) with pure NES-style voices.

Voices by register: >= C#4 (66) -> 25% pulse "lead"; 53..65 -> 50% pulse "chord"; <= 52 -> triangle bass (lowest note only);
drums: noise + sine kick on a detected pattern. Usage: python3 resynth_from_events.py events.pkl out_dir
(events.pkl = list of (start_s, end_s, midi_pitch, amplitude); the file is assumed to hold 16 bars of 4/4 that fill its length.)
"""
import importlib.util
import os
import pickle
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_music.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
SR = mm.SR
DUR, NSTEP, OFF = 29.0, 256, 2  # 29.0 s = 16 bars; the real downbeat is 2 sixteenths into the file
STEP = DUR / NSTEP


def hz(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def load(path):
	ev = pickle.load(open(path, "rb"))
	out = []
	for s, e, p, a in ev:
		i = max(0, int(round(s / STEP)))
		j = max(i + 1, int(round(e / STEP)))
		if a >= 0.25 and j - i >= 1:
			out.append((i, min(j, NSTEP), int(p), float(a)))
	return sorted(out)


def drum_steps(pat):
	"""Step lists per drum. With a detected pattern: kick/snare where the stem has a clear hit; hats on every eighth."""
	out = {"kick": set(), "snare": set(), "hat": set()}
	for b in range(16):
		base = OFF + b * 16
		for s0 in range(0, 16, 2):
			out["hat"].add(base + s0)
		if pat is None:
			for s0 in ((0, 4, 8, 12) if 8 <= b <= 13 else (0, 8) if b < 14 else (0,)):
				out["kick"].add(base + s0)
			for s0 in ((4, 12) if b < 14 else (4,)):
				out["snare"].add(base + s0)
			continue
		for s0 in range(16):
			k = b * 16 + s0
			if pat["kick"][k] > 0.5 and (s0 + 14) % 16 in (0, 4, 8, 12):
				out["kick"].add(k)
			if pat["snare"][k] > 0.5 and (s0 + 14) % 16 in (4, 12):
				out["snare"].add(k)
		# snare rolls (3+ detected hits in the bar's last half) are kept as they are
		bar_hits = [b * 16 + s0 for s0 in range(8, 16) if pat["snare"][b * 16 + s0] > 0.5]
		if len(bar_hits) >= 3:
			out["snare"].update(bar_hits)
	return out


def render(events, out_wav, drum_pat=None):
	n = int(DUR * SR)
	lead, chord, bass, drum = (np.zeros(n) for _ in range(4))
	low_note = {}  # step -> (pitch, amp): keep the lowest strong bass note per step
	counts = {"lead": 0, "chord": 0, "bass": 0}
	for i, j, p, a in events:
		pos = int(i * STEP * SR)
		length = int((j - i) * STEP * SR * 0.94)
		if p >= 66:
			mm.add(lead, pos, mm.pulse(hz(p), length, 0.25), 0.20 * (0.6 + 0.6 * min(a, 1.0)))
			counts["lead"] += 1
		elif p > 52:
			mm.add(chord, pos, mm.pulse(hz(p), length, 0.5), 0.06 * (0.6 + 0.6 * min(a, 1.0)))
			counts["chord"] += 1
		else:
			for k in range(i, j):
				if k not in low_note or p < low_note[k][0]:
					low_note[k] = (p, a)
	# triangle bass: merge consecutive steps with the same pitch into one note
	k = 0
	while k < NSTEP:
		if k in low_note:
			p = low_note[k][0]
			m = k
			while m + 1 in low_note and low_note[m + 1][0] == p:
				m += 1
			mm.add(bass, int(k * STEP * SR), mm.triangle(hz(p), int((m - k + 1) * STEP * SR * 0.94)), 0.40)
			counts["bass"] += 1
			k = m + 1
		else:
			k += 1
	# drums: from a detected pattern (dict of per-step strengths) if given, else a generic pattern; all offset by OFF sixteenths
	for kind, steps in drum_steps(drum_pat).items():
		for st in steps:
			pos = int(st * STEP * SR)
			if kind == "kick":
				mm.add(drum, pos, mm.kick(), 0.42)
			elif kind == "snare":
				mm.add(drum, pos, mm.noise(int(0.11 * SR), 0.035), 0.20)
			else:
				mm.add(drum, pos, mm.noise(int(0.03 * SR), 0.007), 0.045)
	mix = np.tanh((lead + chord + bass + drum) * 1.1) * 0.8
	pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
	with wave.open(out_wav, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	print("wrote", out_wav, counts)
	return mix


def export_midi(events, path):
	import mido
	TPS = 120
	bpm = 64 * 60 / DUR
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
	mid.tracks.append(meta)
	for name, ch, prog, sel in (("Lead (>=C#4)", 0, 80, lambda p: p >= 66), ("Chord (mid)", 1, 81, lambda p: 52 < p < 66),
			("Bass (<=E3)", 2, 38, lambda p: p <= 52)):
		tr = mido.MidiTrack()
		tr.append(mido.MetaMessage("track_name", name=name, time=0))
		tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
		evs = []
		for i, j, p, a in events:
			if sel(p):
				evs.append((i * TPS, 1, mido.Message("note_on", channel=ch, note=p, velocity=int(40 + 80 * min(a, 1.0)))))
				evs.append((j * TPS, 0, mido.Message("note_off", channel=ch, note=p, velocity=0)))
		evs.sort(key=lambda e: (e[0], e[1]))
		t = 0
		for tick, _, msg in evs:
			tr.append(msg.copy(time=tick - t))
			t = tick
		mid.tracks.append(tr)
	mid.save(path)
	print("wrote", path)


if __name__ == "__main__":
	out = sys.argv[2]
	if len(sys.argv) >= 6:  # melody-layer events, bass-stem events, drum pattern pickle, output name
		mel = [e for e in load(sys.argv[1]) if e[2] > 52]
		bas = [e for e in load(sys.argv[3]) if e[2] <= 52]
		ev = sorted(mel + bas)
		render(ev, os.path.join(out, sys.argv[5] + ".wav"), pickle.load(open(sys.argv[4], "rb")))
		export_midi(ev, os.path.join(out, sys.argv[5] + ".mid"))
	else:
		ev = load(sys.argv[1])
		render(ev, os.path.join(out, "loopready_8bit.wav"))
		export_midi(ev, os.path.join(out, "loopready_8bit.mid"))
