extends Node
## The current run: which night it is, Char's flame, chosen stops,
## plus a few stats for the end screen. Autoloaded as `Run`.

const Defs := preload("res://scripts/game/defs.gd")

var night := 0                 ## 0-based; Defs.NIGHTS nights per run
var flame := Defs.MAX_FLAME
var max_flame := Defs.MAX_FLAME
var pool: Array = []           ## die kinds owned this run (Defs.DICE ids, repeats allowed)
var loadout: Array = []        ## die kinds in tonight's slots (Defs.LOADOUT_SIZE)
var forged: Array = []         ## Simon, the Smith: [die id, face index] forged "+" this run
var dice: Array = []           ## tonight's dice as face lists, built from the loadout
var oaths: Array = []          ## Defs.OATHS ids sworn this run
var stop_options: Array = []   ## per night: the stop_ids on offer
var chosen_stops: Array[String] = []
var spirits_banished := 0
var bonus_rerolls := 0         ## extra rerolls every wave (Ember Shrine)
var shrine_seen := false       ## the Ember Shrine shows up once per run
var gates := 1                ## gates Char can cobble tonight (Defs.GATES_FREE, +1 per traded slot)
var layout_seed := 0           ## tonight's battle map, rolled when the stop is chosen
var shrine_curse := false      ## tonight's spirits are tougher (Ember Shrine)
var nights_survived := 0
var bosses: Array = []         ## boss id per leg (Defs.roll_bosses), rolled at the start of a run
var perks: Dictionary = {}       ## lull permanent rewards: id (or "hone_<kind>") -> times picked
var night_flames: Array = []   ## flame left at the end of each night cleared
var riders: Array = []         ## Defs.CARAVAN ids riding along this run
var cook_healed := 0.0        ## flame the Cook actually healed this dawn (for the dawn screen)
var spare_parts := 0           ## Terry, the Tinker: parts banked toward the next free reroll
var riders_picked := false     ## the seat pick has been made this run
var rng := RandomNumberGenerator.new()
## `-- --autoplay`: the game plays itself (for previews and balance checks).
## `-- --autoplay --quit-at-end` also prints the result and quits.
var test_stop := ""   ## --stop=<id>: every night uses this map (testing)
var autoplay := "--autoplay" in OS.get_cmdline_user_args()
## `-- --autoplay --speed=6` runs battles faster (balance checks only).
var test_speed := 1.0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stop="):   # test: force every camp to this map
			test_stop = arg.trim_prefix("--stop=")
		if arg.begins_with("--speed="):
			test_speed = maxf(1.0, arg.trim_prefix("--speed=").to_float())


func new_run() -> void:
	rng.randomize()
	night = 0
	max_flame = Defs.MAX_FLAME
	flame = max_flame
	pool.clear()
	for i in Defs.STARTING_DICE:
		pool.append("ember")
	for arg in OS.get_cmdline_user_args():   # `-- --dice=a,b`: start with these dice instead (tests)
		if arg.begins_with("--dice="):
			pool.assign(arg.trim_prefix("--dice=").split(",", false))
	loadout = pool.duplicate()
	apply_loadout()
	oaths.clear()
	for arg in OS.get_cmdline_user_args():   # `-- --oaths=a,b`: start sworn to these (tests)
		if arg.begins_with("--oaths="):
			oaths.append_array(arg.trim_prefix("--oaths=").split(",", false))
	chosen_stops.clear()
	spirits_banished = 0
	nights_survived = 0
	night_flames.clear()
	bonus_rerolls = 0
	perks = {}
	bosses = Defs.roll_bosses(rng)
	riders.clear()
	riders_picked = false
	spare_parts = 0
	forged = []
	gates = Defs.GATES_FREE
	shrine_seen = false
	shrine_curse = false
	stop_options.clear()
	for n in Defs.NIGHTS:
		stop_options.append(roll_stop_options())




## Builds tonight's dice from the loadout.
func apply_loadout() -> void:
	dice.clear()
	for id in loadout:
		dice.append(Array(Defs.DICE[id]["faces"]).duplicate())
	_apply_forge()


## Simon, the Smith: one random face on one of the run's dice gets a "+".
## Picked once; picked again only if that die leaves the loadout.
func _apply_forge() -> void:
	if not has_rider("smith"):
		return
	if forged.size() != 2 or not forged[0] in loadout or not _forgeable(Defs.DICE[forged[0]]["faces"][int(forged[1])]):
		var options := []
		for id in loadout:
			var faces: Array = Defs.DICE[id]["faces"]
			for j in faces.size():
				if _forgeable(faces[j]) and not [id, j] in options:
					options.append([id, j])
		if options.is_empty():
			forged = []
			return
		forged = options[rng.randi() % options.size()]
	var k: int = loadout.find(forged[0])
	dice[k][int(forged[1])] += "+"


static func _forgeable(f: String) -> bool:
	return Defs.base_face(f) in Defs.SMITH_FACES and Defs.face_levels(f) < 3


## "Torch+ on an Ember Die", for the hint.
func forge_text() -> String:
	if forged.size() != 2:
		return ""
	var f: String = Defs.DICE[forged[0]]["faces"][int(forged[1])] + "+"
	var die: String = Defs.DICE[forged[0]]["name"]
	return "%s%s on %s %s" % [Defs.FACE_INFO[Defs.base_face(f)]["name"], "+".repeat(Defs.face_levels(f) - 1),
		"an" if die[0] in "AEIOU" else "a", die]


func owned(id: String) -> int:
	return pool.count(id)


func has_rider(id: String) -> bool:
	return id in riders


## Carson, the Cook: his own dawn heal, kept apart from dawn_heal() so it
## can be tuned (and boosted) on its own.
func cook_heal() -> float:
	return Defs.COOK_HEAL if has_rider("cook") else 0.0


func has_oath(id: String) -> bool:
	return id in oaths


## Sum of one face_mods stat across all sworn Oaths (0 if none).
func face_mod(face: String, stat: String) -> float:
	var total := 0.0
	for id in oaths:
		var fm: Dictionary = Defs.OATHS.get(id, {}).get("face_mods", {})
		total += float(fm.get(face, {}).get(stat, 0.0))
	if Defs.HONE.has(face):   # lull reward: Hone
		total += float(Defs.HONE[face].get(stat, 0.0)) * int(perks.get("hone_" + face, 0))
	return total


## The boss of the leg this 0-based night is in.
func boss_for(n: int) -> String:
	var leg := Defs.leg_of(n)
	return bosses[leg] if leg < bosses.size() else Defs.BOSSES[0]


func perk(id: String) -> int:
	return int(perks.get(id, 0))


## Applies a lull's permanent reward ({"id", "kind"}).
func take_perk(o: Dictionary) -> void:
	var key: String = "hone_" + o["kind"] if o["id"] == "hone" else o["id"]
	perks[key] = perk(key) + 1
	match o["id"]:
		"steady_hand":
			bonus_rerolls += 1
		"deep_embers":
			max_flame += Defs.DEEP_EMBERS_FLAME
			flame = minf(max_flame, flame + Defs.DEEP_EMBERS_FLAME)


## Flame healed by one Kindle die (Hearth-Bound adds to it).
func kindle_heal() -> float:
	return (Defs.KINDLE_HEAL + (Defs.HEARTH_KINDLE_BONUS if has_oath("hearth_bound") else 0.0) + healthy_bonus()) * (1.0 + dedication("kindle"))


## Flame healed by one Pine Log.
func pine_heal() -> float:
	return (Defs.PINE_HEAL + healthy_bonus()) * (1.0 + dedication("pine"))


## Oath of Dedication: the bonus share for a base face (0 unless it is the
## face found on the most of tonight's dice; ties go to the earlier die).
func dedication(face: String) -> float:
	if not has_oath("dedication"):
		return 0.0
	var counts := {}
	var order := []
	for faces in dice:
		var seen := []
		for f in faces:
			var b := Defs.base_face(f)
			if b != "ashes" and not b in seen:
				seen.append(b)
				counts[b] = counts.get(b, 0) + 1
				if not b in order:
					order.append(b)
	var best := ""
	for b in order:
		if best == "" or counts[b] > counts[best]:
			best = b
	return Defs.DEDICATION_PER_DIE * counts[best] if best == face else 0.0


## Oath of Healthy Nights: +1 per two nights passed, between 1 and the cap.
func healthy_bonus() -> float:
	if not has_oath("healthy_nights"):
		return 0.0
	return clampf(floorf(night / 2.0), 1.0, Defs.HEALTHY_NIGHTS_MAX)


## Flame healed at dawn (Hearth-Bound takes from it).
func dawn_heal() -> float:
	return Defs.DAWN_HEAL - (Defs.HEARTH_DAWN_PENALTY if has_oath("hearth_bound") else 0.0) \
		+ Defs.HEARTHSTONE_HEAL * perk("hearthstones") \
		+ (Defs.SIMPLICITY_DAWN * (Defs.leg_of(night) + 1) if has_oath("simplicity") else 0.0)


## 2-3 camps drawn at random from the pool of stops (Defs.STOPS).
func roll_stop_options() -> Array:
	var ids: Array = Defs.STOPS.keys().filter(func(id):
		var S: Dictionary = Defs.STOPS[id]
		return night >= int(S.get("min_night", 0)) and (not S.has("unlock") or Profile.is_unlocked(S["unlock"])))
	for i in range(ids.size() - 1, 0, -1):   # shuffle with the run's RNG
		var j := rng.randi_range(0, i)
		var t = ids[i]; ids[i] = ids[j]; ids[j] = t
	var n := mini(ids.size(), rng.randi_range(Defs.STOP_CHOICES_MIN, Defs.STOP_CHOICES_MAX))
	return ids.slice(0, n)


func current_stop() -> String:
	if test_stop != "":
		return test_stop
	return chosen_stops[night] if night < chosen_stops.size() else "road"


# ------------------------------------------------------------ saving
## A run is saved as it stood at the camp choice of the current night, so
## Save and Quit mid-battle resumes at that night's camp choice.
const SAVE_PATH := "user://run.save"
const SAVE_KEYS := ["night", "flame", "max_flame", "stop_options", "chosen_stops",
	"spirits_banished", "nights_survived"]
## Newer keys: older saves load without them.
const EXTRA_KEYS := ["bonus_rerolls", "shrine_seen", "gates", "spare_parts", "forged"]

var resume := false   ## set by the menu's Continue; read by the run screen
var _checkpoint := {}


## Called when the camp choice for a night is shown.
func checkpoint() -> void:
	_checkpoint = {}
	for k in SAVE_KEYS:
		_checkpoint[k] = get(k).duplicate() if get(k) is Array else get(k)
	_checkpoint["pool"] = pool.duplicate()
	_checkpoint["loadout"] = loadout.duplicate()
	_checkpoint["oaths"] = oaths.duplicate()
	_checkpoint["perks"] = perks.duplicate()
	_checkpoint["bosses"] = bosses.duplicate()
	_checkpoint["night_flames"] = night_flames.duplicate()
	_checkpoint["riders"] = riders.duplicate()
	for k in EXTRA_KEYS:
		_checkpoint[k] = get(k).duplicate() if get(k) is Array else get(k)
	# The RNG is saved too, so Save and Quit can't reroll anything (fog, ambush,
	# wave modifiers, spawns, dice). Strings: JSON would round 64-bit ints.
	_checkpoint["rng_seed"] = str(rng.seed)
	_checkpoint["rng_state"] = str(rng.state)


func save_run() -> void:
	if _checkpoint.is_empty():
		checkpoint()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_checkpoint))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_run() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return false
	for k in SAVE_KEYS:
		if not d.has(k):
			return false
	night = int(d["night"])
	flame = float(d["flame"])
	max_flame = float(d["max_flame"])
	stop_options = d["stop_options"]
	while stop_options.size() < Defs.NIGHTS:   # saves from shorter runs
		stop_options.append(roll_stop_options())
	chosen_stops.assign(d["chosen_stops"])
	spirits_banished = int(d["spirits_banished"])
	nights_survived = int(d["nights_survived"])
	pool.clear()
	for id in d.get("pool", []):  # older saves have no pool: use the starter set
		if Defs.DICE.has(id):
			pool.append(id)
	if pool.size() < Defs.LOADOUT_SIZE:
		pool.clear()
		for i in Defs.STARTING_DICE:
			pool.append("ember")
	loadout = Array(d.get("loadout", pool.slice(0, Defs.LOADOUT_SIZE)))
	apply_loadout()
	oaths = Array(d.get("oaths", []))
	night_flames = Array(d.get("night_flames", []))
	bonus_rerolls = int(d.get("bonus_rerolls", 0))
	perks = Dictionary(d.get("perks", {}))
	bosses = Array(d.get("bosses", []))
	riders = Array(d.get("riders", []))
	spare_parts = int(d.get("spare_parts", 0))
	forged = Array(d.get("forged", []))
	apply_loadout()   # again, now riders and the Smith's forge are known
	riders_picked = true
	shrine_seen = bool(d.get("shrine_seen", false))
	shrine_curse = false
	if d.has("rng_seed") and d.has("rng_state"):
		rng.seed = int(d["rng_seed"])
		rng.state = int(d["rng_state"])
	if bosses.size() < Defs.LEGS:   # saves from before the boss pool
		bosses = Defs.roll_bosses(rng)
	checkpoint()
	return true


func clear_save() -> void:
	_checkpoint = {}
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
