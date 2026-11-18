extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## Every face that exists. "kindle" (star) goes on the fire to power up Char.
## Every other face must be a key in DEFENSES.
const DIE_FACES := ["kindle", "torch", "vent"]
## A die is a D6: a list of 6 faces. Opposite sides are i and 5 - i.
## The player starts every run with STARTING_DICE copies of the starter die.
const STARTER_DIE := ["torch", "vent", "kindle", "kindle", "vent", "torch"]
const STARTING_DICE := 3
const LOADOUT_SIZE := 3   ## dice slots filled before each night

## Dice kinds the player can own. Opposite faces are i and 5 - i.
const DICE := {
	"ember": {"name": "Ember Die", "faces": STARTER_DIE},
	"torch": {"name": "Torchbearer Die", "faces": ["torch", "kindle", "torch", "vent", "kindle", "torch"]},
	"steam": {"name": "Boiler Die", "faces": ["vent", "kindle", "vent", "torch", "kindle", "vent"]},
}

## Oaths: passives sworn for the rest of the run.
const OATHS := {
	"shifting_embers": {
		"name": "Oath of Shifting Embers",
		"icon": "shift",
		"short": "Move one defense after each wave.",
		"desc": "After each wave, before the next one starts, you may move one defense to another empty tile.\n\nThe move costs 2 flame. Tap a defense to lift it, then tap a glowing tile.",
	},
}
const SHIFT_COST := 2.0

const OFFERINGS := 3   ## Dawn Offerings shown after each night survived


const MAX_DIE_COPIES := 3   ## a die kind leaves the offerings once owned this many times


## Up to three different Dawn Offerings: {"type": "die"|"oath", "id": ...}.
## Dice owned MAX_DIE_COPIES times and Oaths already sworn are left out.
static func dawn_offerings(rng: RandomNumberGenerator, dice_owned: Array, oaths_owned: Array) -> Array:
	var pool := []
	for id in DICE:
		if dice_owned.count(id) < MAX_DIE_COPIES:
			pool.append({"type": "die", "id": id})
	for id in OATHS:
		if not id in oaths_owned:
			pool.append({"type": "oath", "id": id})
	var out := []
	while out.size() < OFFERINGS and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out
const REROLLS_PER_WAVE := 2
const MAX_LEVEL := 3

## Name, colour and tooltip for each die face.
const FACE_INFO := {
	"kindle": {"name": "Kindle Char", "color": Color("#fff0b0"),
		"desc": "Place on the fire: Char hits harder and heals a little."},
	"torch": {"name": "Torch", "color": Color("#ff9a3c"),
		"desc": "A small flame on a post. Shoots embers like a weak Char."},
	"vent": {"name": "Steam Vent", "color": Color("#9fd6d0"),
		"desc": "A brass boiler that puffs steam: slows nearby spirits and scalds them a little."},
}

# ------------------------------------------------------------ defenses
## A defense is built by dropping a die on a tile; another die with the same
## face on it levels it up (max MAX_LEVEL). One entry per face, with stats for
## levels 1..3, e.g.
##   "lantern": [{"range": 235.0, "damage": 10.0, "rate": 1.0}, {...}, {...}],
## range is in world units, rate is attacks per second. Tiles sit between the
## trails: a spirit gets no closer than ~146 to an inner tile and ~180 to an
## outer one, so a range must clear that to hit anything. The behaviour and
## drawing for each kind live in scripts/game/defense.gd.
const DEFENSES := {
	## A weak Char: well under half its damage.
	"torch": [
		{"range": 220.0, "damage": 3.0, "rate": 0.85},
		{"range": 235.0, "damage": 4.5, "rate": 0.95},
		{"range": 250.0, "damage": 7.0, "rate": 1.0},
	],
	## Weak support: a steam puff that scalds everything near it.
	## "slow" is applied by the battle to spirits in range.
	"vent": [
		{"range": 185.0, "damage": 2.0, "rate": 0.5, "slow": 0.2},
		{"range": 195.0, "damage": 3.0, "rate": 0.55, "slow": 0.27},
		{"range": 205.0, "damage": 4.0, "rate": 0.6, "slow": 0.33},
	],
}

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
	"wisp": {"hp": 16.0, "speed": 48.0, "damage": 8.0, "size": 1.0, "color": Color("#d6ecff")},
	## Techy flanker: a hazy blue Wisp whose chill slows Char's attacks while it is near.
	"mist_wisp": {"hp": 16.0, "speed": 56.0, "damage": 7.0, "size": 0.85, "color": Color("#8fb8ff"),
		"chill_range": 120.0, "chill": 0.3},
}

const NIGHTS := 5
const WAVES_PER_NIGHT := 3
const MAX_FLAME := 100.0
const DAWN_HEAL := 20.0

# ------------------------------------------------------------ essence
## Essence is kept between runs (Profile). At the end of a night survived:
## 1 per ESSENCE_PER_FLAME flame left, plus the night's number (night 1 gives
## +1, night 5 gives +5). A lost night gives half the night's number, rounded
## down. Never less than 1 either way.
const ESSENCE_PER_FLAME := 20.0


static func essence_for_night(flame: float, night_idx: int) -> int:
	return maxi(1, floori(flame / ESSENCE_PER_FLAME) + night_idx + 1)


static func essence_for_lost_night(night_idx: int) -> int:
	return maxi(1, (night_idx + 1) / 2)

# ------------------------------------------------------------ map stops
const STOPS := {
	"road": {"name": "Old Road", "desc": "A plain night on the road."},
}


# ------------------------------------------------------------ road events
## Fog Cloud: may roll after the player picks a stop, from night 2 on.
const FOG_CHANCE := 0.3
const POTHOLE_CHANCE := 0.33   ## Press On: the stagecoach hits a pothole
const POTHOLE_DAMAGE := 8.0
const AMBUSH_CHANCE := 0.5     ## Make Camp Early: Mist Wisps find the camp
const CAMP_HEAL := 10.0        ## Make Camp Early always ends with this


## Ember Shrine: same chance as Fog Cloud, at most once per run.
const SHRINE_CHANCE := 0.3
const SHRINE_OFFER_COST := 15.0   ## Kneel and Offer: flame paid
const SHRINE_REROLLS := 1         ## ...for this many extra rerolls every wave, rest of run
const SHRINE_TAKE_HEAL := 20.0    ## Take the Embers: flame gained
const SHRINE_CURSE_HP := 1.25     ## ...but tonight's spirits have this much HP


## The Fog Cloud ambush: one wave of Mist Wisps, as many as the night's first wave.
static func ambush_spirits(night: int) -> Array:
	var out := []
	for i in 3 + night * 2:
		out.append("mist_wisp")
	return out


# ------------------------------------------------------------ wave modifiers
## From night 2 on, each wave has MOD_CHANCE to roll one of these (equal odds).
## Shown in the prep phase so the player can plan for it.
const MOD_CHANCE := 0.1
const WAVE_MODS := {
	"angry": {"name": "Angry", "desc": "The spirits move 20% faster."},
	"hearty": {"name": "Hearty", "desc": "Half the spirits have +50% HP (the bigger ones)."},
	"swarmy": {"name": "Swarmy", "desc": "Most spirits rush down the glowing trail."},
}
const ANGRY_SPEED := 1.2
const HEARTY_HP := 1.5
const HEARTY_SHARE := 0.5
const SWARM_SHARE := 0.75      ## this share of spirits take the swarm trail
const SWARM_GAP := 0.6         ## their spawn gap is multiplied by this


## A wave modifier id, or "" for none. night is 0-based.
static func roll_wave_mod(night: int, rng: RandomNumberGenerator) -> String:
	if night == 0 or rng.randf() >= MOD_CHANCE:
		return ""
	return WAVE_MODS.keys()[rng.randi() % WAVE_MODS.size()]


## Spawn list for one wave: Array of spirit kinds. night/wave are 0-based.
static func wave_spirits(night: int, wave: int, stop: String, rng: RandomNumberGenerator) -> Array:
	var count := 5 + night * 2 + wave * 2
	# Mist Wisps slip into night 1 from wave 2, then drift thicker in the hollow.
	var mist_chance := 0.15 + 0.05 * night
	if night == 0:
		mist_chance = [0.0, 0.1, 0.2][wave]
	if stop == "hollow" and night > 0:
		mist_chance += 0.15
	var out := []
	for i in count:
		out.append("mist_wisp" if rng.randf() < mist_chance else "wisp")
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
