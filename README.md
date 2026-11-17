# Ember Knight

A tower defense / roguelike. You play as Char, the spirit of a campfire who defends his family without question.

**Play it in your browser:** https://wut-lab.github.io/Ember-Knight/

## Running it

Open the folder in **Godot 4.3** (or a newer 4.x) and press Play. The game targets both **PC and mobile**, with touch, mouse, keyboard and gamepad controls.

Every push to `main` rebuilds the web version and publishes it to GitHub Pages (`.github/workflows/pages.yml`).

## Project layout

| Path | What's there |
|---|---|
| `scenes/` | `title_screen.tscn` (the main scene: opening + main menu) and `run.tscn` (one game, from map to end screen) |
| `scripts/autoload/` | Always-loaded singletons: `AudioDirector` (music, fire, crickets, sound effects), `Run` (state of the current run) and `ButtonFx` (the standard button press animation and tap sound) |
| `scripts/title/` | Night sky, campfire, glowing title, opening sequence |
| `scripts/ui/` | Main menu, shared colours and fonts (`ui_style.gd`), choice cards |
| `scripts/game/` | Gameplay: `defs.gd` (all tuning numbers), battle, board, dice, defenses, spirits, map, dawn and end screens |
| `shaders/` | Flame, title glow and title gradient shaders |
| `assets/audio/` | Music and ambience loops; `sfx/` holds the sound effects |
| `assets/char/` | Char's expressions (SVG) |
| `assets/fonts/` | Grenze Gotisch and Alegreya Sans, with their SIL OFL licences |
| `tools/make_audio.py` | Generates all of the game's audio (needs numpy and ffmpeg) |

## Standards

- **Buttons:** every button automatically gets the standard press animation (a quick squash, then a springy release) and the tap sound, through `scripts/autoload/button_fx.gd`. New buttons need no extra code. To opt one out, call `ButtonFx.skip(button)` before adding it to the scene.
- **Full-screen containers** must use `mouse_filter = MOUSE_FILTER_IGNORE`, or they swallow taps meant for the game.
- **Audio:** change or add sounds in `tools/make_audio.py`, then run `python3 tools/make_audio.py` (everything) or `python3 tools/make_audio.py button` (just the named effects).

## Testing helpers

- `godot -- --autoplay --quit-at-end` plays a full run by itself, which is handy for checking balance.
- `godot res://scenes/title_screen.tscn -- --demo` plays the opening and menu on its own, for preview videos.

The early 3D mockup of Char was removed to keep the project lean. It is still in the git history if you ever want it back.
