#!/usr/bin/env python3
"""Generates the game's sound effects procedurally (sine/triangle tones with envelopes).

The output is original work of this project and released under CC0 (see CREDITS.md).
Usage: python3 tools/make_sfx.py   (writes audio/*.wav, deterministic)
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def tone(freq, dur, vol=0.5, shape="sine", decay=6.0):
	n = int(RATE * dur)
	out = []
	for i in range(n):
		t = i / RATE
		ph = 2 * math.pi * freq * t
		s = math.sin(ph) if shape == "sine" else (2 / math.pi) * math.asin(math.sin(ph))
		attack = min(1.0, t / 0.005)
		out.append(s * vol * attack * math.exp(-decay * t / dur))
	return out


def seq(notes):
	"""notes: list of (freq, dur, vol, shape, decay); samples are concatenated."""
	out = []
	for f, d, v, sh, dc in notes:
		out += tone(f, d, v, sh, dc)
	return out


def write(name, samples):
	path = os.path.join(OUT, name)
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))


os.makedirs(OUT, exist_ok=True)
write("buy.wav", seq([(660, 0.07, 0.5, "sine", 4), (880, 0.12, 0.5, "sine", 5)]))
write("sell.wav", seq([(880, 0.07, 0.5, "sine", 4), (587, 0.12, 0.5, "sine", 5)]))
write("next_day.wav", tone(440, 0.10, 0.35, "triangle", 7))
write("perk.wav", seq([(523, 0.09, 0.45, "sine", 4), (659, 0.09, 0.45, "sine", 4), (784, 0.09, 0.45, "sine", 4), (1047, 0.25, 0.45, "sine", 5)]))
write("margin_call.wav", seq([(220, 0.18, 0.55, "triangle", 3), (165, 0.30, 0.55, "triangle", 3)]))
write("error.wav", tone(180, 0.15, 0.45, "triangle", 5))
write("win.wav", seq([(523, 0.12, 0.45, "sine", 3), (659, 0.12, 0.45, "sine", 3), (784, 0.12, 0.45, "sine", 3), (1047, 0.4, 0.45, "sine", 4)]))
write("lose.wav", seq([(392, 0.18, 0.45, "triangle", 3), (330, 0.18, 0.45, "triangle", 3), (262, 0.4, 0.45, "triangle", 4)]))
