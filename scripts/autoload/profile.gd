extends Node
## What the player keeps between runs: Essence, unlocks (Defs.UNLOCKS ids) and
## the stats that unlock them. Saved to disk whenever it changes. Autoloaded
## as `Profile`.

signal essence_changed(total: int, gained: int)
signal unlocked(id: String)

const Defs := preload("res://scripts/game/defs.gd")
const SAVE_PATH := "user://profile.save"

var essence := 0
var unlocks: Array = []      ## Defs.UNLOCKS ids earned
var stats := {}             ## stat name -> count, for unlock progress
var members: Array = []     ## Defs.CARAVAN ids hired
var riders: Array = []      ## last run's riders, offered again next run


func _ready() -> void:
	_load()


func add_essence(n: int) -> void:
	if n <= 0:
		return
	essence += n
	_save()
	essence_changed.emit(essence, n)


## Spends n Essence if there is enough; returns whether it did.
func spend_essence(n: int) -> bool:
	if essence < n:
		return false
	essence -= n
	_save()
	essence_changed.emit(essence, 0)
	return true


## Hires a caravan member if there is enough Essence; returns whether it did.
func hire(id: String) -> bool:
	if id in members or not Defs.CARAVAN.has(id):
		return false
	if not spend_essence(int(Defs.CARAVAN[id]["cost"])):
		return false
	members.append(id)
	_save()
	return true


func set_riders(ids: Array) -> void:
	riders = ids.duplicate()
	_save()


func is_unlocked(id: String) -> bool:
	return id in unlocks


func stat(name: String) -> int:
	return int(stats.get(name, 0))


## Counts toward a stat, then unlocks anything whose goal it now meets.
func add_stat(name: String, n := 1) -> void:
	stats[name] = stat(name) + n
	for id in Defs.UNLOCKS:
		var u: Dictionary = Defs.UNLOCKS[id]
		if u.get("stat", "") == name and stat(name) >= int(u["goal"]) and not id in unlocks:
			unlocks.append(id)
			unlocked.emit(id)
	_save()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"essence": essence, "unlocks": unlocks, "stats": stats,
			"members": members, "riders": riders}))


func _load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		essence = int(d.get("essence", 0))
		unlocks = Array(d.get("unlocks", []))
		stats = d.get("stats", {})
		members = Array(d.get("members", []))
		riders = Array(d.get("riders", []))
