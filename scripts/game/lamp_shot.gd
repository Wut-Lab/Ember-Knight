extends Node2D
## A Lit Lamp shot: pure white, flies straight (no aim), hits the first spirit
## it touches, and drizzles out in sparks at the end of its reach.

const HIT_R := 20.0
const SPEED := 360.0
const DRIZZLE := 0.45

var battle
var board
var world := Vector2.ZERO
var dir := Vector2.RIGHT
var reach := 300.0
var damage := 6.0
var _went := 0.0
var _fade := 0.0    # > 0: drizzling out
var _trail: Array[Vector2] = []


func setup(b, bd, from: Vector2, d: Vector2, r: float, dmg: float) -> void:
	battle = b
	board = bd
	world = from + d * 14.0
	dir = d
	reach = r
	damage = dmg
	_place()


func _place() -> void:
	position = board.proj(world) + Vector2(0, -50.0 * board.view_scale * (1.0 - 0.6 * _fade / DRIZZLE))


func _process(delta: float) -> void:
	if _fade > 0.0:
		_fade += delta
		world += dir * SPEED * 0.25 * delta
		if _fade >= DRIZZLE:
			queue_free()
			return
	else:
		world += dir * SPEED * delta
		_went += SPEED * delta
		for sp in battle.spirits_in_range(world, HIT_R):
			sp.hit(damage)
			battle.lamp_spark(world)
			queue_free()
			return
		if _went >= reach:
			_fade = 0.001
	_place()
	_trail.push_front(position)
	if _trail.size() > 6:
		_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	var v: float = board.view_scale
	var a := 1.0 - _fade / DRIZZLE
	for i in _trail.size():
		var f := 1.0 - float(i) / _trail.size()
		draw_circle(_trail[i] - position, 5.0 * v * f, Color(1, 1, 1, 0.45 * f * a))
	if _fade > 0.0:   # drizzle: a few falling sparks
		for k in 4:
			var o := Vector2(sin(k * 2.1) * 8.0, 4.0 + k * 3.0) * v * (_fade / DRIZZLE) * 2.0
			draw_circle(o, 1.8 * v * a, Color(1, 1, 1, a))
	draw_circle(Vector2.ZERO, 11.0 * v, Color(1, 1, 1, 0.22 * a))
	draw_circle(Vector2.ZERO, 5.0 * v * (0.6 + 0.4 * a), Color(1, 1, 1, a))
