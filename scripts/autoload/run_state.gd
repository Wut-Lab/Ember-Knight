extends Node
## The current run: which night it is, Char's flame, chosen stops,
## plus a few stats for the end screen. Autoloaded as `Run`.

const Defs := preload("res://scripts/game/defs.gd")

var night := 0                 ## 0-based; Defs.NIGHTS nights per run
var flame := Defs.MAX_FLAME
var max_flame := Defs.MAX_FLAME
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
	chosen_stops.clear()
	spirits_banished = 0
	nights_survived = 0
	stop_options.clear()
	for n in Defs.NIGHTS:
		stop_options.append(Defs.STOPS.keys())


func current_stop() -> String:
	return chosen_stops[night] if night < chosen_stops.size() else "road"
