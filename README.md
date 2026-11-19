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
| `scripts/autoload/` | Always-loaded singletons: `AudioDirector` (music, fire, crickets, sound effects, volume settings), `Run` (state of the current run), `Profile` (what's kept between runs, such as Essence) and `ButtonFx` (the standard button press animation and tap sound) |
| `scripts/title/` | Night sky, campfire, glowing title, opening sequence |
| `scripts/ui/` | Main menu, Oaths menu, Essence tracker, volume sliders, shared colours and fonts (`ui_style.gd`), choice cards |
| `scripts/game/` | Gameplay: `defs.gd` (all tuning numbers), battle, board, dice, defenses, spirits, map, loadout, road events (`road_event.gd` base, Fog Cloud, Ember Shrine), dawn and end screens |
| `shaders/` | Flame, title glow and title gradient shaders |
| `assets/audio/` | Music and ambience loops; `sfx/` holds the sound effects |
| `assets/char/` | Char's expressions (SVG) |
| `assets/fonts/` | Grenze Gotisch and Alegreya Sans, with their SIL OFL licences |
| `tools/make_audio.py` | Generates all of the game's audio (needs numpy and ffmpeg) |
| `tools/gen_camp_art.py` | Builds the 2.5D camp props (stagecoach, horse) as shaded SVGs |
| `default_bus_layout.tres` | Audio buses: Music, Effects, and Fire (low-pass, feeds Effects). Buses must live here: adding one at runtime silences the web build |

## Standards

- **Buttons:** every button automatically gets the standard press animation (a quick squash, then a springy release) and the tap sound, through `scripts/autoload/button_fx.gd`. New buttons need no extra code. To opt one out, call `ButtonFx.skip(button)` before adding it to the scene.
- **Button look:** every themed button has a faint white glow; the selected (hovered, focused or pressed) one glows orange. This comes from `Style.make_theme()`, so don't override button styleboxes.
- **Save files:** `user://run.save` (the run in progress), `user://profile.save` (Essence and other keepsakes) and `user://settings.cfg` (volumes).
- **Full-screen containers** must use `mouse_filter = MOUSE_FILTER_IGNORE`, or they swallow taps meant for the game.
- **Audio:** change or add sounds in `tools/make_audio.py`, then run `python3 tools/make_audio.py` (everything) or `python3 tools/make_audio.py button` (just the named effects).

## Testing helpers

- `godot -- --autoplay --quit-at-end` plays a full run by itself, which is handy for checking balance.
- `godot res://scenes/title_screen.tscn -- --demo` plays the opening and menu on its own, for preview videos.

The early 3D mockup of Char was removed to keep the project lean. It is still in the git history if you ever want it back.
