extends RefCounted
## Game data for the First Playable: dice faces, defenses, spirits,
## map stops and wave sizes. Tune numbers here.

# ------------------------------------------------------------ dice
## Every face that exists. "kindle" (star) goes on the fire to power up Char.
## Every other face must be a key in DEFENSES.
const DIE_FACES := ["kindle", "torch", "vent", "mortar", "guide", "bellows", "brazier", "wall", "mire", "lure", "votive", "pine", "ward", "reliquary", "ashes"]
## Fire faces go on the fire instead of a tile.
const FIRE_FACES := ["kindle", "pine", "ward", "reliquary"]
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
	## Two Kindle and two Pine Logs heal; a Torch and an Ashes keep it honest.
	"healing": {"name": "Healing Die", "faces": ["kindle", "pine", "torch", "kindle", "ashes", "pine"]},
	## Ashen Dice: four blanks pay for a "++" face (places a level-3 defense)
	## and a "+" face. Weak alone; built to feed the Ash Oaths.
	"ashen_torch": {"name": "Ashen Torch Die", "faces": ["torch++", "ashes", "ashes", "torch+", "ashes", "ashes"]},
	"ashen_mortar": {"name": "Ashen Mortar Die", "faces": ["mortar++", "ashes", "ashes", "mortar+", "ashes", "ashes"]},
	"ashen_vent": {"name": "Ashen Vent Die", "faces": ["vent++", "ashes", "ashes", "vent+", "ashes", "ashes"]},
	## Mason Die: Ember Walls hold spirits where the Mortars can land on them.
	"mason": {"name": "Mason Die", "faces": ["wall", "mortar", "wall+", "ashes", "mortar", "wall"]},
	"ward": {"name": "Ward Die", "faces": ["ward", "vent", "kindle", "ward", "vent", "kindle"]},
	"crazy": {"name": "Crazy Die", "faces": ["torch", "mortar", "vent", "wall", "guide", "ashes"]},
	## Wayfinder Die: Guide Lights with Torches to light and a Wall to hold the line.
	"wayfinder": {"name": "Wayfinder Die", "faces": ["guide", "torch", "guide", "wall", "torch", "ashes"]},
	"bombardment": {"name": "Bombardment Die", "faces": ["mortar+", "ashes", "vent+", "kindle", "ashes", "mortar+"]},
	## Forge Die: two Bellows to drive a patch of Torches and Vents.
	"forge": {"name": "Forge Die", "faces": ["bellows", "torch", "vent", "ashes", "torch", "bellows"]},
	## Fire Support Die: no attackers at all, only patch buffs (opposite faces match).
	"fire_support": {"name": "Fire Support Die", "faces": ["guide", "bellows", "brazier", "brazier", "bellows", "guide"]},
	## Swamp dice (SWAMP_DICE): only offered at dawn after a Swamp Turnpike night.
	## Bog Die: Mire patches on the trails hold spirits for the Torches.
	"bog": {"name": "Bog Die", "faces": ["mire", "torch+", "vent", "ashes", "torch+", "mire"]},
	## Will-o'-Wisp Die: Wisp Lanterns bunch spirits up for Mortars and Braziers.
	"will_o_wisp": {"name": "Will-o'-Wisp Die", "faces": ["lure", "mortar", "brazier", "ashes", "mortar", "lure"]},
	## Bone Die: no Ashes at all, three "+" faces. Plain, raw power.
	"bone": {"name": "Bone Die", "faces": ["torch+", "mortar+", "guide", "wall", "vent+", "kindle"]},
	## Chapel dice (CHAPEL_DICE): only offered at dawn after a Sunken Chapel night.
	## Votive Die: candles that mend the fire as spirits fall near them.
	"votive": {"name": "Votive Die", "faces": ["votive", "torch+", "kindle", "ashes", "vent", "votive+"]},
	## Reliquary Die: a blessed box on the fire soaks up the first hurts of a wave.
	"reliquary": {"name": "Reliquary Die", "faces": ["reliquary", "mortar", "ward", "ashes", "torch", "reliquary+"]},
	## Pilgrim Die: heal, ward and wall; next to no attack of its own.
	"pilgrim": {"name": "Pilgrim Die", "faces": ["pine+", "ward+", "kindle", "wall", "guide", "pine"]},
}
const SWAMP_DICE := ["bog", "will_o_wisp", "bone"]
## Chapel dice (CHAPEL_DICE): only offered at dawn after a Sunken Chapel night.
const CHAPEL_DICE := ["votive", "reliquary", "pilgrim"]

## A "+" face ("torch+") acts as its base face but adds two levels at once;
## a "++" face adds three (a level-3 defense in one die).
static func base_face(f: String) -> String:
	return f.rstrip("+")
static func face_levels(f: String) -> int:
	return 1 + f.length() - f.rstrip("+").length()
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
		"short": "Guide Light also gives the rest of its patch +1 damage.",
		"desc": "Guide Lights burn brighter.\n\nOther defenses on a Guide Light's ashy patch deal +1 damage, on top of the longer reach.",
		"face_mods": {"guide": {"group_damage": 1.0}},
	},
	"roaring_forge": {
		"rarity": "common",
		"name": "Oath of the Roaring Forge",
		"icon": "forge",
		"short": "Each Bellows also makes Char attack 6% faster.",
		"desc": "The bellows fan the campfire too.\n\nFor each Bellows on the board, Char attacks 6% faster (up to 4 Bellows, +24%), on top of the faster attacks on its patch.",
	},
	"smouldering_wake": {
		"rarity": "uncommon",
		"name": "Oath of the Ember Wake",
		"icon": "wake",
		"short": "A banished spirit passes its burn on.",
		"desc": "Embers find new fuel.\n\nWhen a smouldering spirit is banished, its burn jumps to the nearest spirit close by, fresh and at full strength. A burn jumps at most 3 times.",
	},
	"healing_ash": {
		"rarity": "common",
		"name": "Oath of the Healing Ash",
		"icon": "ash_heal",
		"short": "Unused Ashes may heal 3 flame.",
		"desc": "Even cold ashes hold a little warmth.\n\nWhen a wave starts, each Ashes die you rolled has a 50% chance to heal 3 flame.",
		"face_mods": {"ashes": {"heal": 3.0, "heal_chance": 0.5}},
	},
	"healthy_nights": {
		"rarity": "uncommon",
		"name": "Oath of Healthy Nights",
		"icon": "heart",
		"short": "Kindle and Pine Logs heal more as nights pass.",
		"desc": "The fire grows stronger the longer it burns.\n\nKindle and Pine Logs put on the fire heal +1 flame for every two nights passed (at least +1, at most +4).",
	},
	"ash_buckets": {
		"rarity": "common",
		"name": "Oath of Ash Buckets",
		"icon": "ash_heal",
		"short": "Each Ashes left when a wave starts heals 1.",
		"desc": "Sweep the ashes back into the fire.\n\nWhen a wave starts, each Ashes die still showing heals 1 flame.",
	},
	"banked_fire": {
		"rarity": "rare",
		"name": "Oath of the Banked Fire",
		"icon": "hearth",
		"short": "Each Ashes left gives +6% damage for the wave.",
		"desc": "Ash smothers the coals, and they burn hotter beneath.\n\nWhen a wave starts, each Ashes die still showing gives every defense and Char +6% damage for that wave (up to +30%).",
	},
	"simplicity": {
		"rarity": "common",
		"name": "Oath of Simplicity",
		"icon": "kindle",
		"short": "Dawn heals +3 per leg; Char fires 5% faster.",
		"desc": "Keep it simple: tend the fire, watch the dark.\n\nDawn heals +3 flame on leg 1, +6 on leg 2 and +9 on leg 3, and Char fires 5% faster.",
	},
	"warm_coals": {
		"rarity": "common",
		"name": "Oath of Warm Coals",
		"icon": "hearth",
		"short": "Ember Drops heal 7 instead of 5.",
		"desc": "The coals the spirits leave burn warmer.\n\nEach Ember Drop you tap heals 7 flame instead of 5.",
	},
	"sturdy_stones": {
		"rarity": "common",
		"name": "Oath of Sturdy Stones",
		"icon": "wall",
		"short": "Ember Walls have 25% more HP.",
		"desc": "Char lays the stones deep and tight.\n\nEmber Walls have 25% more HP (50 / 94 / 150).",
	},
	"sixth_face": {
		"rarity": "unique",
		"name": "Oath of the Sixth Face",
		"icon": "shift",
		"short": "Once per wave, choose a die's face.",
		"desc": "The dice answer to Char now.\n\nOnce per wave, pick one of your dice and choose which of its faces it shows (the Choose button by Roll).",
	},
	"urgency": {
		"rarity": "unique",
		"name": "Oath of Urgency",
		"icon": "hourglass",
		"short": "Char and defenses fire 25% faster; half the spirits are 30% faster.",
		"desc": "No time to waste. No time to rest.\n\nChar and every defense that attacks (Torches, Mortars, Steam Vents) fire 25% faster, and Char deals 10% more damage. But half the spirits move 30% faster.",
	},
	"dedication": {
		"rarity": "rare",
		"name": "Oath of Dedication",
		"icon": "devotion",
		"short": "Your most shared face gets +10% per die that has it.",
		"desc": "Char commits to one craft.\n\nThe face found on the most of tonight's dice gets +10% for each die that has it: damage (Torch, Mortar), slow (Steam Vent), healing (Kindle, Pine Log), HP (Ember Wall), reach (Guide Light), haste (Bellows) or burn (Ember Brazier). Ashes don't count; ties go to the earlier die.",
	},
	"immortals": {
		"rarity": "unique",
		"name": "Oath of the Immortals",
		"icon": "rune",
		"short": "Char's kills have a 33% chance to heal 5.",
		"desc": "What Char burns away feeds his flame.\n\nEach spirit Char banishes himself has a 33% chance to heal 5 flame.",
	},
	"crossfire": {
		"rarity": "uncommon",
		"name": "Oath of Crossfire",
		"icon": "mortar",
		"short": "Mortars +1 damage; their hits scorch spirits for Torches.",
		"desc": "Lob them in, then pick them off.\n\nCinder Mortars deal +1 damage. Spirits hit by a Mortar are scorched for 2s, and Torches deal 30% more damage to scorched spirits.",
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
	"dawn_offerings": {
		"name": "Oath of Dawn Offerings",
		"rarity": "uncommon",
		"icon": "sunrise",
		"short": "Once each dawn, pay 5 flame and 3 Essence to reroll the offerings.",
		"desc": "The sunrise can be bargained with.\n\nOnce each dawn, you may spend 5 flame and 3 Essence to reroll the dice and Oaths still on offer.",
	},
	"steady_hands": {
		"name": "Oath of Steady Hands",
		"rarity": "uncommon",
		"icon": "hand",
		"short": "Rerolls never land on Ashes.",
		"desc": "Char's hands are steady now; nothing slips into the ashes.\n\nWhen you reroll, dice never land on an Ashes face. The first roll each wave is unchanged.",
	},
	"ash_clouds": {
		"name": "Oath of Ash Clouds",
		"rarity": "uncommon",
		"icon": "ash_cloud",
		"short": "Unused Ashes slow the first spirits of a wave.",
		"desc": "Char scatters the dead ash into a choking cloud.\n\nFor each Ashes face left unused on your dice when a wave begins, one of the first spirits to enter moves 50% slower for the rest of the wave. Bosses are unaffected.",
	},
}
## Oaths that only reach the Dawn Offerings once unlocked (Defs.UNLOCKS).
const LOCKED_OATHS := ["dawn_offerings", "steady_hands", "ash_clouds"]
## Dice that only reach the Dawn Offerings once unlocked (Defs.UNLOCKS).
const LOCKED_DICE := ["crazy"]
const DAWN_REROLL_FLAME := 5.0   ## Oath of Dawn Offerings: reroll cost
const DAWN_REROLL_ESSENCE := 3

## Unlockables shown in the main menu's Unlocks list, grouped by "type"
## (oath, die, misc; listed in that order). Each counts a Profile stat up to
## "goal"; "ref" is the Oath or die id it unlocks. "hidden" ones stay off the
## list until earned (the route and everything that comes with it).
const UNLOCK_TYPES := [["oath", "Oaths"], ["die", "Dice"], ["misc", "Misc"], ["outfit", "Outfits"], ["route", "Routes"], ["member", "Caravan"]]
const UNLOCKS := {
	"dawn_offerings": {"type": "oath", "ref": "dawn_offerings", "stat": "dawn_skips", "goal": 10,
		"hint": "Skip 10 Dawn Offerings."},
	"crazy": {"type": "die", "ref": "crazy", "stat": "nights_won", "goal": 1,
		"hint": "Survive night 1."},
	"steady_hands": {"type": "oath", "ref": "steady_hands", "stat": "night_2_won", "goal": 1,
		"hint": "Survive night 2."},
	"ash_clouds": {"type": "oath", "ref": "ash_clouds", "stat": "ashes_rolled", "goal": 50,
		"hint": "Roll 50 Ashes."},
	"swamp": {"type": "route", "ref": "swamp", "stat": "routes_chosen", "goal": 10,
		"hint": "Choose 10 routes. Appears from night 5.", "hidden": true},
	"chapel": {"type": "route", "ref": "chapel", "stat": "night_11_won", "goal": 1,
		"hint": "Reach night 12. Appears from night 9.", "hidden": true},
	"paolo": {"type": "member", "ref": "priest", "stat": "chapel_nights_won", "goal": 1,
		"hint": "Survive a night in the Sunken Chapel.", "hidden": true},
	"heavy_support": {"type": "misc", "ref": "heavy_support", "stat": "night_3_won", "goal": 1,
		"hint": "Survive night 3."},
	"warden_helm": {"type": "outfit", "ref": "helm", "stat": "night_4_won", "goal": 1,
		"hint": "Survive night 4."},
	"sage_robes": {"type": "outfit", "ref": "robes", "stat": "night_8_won", "goal": 1,
		"hint": "Survive night 8."},
	"seraph_wings": {"type": "outfit", "ref": "angel", "stat": "night_12_won", "goal": 1,
		"hint": "Survive night 12 and finish a run."},
}

## Caravan members: hired once with Essence (kept in Profile.members), then up
## to CARAVAN_SEATS of them ride along on a run (Run.riders, picked before
## night 1). "icon" is an Icons kind; "role" is the short tag on the card.
## Their abilities are wired up member by member (blueprint: Caravan).
const CARAVAN_SEATS := 2
const TINKER_PARTS := 3  ## Terry, the Tinker: Ashes rolled per free reroll
const LAMP_SHOTS := 8       ## Leopold, the Lamplighter: shots per ring
const LAMP_EVERY := 4.0     ## seconds between rings
const LAMP_DAMAGE := 1.0    ## each shot's damage, as a share of Char's
const LAMP_RANGE := 0.75    ## reach, as a share of the farthest trail start
const LAMP_TURN := PI / 8.0 ## the ring turns this much each volley
const SMITH_FACES := ["torch", "vent", "mortar", "wall"]   ## Simon, the Smith: faces he can forge a "+" onto
const HOUND_SCARES := 1   ## Hella, the Caravan Hound: Wisps she scares off each wave
const PRIEST_RITES := 0.3   ## Paolo, the Priest: Last Rites relight Char to this share of max flame
const COOK_HEAL := 5.0   ## Carson, the Cook: his own heal at each dawn
const CARAVAN := {
	"cook": {"name": "Carson, the Cook", "role": "Sustain", "icon": "cook", "cost": 30,
		"desc": "Serves a hot broth at each dawn: +5 flame."},
	"tinker": {"name": "Terry, the Tinker", "role": "Dice", "icon": "tinker", "cost": 40,
		"desc": "Keeps a part from every Ashes you roll. Every 3 parts make a free reroll next wave."},
	"cat": {"name": "Carl, the Caravan Cat", "role": "Information", "icon": "cat", "cost": 50,
		"desc": "His ears point to the lane the most Wisps will come down each wave."},
	"hound": {"name": "Hella, the Caravan Hound", "role": "Defense", "icon": "hound", "cost": 70,
		"desc": "Scares off the first Wisp to reach the fire each wave, back to the start of a random lane. Bosses ignore her."},
	"lamplighter": {"name": "Leopold, the Lamplighter", "role": "Synergy", "icon": "guide", "cost": 90,
		"desc": "A Lit Lamp beside Char fires a ring of 8 white shots every few seconds."},
	"smith": {"name": "Simon, the Smith", "role": "Power", "icon": "smith", "cost": 120,
		"desc": "Forges one random face on one of your dice into its \"+\" version for the run."},
	## Hidden until his unlock (survive a night in the Sunken Chapel), then for hire.
	"priest": {"name": "Paolo, the Priest", "role": "Rescue", "icon": "censer", "cost": 120, "unlock": "paolo",
		"desc": "Last Rites: once per run, when Char's flame would go out, Paolo relights it to 30%."},
}

## Char's outfits (Caravan > Wardrobe). "swap" recolours the Char SVGs
## (old hex -> new hex, all at once); "bolt" is [core, outer] of his flame bolts.
const FLAME_HEX := ["#fff3c4", "#fffbe8", "#ffd27a", "#ffb238", "#ffa64a", "#ff9a3c", "#ff7a2a", "#ff6a1f", "#d8341c"]
const ARMOR_HEX := ["#857f8f", "#5e5967", "#4a4752", "#2f2d34", "#222027", "#151319"]
const OutfitArt := preload("res://scripts/game/outfit_art.gd")
const OUTFITS := {
	"ember": {"name": "Ember Knight", "cost": 0, "desc": "Char as the fire first made him.",
		"flame": [], "armor": [], "bolt": ["#fff3c4", "#ffb238"]},
	"crimson": {"name": "Crimson Knight", "cost": 60, "desc": "A redder, angrier flame over burnished armor.",
		"flame": ["#ffd8b8", "#ffeadc", "#ffa07a", "#ff6a3a", "#ff5a36", "#ff5030", "#e8341e", "#e02a1a", "#a8101a"],
		"armor": ["#aaa3b4", "#827c8c", "#6c6676", "#4d4a55", "#3a3740", "#26242b"],
		"bolt": ["#ffd8b8", "#ff5a36"]},
	"azure": {"name": "Azure Knight", "cost": 90, "desc": "A cold blue flame in blackened armor.",
		"flame": ["#e4f4ff", "#f4fbff", "#a8e0ff", "#6cc8ff", "#58b8ff", "#4aa8ff", "#2f80f0", "#2a76e8", "#1a4fc0"],
		"armor": ["#5c5766", "#3e3a46", "#302e36", "#1b1a20", "#121116", "#08070a"],
		"bolt": ["#e4f4ff", "#58b8ff"]},
	"silver": {"name": "Silver Knight", "cost": 140, "desc": "A white-hot flame in polished silver.",
		"flame": ["#ffffff", "#ffffff", "#ffffff", "#f2f4ff", "#e8ecff", "#dfe6ff", "#c4cce8", "#c0c8e8", "#98a0c0"],
		"armor": ["#f6f8fb", "#dde2e9", "#b8bec8", "#9aa1ad", "#6a707c", "#4c515c"],
		"bolt": ["#ffffff", "#dfe6ff"]},
	"helm": {"name": "Pyre Warden", "cost": 160, "unlock": "warden_helm",
		"desc": "A great helm in dark iron, trimmed gold and red. Fire pours from the eye slits.",
		"flame": [], "armor": ["#5c5766", "#3e3a46", "#302e36", "#1b1a20", "#121116", "#08070a"],
		"swap": {"#eaa868": "#ffe08a", "#b5652b": "#d4a530", "#5e2c10": "#7a5a1e", "#f4efe6": "#2a2428",
			'fill="url(#flameO)"': 'fill="none"', 'fill="url(#flameM)"': 'fill="none"'},
		"bolt": ["#fff3c4", "#ff7a2a"]},
	"robes": {"name": "Hearth Sage", "cost": 160, "unlock": "sage_robes",
		"desc": "White robes with a gold key hem, a blue mantle and a laurel wreath.",
		"flame": [], "armor": ["#f0c987", "#c8924a", "#b07e3c", "#8a5a26", "#5e3a16", "#3a220c"],
		"swap": {}, "bolt": ["#fffbe8", "#ffd27a"]},
	"angel": {"name": "Seraph Knight", "cost": 220, "unlock": "seraph_wings", "wide": true,
		"desc": "Gleaming armor and white wings whose feathers burn at the tips.",
		"flame": [], "armor": ["#ffffff", "#e8ecf2", "#cdd3dc", "#aab1bd", "#7c8390", "#5a606c"],
		"swap": {"#eaa868": "#fff0b0", "#b5652b": "#e0b040", "#5e2c10": "#8a6420", "#c8262b": "#e0b040"},
		"bolt": ["#fffbe8", "#ffc14a"]},
}


## Char's SVG with an outfit's colours swapped in.
## rigged: leave out parts char_unit.gd draws and moves itself (the wings).
static func outfit_svg(svg: String, id: String, rigged := false) -> String:
	var o: Dictionary = OUTFITS.get(id, OUTFITS["ember"])
	var pairs := []
	for k in o.get("swap", {}):
		pairs.append([k, o["swap"][k]])
	for i in o["flame"].size():
		pairs.append([FLAME_HEX[i], o["flame"][i]])
	for i in o["armor"].size():
		pairs.append([ARMOR_HEX[i], o["armor"][i]])
	for i in pairs.size():
		svg = svg.replace(pairs[i][0], "@%d@" % i)
	for i in pairs.size():
		svg = svg.replace("@%d@" % i, pairs[i][1])
	var back: String = (OutfitArt.RIGGED if rigged and OutfitArt.RIGGED.has(id) else OutfitArt.UNDERLAYS).get(id, "")
	if back != "":
		var at := svg.find("</defs>") + 7
		svg = svg.substr(0, at) + back + svg.substr(at)
	if o.get("wide", false):   # 60 more each side, for wings; still centred on x = 100
		svg = svg.replace('width="160" height="252" viewBox="20 0 160 252"', 'width="280" height="252" viewBox="-40 0 280 252"')
	var extra: String = OutfitArt.OVERLAYS.get(id, "")
	if extra != "":
		var at := svg.rfind("</svg>")
		svg = svg.substr(0, at) + extra + svg.substr(at)
	return svg


## Whether an outfit can be bought yet (some wait on a Milestone).
static func outfit_open(id: String, unlocked: Array) -> bool:
	return not OUTFITS[id].has("unlock") or OUTFITS[id]["unlock"] in unlocked

const GATHERED_FLAME_DIE := "torch"   ## the die Gathered Flame counts
const HEALTHY_NIGHTS_MAX := 4.0  ## Oath of Healthy Nights: cap on the bonus heal
const ASH_BUCKET_HEAL := 1.0     ## Oath of Ash Buckets: flame per unused Ashes
const BANKED_PER_ASH := 0.06     ## Oath of the Banked Fire: + damage per unused Ashes
const BANKED_CAP := 0.30
const SIMPLICITY_DAWN := 3.0     ## Oath of Simplicity: + dawn heal per leg number
const SIMPLICITY_RATE := 1.05    ## ... and Char's fire rate
## Ember Wall, levels 1..3: hp, and burn damage per second to spirits held at it.
const WALL := [{"hp": 40.0, "burn": 2.0}, {"hp": 75.0, "burn": 3.0}, {"hp": 120.0, "burn": 4.5}]
const WALL_BLOCK := 22.0         ## spirits stop this close to a wall
const WALL_CHEW := 0.5           ## wall hp lost per second = spirit damage x this
const WALL_MIN_R := 130.0        ## walls go on trails between these distances from the fire
const WALL_MAX_R := 460.0
const WALL_GAP := 60.0           ## min distance between walls
## Mire (a trail face like the Wall): a mud patch of radius "r"; spirits that
## wade through it are slowed by "slow" for "t" seconds. Lasts the night.
const MIRE := [
	{"r": 42.0, "slow": 0.4, "t": 2.5},
	{"r": 50.0, "slow": 0.48, "t": 3.0},
	{"r": 58.0, "slow": 0.55, "t": 3.5},
]
const LURE_GAP := 40.0   ## Wisp Lantern: a spirit this far behind makes the one ahead slow
const WARM_COALS_BONUS := 2.0    ## Oath of Warm Coals: + Ember Drop heal
const STURDY_WALL := 1.25        ## Oath of Sturdy Stones: Ember Wall hp x
const IMMORTAL_CHANCE := 0.33    ## Oath of the Immortals: chance a Char kill heals
const IMMORTAL_HEAL := 5.0
const CROSSFIRE_MORTAR := 1.0    ## Oath of Crossfire: + Mortar damage
const CROSSFIRE_SCORCH := 2.0    ## ... seconds a Mortar hit scorches a spirit
const CROSSFIRE_TORCH := 1.3     ## ... Torch damage x vs scorched spirits
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
## one (rest of the run). Permanent rewards stack up to PERK_CAP picks each
## (PERK_CAPS overrides that for the strongest).
const LULL_QUICK := 2
const PERK_CAP := 3
const PERK_CAPS := {"steady_hand": 1, "deep_embers": 2, "hearthstones": 2}


static func perk_cap(id: String) -> int:
	return int(PERK_CAPS.get(id, PERK_CAP))
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
const WARD_AT := 0.5       ## Ash Ward pulses when the fire falls to this share of max flame
const WARD_SLOW := 0.5     ## multiplies with other slows
const WARD_TIME := 3.0
const WARD_EXTRA := 1.5    ## seconds per extra Ash Ward on the fire that wave
const URGENCY_RATE := 1.25     ## Oath of Urgency: Char and firing defenses
const URGENCY_DAMAGE := 1.1    ## ...Char damage
const URGENCY_SHARE := 0.5     ## ...share of spirits sped up
const URGENCY_SPEED := 1.3
const ASH_CLOUD_SLOW := 0.5
const DEDICATION_PER_DIE := 0.10   ## Oath of Dedication
const COMEBACK_AT := 0.3    ## below this share of max flame...
const COMEBACK_RATE := 1.3  ## ...Char fires this much faster
const MIN_SPEED := 0.2     ## spirits never drop below this share of their speed
const SLOW_CAP := 0.5   ## no defense slows spirits more than this (honed Vents)
const QUICK_REWARDS := {
	"second_wind": {"name": "Second Wind", "desc": "Heal 15 flame now."},
	"spare_luck": {"name": "Spare Luck", "desc": "+2 rerolls for wave 3."},
	"stoke": {"name": "Stoke", "desc": "Your defenses fire 25% faster in wave 3."},
	"adjustment": {"name": "Adjustment", "desc": "Move one defense to another open tile, for free."},
	"heavy_support": {"name": "Heavy Support Fire", "icon": "mortar",
		"desc": "Wave 3: Char lobs mortar shots. +50% damage, a blast and double range, but slower shots."},
}
## Heavy Support Fire (unlockable lull reward): Char's wave-3 shots become mortar lobs.
const LOCKED_QUICK := ["heavy_support"]
const HEAVY_DAMAGE := 1.5
const HEAVY_RATE := 0.6
const HEAVY_RANGE := 2.0
const HEAVY_SPLASH := 50.0
const PERKS := {
	"hone": {"name": "Hone", "desc": "%s: %s for the rest of the run."},
	"steady_hand": {"name": "Steady Hand", "desc": "+1 reroll every wave for the rest of the run. Once per run."},
	"deep_embers": {"name": "Deep Embers", "desc": "+10 max flame, and heal 10. Up to twice per run."},
	"hearthstones": {"name": "Hearthstones", "desc": "Dawn heals 5 more for the rest of the run. Up to twice per run."},
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
		elif int(perks.get(id, 0)) < perk_cap(id):
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
		if dice_owned.count(id) < MAX_DIE_COPIES and not id in SWAMP_DICE and not id in CHAPEL_DICE and (not id in LOCKED_DICE or Profile.is_unlocked(id)):
			pool.append(id)
	var out := []
	while out.size() < DAWN_DICE and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out

## Dawn after a Swamp Turnpike night: one swamp die (SWAMP_DICE) and one from
## the normal pool.
static func swamp_dawn_dice(rng: RandomNumberGenerator, dice_owned: Array, own: Array = SWAMP_DICE) -> Array:
	var bog := own.filter(func(id): return dice_owned.count(id) < MAX_DIE_COPIES)
	var out := []
	if not bog.is_empty():
		out.append(bog[rng.randi() % bog.size()])
	var rest := dawn_dice(rng, dice_owned)
	if not rest.is_empty():
		out.append(rest[0])
	return out

## Up to DAWN_OATHS unsworn Oaths, each slot rolling a rarity for the dawn
## after night `night_idx` (0-based). If no Oath of the rolled rarity is left,
## the next rarity down is tried, then any.
static func dawn_oaths(rng: RandomNumberGenerator, oaths_owned: Array, night_idx: int) -> Array:
	var left := []
	for id in OATHS:
		if not id in oaths_owned and (not id in LOCKED_OATHS or Profile.is_unlocked(id)):
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
const MAX_REROLLS := 4        ## rerolls a wave starts with, at most (Tinker's free rerolls and Spare Luck add on top)
const FIRE_HEAL_FALLOFF := 0.1   ## each Kindle/Pine heal on the fire after the first in a wave heals 10% less...
const FIRE_HEAL_FLOOR := 0.6     ## ...down to this share
const DAWN_HEAL_MAX := 30.0      ## dawn heal (before the boss bonus and the Cook) never exceeds this
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
		"desc": "A lantern on a pole. Every other defense on its ashy patch reaches farther (Mortars fire closer in too). Doesn't stack."},
	"bellows": {"name": "Bellows", "color": Color("#d9a06a"),
		"desc": "A leather bellows on a frame. Every other defense on its patch attacks faster. Doesn't stack."},
	"brazier": {"name": "Ember Brazier", "color": Color("#ff7a3a"),
		"desc": "An iron bowl of hot coals. Hits from every other defense on its patch leave spirits smouldering. Doesn't stack."},
	"mire": {"name": "Mire", "color": Color("#8a6a3e"),
		"desc": "Spread across a trail like a Wall: spirits wading through it move 40% slower for a few seconds. Lasts the night."},
	"lure": {"name": "Wisp Lantern", "color": Color("#bfe8d8"),
		"desc": "A swamp orb caught in a lantern. Spirits in its light that lead their trail slow down, so the ones behind bunch up on them."},
	"wall": {"name": "Ember Wall", "color": Color("#d9743a"),
		"desc": "Build across a trail: spirits stop and burn through it, scorched by its embers."},
	"pine": {"name": "Pine Log", "color": Color("#c98a4a"),
		"desc": "Place on the fire: heals 3 flame, and every Torch reaches 10% farther this wave."},
	"votive": {"name": "Votive Candles", "color": Color("#ffd98a"),
		"desc": "A stand of chapel candles. Each spirit banished in their glow mends the fire a little (1 / 1.5 / 2 flame). Doesn't stack."},
	"reliquary": {"name": "Reliquary", "color": Color("#e8c66a"),
		"desc": "Place on the fire: a blessed box that soaks up the first 8 / 12 / 16 damage the fire takes this wave."},
	"ward": {"name": "Ash Ward", "color": Color("#b9a8d8"),
		"desc": "Place on the fire. When the fire falls to half flame this wave, it pulses: every spirit 50% slower for 3s (+1.5s per extra Ward)."},
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
	## No attack. Defenses on the other tiles of its group attack "haste"
	## times as often. Several Bellows don't stack: the best one counts.
	## No attack. Hits from defenses on the other tiles of its group set
	## spirits smouldering: "burn_dps" damage a second for "burn_t" seconds
	## (a fresh hit restarts it; the strongest burn counts).
	"brazier": [
		{"range": 0.0, "burn_dps": 1.5, "burn_t": 3.0},
		{"range": 0.0, "burn_dps": 2.25, "burn_t": 3.0},
		{"range": 0.0, "burn_dps": 3.0, "burn_t": 3.0},
	],
	## Wisp Lantern: spirits in range with another spirit in range behind them on
	## their trail (over LURE_GAP back) are slowed by "lure", so packs close up.
	## Votive Candles: spirits banished within "range" heal the fire by "heal".
	"votive": [
		{"range": 150.0, "heal": 1.0},
		{"range": 165.0, "heal": 1.5},
		{"range": 180.0, "heal": 2.0},
	],
	"lure": [
		{"range": 210.0, "lure": 0.3},
		{"range": 225.0, "lure": 0.4},
		{"range": 240.0, "lure": 0.5},
	],
	"bellows": [
		{"range": 0.0, "haste": 1.15},
		{"range": 0.0, "haste": 1.2},
		{"range": 0.0, "haste": 1.25},
	],
}
## Guide Light boosts every other defense in its group: three neighbouring
## tiles on one ashy patch (board.tile_group).

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
	## Swamp Turnpike only: a slow Wisp in a muddy brown aura, a faint skull in its
	## light. When banished it may haul itself back up out of the mud (revive_chance),
	## lie still for revive_time, then go on at revive_hp of its health and
	## revive_speed of its pace. Each one banished pays MUD_ESSENCE.
	"mud_wisp": {"hp": 20.0, "speed": 38.0, "damage": 8.0, "size": 1.0, "color": Color("#d9cdb4"),
		"glow": Color("#8a5a2c"), "revive_chance": 0.25, "revive_time": 1.2, "revive_hp": 0.5, "revive_speed": 0.7},
	## Sunken Chapel only: a pale bronze Wisp with a little bell hanging under it.
	## Every ring_every seconds it tolls: other spirits within ring_range are
	## hastened by haste for haste_time. Banish it first.
	"bellringer": {"hp": 28.0, "speed": 40.0, "damage": 8.0, "size": 1.05, "color": Color("#f0e2b6"),
		"glow": Color("#c99a3a"), "ring_every": 3.5, "ring_range": 120.0, "haste": 0.35, "haste_time": 2.5},
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
## Faces that boost the rest of their tile group instead of attacking.
const SUPPORT_FACES := ["guide", "bellows", "brazier"]
const WAKE_RANGE := 140.0   ## Oath of the Ember Wake: how far a burn jumps
const FORGE_CHAR_RATE := 0.06   ## Oath of the Roaring Forge: Char's rate per Bellows
const FORGE_MAX_BELLOWS := 4    ## ...counting at most this many (+24%)
const WAKE_MAX_JUMPS := 3       ## Oath of the Ember Wake: jumps per burn chain


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
	"swamp": {"name": "Swamp Turnpike", "desc": "A causeway through the bog. 3-4 trails wade murky pools under dead trees. Tougher spirits and Mud Wisps, richer spoils: double Essence.",
		"icon": "swamp", "unlock": "swamp", "min_night": 4},
	"chapel": {"name": "Sunken Chapel", "desc": "A ruined chapel half sunk in the earth. 3-5 aisles between broken pews and a shattered altar. Tougher spirits and Bellringers; double Essence and a stronger dawn heal.",
		"icon": "altar", "unlock": "chapel", "min_night": 8},
}
## Quiet Lakeside: a lake fills one side, its near shore this far from the fire.
## Spirits crossing the water drift slower. 2-3 land trails + 1 water crossing.
const LAKE_SHORE := 235.0
const LAKE_RX := 380.0
const LAKE_RY := 330.0
const LAKE_WATER_SPEED := 0.6
const LAKE_FOUR_LANE_CHANCE := 0.5
## Swamp Turnpike: murky pools (trails wade through, no tiles), dead trees,
## faint drifting orbs. Offered from night 5 once unlocked; spirits are
## tougher, but the night pays double Essence (and +1 per Mud Wisp banished).
const RELIQUARY := [8.0, 12.0, 16.0]   ## fire damage a Reliquary soaks up, by level
const PINE_PLUS_HEAL := 0.5      ## Pine Log+: heals this much more per extra level
const CHAPEL_HP := 1.2          ## Sunken Chapel: spirits a bit tougher than the swamp's
const CHAPEL_ESSENCE := 2        ## dawn Essence multiplier at the chapel
const BELL_ESSENCE := 2          ## Essence for each Bellringer banished
const CHAPEL_DAWN_HEAL := 8.0    ## extra dawn heal after a chapel night
const SWAMP_HP := 1.15
const SWAMP_ESSENCE := 2
const CHAPEL_BELL_CHANCE := 0.15   ## share of plain Wisps that come as Bellringers
const CHAPEL_BELL_MAX := 2          ## at most this many in one wave
const SWAMP_MUD_CHANCE := 0.35   ## share of plain Wisps that come as Mud Wisps
const MUD_ESSENCE := 1           ## Essence for each Mud Wisp banished
const SWAMP_POOLS_MIN := 1
const SWAMP_POOLS_MAX := 3
const SWAMP_ORBS := 5
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

## Abandoned Stagecoach: at most once per run. Searching it turns up one random
## die (from the dawn pool); taking it means its lost passengers follow you:
## every wave tonight brings this many extra Wisps.
const COACH_CHANCE := 0.25
const COACH_HAUNT_SPIRITS := 2


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


## Ramp for one wave: wave 1 opens partway back toward the night before and
## each wave climbs to the full night, so a night's jump is spread over its
## waves. Never above the night (a new leg's step down stays a step down).
const WAVE_RAMP_FROM := 0.5

static func wave_step(night: int, wave: int) -> float:
	var cur := night_step(night)
	if night <= 0:
		return cur
	var prev := minf(night_step(night - 1), cur)
	var t := WAVE_RAMP_FROM + (1.0 - WAVE_RAMP_FROM) * float(wave) / float(WAVES_PER_NIGHT - 1)
	return lerpf(prev, cur, t)


## Spawn list for one wave: Array of spirit kinds. night/wave are 0-based.
static func wave_spirits(night: int, wave: int, stop: String, rng: RandomNumberGenerator, boss_id := "dark_wisp") -> Array:
	var count := floori(5 + wave_step(night, wave) * 2 + wave * 1 + 0.000001)
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
	if stop == "swamp":   # the bog's own: Mud Wisps take some of the plain Wisps' places
		for i in out.size():
			if out[i] == "wisp" and rng.randf() < SWAMP_MUD_CHANCE:
				out[i] = "mud_wisp"
	if stop == "chapel":   # the chapel's own: a Bellringer or two among the Wisps
		var bells := 0
		for i in out.size():
			if bells < CHAPEL_BELL_MAX and out[i] == "wisp" and rng.randf() < CHAPEL_BELL_CHANCE:
				out[i] = "bellringer"
				bells += 1
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
const SPAWN_GAP_PER_NIGHT := 0.06
const SPAWN_GAP_PER_WAVE := 0.14
const SPAWN_GAP_MIN := 0.55

static func spawn_gap(night: int, wave: int) -> float:
	return maxf(SPAWN_GAP_MIN, SPAWN_GAP - SPAWN_GAP_PER_NIGHT * wave_step(night, wave) - SPAWN_GAP_PER_WAVE * wave)


## Does this stop's map get forks (and so gates)? Set "forks": false on a stop to drop them.
static func has_forks(stop: String) -> bool:
	return STOPS.get(stop, {}).get("forks", true)


static func spirit_hp_scale(night: int, stop: String) -> float:
	var s := 1.0 + 0.15 * night_step(night)
	if stop == "swamp":
		s *= SWAMP_HP
	elif stop == "chapel":
		s *= CHAPEL_HP
	return s
