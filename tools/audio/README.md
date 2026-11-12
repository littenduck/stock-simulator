# How the music was made

Notes on the two tracks in `audio/music/` and the scripts around them. Run every script with an output folder
(`python3 tools/audio/<script>.py some/dir`); a few of them write into `audio/music/` or next to themselves when you don't.

## What is in `audio/music/`

| File | What it is |
|---|---|
| `startmenu.ogg` | Start-screen theme (Suno), 29 s, loops by itself |
| `gameplay.ogg` | In-game loop (Suno), 113.04 s, cut at a bar line so it loops |
| `startmenu.mid`, `gameplay.mid` | The same two pieces as plain NES-style MIDI (pulse + triangle). Godot does not import them |

## The start-menu theme

1. A melody was hummed and transcribed with Basic Pitch: `source/hum_basic_pitch.mid` (22 s).
2. The weekly closes of TQQQ, SOXL and DRAM were turned into melodies (`sonify_ticker.py`, `sonify_musical.py`, `sonify_adventure.py`):
   the price decides whether the line goes up or down, the notes are snapped to a fixed chord progression.
3. The opening of the SOXL one (E, F and G swinging up and down in a long-short rhythm) was kept and tidied into a ladder:
   `mi fa` x3 | `so fa` x3 | `la si` x3 | `do re` x3, one chord per bar (C G Am F). `compose_soxl_story.py` builds the 24-bar story from it;
   `source/soxl_story.mid` is the copy that was opened in GarageBand.
   `notes/soxl_to_startmenu.png` puts the three versions side by side (SOXL melody, the ladder, the notes read back from the Suno track).
4. The first four bars were rendered as a small 8-bit clip (`render_game_8bit.py`, `start_8bit.wav`), given to Suno as the reference with
   `prompts/startmenu.txt`, and the result (`Loop Ready.m4a`) was converted: `ffmpeg -i in.m4a -ar 44100 -ac 2 out.wav`, then `oggenc -q 5`.

## The gameplay loop

1. The first four bars of the start-menu track were cut out (one bar is 4 beats at ~132.4 BPM, the music starts 0.2265 s into the file):
   `ffmpeg -ss 0.2265 -t 7.25 -i startmenu.wav -af "afade=t=in:d=0.005,afade=t=out:st=7.23:d=0.02" clip.wav`,
   then slowed to 108 BPM without changing the pitch: `ffmpeg -i clip.wav -af atempo=0.8157 clip_108.wav`.
2. `prompts/gameplay.txt` + that clip went to Suno; the result was `Trading Duel.m4a`.
3. The track fades out at the end, so it is cut at the end of bar 51 (a bar is 2.2165 s, ~108.3 BPM; the cut is at 113.04 s, on a G chord):
   `ffmpeg -i in.wav -af atrim=end_sample=4985064 gp_trim.wav`.
4. Suno's first note is weak, so `pipeline/fixloop.py` lifts it and puts an 8 ms fade on the last sample (this also stops the loop from clicking).
5. `oggenc -q 5 -o gameplay.ogg gp_fixed.wav`.

## The MIDI files

`render_game_8bit.py out_dir` regenerates `startmenu.mid` and `gameplay.mid` (it writes `start_8bit.mid` / `gameplay_8bit.mid` into `out_dir/midi`) and the
matching WAVs. The WAVs come out bit-identical every time. The gameplay one is the "duel" idea: two square voices answering each other over a
triangle bass, no drums, 108 BPM, F major.

## Reading a melody back out of a finished track

The melody read back out of `startmenu.ogg` is in `notes/startmenu_extracted_melody.json`. How: stems with `audio-separator` (MDX-Net `kuielab_a_drums`, then `kuielab_a_bass`),
notes with Basic Pitch (ONNX), then the loudest note at each of the six long/short positions of a bar. Bars 1-5 are reliable; from bar 6 on, arpeggio and chord notes get in the way.

## Other scripts

`compose_*.py`, `make_light_variants.py`, `soxl_bar6_variants.py` are the sketches that came before (loops, casino/minimal ideas, bar-6 variants);
`resynth_from_events.py` turns a Basic Pitch transcription back into NES voices. `make_music.py` is the small synth they all use.

## Licence

The two Suno tracks follow the terms of the Suno plan they were made with; check them before a commercial release (see `CREDITS.md`).
