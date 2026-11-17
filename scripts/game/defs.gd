extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits, passives,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## A standard die. "kindle" (★) goes on the fire to power up Char.
const DIE_FACES := ["bolt", "bolt", "flare", "flare", "ward", "kindle"]
const DICE_PER_WAVE := 3
const REROLLS_PER_WAVE := 2
const MAX_LEVEL := 3

const FACE_INFO := {
	"bolt": {"name": "Ember Lantern", "color": Color("#ffb238"),
		"desc": "Shoots ember bolts at one spirit."},
	"flare": {"name": "Brazier", "color": Color("#ff6a2a"),
		"desc": "Bursts flame at every spirit close by."},
	"ward": {"name": "Rune Stone", "color": Color("#7fd3ff"),
		"desc": "Slows spirits that drift near it."},
	"kindle": {"name": "Kindle Char", "color": Color("#fff0b0"),
		"desc": "Place on the fire: Char hits harder and heals a little."},
}

# ------------------------------------------------------------ defenses
## Per level 1..3. range in world units, rate = attacks per second.
const DEFENSES := {
	"bolt": [
		{"range": 235.0, "damage": 10.0, "rate": 1.0},
		{"range": 250.0, "damage": 14.0, "rate": 1.25},
		{"range": 275.0, "damage": 22.0, "rate": 1.5},
	],
	"flare": [
		{"range": 125.0, "damage": 11.0, "rate": 0.62},
		{"range": 140.0, "damage": 17.0, "rate": 0.72},
		{"range": 155.0, "damage": 26.0, "rate": 0.85},
	],
	"ward": [
		{"range": 165.0, "slow": 0.35, "damage": 0.0},
		{"range": 185.0, "slow": 0.45, "damage": 0.0},
		{"range": 205.0, "slow": 0.55, "damage": 3.0},  # damage per second
	],
}

## Char by kindle level 0..3.
const CHAR_STATS := [
	{"range": 175.0, "damage": 8.0, "rate": 1.1},
	{"range": 190.0, "damage": 11.0, "rate": 1.25},
	{"range": 200.0, "damage": 13.0, "rate": 1.4},
	{"range": 215.0, "damage": 18.0, "rate": 1.55},
]
const KINDLE_HEAL := 8.0

# ------------------------------------------------------------ spirits
const SPIRITS := {
	"wisp": {"hp": 21.0, "speed": 52.0, "damage": 7.0, "size": 1.0, "color": Color("#5a6bd8")},
	"flit": {"hp": 12.0, "speed": 90.0, "damage": 4.0, "size": 0.75, "color": Color("#a46be0")},
	"shade": {"hp": 64.0, "speed": 34.0, "damage": 12.0, "size": 1.35, "color": Color("#3c3a78")},
}

const NIGHTS := 3
const WAVES_PER_NIGHT := 3
const MAX_FLAME := 100.0
const DAWN_HEAL := 20.0

# ------------------------------------------------------------ passives
const PASSIVES := {
	"blue_flame": {"name": "Blue Flame", "desc": "Char's bolts deal +60% damage."},
	"ember_sparks": {"name": "Ember Sparks", "desc": "Lantern bolts splash half damage onto nearby spirits."},
	"copper_plating": {"name": "Copper Plating", "desc": "+30 max flame, and refill the flame now."},
	"lucky_hand": {"name": "Lucky Hand", "desc": "+1 reroll every wave."},
	"kindling": {"name": "Kindling", "desc": "Braziers burst 30% faster."},
	"old_runes": {"name": "Old Runes", "desc": "Rune Stones slow 15% more and reach further."},
	"fourth_die": {"name": "Fourth Die", "desc": "Roll 4 dice every wave."},
}

# ------------------------------------------------------------ map stops
const STOPS := {
	"glade": {"name": "Quiet Glade", "desc": "Fewer spirits."},
	"road": {"name": "Old Road", "desc": "A plain night on the road."},
	"hollow": {"name": "Haunted Hollow", "desc": "More spirits. Choose from 3 passives at dawn."},
	"mill": {"name": "Mill Ruins", "desc": "More shades. +1 reroll each wave."},
	"ford": {"name": "Lantern Ford", "desc": "Start with a free Ember Lantern."},
}


## Spawn list for one wave: Array of spirit kinds. night/wave are 0-based.
static func wave_spirits(night: int, wave: int, stop: String, rng: RandomNumberGenerator) -> Array:
	var count := 3 + night * 2 + wave * 2
	if stop == "glade":
		count -= 2
	elif stop == "hollow":
		count += 2
	var shade_chance := 0.0 if night == 0 else 0.12 + 0.06 * night
	if stop == "mill":
		shade_chance += 0.15
	var flit_chance := 0.0 if (night == 0 and wave == 0) else 0.25
	var out := []
	for i in count:
		var r := rng.randf()
		if r < shade_chance:
			out.append("shade")
		elif r < shade_chance + flit_chance:
			out.append("flit")
		else:
			out.append("wisp")
	return out


static func spirit_hp_scale(night: int, stop: String) -> float:
	var s := 1.0 + 0.25 * night
	return s
