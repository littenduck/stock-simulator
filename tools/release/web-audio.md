# Web audio notes

- Browsers suspend the audio context until the first user gesture. Godot's web runtime resumes it on the
  first click/key press. Every sound in the game is triggered after at least one click (menu -> run setup ->
  game), so `AudioFeedback` needs no unlock code. Do not add background music that autoplays from the main menu
  scene's `_ready` without a click first.
- Effects are 22.05 kHz mono WAV (about 140 KB in total) so the Web build stays small.
- `AudioFeedback` skips any effect whose file is missing; it never errors.
- Regenerate the effects with `python3 tools/make_sfx.py` (deterministic).
