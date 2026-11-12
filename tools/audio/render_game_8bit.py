#!/usr/bin/env python3
"""Regenerates the two raw NES-style (pulse + triangle) pieces and their MIDI sources.

  start_8bit      the start-screen theme's first four bars (the user's long-short ladder), 132 BPM, C major, full 8-bit backing
  gameplay_8bit   the 'duel' sketch: two square voices answering each other + a triangle bass, no drums, 108 BPM, F major

Writes <out_dir>/start_8bit.wav, gameplay_8bit.wav and <out_dir>/midi/*.mid (copy those to audio/music/startmenu.mid and gameplay.mid). The WAVs are bit-identical on every run (no randomness
besides fixed seeds), so only the scripts and the MIDI files need to live in the repository.
Usage: python3 tools/audio/render_game_8bit.py out_dir      (needs numpy, mido)
"""
import importlib.util
import os
import sys

import mido

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "build")
os.makedirs(os.path.join(OUT, "midi"), exist_ok=True)


def load(name):
	spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + ".py"))
	mod = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(mod)
	return mod


def write_midi(path, bpm, tracks):
	"""tracks: {name: (channel, program, [(start_step, length_steps, midi)])}; one step = a sixteenth."""
	TPS = 120
	mid = mido.MidiFile(type=1, ticks_per_beat=4 * TPS)
	meta = mido.MidiTrack()
	meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(bpm), time=0))
	meta.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
	mid.tracks.append(meta)
	for name, (ch, prog, notes) in tracks.items():
		tr = mido.MidiTrack()
		tr.append(mido.MetaMessage("track_name", name=name, time=0))
		tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
		ev = []
		for st, ln, m in notes:
			ev.append((st * TPS, 1, mido.Message("note_on", channel=ch, note=m, velocity=90)))
			ev.append((round((st + ln * 0.94) * TPS), 0, mido.Message("note_off", channel=ch, note=m, velocity=0)))
		ev.sort(key=lambda e: (e[0], e[1]))
		t = 0
		for tick, _, msg in ev:
			tr.append(msg.copy(time=tick - t))
			t = tick
		mid.tracks.append(tr)
	mid.save(path)


# ---- start_8bit: the first four bars with the full backing -------------------------------------------------------
loops = load("compose_loops")
plans = [loops.plan(bass=1, arp=1, drums=3) for _ in loops.HEAD]
loops.prog.render(loops.HEAD, plans, "start_8bit")
loops.export_midi(loops.HEAD, plans, os.path.join(OUT, "midi", "start_8bit.mid"))

# ---- gameplay_8bit: the duel sketch without drums ---------------------------------------------------------------
ms = load("compose_match_sketches")
cs = loops.cs
rec = []


class RecSong(ms.mm.Song):
	"""A Song that also remembers its notes so they can be written to MIDI."""

	def add_lead(self, bar, notes, duty=0.25, gain=0.30, octave_shift=0):
		track = "Voice B (round, answers)" if duty == 0.5 else "Voice A (bright, asks)"
		for st, ln, name in notes:
			rec.append((track, bar * 16 + st, ln, cs.to_midi(name) + 12 * octave_shift))
		super().add_lead(bar, notes, duty=duty, gain=gain, octave_shift=octave_shift)

	def add_bass_pattern(self, bar, root, pattern, length=2, gain=0.38, fifth=None):
		for i, tok in enumerate(pattern.split()):
			if tok != ".":
				rec.append(("Bass", bar * 16 + i, length, cs.to_midi(root) + {"1": 0, "8": 12, "5": 7}[tok]))
		super().add_bass_pattern(bar, root, pattern, length=length, gain=gain, fifth=fifth)


ms.mm.Song = RecSong
ms.tick_drums = lambda *a, **k: None  # no percussion at all
orig_finish = ms.finish
ms.finish = lambda s, name: orig_finish(s, "gameplay_8bit")
ms.duel()
tracks = {}
progs = {"Voice A (bright, asks)": (0, 80), "Voice B (round, answers)": (1, 80), "Bass": (2, 38)}
for name, (ch, prog) in progs.items():
	tracks[name] = (ch, prog, [(st, ln, m) for tr, st, ln, m in rec if tr == name])
write_midi(os.path.join(OUT, "midi", "gameplay_8bit.mid"), 108, tracks)
print("wrote start_8bit / gameplay_8bit (.wav and midi/*.mid) in", OUT)
