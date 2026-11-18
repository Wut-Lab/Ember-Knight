extends Node
## The current run: which night it is, Char's flame, chosen stops,
## plus a few stats for the end screen. Autoloaded as `Run`.

const Defs := preload("res://scripts/game/defs.gd")

var night := 0                 ## 0-based; Defs.NIGHTS nights per run
var flame := Defs.MAX_FLAME
var max_flame := Defs.MAX_FLAME
var defenses: Array[String] = []  ## defense kinds owned this run
var stop_options: Array = []   ## per night: the stop_ids on offer
var chosen_stops: Array[String] = []
var spirits_banished := 0
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
	defenses.assign(Defs.STARTING_DEFENSES)
	chosen_stops.clear()
	spirits_banished = 0
	nights_survived = 0
	stop_options.clear()
	for n in Defs.NIGHTS:
		stop_options.append(Defs.STOPS.keys())


## Faces the dice can roll: Kindle plus every owned defense.
func die_faces() -> Array:
	return ["kindle"] + defenses


func current_stop() -> String:
	return chosen_stops[night] if night < chosen_stops.size() else "road"


# ------------------------------------------------------------ saving
## A run is saved as it stood at the camp choice of the current night, so
## Save and Quit mid-battle resumes at that night's camp choice.
const SAVE_PATH := "user://run.save"
const SAVE_KEYS := ["night", "flame", "max_flame", "stop_options", "chosen_stops",
	"spirits_banished", "nights_survived"]

var resume := false   ## set by the menu's Continue; read by the run screen
var _checkpoint := {}


## Called when the camp choice for a night is shown.
func checkpoint() -> void:
	_checkpoint = {}
	for k in SAVE_KEYS:
		_checkpoint[k] = get(k).duplicate() if get(k) is Array else get(k)
	_checkpoint["defenses"] = defenses.duplicate()


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
	defenses.assign(d.get("defenses", Defs.STARTING_DEFENSES))  # older saves lack it
	checkpoint()
	return true


func clear_save() -> void:
	_checkpoint = {}
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
