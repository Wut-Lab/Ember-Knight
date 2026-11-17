extends Node2D
## A spirit drifting out of the dark along a trail toward the fire.
## Cute ghost shape; its body is only lit near the fire, but its eyes
## always glow, so you see eyes in the dark first.

signal banished(spirit)
signal reached_fire(spirit)

const Defs := preload("res://scripts/game/defs.gd")

var kind := "wisp"
var hp := 1.0
var max_hp := 1.0
var speed := 50.0
var damage := 5.0
var size_k := 1.0
var base_color := Color.WHITE
var path_idx := 0
var dist := 0.0
var world := Vector2.ZERO
var slow := 0.0            ## 0..1, set by the battle from nearby Rune Stones
var dead := false

var board
var _t := 0.0
var _flash := 0.0
var _fade_in := 0.0
var _death := 0.0


func setup(b, k: String, path: int, hp_scale: float) -> void:
	board = b
	kind = k
	path_idx = path
	var d: Dictionary = Defs.SPIRITS[k]
	max_hp = d["hp"] * hp_scale
	hp = max_hp
	speed = d["speed"] * randf_range(0.92, 1.08)
	damage = d["damage"]
	size_k = d["size"]
	base_color = d["color"]
	_t = randf() * 10.0
	world = board.path_point(path_idx, 0.0)
	position = board.proj(world)


func progress() -> float:
	return dist / board.path_lengths[path_idx]


func hit(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.12
	if hp <= 0.0:
		dead = true
		banished.emit(self)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_fade_in = minf(1.0, _fade_in + delta / 0.8)
	if dead:
		_death += delta
		if _death > 0.35:
			queue_free()
		queue_redraw()
		return
	dist += speed * (1.0 - slow) * delta
	if dist >= board.path_lengths[path_idx]:
		dead = true
		reached_fire.emit(self)
		queue_free()
		return
	world = board.path_point(path_idx, dist)
	position = board.proj(world)
	queue_redraw()


func _draw() -> void:
	var s: float = 22.0 * size_k * board.view_scale
	var bob: float = sin(_t * 3.0) * 4.0 * board.view_scale
	var lit: float = board.light_at(world)
	var alpha := _fade_in * (1.0 - _death / 0.35)
	var squash := 1.0 + _death * 1.5
	# Ground shadow (only visible in the light).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	_oval(Vector2(0, 2), s * 0.8, s * 0.25, Color(0, 0, 0, 0.35 * lit * alpha))
	draw_set_transform(Vector2(0, -s * 1.4 + bob), 0.0, Vector2(squash, 1.0 / squash))
	var body := Color("#07060c").lerp(base_color, 0.25 + 0.75 * lit)
	if _flash > 0.0:
		body = body.lerp(Color.WHITE, 0.7)
	body.a = 0.92 * alpha
	# Ghost body: round head, wavy tail.
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a), sin(a)) * s)
	var waves := 4
	for i in waves * 2 + 1:
		var f := 1.0 - float(i) / (waves * 2)
		var x := lerpf(-s, s, f)
		var y := s * (0.95 if i % 2 == 0 else 0.62) + sin(_t * 6.0 + i) * s * 0.08
		pts.append(Vector2(x, y))
	draw_colored_polygon(pts, body)
	var shine := Color(1, 1, 1, 0.16 * alpha * (0.4 + 0.6 * lit))
	_oval(Vector2(-s * 0.38, -s * 0.45), s * 0.32, s * 0.2, shine)
	# Eyes look toward the fire; they glow even in the dark.
	var look: Vector2 = (-world).normalized() * s * 0.08
	var eye := Color(1.0, 0.95, 0.75, alpha)
	var ex := s * 0.36
	var er := s * (0.24 if kind != "shade" else 0.2)
	if kind == "shade":
		# Hood points.
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.7, -s * 0.6), Vector2(-s * 0.5, -s * 1.35), Vector2(-s * 0.2, -s * 0.85)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(s * 0.7, -s * 0.6), Vector2(s * 0.5, -s * 1.35), Vector2(s * 0.2, -s * 0.85)]), body)
		eye = Color(1.0, 0.6, 0.35, alpha)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * ex, -s * 0.05) + look
		draw_circle(c, er * 1.9, Color(eye, 0.12 * alpha))
		_oval(c, er, er * 1.25, eye)
		draw_circle(c + look * 1.4 + Vector2(0, er * 0.15), er * 0.5, Color(0.08, 0.06, 0.15, alpha))
	# Little blush-mouth for cuteness.
	if kind == "wisp":
		draw_arc(Vector2(0, s * 0.35), s * 0.12, 0.2, PI - 0.2, 8, Color(0.08, 0.06, 0.15, 0.8 * alpha), 2.0)
	draw_set_transform(Vector2.ZERO)
	# Health bar once hurt.
	if hp < max_hp and not dead:
		var w := s * 1.8
		var y: float = -s * 2.85 + bob
		draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.6 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 4), Color(1.0, 0.7, 0.3, alpha))


func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
