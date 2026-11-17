extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## Faces on a standard die. "kindle" (star) goes on the fire to power up Char.
## Every other face must be a key in DEFENSES. No defenses exist yet, so for
## now every die rolls Kindle. Add defense faces here as they are designed.
const DIE_FACES := ["kindle"]
const DICE_PER_WAVE := 3
const REROLLS_PER_WAVE := 2
const MAX_LEVEL := 3

## Name, colour and tooltip for each die face.
const FACE_INFO := {
	"kindle": {"name": "Kindle Char", "color": Color("#fff0b0"),
		"desc": "Place on the fire: Char hits harder and heals a little."},
}

# ------------------------------------------------------------ defenses
## A defense is built by dropping a die on a tile; another die with the same
## face on it levels it up (max MAX_LEVEL). One entry per face, with stats for
## levels 1..3, e.g.
##   "lantern": [{"range": 235.0, "damage": 10.0, "rate": 1.0}, {...}, {...}],
## range is in world units, rate is attacks per second. The behaviour and
## drawing for each kind live in scripts/game/defense.gd.
const DEFENSES := {}

## Char by kindle level 0..3. Kept weak on purpose: with no defenses or
## upgrades, a run should usually fail by night 4 or 5.
const CHAR_STATS := [
	{"range": 175.0, "damage": 6.0, "rate": 1.1},
	{"range": 190.0, "damage": 8.0, "rate": 1.25},
	{"range": 200.0, "damage": 10.0, "rate": 1.4},
	{"range": 215.0, "damage": 12.0, "rate": 1.55},
]
const KINDLE_HEAL := 8.0

# ------------------------------------------------------------ spirits
## The base spirit. Most normal spirits will be built off the Wisp's numbers.
const SPIRITS := {
	"wisp": {"hp": 16.0, "speed": 48.0, "damage": 6.0, "size": 1.0, "color": Color("#d6ecff")},
}

const NIGHTS := 5
const WAVES_PER_NIGHT := 3
const MAX_FLAME := 100.0
const DAWN_HEAL := 20.0

# ------------------------------------------------------------ map stops
const STOPS := {
	"road": {"name": "Old Road", "desc": "A plain night on the road."},
}


## Spawn list for one wave: Array of spirit kinds. night/wave are 0-based.
static func wave_spirits(night: int, wave: int, stop: String, _rng: RandomNumberGenerator) -> Array:
	var count := 3 + night * 2 + wave * 2
	var out := []
	for i in count:
		out.append("wisp")
	return out


## Seconds between spawns (before the battle's ±20% jitter). It shrinks each
## night AND each wave, so wave 1 is gentle and wave 3 tends to overrun Char.
## Night 1: 1.15 / 0.95 / 0.75.
const SPAWN_GAP := 1.15
const SPAWN_GAP_PER_NIGHT := 0.12
const SPAWN_GAP_PER_WAVE := 0.2
const SPAWN_GAP_MIN := 0.55

static func spawn_gap(night: int, wave: int) -> float:
	return maxf(SPAWN_GAP_MIN, SPAWN_GAP - SPAWN_GAP_PER_NIGHT * night - SPAWN_GAP_PER_WAVE * wave)


static func spirit_hp_scale(night: int, stop: String) -> float:
	var s := 1.0 + 0.25 * night
	return s
