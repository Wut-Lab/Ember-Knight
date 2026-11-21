extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## Every face that exists. "kindle" (star) goes on the fire to power up Char.
## Every other face must be a key in DEFENSES.
const DIE_FACES := ["kindle", "torch", "vent", "mortar", "guide", "pine", "ashes"]
## Fire faces go on the fire instead of a tile.
const FIRE_FACES := ["kindle", "pine"]
## A die is a D6: a list of 6 faces. Opposite sides are i and 5 - i.
## The player starts every run with STARTING_DICE copies of the starter die.
const STARTER_DIE := ["torch", "vent", "kindle", "kindle", "vent", "torch"]
const STARTING_DICE := 3
const LOADOUT_SIZE := 3   ## dice slots on leg 1 (+1 per leg finished: Defs.dice_slots)

## Dice kinds the player can own. Opposite faces are i and 5 - i.
const DICE := {
	"ember": {"name": "Ember Die", "faces": STARTER_DIE},
	"torch": {"name": "Torchbearer Die", "faces": ["torch", "kindle", "torch", "vent", "kindle", "torch"]},
	"steam": {"name": "Boiler Die", "faces": ["vent", "kindle", "vent", "torch", "kindle", "vent"]},
	## Long-range themed die: 3 Mortar, 2 Guide Light, 1 Ashes (a blank that
	## pays for the strong faces).
	"artillery": {"name": "Artillery Die", "faces": ["mortar", "guide", "mortar", "ashes", "guide", "mortar"]},
	## Torch+ places a Torch at level 2 (or adds two levels): one die doing
	## the work of two.
	"blazing": {"name": "Blazing Die", "faces": ["torch+", "torch", "kindle", "ashes", "torch", "torch+"]},
	## Two blanks pay for three "+" faces: strong but swingy.
	## Pine Logs feed the fire: a small heal and longer Torch reach for the wave.
	"stoking": {"name": "Stoking Die", "faces": ["kindle", "pine", "kindle", "ashes", "pine", "kindle"]},
	"bombardment": {"name": "Bombardment Die", "faces": ["mortar+", "ashes", "vent+", "kindle", "ashes", "mortar+"]},
}

## A "+" face ("torch+") acts as its base face but adds two levels at once.
static func base_face(f: String) -> String:
	return f.trim_suffix("+")
static func face_levels(f: String) -> int:
	return 2 if f.ends_with("+") else 1
## How many faces of a kind a die has, "+" faces included.
static func face_count(faces: Array, f: String) -> int:
	var n := 0
	for x in faces:
		if base_face(x) == f:
			n += 1
	return n

## Oaths: passives sworn for the rest of the run.
## "face_mods" upgrade a die face: {face: {stat: amount}}. Numbers add to a
## defense's stats; special keys (group_damage, heal, heal_chance) are read
## where that face acts. See Run.face_mod().
const OATHS := {
	"shifting_embers": {
		"rarity": "uncommon",
		"name": "Oath of Shifting Embers",
		"icon": "shift",
		"short": "Move one defense after each wave.",
		"desc": "After each wave, before the next one starts, you may move one defense to another empty tile.\n\nThe move costs 2 flame. Tap a defense to lift it, then tap a glowing tile.",
	},
	"hearth_bound": {
		"rarity": "rare",
		"name": "Hearth-Bound",
		"icon": "hearth",
		"short": "Kindle heals +4 more, but dawn heals 10 less.",
		"desc": "Char is bound to the campfire.\n\nEach Kindle die put on the fire heals 4 more flame (12 instead of 8), but dawn heals 10 less (10 instead of 20).\n\nPays off when you put plenty of Kindle dice on the fire.",
	},
	"bright_beacon": {
		"rarity": "common",
		"name": "Oath of the Bright Beacon",
		"icon": "beacon",
		"short": "Guide Light also gives its group +1 damage.",
		"desc": "Guide Lights burn brighter.\n\nDefenses in a Guide Light's group deal +1 damage, on top of the longer reach.",
		"face_mods": {"guide": {"group_damage": 1.0}},
	},
	"healing_ash": {
		"rarity": "common",
		"name": "Oath of the Healing Ash",
		"icon": "ash_heal",
		"short": "Unused Ashes may heal 3 flame.",
		"desc": "Even cold ashes hold a little warmth.\n\nWhen a wave starts, each Ashes die you rolled has a 50% chance to heal 3 flame.",
		"face_mods": {"ashes": {"heal": 3.0, "heal_chance": 0.5}},
	},
	"gathered_flame": {
		"rarity": "rare",
		"name": "Oath of the Gathered Flame",
		"icon": "flare",
		"short": "Torches deal +1 damage per Torchbearer Die you own.",
		"desc": "Every flame you carry feeds the others.\n\nEach Torch deals +1 damage for every Torchbearer Die in your bag (up to +3 with 3 copies).",
	},
	"decimation": {
		"name": "Oath of Decimation",
		"rarity": "uncommon",
		"icon": "mortar",
		"short": "Mortars reach closer: -10% minimum range per Steam Vent level.",
		"desc": "Vents hold the spirits close; the Mortars learn to drop shells right on them.\n\nEach Cinder Mortar's minimum range shrinks 10% for every Steam Vent level on the map (up to 50%).",
	},
	"forest_friend": {
		"name": "Oath of the Forest Friend",
		"rarity": "rare",
		"icon": "leaf",
		"short": "A dryad wanders the trails, slowing and stinging spirits.",
		"desc": "A dryad joins the camp and wanders the trails all night.\n\nWhen she touches a spirit, vines wrap it: 2 damage and 30% slower for 2s. Each spirit can be touched once every 1.5s.",
	},
}
const GATHERED_FLAME_DIE := "torch"   ## the die Gathered Flame counts
const PINE_HEAL := 3.0           ## Pine Log: flame healed
const PINE_TORCH_RANGE := 0.10   ## Pine Log: + Torch range per log this wave (stacks)
## Forest Friend's dryad (scripts/game/dryad.gd).
const DRYAD_SPEED := 40.0       ## world units/s (a Wisp is 48)
const DRYAD_REACH := 30.0       ## touch distance
const DRYAD_DAMAGE := 2.0
const DRYAD_SLOW := 0.3
const DRYAD_SLOW_TIME := 2.0
const DRYAD_TOUCH_CD := 1.5     ## per spirit
const DECIMATION_PER_VENT := 0.10   ## Mortar min range cut per Steam Vent level
const DECIMATION_CAP := 0.5         ## at most this much of the min range is cut
const SHIFT_COST := 2.0

## Lull rewards: picked just before wave 3 of every night (not the fog ambush).
## Each lull offers LULL_QUICK quick-use rewards (tonight only) and 1 permanent
## one (rest of the run). Permanent rewards stack up to PERK_CAP picks each.
const LULL_QUICK := 2
const PERK_CAP := 3
const LULL_HEAL := 15.0          ## Second Wind
const LULL_REROLLS := 2          ## Spare Luck
const STOKE_RATE := 1.25         ## Stoke: defenses fire this much faster
const DEEP_EMBERS_FLAME := 10.0  ## Deep Embers: +max flame, and heals the same
const HEARTHSTONE_HEAL := 5.0    ## Hearthstones: + dawn heal per pick
## Hone: what one pick adds to a defense kind's stats. Add new damage faces here.
const HONE := {
	"torch": {"damage": 1.0},
	"mortar": {"damage": 1.0},
	"vent": {"slow": 0.1},
}
const SLOW_CAP := 0.5   ## no defense slows spirits more than this (honed Vents)
const QUICK_REWARDS := {
	"second_wind": {"name": "Second Wind", "desc": "Heal 15 flame now."},
	"spare_luck": {"name": "Spare Luck", "desc": "+2 rerolls for wave 3."},
	"stoke": {"name": "Stoke", "desc": "Your defenses fire 25% faster in wave 3."},
	"adjustment": {"name": "Adjustment", "desc": "Move one defense to another open tile, for free."},
}
const PERKS := {
	"hone": {"name": "Hone", "desc": "%s: %s for the rest of the run."},
	"steady_hand": {"name": "Steady Hand", "desc": "+1 reroll every wave for the rest of the run."},
	"deep_embers": {"name": "Deep Embers", "desc": "+10 max flame, and heal 10."},
	"hearthstones": {"name": "Hearthstones", "desc": "Dawn heals 5 more for the rest of the run."},
}


## Text for a Hone pick on one defense kind, e.g. "+1 damage".
static func hone_text(kind: String) -> String:
	var parts := []
	for stat in HONE[kind]:
		var v: float = HONE[kind][stat]
		parts.append("+%d%% slow" % roundi(v * 100) if stat == "slow" else "+%s %s" % [str(v).trim_suffix(".0"), stat])
	return ", ".join(parts)


## One lull's offer: LULL_QUICK quick rewards + 1 permanent, as
## {"type": "quick"|"perk", "id": ..., "kind": defense kind for Hone}.
## quick_ok filters quick ids (Adjustment needs a defense and an open tile);
## hone_kinds are the defense kinds on the board that Hone can still improve.
static func lull_offer(rng: RandomNumberGenerator, perks: Dictionary, quick_ok: Array, hone_kinds: Array) -> Array:
	var quick := quick_ok.duplicate()
	var out := []
	while out.size() < LULL_QUICK and not quick.is_empty():
		out.append({"type": "quick", "id": quick.pop_at(rng.randi() % quick.size())})
	var perm := []
	for id in PERKS:
		if id == "hone":
			for k in hone_kinds:
				if int(perks.get("hone_" + k, 0)) < PERK_CAP:
					perm.append({"type": "perk", "id": "hone", "kind": k})
		elif int(perks.get(id, 0)) < PERK_CAP:
			perm.append({"type": "perk", "id": id})
	if not perm.is_empty():
		out.append(perm[rng.randi() % perm.size()])
	return out
const HEARTH_KINDLE_BONUS := 4.0
const HEARTH_DAWN_PENALTY := 10.0



const MAX_DIE_COPIES := 3   ## a die kind leaves the offerings once owned this many times


## Up to three different Dawn Offerings: {"type": "die"|"oath", "id": ...}.
## Dice owned MAX_DIE_COPIES times and Oaths already sworn are left out.
## Dawn: two dice and two Oaths are offered; the player takes one of each, or
## skips either for SKIP_FLAME flame.
const DAWN_DICE := 2
const DAWN_OATHS := 2
const SKIP_FLAME := 4.0
## Oath rarity. Weights are used from the third dawn on; the first dawn offers
## Commons only, the second Commons and Uncommons. A Unique can still slip into
## those early dawns with UNIQUE_EARLY_CHANCE, for the odd god run.
const RARITY := {
	"common": {"name": "Common", "color": Color("#d9d0c4"), "weight": 55},
	"uncommon": {"name": "Uncommon", "color": Color("#8fd17f"), "weight": 28},
	"rare": {"name": "Rare", "color": Color("#7fb2ff"), "weight": 14},
	"unique": {"name": "Unique", "color": Color("#ffb238"), "weight": 3},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "unique"]
const UNIQUE_EARLY_CHANCE := 0.02

## Up to DAWN_DICE die kinds, leaving out any owned MAX_DIE_COPIES times.
static func dawn_dice(rng: RandomNumberGenerator, dice_owned: Array) -> Array:
	var pool := []
	for id in DICE:
		if dice_owned.count(id) < MAX_DIE_COPIES:
			pool.append(id)
	var out := []
	while out.size() < DAWN_DICE and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out

## Up to DAWN_OATHS unsworn Oaths, each slot rolling a rarity for the dawn
## after night `night_idx` (0-based). If no Oath of the rolled rarity is left,
## the next rarity down is tried, then any.
static func dawn_oaths(rng: RandomNumberGenerator, oaths_owned: Array, night_idx: int) -> Array:
	var left := []
	for id in OATHS:
		if not id in oaths_owned:
			left.append(id)
	var out := []
	while out.size() < DAWN_OATHS and not left.is_empty():
		var tier := oath_rarity_roll(rng, night_idx)
		var pick := ""
		for k in range(RARITY_ORDER.find(tier), -1, -1):
			var of_tier := left.filter(func(id): return OATHS[id].get("rarity", "common") == RARITY_ORDER[k])
			if not of_tier.is_empty():
				pick = of_tier[rng.randi() % of_tier.size()]
				break
		if pick == "":
			pick = left[rng.randi() % left.size()]
		left.erase(pick)
		out.append(pick)
	return out

static func oath_rarity_roll(rng: RandomNumberGenerator, night_idx: int) -> String:
	if night_idx < 2:
		if rng.randf() < UNIQUE_EARLY_CHANCE:
			return "unique"
		if night_idx == 0:
			return "common"
		var w0: int = RARITY["common"]["weight"] + RARITY["uncommon"]["weight"]
		return "common" if rng.randi() % w0 < RARITY["common"]["weight"] else "uncommon"
	var total := 0
	for r in RARITY_ORDER:
		total += RARITY[r]["weight"]
	var roll := rng.randi() % total
	for r in RARITY_ORDER:
		roll -= RARITY[r]["weight"]
		if roll < 0:
			return r
	return "common"

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
	"pine": {"name": "Pine Log", "color": Color("#c98a4a"),
		"desc": "Place on the fire: heals 3 flame, and every Torch reaches 10% farther this wave."},
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
	## Boss: Carl, the Dark Wisp. A big, slow black Wisp with a lavender glow.
	## Light defenses (LIGHT_DEFENSES) inside his dim_range fire dim slower. He
	## bobs, and the dimming circle bobs with him (dim_bob world units, back and forth).
	"dark_wisp": {"name": "Carl, the Dark Wisp", "boss": true,
		"blurb": "dims Torches and Mortars near him: they fire slower", "arrive_sfx": "dark_arrive", "hp": 220.0, "speed": 22.0, "damage": 40.0,
		"size": 2.6, "color": Color("#16121f"), "bar_color": Color("#9b7fe8"), "dim_range": 170.0, "dim": 0.4, "dim_bob": 26.0},
	## Boss: the Lantern Thief. A small, quick gold Wisp in a bandit's mask. Every
	## dash_every seconds he dashes (dash_mult × speed for dash_time). While dashing
	## he snuffs every defense within snuff_range: it can't fire for snuff_time.
	"lantern_thief": {"name": "The Lantern Thief", "boss": true, "hp": 150.0, "speed": 60.0, "damage": 30.0,
		"size": 1.6, "color": Color("#f2c14e"), "dash_every": 3.0, "dash_time": 1.0, "dash_mult": 2.4,
		"snuff_range": 190.0, "snuff_time": 3.0,
		"blurb": "dashes past your defenses and snuffs them out for a few seconds", "arrive_sfx": "thief_arrive"},
	## Boss: Helio, the Midnight Sun. A large, furious yellow Wisp in an orange glow.
	## At each summon_at share of his trail he stops for summon_pause s and calls up
	## 1-2 Midnight Sun Rays. Within burn_range of the fire he holds still, the camp
	## glares bright, and the fire loses burn_dps a second (no hits) until he's banished.
	"helio": {"name": "Helio, the Midnight Sun", "boss": true, "hp": 240.0, "speed": 26.0, "damage": 0.0,
		"size": 2.8, "color": Color("#ffd23a"), "summon_at": [0.25, 0.5, 0.72], "summon_pause": 1.4,
		"burn_range": 110.0, "burn_dps": 4.0,
		"blurb": "calls up Midnight Sun Rays, then sears the fire from close by", "arrive_sfx": "helio_arrive"},
	## Helio's minion: a small, quick, furious yellow Wisp. Light hits only.
	"sun_ray": {"hp": 8.0, "speed": 88.0, "damage": 3.0, "size": 0.65, "color": Color("#ffe14d")},
}

# ------------------------------------------------------------ bosses
## The boss pool: each leg's boss on wave 3 of its last night is drawn from
## here at the start of a run (Run.bosses), never repeating until all are used.
const BOSSES := ["dark_wisp", "lantern_thief", "helio"]


## One boss per leg, shuffled; once the pool runs out it reshuffles, never
## putting the same boss on two legs in a row.
static func roll_bosses(rng: RandomNumberGenerator) -> Array:
	var out := []
	var bag := []
	while out.size() < LEGS:
		if bag.is_empty():
			bag = BOSSES.duplicate()
		var pick: String = bag.pop_at(rng.randi() % bag.size())
		if not out.is_empty() and pick == out[-1] and not bag.is_empty():
			bag.append(pick)
			pick = bag.pop_at(rng.randi() % (bag.size() - 1))
		out.append(pick)
	return out
const BOSS_ESCORT := 0.5         ## the boss wave brings this share of a normal wave 3
const BOSS_DAWN_HEAL := 30.0     ## extra dawn heal after beating a leg's boss
## Light-based defenses: a Dark Wisp dims these (they fire slower near him).
const LIGHT_DEFENSES := ["torch", "mortar"]


## Is this the boss wave? Wave 3 of each leg's 4th night (0-based night/wave).
static func is_boss_wave(night: int, wave: int) -> bool:
	return night_in_leg(night) == NIGHTS_PER_LEG - 1 and wave == WAVES_PER_NIGHT - 1
## Charged Wisps in a night's wave 3, indexed by the whole part of its
## night_step (so each leg gets its own build-up). None on night 1.
const CHARGED_PER_NIGHT := [0, 1, 1, 2, 2, 3, 3]

## Ember Drop: a banished spirit may leave a coal; tap it to heal.
const EMBER_DROP_CHANCE := 0.12
const EMBER_HEAL := 5.0
const EMBER_MAX_PER_WAVE := 5   ## so big late waves can't snowball the healing
const EMBER_LIFE := 4.0   ## seconds before it fades away

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


## Finishing a leg (surviving its 4th night) gives +1 dice slot for the rest
## of the run and puts this die in the bag, so there's always one to fill it.
const LEG_REWARD_DIE := "ember"


## Dice slots on a 0-based night: LOADOUT_SIZE, +1 per leg finished (3, 4, 5).
static func dice_slots(night: int) -> int:
	return LOADOUT_SIZE + leg_of(night)


## Is this 0-based night the last of its leg (but not of the run)?
static func ends_leg(night: int) -> bool:
	return night_in_leg(night) == NIGHTS_PER_LEG - 1 and night < NIGHTS - 1
const WAVES_PER_NIGHT := 3
const MAX_FLAME := 100.0
const DAWN_HEAL := 20.0

# ------------------------------------------------------------ essence
## Essence is kept between runs (Profile). At the end of a night survived:
## 1 per ESSENCE_PER_FLAME flame left, plus the leg's number (leg 1 gives +1
## a night, leg 3 gives +3). Beating a leg's boss adds ESSENCE_PER_BOSS x the
## leg's number. A lost night gives the leg's number. Never less than 1.
## A full 12-night run earns roughly 80, close to the old 7-night pace per night.
const ESSENCE_PER_FLAME := 20.0
const ESSENCE_PER_BOSS := 5


static func essence_for_night(flame: float, night_idx: int) -> int:
	var leg := leg_of(night_idx) + 1
	var boss := ESSENCE_PER_BOSS * leg if night_in_leg(night_idx) == NIGHTS_PER_LEG - 1 else 0
	return maxi(1, floori(flame / ESSENCE_PER_FLAME) + leg + boss)


static func essence_for_lost_night(night_idx: int) -> int:
	return leg_of(night_idx) + 1

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
static func wave_spirits(night: int, wave: int, stop: String, rng: RandomNumberGenerator, boss_id := "dark_wisp") -> Array:
	var count := floori(5 + night_step(night) * 2 + wave * 2 + 0.000001)
	# Mist Wisps slip into night 1 from wave 2, thicker at misty stops (the lake).
	var mist_chance := 0.15 + 0.05 * night_step(night)
	if night == 0:
		mist_chance = [0.0, 0.1, 0.2][wave]
	if night > 0 or wave > 0:   # some stops (the lake) breed more Mist Wisps
		mist_chance += STOPS.get(stop, {}).get("mist_bonus", 0.0)
	var boss := is_boss_wave(night, wave)
	if boss:   # a lighter escort, and the boss a third of the way in
		count = maxi(2, roundi(count * BOSS_ESCORT))
	var out := []
	for i in count:
		out.append("mist_wisp" if rng.randf() < mist_chance else "wisp")
	if boss:
		out.insert(count / 3, boss_id)
		return out
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
	var s := 1.0 + 0.15 * night_step(night)
	return s
