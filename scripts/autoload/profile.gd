extends Node
## What the player keeps between runs (for now just Essence). Saved to disk
## whenever it changes. Autoloaded as `Profile`.

signal essence_changed(total: int, gained: int)

const SAVE_PATH := "user://profile.save"

var essence := 0


func _ready() -> void:
	_load()


func add_essence(n: int) -> void:
	if n <= 0:
		return
	essence += n
	_save()
	essence_changed.emit(essence, n)


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"essence": essence}))


func _load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		essence = int(d.get("essence", 0))
