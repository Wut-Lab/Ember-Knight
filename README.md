# Ember-Knight
A tower defense/rogue-like.  You play as Char, the spirit of a campfire who defends his family without question.

## Running it

Open the folder in **Godot 4.3** (or newer 4.x) and press Play. The game targets both **PC and mobile** (touch, mouse, keyboard and gamepad).

## Layout

| Path | What's there |
|---|---|
| `scenes/title_screen.tscn` | Opening sequence + main menu (the main scene) |
| `scripts/title/` | Night sky, campfire, glowing title, sequence timing |
| `scripts/ui/` | Main menu and shared UI style |
| `scripts/autoload/audio_director.gd` | Music, crickets, fire, and the menu's fire swells |
| `shaders/` | Flame, title glow and title gradient shaders |
| `assets/audio/` | Generated loops (see `tools/make_audio.py`) |
| `assets/fonts/` | Grenze Gotisch, Alegreya Sans (SIL OFL) |
| `prototypes/3d_mockup/` | The early 3D Char mockup, kept for reference |

Regenerate the audio with `python3 tools/make_audio.py` (needs numpy and ffmpeg).
