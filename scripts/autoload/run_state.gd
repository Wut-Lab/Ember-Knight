extends Node
## The current run: which night it is, Char's flame, chosen stops,
## plus a few stats for the end screen. Autoloaded as `Run`.

const Defs := preload("res://scripts/game/defs.gd")

var night := 0                 ## 0-based; Defs.NIGHTS nights per run
var flame := Defs.MAX_FLAME
var max_flame := Defs.MAX_FLAME
var pool: Array = []           ## die kinds owned this run (Defs.DICE ids, repeats allowed)
var loadout: Array = []        ## die kinds in tonight's slots (Defs.LOADOUT_SIZE)
var dice: Array = []           ## tonight's dice as face lists, built from the loadout
var oaths: Array = []          ## Defs.OATHS ids sworn this run
var stop_options: Array = []   ## per night: the stop_ids on offer
var chosen_stops: Array[String] = []
var spirits_banished := 0
var bonus_rerolls := 0         ## extra rerolls every wave (Ember Shrine)
var shrine_seen := false       ## the Ember Shrine shows up once per run
var gates := 1                ## gates Char can cobble tonight (Defs.GATES_FREE, +1 per traded slot)
var shrine_curse := false      ## tonight's spirits are tougher (Ember Shrine)
var nights_survived := 0
var rng := RandomNumberGenerator.new()
## `-- --autoplay`: the game plays itself (for previews and balance checks).
## `-- --autoplay --quit-at-end` also prints the result and quits.
var autoplay := "--autoplay" in OS.get_cmdline_user_args()


func new_run() -> void:
	rng.randomize()
	night = 0
	max_flame = Defs.MAX_FLAME
	flame = max_flame
	pool.clear()
	for i in Defs.STARTING_DICE:
		pool.append("ember")
	loadout = pool.duplicate()
	apply_loadout()
	oaths.clear()
	chosen_stops.clear()
	spirits_banished = 0
	nights_survived = 0
	bonus_rerolls = 0
	gates = Defs.GATES_FREE
	shrine_seen = false
	shrine_curse = false
	stop_options.clear()
	for n in Defs.NIGHTS:
		stop_options.append(Defs.STOPS.keys())




## Builds tonight's dice from the loadout.
func apply_loadout() -> void:
	dice.clear()
	for id in loadout:
		dice.append(Array(Defs.DICE[id]["faces"]).duplicate())


func owned(id: String) -> int:
	return pool.count(id)


func has_oath(id: String) -> bool:
	return id in oaths


## Flame healed by one Kindle die (Hearth-Bound adds to it).
func kindle_heal() -> float:
	return Defs.KINDLE_HEAL + (Defs.HEARTH_KINDLE_BONUS if has_oath("hearth_bound") else 0.0)


## Flame healed at dawn (Hearth-Bound takes from it).
func dawn_heal() -> float:
	return Defs.DAWN_HEAL - (Defs.HEARTH_DAWN_PENALTY if has_oath("hearth_bound") else 0.0)


func current_stop() -> String:
	return chosen_stops[night] if night < chosen_stops.size() else "road"


# ------------------------------------------------------------ saving
## A run is saved as it stood at the camp choice of the current night, so
## Save and Quit mid-battle resumes at that night's camp choice.
const SAVE_PATH := "user://run.save"
const SAVE_KEYS := ["night", "flame", "max_flame", "stop_options", "chosen_stops",
	"spirits_banished", "nights_survived"]
## Newer keys: older saves load without them.
const EXTRA_KEYS := ["bonus_rerolls", "shrine_seen", "gates"]

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
	for k in EXTRA_KEYS:
		_checkpoint[k] = get(k)
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
	bonus_rerolls = int(d.get("bonus_rerolls", 0))
	shrine_seen = bool(d.get("shrine_seen", false))
	shrine_curse = false
	if d.has("rng_seed") and d.has("rng_state"):
		rng.seed = int(d["rng_seed"])
		rng.state = int(d["rng_state"])
	checkpoint()
	return true


func clear_save() -> void:
	_checkpoint = {}
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
