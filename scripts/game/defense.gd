extends Node2D
## A defense built from a die on a tile. Placing another die with the same
## face on it raises its level (max Defs.MAX_LEVEL).
##
## To add a defense kind:
##   1. Add its stats to Defs.DEFENSES and its face to Defs.DIE_FACES / FACE_INFO,
##      then put the face on a die (Defs.STARTER_DIE or a new die).
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
var _puff := 0.0       ## steam vent: 1 right after a puff, fades to 0


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
	_puff = maxf(0.0, _puff - delta * 1.5)
	queue_redraw()
	if battle.fighting:
		_act(delta, stats())


## Per-kind behaviour while a wave is on.
func _act(delta: float, st: Dictionary) -> void:
	match kind:
		"torch":
			_cool -= delta
			if _cool <= 0.0:
				var target = battle.pick_target(world, st["range"])
				if target:
					battle.shoot(world, Vector2(0, -46.0 * board.view_scale * _scale()), target, st["damage"], "torch")
					_cool = 1.0 / st["rate"]
		"vent":
			_cool -= delta
			if _cool <= 0.0:
				var near: Array = battle.spirits_in_range(world, st["range"])
				if not near.is_empty():
					for sp in near:
						sp.hit(st["damage"])
					battle.ring_fx(world, st["range"], Color("#cfeee9"))
					_puff = 1.0
					_cool = 1.0 / st["rate"]


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
	var wood := Color("#3b2416").lerp(Color("#8b5a3a"), lit)
	match kind:
		"torch":
			# Post, iron cup and a flickering flame that grows with level.
			draw_rect(Rect2(-3.5 * v, -36 * v, 7 * v, 38 * v), wood)
			draw_rect(Rect2(-7 * v, -40 * v, 14 * v, 5 * v), Color("#4a4038"))
			var f := 1.0 + 0.08 * sin(_t * 11.0) + 0.05 * sin(_t * 17.0)
			var h := (12.0 + 3.0 * level) * v * f
			var sway := 1.5 * v * sin(_t * 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-6 * v, -40 * v), Vector2(sway, -40 * v - h * 1.6), Vector2(6 * v, -40 * v)]), Color("#ff7a1e"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3 * v, -40 * v), Vector2(sway * 0.6, -40 * v - h), Vector2(3 * v, -40 * v)]), Color("#ffe27a"))
		"vent":
			# Brass boiler with a pressure gauge and a chimney; steam after a puff.
			var brass := Color("#5a4220").lerp(Color("#c9973f"), lit)
			draw_rect(Rect2(-11 * v, -26 * v, 22 * v, 28 * v), brass)
			draw_rect(Rect2(-11 * v, -28 * v, 22 * v, 3 * v), brass.darkened(0.3))
			draw_rect(Rect2(3 * v, -42 * v, 6 * v, 15 * v), Color("#4a4038"))
			draw_circle(Vector2(-3 * v, -13 * v), 5 * v, Color("#e8e2d0"))
			var a := -PI * 0.75 + PI * 1.5 * (0.3 + 0.7 * _puff)
			draw_line(Vector2(-3 * v, -13 * v), Vector2(-3 * v, -13 * v) + Vector2.from_angle(a) * 4 * v, Color("#a02a1a"), 1.2 * v)
			for k in 3:
				var age := fmod(_t * 0.6 + k / 3.0, 1.0)
				var alpha := 0.15 + 0.55 * _puff
				var r := (3.0 + 6.0 * age + 2.0 * level) * v
				draw_circle(Vector2(6 * v + 4 * v * sin(_t * 2.0 + k), -44 * v - 22 * v * age), r, Color(0.92, 0.96, 0.95, alpha * (1.0 - age)))
		_:
			draw_rect(Rect2(-4 * v, -40 * v, 8 * v, 42 * v), wood)
