class_name Dryad
extends Node2D
## Oath of the Forest Friend: a dryad who wanders the trails all night. She
## drifts to a random point along a trail, pauses, and picks another. A spirit
## she touches is wrapped in vines: Defs.DRYAD_DAMAGE damage and DRYAD_SLOW
## slower for DRYAD_SLOW_TIME (battle.gd applies the slow through vine_t).
## She can't be hurt and needs no tile. Art: assets/dryad/dryad.svg
## (tools/dryad_svg.py), feet at (80, 246) in a 160x252 view box.

const Defs := preload("res://scripts/game/defs.gd")
const ART_SCALE := 2.0
const SIZE := 0.32   ## × view_scale; Char is 0.42

var battle
var board
var world := Vector2(40, 70)
var _goal := Vector2.ZERO
var _pause := 0.6
var _t := 0.0
var _facing := 1.0
var _walk := 0.0          ## 0 standing .. 1 walking (eases)
var _cool := {}           ## spirit instance id -> seconds until she can touch it again
var _petals: Array = []   ## [world, age, life, drift, spin]
var _petal_t := 0.0
var _pivot := Node2D.new()
var _sprite := Sprite2D.new()
static var _tex: Texture2D


func setup(b, bd) -> void:
	battle = b
	board = bd
	_goal = world
	position = board.proj(world)


func _ready() -> void:
	if _tex == null:
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string("res://assets/dryad/dryad.svg"), ART_SCALE)
		_tex = ImageTexture.create_from_image(img)
	_sprite.texture = _tex
	_sprite.centered = false
	_sprite.offset = Vector2(-80, -246) * ART_SCALE
	add_child(_pivot)
	_pivot.add_child(_sprite)


## A random point along one of tonight's trails, away from the fire and the map edge.
func _new_goal() -> void:
	if board.paths.is_empty():
		return
	var pts: PackedVector2Array = board.paths[Run.rng.randi() % board.paths.size()]
	_goal = pts[int(Run.rng.randf_range(0.3, 0.8) * (pts.size() - 1))]
	_goal += Vector2(Run.rng.randf_range(-12, 12), Run.rng.randf_range(-12, 12))


func _process(delta: float) -> void:
	_t += delta
	var to := _goal - world
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_new_goal()
	elif to.length() < 4.0:
		_pause = Run.rng.randf_range(0.5, 1.2)
	else:
		world += to.limit_length(Defs.DRYAD_SPEED * delta)
		if absf(to.x) > 2.0:
			_facing = signf(to.x)
	var moving := _pause <= 0.0 and to.length() >= 4.0
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 4.0)
	position = board.proj(world)
	# Waddle: a side-to-side sway and a little hop each step.
	var v: float = board.view_scale
	var k: float = SIZE * v / ART_SCALE
	var step := sin(_t * 7.0)
	_pivot.rotation = step * 0.09 * _walk + sin(_t * 1.7) * 0.02
	_pivot.position = Vector2(0, -absf(step) * 3.0 * v * _walk)
	_pivot.scale = Vector2(_facing * k, k * (1.0 + 0.015 * sin(_t * 2.2)))
	_touch(delta)
	_trail(delta)
	queue_redraw()


func _touch(delta: float) -> void:
	for id in _cool.keys():
		_cool[id] -= delta
		if _cool[id] <= 0.0:
			_cool.erase(id)
	if not battle.fighting:
		return
	for sp in battle.spirits:
		if sp.dead or _cool.has(sp.get_instance_id()) or sp.world.distance_to(world) > Defs.DRYAD_REACH:
			continue
		_cool[sp.get_instance_id()] = Defs.DRYAD_TOUCH_CD
		sp.vine_t = Defs.DRYAD_SLOW_TIME
		var wrap := VineWrap.new()
		wrap.board = board
		wrap.size_k = sp.size_k
		sp.add_child(wrap)
		sp.hit(Defs.DRYAD_DAMAGE)
		AudioDirector.play_sfx("vine", -8.0, 0.1)


## A faint trail of drifting petals behind her while she walks.
func _trail(delta: float) -> void:
	_petal_t -= delta * _walk
	if _petal_t <= 0.0 and _walk > 0.5:
		_petal_t = 0.22
		_petals.append([world + Vector2(Run.rng.randf_range(-6, 6), 0), 0.0, Run.rng.randf_range(1.2, 1.9),
			Run.rng.randf_range(-1.0, 1.0), Run.rng.randf_range(0, TAU)])
	for p in _petals:
		p[1] += delta
	_petals = _petals.filter(func(p): return p[1] < p[2])


func _draw() -> void:
	var v: float = board.view_scale
	# Soft green glow and a shadow at her feet.
	var gr := 46.0 * v
	draw_texture_rect(VineWrap.glow_tex(), Rect2(Vector2(-gr, -gr - 34.0 * v), Vector2(gr, gr) * 2.0), false, Color(0.55, 0.94, 0.42, 0.22))
	draw_set_transform(Vector2(0, 1.5 * v), 0.0, Vector2(1, board.K))
	draw_circle(Vector2.ZERO, 12.0 * v, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	# Petals: pink and white, falling and fading; a few are fireflies.
	for p in _petals:
		var u: float = p[1] / p[2]
		var at: Vector2 = board.proj(p[0]) - position + Vector2(p[3] * 10.0 * u + sin(p[1] * 3.0 + p[4]) * 3.0, -18.0 * (1.0 - u)) * v
		var a := (1.0 - u) * minf(1.0, p[1] * 5.0)
		if int(p[4] * 10.0) % 5 == 0:
			draw_circle(at, 1.6 * v, Color(0.85, 1.0, 0.5, a * 0.9))
			draw_circle(at, 4.0 * v, Color(0.7, 1.0, 0.4, a * 0.25))
		else:
			draw_set_transform(at, p[4] + p[1] * 2.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 2.2 * v, Color(1.0, 0.82, 0.9, a * 0.85) if int(p[4] * 7.0) % 2 else Color(1, 0.97, 0.98, a * 0.8))
			draw_set_transform(Vector2.ZERO)


## Vines that curl around a spirit she touched, then fall away.
class VineWrap extends Node2D:
	const LIFE := 2.0
	var board
	var size_k := 1.0
	var _age := 0.0
	static var _glow: Texture2D

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var v: float = board.view_scale
		var s: float = 15.0 * size_k * v
		var c := Vector2(0, -s * 1.9)
		var grow := minf(1.0, _age / 0.25)
		var a := minf(1.0, (LIFE - _age) / 0.35)
		var dark := Color(0.06, 0.2, 0.07, 0.9 * a)
		var green := Color(0.31, 0.68, 0.24, a)
		var lit := Color(0.66, 0.92, 0.47, 0.8 * a)
		# Three coils at different heights, wound in from one side as they grow.
		for i in 3:
			var y := c.y + (i - 1) * s * 0.55
			var rx := s * (1.05 - absf(i - 1) * 0.2)
			var from := PI * 0.1 + i * 0.7
			var span := TAU * 0.8 * grow
			draw_arc(Vector2(c.x, y), rx, from, from + span, 20, dark, 3.2 * v, true)
			draw_arc(Vector2(c.x, y), rx, from, from + span, 20, green, 2.0 * v, true)
			draw_arc(Vector2(c.x, y - 0.5 * v), rx, from + 0.2, from + span * 0.6, 12, lit, 0.7 * v, true)
			# A small leaf where each coil ends.
			var tip := Vector2(c.x, y) + Vector2.from_angle(from + span) * rx
			var lp := PackedVector2Array()
			for j in 10:
				var u := TAU * j / 10.0
				lp.append(tip + Vector2(sin(u) * 1.6, -cos(u) * 3.2).rotated(from + span) * v)
			draw_colored_polygon(lp, green)

	static func glow_tex() -> Texture2D:
		if _glow == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			var tex := GradientTexture2D.new()
			tex.gradient = g
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			_glow = tex
		return _glow
