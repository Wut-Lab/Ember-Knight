extends Node
## The current run: which night it is, Char's flame, chosen stops and
## passives, plus a few stats for the end screen. Autoloaded as `Run`.

const Defs := preload("res://scripts/game/defs.gd")

var night := 0                 ## 0-based; Defs.NIGHTS nights per run
var flame := Defs.MAX_FLAME
var max_flame := Defs.MAX_FLAME
var passives: Array[String] = []
var stop_options: Array = []   ## per night: [stop_id, stop_id]
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
	passives.clear()
	chosen_stops.clear()
	spirits_banished = 0
	nights_survived = 0
	stop_options.clear()
	var ids: Array = Defs.STOPS.keys()
	for n in Defs.NIGHTS:
		var pool := ids.duplicate()
		pool.shuffle()
		stop_options.append([pool[0], pool[1]])


func has(passive: String) -> bool:
	return passive in passives


func current_stop() -> String:
	return chosen_stops[night] if night < chosen_stops.size() else "road"


func add_passive(id: String) -> void:
	passives.append(id)
	if id == "copper_plating":
		max_flame += 30.0
		flame = max_flame


## Two (or three, after a Haunted Hollow) passives not yet taken.
func passive_offer() -> Array:
	var pool: Array = []
	for id in Defs.PASSIVES.keys():
		if not has(id):
			pool.append(id)
	pool.shuffle()
	var n := 3 if current_stop() == "hollow" else 2
	return pool.slice(0, mini(n, pool.size()))
