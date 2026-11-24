extends Node2D

const Defs := preload("res://scripts/game/defs.gd")
## An ember bolt (from a lantern) or a flame bolt (from Char). Homes in on its
## target; if the target is gone, it fizzles where the target was.

var board
var battle
var target
var damage := 1.0
var style := "bolt"
var splash := 0.0           ## > 0: hits every spirit this close to the impact
var burn := Vector2.ZERO    ## Ember Brazier: (dps, seconds) to set the hit smouldering
var height := 40.0          ## screen-space lift above the ground
var world := Vector2.ZERO
var _aim := Vector2.ZERO
var _trail: Array[Vector2] = []
var _from := Vector2.ZERO
const SPEED := 620.0


func setup(b, bd, from_world: Vector2, lift: float, t, dmg: float, st: String) -> void:
	battle = b
	board = bd
	world = from_world
	height = lift
	target = t
	damage = dmg
	style = st
	_aim = t.world
	_from = from_world


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		_aim = target.world
	var to := _aim - world
	var step := SPEED * delta * (0.55 if style == "mortar" else 1.0)
	if style == "mortar":   # lob: a high arc over the clearing
		var total := maxf(_from.distance_to(_aim), 1.0)
		var f := clampf(1.0 - to.length() / total, 0.0, 1.0)
		height = 26.0 + 4.0 * total * 0.25 * f * (1.0 - f)
	else:
		height = lerpf(height, 26.0, clampf(delta * 6.0, 0.0, 1.0))
	if to.length() <= step:
		if splash > 0.0:
			for sp in battle.spirits_in_range(_aim, splash):
				sp.hit(damage)
				sp.ignite(burn.x, burn.y)
				if style == "mortar" and Run.has_oath("crossfire"):
					sp.scorch_t = Defs.CROSSFIRE_SCORCH
			battle.ring_fx(_aim, splash, Color("#e0603a"))
		elif is_instance_valid(target) and not target.dead:
			if style == "torch" and target.scorch_t > 0.0:   # Oath of Crossfire
				damage *= Defs.CROSSFIRE_TORCH
			target.hit(damage)
			target.ignite(burn.x, burn.y)
			if style == "char" and target.dead:
				battle.char_kill(target.world)
		battle.spark_fx(_aim, style)
		queue_free()
		return
	world += to.normalized() * step
	position = board.proj(world) + Vector2(0, -height * board.view_scale)
	_trail.push_front(position)
	if _trail.size() > 7:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	var v: float = board.view_scale
	var core := Color("#fff3c4")
	var outer := Color("#ff8a3a") if style == "bolt" else (Color("#e0603a") if style == "mortar" else Color("#ffb238"))
	if style == "char":
		var b: Array = Defs.OUTFITS[Profile.outfit]["bolt"]
		core = Color(b[0])
		outer = Color(b[1])
	for i in _trail.size():
		var p := _trail[i] - position
		var f := 1.0 - float(i) / _trail.size()
		draw_circle(p, 5.0 * v * f, Color(outer, 0.45 * f))
	draw_circle(Vector2.ZERO, 9.0 * v, Color(outer, 0.3))
	draw_circle(Vector2.ZERO, 5.0 * v, outer)
	draw_circle(Vector2.ZERO, 2.6 * v, core)
