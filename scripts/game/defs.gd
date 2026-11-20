extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## Every face that exists. "kindle" (star) goes on the fire to power up Char.
## Every other face must be a key in DEFENSES.
const DIE_FACES := ["kindle", "torch", "vent", "mortar", "guide", "ashes"]
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
	## Long-range themed die: 3 Mortar, 2 Guide Light, 1 Ashes (a blank that
	## pays for the strong faces).
	"artillery": {"name": "Artillery Die", "faces": ["mortar", "guide", "mortar", "ashes", "guide", "mortar"]},
}

## Oaths: passives sworn for the rest of the run.
## "face_mods" upgrade a die face: {face: {stat: amount}}. Numbers add to a
## defense's stats; special keys (group_damage, heal, heal_chance) are read
## where that face acts. See Run.face_mod().
const OATHS := {
	"shifting_embers": {
		"name": "Oath of Shifting Embers",
		"icon": "shift",
		"short": "Move one defense after each wave.",
		"desc": "After each wave, before the next one starts, you may move one defense to another empty tile.\n\nThe move costs 2 flame. Tap a defense to lift it, then tap a glowing tile.",
	},
	"hearth_bound": {
		"name": "Hearth-Bound",
		"icon": "hearth",
		"short": "Kindle heals +4 more, but dawn heals 10 less.",
		"desc": "Char is bound to the campfire.\n\nEach Kindle die put on the fire heals 4 more flame (12 instead of 8), but dawn heals 10 less (10 instead of 20).\n\nPays off when you put plenty of Kindle dice on the fire.",
	},
	"bright_beacon": {
		"name": "Oath of the Bright Beacon",
		"icon": "beacon",
		"short": "Guide Light also gives its group +1 damage.",
		"desc": "Guide Lights burn brighter.\n\nDefenses in a Guide Light's group deal +1 damage, on top of the longer reach.",
		"face_mods": {"guide": {"group_damage": 1.0}},
	},
	"healing_ash": {
		"name": "Oath of the Healing Ash",
		"icon": "ash_heal",
		"short": "Unused Ashes may heal 3 flame.",
		"desc": "Even cold ashes hold a little warmth.\n\nWhen a wave starts, each Ashes die you rolled has a 50% chance to heal 3 flame.",
		"face_mods": {"ashes": {"heal": 3.0, "heal_chance": 0.5}},
	},
}
const SHIFT_COST := 2.0
const HEARTH_KINDLE_BONUS := 4.0
const HEARTH_DAWN_PENALTY := 10.0

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
const REROLLS_PER_WAVE := 1
const MAX_LEVEL := 3

## Name, colour and tooltip for each die face.
const FACE_INFO := {
	"kindle": {"name": "Kindle Char", "color": Color("#fff0b0"),
		"desc": "Place on the fire: Char hits harder and heals a little."},
	"torch": {"name": "Torch", "color": Color("#ff9a3c"),
		"desc": "A small flame on a post. Shoots embers like a weak Char."},
	"vent": {"name": "Steam Vent", "color": Color("#9fd6d0"),
		"desc": "A brass boiler that puffs steam: slows nearby spirits and scalds them a little."},
	"mortar": {"name": "Cinder Mortar", "color": Color("#e0603a"),
		"desc": "Lobs a cinder at the spirit farthest back on its trail. Slow, splashes, can't hit up close."},
	"guide": {"name": "Guide Light", "color": Color("#ffe9a8"),
		"desc": "A lantern on a pole. Neighbouring defenses reach a little farther and closer."},
	"ashes": {"name": "Ashes", "color": Color("#8a8078"),
		"desc": "Cold ashes. Does nothing: reroll it or leave it."},
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
	## Slow artillery: aims at the spirit farthest back on its trail between
	## "min" and "range", and splashes everything within "splash" of the hit.
	"mortar": [
		{"range": 380.0, "min": 200.0, "damage": 5.0, "rate": 0.36, "splash": 45.0},
		{"range": 400.0, "min": 200.0, "damage": 7.0, "rate": 0.4, "splash": 50.0},
		{"range": 420.0, "min": 200.0, "damage": 10.0, "rate": 0.44, "splash": 55.0},
	],
	## No attack. Defenses on the other tiles of its group get their
	## range multiplied by "boost" and any "min" range by "min_mult". Several
	## Guide Lights don't stack: the best one counts.
	"guide": [
		{"range": 0.0, "boost": 1.15, "min_mult": 0.75},
		{"range": 0.0, "boost": 1.2, "min_mult": 0.7},
		{"range": 0.0, "boost": 1.25, "min_mult": 0.65},
	],
}
## Guide Light boosts the other tiles in its group (the three tiles between
## two trails: board tiles 3g, 3g+1, 3g+2).

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
	## Elite, wave 3 only: a yellow Wisp in red crackle. Stops short of the fire and
	## zaps it every zap_every seconds until banished. zap_range is from the fire's
	## centre, kept under Char's shortest reach so he can always hit it.
	"charged_wisp": {"hp": 40.0, "speed": 38.0, "damage": 3.0, "size": 1.2, "color": Color("#ffe36b"),
		"zap_range": 80.0, "zap_every": 2.0},
}
## Charged Wisps in a night's wave 3, indexed by the whole part of its
## night_step (so each leg gets its own build-up). None on night 1.
const CHARGED_PER_NIGHT := [0, 1, 1, 2, 2, 3, 3]

const NIGHTS := 12  ## the Long Road: 3 legs of 4 nights
const LEGS := 3
const NIGHTS_PER_LEG := 4
## Each new leg starts this far up the night ramp. It's less than a full leg
## (3 steps), so difficulty steps back a little when a leg begins.
const LEG_RAMP := 1.75


## Which leg (0-based) a 0-based night is in, and its place in that leg.
static func leg_of(night: int) -> int:
	return mini(night / NIGHTS_PER_LEG, LEGS - 1)


static func night_in_leg(night: int) -> int:
	return night - leg_of(night) * NIGHTS_PER_LEG
const WAVES_PER_NIGHT := 3
const MAX_FLAME := 100.0
const DAWN_HEAL := 20.0

# ------------------------------------------------------------ essence
## Essence is kept between runs (Profile). At the end of a night survived:
## 1 per ESSENCE_PER_FLAME flame left, plus the night's number (night 1 gives
## +1, night 7 gives +7). A lost night gives half the night's number, rounded
## down. Never less than 1 either way.
const ESSENCE_PER_FLAME := 20.0


static func essence_for_night(flame: float, night_idx: int) -> int:
	return maxi(1, floori(flame / ESSENCE_PER_FLAME) + night_idx + 1)


static func essence_for_lost_night(night_idx: int) -> int:
	return maxi(1, (night_idx + 1) / 2)

# ------------------------------------------------------------ map stops
const STOPS := {
	"road": {"name": "Old Road", "desc": "A plain night on the road."},
	"hill": {"name": "Hillside Clearing", "desc": "Camp on a hilltop. 3 trails spiral round the stagecoach."},
	"cliff": {"name": "Cliff Edge", "desc": "A sheer drop behind camp. 2-3 trails, front and sides."},
	"lake": {"name": "Quiet Lakeside", "desc": "Camp by a calm lake. Spirits drift across the water; mist rises.",
		"mist_bonus": 0.15},
}
## Quiet Lakeside: a lake fills one side, its near shore this far from the fire.
## Spirits crossing the water drift slower. 2-3 land trails + 1 water crossing.
const LAKE_SHORE := 235.0
const LAKE_RX := 380.0
const LAKE_RY := 330.0
const LAKE_WATER_SPEED := 0.6
const LAKE_FOUR_LANE_CHANCE := 0.5
const STOP_CHOICES_MIN := 2   ## camps offered each night, drawn from STOPS
const STOP_CHOICES_MAX := 3
## Cliff Edge: the drop runs behind the stagecoach. Its edge sits this far
## behind the fire (world y) and bends away toward the sides.
const CLIFF_EDGE_Y := -175.0
const CLIFF_BEND := 0.0009
const CLIFF_THREE_LANE_CHANCE := 0.6

static func cliff_edge_y(x: float) -> float:
	return CLIFF_EDGE_Y - CLIFF_BEND * x * x
## Hillside Clearing: each trail wraps this far round the camp (degrees), and
## spirits run faster down the long spirals.
const HILL_WRAP_MIN := 200.0
const HILL_WRAP_MAX := 270.0
const HILL_SPEED := 1.6

## Forks and Char's gates. Each battle map gets FORKS_MIN..MAX one-way forks;
## a spirit at an ungated fork goes either way at random. Gates come two to a
## loadout slot; tapping one in a wave switches it, then it needs GATE_COOLDOWN.
const FORKS_MIN := 1
const FORKS_MAX := 3
## Tiles sit in two rows with a clear ring between them where the forks cross.
const INNER_TILE_R := 150.0
const OUTER_TILE_R := 330.0
const FORK_RADIUS := 258.0    ## road forks leave their trail this far out ...
const MERGE_RADIUS := 222.0   ## ... and join the next trail here (between the tile rows)
const GATES_FREE := 1       ## every night Char has this many gates to cobble
const GATES_PER_SLOT := 1   ## ... plus this many for a traded die slot
## World area hidden behind the stagecoach art; no fork may run through it.
const COACH_ZONE := Rect2(-130.0, -330.0, 290.0, 300.0)
const GATE_COOLDOWN := 4.0


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


## Night curve: how far up the difficulty ramp a night is. Each leg ramps on
## its own (0..3 inside a leg, bent by DIFF_K: 1 = straight line, below 1
## front-loads it) and starts LEG_RAMP higher than the last leg did, so each
## leg's 4th night is its peak and the next leg opens a step easier.
## night is 0-based: legs run 0-3, 1.75-4.75, 3.5-6.5.
## Every per-night step below scales by this instead of the raw night number.
const DIFF_K := 0.95

static func night_step(night: int) -> float:
	if night <= 0:
		return 0.0
	var last := float(NIGHTS_PER_LEG - 1)
	var i := float(night_in_leg(night))
	return leg_of(night) * LEG_RAMP + last * pow(minf(i / last, 1.0), DIFF_K)


## Spawn list for one wave: Array of spirit kinds. night/wave are 0-based.
static func wave_spirits(night: int, wave: int, stop: String, rng: RandomNumberGenerator) -> Array:
	var count := floori(5 + night_step(night) * 2 + wave * 2 + 0.000001)
	# Mist Wisps slip into night 1 from wave 2, thicker at misty stops (the lake).
	var mist_chance := 0.15 + 0.05 * night_step(night)
	if night == 0:
		mist_chance = [0.0, 0.1, 0.2][wave]
	if night > 0 or wave > 0:   # some stops (the lake) breed more Mist Wisps
		mist_chance += STOPS.get(stop, {}).get("mist_bonus", 0.0)
	var out := []
	for i in count:
		out.append("mist_wisp" if rng.randf() < mist_chance else "wisp")
	# Charged Wisps take spots in the back half of wave 3, so they come late.
	if wave == WAVES_PER_NIGHT - 1:
		var n: int = CHARGED_PER_NIGHT[mini(floori(night_step(night) + 0.000001), CHARGED_PER_NIGHT.size() - 1)]
		var free := range(count / 2, count)
		for j in mini(n, free.size()):
			var at: int = free.pop_at(rng.randi() % free.size())
			out[at] = "charged_wisp"
	return out


## Seconds between spawns (before the battle's ±20% jitter). It shrinks each
## night AND each wave, so wave 1 is gentle and wave 3 tends to overrun Char.
## Night 1: 1.15 / 0.95 / 0.75.
const SPAWN_GAP := 1.15
const SPAWN_GAP_PER_NIGHT := 0.12
const SPAWN_GAP_PER_WAVE := 0.2
const SPAWN_GAP_MIN := 0.55

static func spawn_gap(night: int, wave: int) -> float:
	return maxf(SPAWN_GAP_MIN, SPAWN_GAP - SPAWN_GAP_PER_NIGHT * night_step(night) - SPAWN_GAP_PER_WAVE * wave)


## Does this stop's map get forks (and so gates)? Set "forks": false on a stop to drop them.
static func has_forks(stop: String) -> bool:
	return STOPS.get(stop, {}).get("forks", true)


static func spirit_hp_scale(night: int, stop: String) -> float:
	var s := 1.0 + 0.25 * night_step(night)
	return s
