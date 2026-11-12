#!/usr/bin/env python3
"""Synthesises the game's 8-bit music (original compositions, no samples) into audio/music/*.wav.

Channels like an NES: two pulse waves (lead 25% duty, harmony 50% duty), a 4-bit triangle bass and noise drums.
Usage: python3 tools/audio/make_music.py      (needs numpy)
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "music")
NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name: str) -> float:
	"""'C#5' -> Hz."""
	n = NOTE_INDEX[name[0]]
	i = 1
	if name[i] == "#":
		n += 1
		i += 1
	elif name[i] == "b":
		n -= 1
		i += 1
	octave = int(name[i:])
	midi = 12 * (octave + 1) + n
	return 440.0 * 2 ** ((midi - 69) / 12)


def parse_bar(bar: str):
	"""16 tokens (one per 16th). 'X5' starts a note, '-' sustains it, '.' is a rest.
	Returns [(start_step, length_steps, note)]."""
	toks = bar.split()
	assert len(toks) <= 16, f"bar has more than 16 tokens ({len(toks)}): {bar}"
	toks += ["-"] * (16 - len(toks))  # a short bar sustains its last note
	out = []
	for i, t in enumerate(toks):
		if t == ".":
			continue
		if t == "-":
			if out and out[-1][0] + out[-1][1] == i:
				s, l, n = out[-1]
				out[-1] = (s, l + 1, n)
			continue
		out.append((i, 1, t))
	return out


def phase_of(f: float, n: int) -> np.ndarray:
	return (np.arange(n) * f / SR) % 1.0


def envelope(n: int, a=0.002, d=0.08, sus=0.7, r=0.012) -> np.ndarray:
	t = np.arange(n) / SR
	env = np.where(t < a, t / a, sus + (1 - sus) * np.exp(-(t - a) / d))
	rel = int(r * SR)
	if n > rel:
		env[-rel:] *= np.linspace(1, 0, rel)
	return env


def pulse(f, n, duty):
	return np.where(phase_of(f, n) < duty, 1.0, -1.0) * envelope(n)


def triangle(f, n):
	p = phase_of(f, n)
	w = 4 * np.abs(p - 0.5) - 1
	w = np.round(w * 7.5) / 7.5  # 4-bit stair-steps, like the NES triangle channel
	return w * envelope(n, d=0.2, sus=0.85, r=0.01)


def noise(n, decay):
	rng = np.random.default_rng(7)
	t = np.arange(n) / SR
	return rng.uniform(-1, 1, n) * np.exp(-t / decay)


def kick(n=int(0.14 * SR)):
	t = np.arange(n) / SR
	f = 50 + 110 * np.exp(-t / 0.03)
	return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.06)


def add(buf, start, sig, gain):
	end = min(len(buf), start + len(sig))
	if end > start:
		buf[start:end] += sig[: end - start] * gain


class Song:
	def __init__(self, bpm, bars, swing=0.0):
		self.swing = swing  # 0 = straight, 1 = full triplet swing on the off-8ths
		self.step = 60.0 / bpm / 4  # seconds per 16th
		self.bars = bars
		self.n = int(round(self.step * 16 * bars * SR))
		self.lead = np.zeros(self.n)
		self.harm = np.zeros(self.n)
		self.bass = np.zeros(self.n)
		self.drum = np.zeros(self.n)

	def at(self, bar, step):
		if self.swing and int(step) % 4 in (2, 3):
			step += self.swing * 0.67  # push the second 8th of each beat late
		return int(round((bar * 16 + step) * self.step * SR))

	def add_lead(self, bar, notes, duty=0.25, gain=0.30, octave_shift=0):
		for s, l, name in notes:
			n = int(l * self.step * SR * 0.94)  # slight gap between notes
			f = freq(name) * 2 ** octave_shift
			add(self.lead, self.at(bar, s), pulse(f, n, duty), gain)

	def add_arp(self, bar, chord, pattern=(0, 1, 2, 1), every=2, gain=0.13):
		for s in range(0, 16, every):
			f = freq(chord[pattern[(s // every) % len(pattern)]])
			n = int(every * self.step * SR * 0.8)
			add(self.harm, self.at(bar, s), pulse(f, n, 0.5), gain)

	def add_bass(self, bar, root, fifth=None, style="oct", gain=0.38):
		for k in range(8):
			s = k * 2
			name = root
			if style == "oct" and k % 2 == 1:
				name = root[:-1] + str(int(root[-1]) + 1)
			if style == "walk" and k in (3, 7) and fifth:
				name = fifth
			n = int(2 * self.step * SR * 0.9)
			add(self.bass, self.at(bar, s), triangle(freq(name), n), gain)

	def add_bass_pattern(self, bar, root, pattern, length=2, gain=0.38, fifth=None):
		"""pattern: 16 tokens. '.' rest, '1' root, '5' fifth, '8' octave, or an explicit note name (walking bass)."""
		toks = pattern.split()
		assert len(toks) == 16, pattern
		for i, t in enumerate(toks):
			if t == ".":
				continue
			f = {"1": freq(root), "8": freq(root) * 2, "5": freq(fifth) if fifth else freq(root) * 1.4983}.get(t) or freq(t)
			add(self.bass, self.at(bar, i), triangle(f, int(length * self.step * SR * 0.9)), gain)

	def add_stab(self, bar, chord, steps, length=2, duty=0.5, gain=0.10):
		"""Short chord hits (comping) on the given steps."""
		for st in steps:
			n = int(length * self.step * SR * 0.8)
			for name in chord:
				add(self.harm, self.at(bar, st), pulse(freq(name), n, duty), gain)

	def add_drums(self, bar, kicks, snares, hat_every=2, hat_gain=0.06):
		for s in kicks:
			add(self.drum, self.at(bar, s), kick(), 0.45)
		for s in snares:
			add(self.drum, self.at(bar, s), noise(int(0.12 * SR), 0.04), 0.22)
		for s in range(0, 16, hat_every):
			add(self.drum, self.at(bar, s), noise(int(0.03 * SR), 0.008), hat_gain)

	def mix(self):
		m = self.lead + self.harm + self.bass + self.drum
		m = np.tanh(m * 1.1)
		return m * 0.8


def write_wav(signal, name):
	os.makedirs(OUT, exist_ok=True)
	pcm = (np.clip(signal, -1, 1) * 32767).astype(np.int16)
	dst = os.path.join(OUT, name + ".wav")
	with wave.open(dst, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	print("wrote", os.path.normpath(dst), f"{len(signal) / SR:.1f}s")


CHORDS = {
	"C": ("C2", "G2", ["C4", "E4", "G4"]),
	"Am": ("A1", "E2", ["A3", "C4", "E4"]),
	"F": ("F2", "C3", ["F3", "A3", "C4"]),
	"G": ("G1", "D2", ["G3", "B3", "D4"]),
	"E": ("E2", "B2", ["E3", "G#3", "B3"]),
}


def menu():
	"""Cheerful, C major, 112 BPM, 8 bars. Relaxed 'market opens' feel."""
	s = Song(112, 8)
	prog = ["C", "Am", "F", "G", "C", "Am", "F", "G"]
	mel = [
		"E5 - G5 - E5 - C5 - D5 - E5 - G5 -",
		"A5 - - - G5 - E5 - C5 - D5 - E5 - . .",
		"F5 - A5 - F5 - C5 - D5 - F5 - A5 -",
		"G5 - - - F5 - D5 - B4 - - - . . . .",
		"C6 - B5 - G5 - E5 - G5 - C6 - - - . .",
		"A5 - G5 - E5 - C5 - E5 - A5 - - - . .",
		"A5 - C6 - A5 - F5 - G5 - A5 - C6 -",
		"D6 - - - B5 - G5 - D5 - G5 - - - - -",
	]
	for b, (c, m) in enumerate(zip(prog, mel)):
		root, fifth, chord = CHORDS[c]
		s.add_lead(b, parse_bar(m))
		s.add_arp(b, chord)
		s.add_bass(b, root, fifth, style="oct")
		s.add_drums(b, kicks=(0, 8), snares=(4, 12), hat_every=4, hat_gain=0.05)
	return s.mix()


def gameplay():
	"""Driving, A minor, 132 BPM, 8 bars. Busy trading-floor energy; ends on E (dominant) so the loop pulls forward."""
	s = Song(132, 8)
	prog = ["Am", "F", "C", "G", "Am", "F", "G", "E"]
	mel = [
		"A4 - C5 - E5 - A5 - G5 - E5 - C5 - E5 -",
		"F4 - A4 - C5 - F5 - E5 - C5 - A4 - C5 -",
		"C5 - E5 - G5 - C6 - B5 - G5 - E5 - G5 -",
		"D5 - G5 - B5 - D6 - C6 - B5 - G5 - B5 -",
		"A5 - - - E5 - A5 - C6 - - - B5 - A5 -",
		"A5 - - - F5 - A5 - C6 - - - A5 - F5 -",
		"B5 - - - G5 - B5 - D6 - - - C6 - B5 -",
		"E5 - G#5 - B5 - E6 - D6 - B5 - G#5 - E5 -",
	]
	for b, (c, m) in enumerate(zip(prog, mel)):
		root, fifth, chord = CHORDS[c]
		s.add_lead(b, parse_bar(m), gain=0.28)
		s.add_arp(b, chord, pattern=(0, 2, 1, 2), every=1, gain=0.07)
		s.add_bass(b, root, fifth, style="walk")
		s.add_drums(b, kicks=(0, 4, 8, 12), snares=(4, 12), hat_every=2, hat_gain=0.06)
	return s.mix()


def hurry_jingle():
	"""Short 'time is running out' fanfare (Mario's low-time warning idea, original notes)."""
	s = Song(168, 2)
	notes = "E5 - G5 - E5 - C6 - B5 - A5 - G5 - E5 - . . | C5 - E5 - G5 - E5 - C6 - - - - - . . . ."
	bar0 = "E5 G5 E5 C6 B5 A5 G5 E5 A5 C6 A5 E6 D6 C6 B5 A5".split()
	bar1 = "G#5 - B5 - E6 - - - - - . . . . . .".split()
	s.add_lead(0, [(i, 1, n) for i, n in enumerate(bar0)], duty=0.5, gain=0.4)
	s.add_lead(1, parse_bar(" ".join(bar1)), duty=0.5, gain=0.4)
	s.add_bass(0, "A1", style="oct", gain=0.4)
	return s.mix()


if __name__ == "__main__":
	write_wav(menu(), "menu")
	write_wav(gameplay(), "gameplay")
	write_wav(hurry_jingle(), "hurry_jingle")
