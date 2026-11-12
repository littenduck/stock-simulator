# Credits

## Code
Stock Simulator is released under the MIT licence (see `LICENSE`). The licence holder line is a
proposal: the lead confirms the name/year before the first public release.

Built with [Godot Engine](https://godotengine.org) 4.7 (MIT licence, (c) Godot Engine contributors).

## Audio (`audio/`)
Four sound packs by Kenney (https://kenney.nl), downloaded from kenney.nl, licence CC0 1.0
(https://creativecommons.org/publicdomain/zero/1.0/). Each is kept in its own folder under its original name,
with its original `License.txt`. Credit is not required but appreciated: "Sound effects by Kenney (kenney.nl)".

| Folder | Pack | Used by the game |
|---|---|---|
| `audio/kenney_interface-sounds/` | Interface Sounds 1.0 | yes, all effects (`ui/audio/audio_feedback.gd`) |
| `audio/kenney_ui-audio/` | UI Audio | not yet |
| `audio/kenney_digital-audio/` | Digital Audio | not yet |
| `audio/kenney_impact-sounds/` | Impact Sounds 1.0 | not yet |

## Art / fonts
`icon.svg` belongs to the project. No third-party art or fonts yet.

## Music (`audio/music/`)
| File | What it is |
|---|---|
| `startmenu.ogg` | Start-screen theme, generated with Suno (a chiptune track from the project owner's own prompts) |
| `gameplay.ogg` | In-game background loop, generated with Suno from the owner's 4-bar theme; cut at a bar line so it loops seamlessly |
| `startmenu.mid`, `gameplay.mid` | Raw NES-style (pulse + triangle) versions of the two pieces as MIDI. Not used by the game (Godot does not import them); made with `tools/audio/render_game_8bit.py`, no samples |

The Suno tracks are subject to the terms of the Suno plan they were generated under: check them before a commercial release.
The Suno masters are not in the repository (about 25 MB as WAV); only the compressed .ogg files are.
