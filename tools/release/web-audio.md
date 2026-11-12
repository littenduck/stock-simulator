# Web audio notes

- Browsers suspend the audio context until the first user gesture. Godot's web runtime resumes it on the
  first click/key press. Every sound in the game is triggered after at least one click (menu -> run setup ->
  game), so `AudioFeedback` needs no unlock code. Background music (`ui/audio/music_player.gd`) handles this itself: on the web it
  waits for the first click/key press and starts then (later scenes start at once); on desktop it starts in `_ready`.
- Effects are Kenney OGG files (about 6 MB for all four packs; unused packs can be deleted before release).
- `AudioFeedback` skips any effect whose file is missing; it never errors.
- Mapping from game events to files is the SFX constant in ui/audio/audio_feedback.gd.
