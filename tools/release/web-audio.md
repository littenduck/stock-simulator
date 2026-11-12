# Web audio notes

- Browsers suspend the audio context until the first user gesture. Godot's web runtime resumes it on the
  first click/key press. Every sound in the game is triggered after at least one click (menu -> run setup ->
  game), so `AudioFeedback` needs no unlock code. Background music is played by one shared `MusicHost` (`ui/audio/music_host.gd`), which lives under the root window so the music
  keeps going across screens: the menu screens (main menu, run setup, high scores, settings) ask for the start-menu theme through a
  `MusicPlayer` node, the game screen asks for the gameplay track, and asking for the track that is already playing changes nothing.
  Browsers do not let a page make sound before the first click/key press (the audio context starts "suspended"), so on the web the host
  starts the music at the first press and then never stops it when the screen changes; on desktop it starts at once.
- Effects are Kenney OGG files (about 6 MB for all four packs; unused packs can be deleted before release).
- `AudioFeedback` skips any effect whose file is missing; it never errors.
- Mapping from game events to files is the SFX constant in ui/audio/audio_feedback.gd.
