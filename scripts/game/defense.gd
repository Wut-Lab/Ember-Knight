extends Node2D
## A defense built from a die on a tile. Placing another die with the same
## face on it raises its level (max 3).
##   bolt  - Ember Lantern: post with a hanging lantern, shoots ember bolts
##   flare - Brazier: iron bowl of fire, bursts at everything close by
##   ward  - Rune Stone: standing stone with a blue rune, slows spirits

const Defs := preload("res://scripts/game/defs.gd")
const Icons := preload("res://scripts/game/icons.gd")

var kind := "bolt"
var level := 1
var tile := -1
var world := Vector2.ZERO
var battle            ## the Battle node (targets, projectiles, passives)
var board

var _cool := 0.0
var _t := 0.0
var _pop := 0.0        ## build / level-up bounce
var _fire_kick := 0.0


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


func stats() -> Dictionary:
	var s: Dictionary = Defs.DEFENSES[kind][level - 1].duplicate()
	if kind == "flare" and Run.has("kindling"):
		s["rate"] *= 1.3
	if kind == "ward" and Run.has("old_runes"):
		s["slow"] = minf(s["slow"] + 0.15, 0.8)
		s["range"] *= 1.15
	return s


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 3.0)
	_fire_kick = maxf(0.0, _fire_kick - delta * 4.0)
	queue_redraw()
	if not battle.fighting:
		return
	var st := stats()
	match kind:
		"bolt":
			_cool -= delta
			if _cool <= 0.0:
				var target = battle.pick_target(world, st["range"])
				if target:
					battle.shoot(world + Vector2(0, -1), _muzzle(), target, st["damage"], "bolt")
					_cool = 1.0 / st["rate"]
					_fire_kick = 1.0
		"flare":
			_cool -= delta
			if _cool <= 0.0:
				var hits: Array = battle.spirits_in_range(world, st["range"])
				if not hits.is_empty():
					for sp in hits:
						sp.hit(st["damage"])
					battle.ring_fx(world, st["range"], Color("#ff7a2a"))
					AudioDirector.play_sfx("flare", -6.0)
					_cool = 1.0 / st["rate"]
					_fire_kick = 1.0
		"ward":
			if st["damage"] > 0.0:
				for sp in battle.spirits_in_range(world, st["range"]):
					sp.hit(st["damage"] * delta)


## Screen-space offset (local) where bolts leave the lantern.
func _muzzle() -> Vector2:
	return Vector2(14, -52) * board.view_scale * _scale()


func _scale() -> float:
	return (0.9 + 0.12 * level) * (1.0 + 0.25 * sin(_pop * PI))


func _draw() -> void:
	var v: float = board.view_scale * _scale()
	var lit: float = maxf(board.light_at(world), 0.4)
	match kind:
		"bolt":
			_draw_lantern(v, lit)
		"flare":
			_draw_brazier(v, lit)
		"ward":
			_draw_rune_stone(v, lit)
	# Level pips on the slab.
	for i in level:
		var x: float = (i - (level - 1) / 2.0) * 10.0 * board.view_scale
		draw_circle(Vector2(x, 12.0 * board.view_scale), 3.2 * board.view_scale, Color("#ffb238"))


func _draw_lantern(v: float, lit: float) -> void:
	var wood := Color("#3b2416").lerp(Color("#8b5a3a"), lit)
	draw_rect(Rect2(-4 * v, -62 * v, 8 * v, 64 * v), wood)
	draw_rect(Rect2(-4 * v, -62 * v, 26 * v, 6 * v), wood)
	draw_line(Vector2(16 * v, -56 * v), Vector2(16 * v, -50 * v), Color("#2a2420"), 2.0 * v)
	# Lantern: copper frame, glowing glass.
	var c := Vector2(16 * v, -40 * v)
	var glow := 0.8 + 0.2 * sin(_t * 9.0) + 0.5 * _fire_kick
	draw_circle(c, 26 * v, Color(1.0, 0.65, 0.25, 0.10 * glow))
	draw_circle(c, 15 * v, Color(1.0, 0.7, 0.3, 0.16 * glow))
	draw_rect(Rect2(c.x - 8 * v, c.y - 10 * v, 16 * v, 20 * v), Color("#ffcf6b").lerp(Color.WHITE, 0.2 * _fire_kick))
	draw_rect(Rect2(c.x - 8 * v, c.y - 10 * v, 16 * v, 20 * v), Color("#b5652b"), false, 2.5 * v)
	draw_line(c + Vector2(0, -10 * v), c + Vector2(0, 10 * v), Color("#b5652b"), 2.0 * v)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10 * v, -10 * v), c + Vector2(10 * v, -10 * v), c + Vector2(0, -17 * v)]), Color("#8a4a22"))


func _draw_brazier(v: float, lit: float) -> void:
	var iron := Color("#1c1a20").lerp(Color("#4a4752"), lit)
	for x in [-14.0, 0.0, 14.0]:
		draw_line(Vector2(x * 0.6 * v, -18 * v), Vector2(x * v, 2 * v), iron, 3.5 * v)
	draw_colored_polygon(PackedVector2Array([Vector2(-22 * v, -30 * v), Vector2(22 * v, -30 * v),
		Vector2(13 * v, -16 * v), Vector2(-13 * v, -16 * v)]), iron)
	draw_rect(Rect2(-22 * v, -32 * v, 44 * v, 4 * v), Color("#b5652b"))
	# Flame in the bowl.
	var h := (26.0 + 6.0 * sin(_t * 7.0) + 14.0 * _fire_kick) * v
	draw_circle(Vector2(0, -40 * v), 30 * v, Color(1.0, 0.45, 0.15, 0.10 + 0.1 * _fire_kick))
	var pts := PackedVector2Array([Vector2(-17 * v, -31 * v), Vector2(-9 * v, -31 * v - h * 0.75),
		Vector2(-3 * v, -31 * v - h * 0.55), Vector2(2 * v, -31 * v - h), Vector2(8 * v, -31 * v - h * 0.6),
		Vector2(13 * v, -31 * v - h * 0.8), Vector2(17 * v, -31 * v)])
	draw_colored_polygon(pts, Color("#ff6a2a"))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(Vector2(p.x * 0.55, -31 * v + (p.y + 31 * v) * 0.6))
	draw_colored_polygon(inner, Color("#ffd27a"))


func _draw_rune_stone(v: float, lit: float) -> void:
	var st := stats()
	var r: float = st["range"] * board.view_scale
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	# Aura shows its reach.
	_ellipse_line(Vector2.ZERO, r, r * board.K, Color(0.5, 0.82, 1.0, 0.18 + 0.1 * pulse), 2.0)
	_ellipse_fill(Vector2.ZERO, r, r * board.K, Color(0.5, 0.82, 1.0, 0.05))
	var stone := Color("#2c2a33").lerp(Color("#77707e"), lit)
	var pts := PackedVector2Array([Vector2(-14 * v, 0), Vector2(-16 * v, -40 * v), Vector2(-8 * v, -58 * v),
		Vector2(8 * v, -60 * v), Vector2(15 * v, -42 * v), Vector2(14 * v, 0)])
	draw_colored_polygon(pts, stone)
	draw_line(Vector2(-8 * v, -58 * v), Vector2(8 * v, -60 * v), stone.lightened(0.3), 2.0 * v)
	draw_circle(Vector2(0, -30 * v), 18 * v, Color(0.5, 0.82, 1.0, 0.12 + 0.08 * pulse))
	Icons.draw(self, "ward", Vector2(0, -30 * v), 30 * v, Color(0.6, 0.88, 1.0, 0.75 + 0.25 * pulse))


func _ellipse_line(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)


func _ellipse_fill(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
