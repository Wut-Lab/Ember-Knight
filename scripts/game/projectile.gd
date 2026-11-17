extends Node2D
## An ember bolt (from a lantern) or a flame bolt (from Char). Homes in on its
## target; if the target is gone, it fizzles where the target was.

var board
var battle
var target
var damage := 1.0
var style := "bolt"
var height := 40.0          ## screen-space lift above the ground
var world := Vector2.ZERO
var _aim := Vector2.ZERO
var _trail: Array[Vector2] = []
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


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		_aim = target.world
	var to := _aim - world
	var step := SPEED * delta
	height = lerpf(height, 26.0, clampf(delta * 6.0, 0.0, 1.0))
	if to.length() <= step:
		if is_instance_valid(target) and not target.dead:
			target.hit(damage)
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
	var outer := Color("#ff8a3a") if style == "bolt" else Color("#ffb238")
	for i in _trail.size():
		var p := _trail[i] - position
		var f := 1.0 - float(i) / _trail.size()
		draw_circle(p, 5.0 * v * f, Color(outer, 0.45 * f))
	draw_circle(Vector2.ZERO, 9.0 * v, Color(outer, 0.3))
	draw_circle(Vector2.ZERO, 5.0 * v, outer)
	draw_circle(Vector2.ZERO, 2.6 * v, core)
