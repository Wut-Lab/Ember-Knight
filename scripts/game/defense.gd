extends Node2D
## A defense built from a die on a tile. Placing another die with the same
## face on it raises its level (max Defs.MAX_LEVEL).
##
## No defense kinds exist yet. To add one:
##   1. Add its stats to Defs.DEFENSES and its face to Defs.DIE_FACES / FACE_INFO.
##   2. Add its behaviour to _act() and its look to _draw_kind() below.
## Helpers on the battle: pick_target(world, range), shoot(...),
## spirits_in_range(world, range), ring_fx(...). A "slow" stat is applied by the
## battle automatically.

const Defs := preload("res://scripts/game/defs.gd")

var kind := ""
var level := 1
var tile := -1
var world := Vector2.ZERO
var battle            ## the Battle node (targets, projectiles, passives)
var board

var _cool := 0.0
var _t := 0.0
var _pop := 0.0        ## build / level-up bounce


func setup(b, bd, k: String, tile_idx: int) -> void:
	battle = b
	board = bd
	kind = k
	tile = tile_idx
	world = board.tiles[tile_idx]
	position = board.proj(world)
	_pop = 1.0
	_cool = randf_range(0.1, 0.5)


func level_up() -> void:
	level = mini(level + 1, Defs.MAX_LEVEL)
	_pop = 1.0


## This defense's stats at its current level (passives can adjust them here).
func stats() -> Dictionary:
	return Defs.DEFENSES[kind][level - 1].duplicate()


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 3.0)
	queue_redraw()
	if battle.fighting:
		_act(delta, stats())


## Per-kind behaviour while a wave is on.
func _act(_delta: float, _st: Dictionary) -> void:
	match kind:
		_:
			pass


func _scale() -> float:
	return (0.9 + 0.12 * level) * (1.0 + 0.25 * sin(_pop * PI))


func _draw() -> void:
	var v: float = board.view_scale * _scale()
	var lit: float = maxf(board.light_at(world), 0.4)
	_draw_kind(v, lit)
	# Level pips on the slab.
	for i in level:
		var x: float = (i - (level - 1) / 2.0) * 10.0 * board.view_scale
		draw_circle(Vector2(x, 12.0 * board.view_scale), 3.2 * board.view_scale, Color("#ffb238"))


## Per-kind look. Until a kind has art, it shows as a plain marker post.
func _draw_kind(v: float, lit: float) -> void:
	match kind:
		_:
			var wood := Color("#3b2416").lerp(Color("#8b5a3a"), lit)
			draw_rect(Rect2(-4 * v, -40 * v, 8 * v, 42 * v), wood)
