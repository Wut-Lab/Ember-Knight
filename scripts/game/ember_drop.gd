extends Node2D
const Defs := preload("res://scripts/game/defs.gd")
## Ember Drop: a small charred coal with a little flame dancing off it, left
## behind by a banished spirit. Tap it to heal Char's flame. It fades after
## Defs.EMBER_LIFE seconds, blinking through its last second.

var board
var world := Vector2.ZERO
var life := Defs.EMBER_LIFE
var picked := false
var _t := 0.0
var _hop := 0.0          ## 0..1 little bounce as it lands
var _shape := PackedVector2Array()


func setup(b, at: Vector2) -> void:
	board = b
	world = at
	position = board.proj(world)
	_t = randf() * 10.0
	# A lumpy coal outline, fixed for this ember.
	for i in 9:
		var a := TAU * i / 9.0
		_shape.append(Vector2(cos(a) * randf_range(0.8, 1.15), sin(a) * randf_range(0.55, 0.75)))


## Is a board-local point close enough to count as a tap on this ember?
func hit(local: Vector2) -> bool:
	var s: float = board.view_scale
	return not picked and (local - (position + Vector2(0, -6.0 * s))).length() <= 24.0 * s


func _process(delta: float) -> void:
	_t += delta
	_hop = minf(1.0, _hop + delta / 0.35)
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var s: float = board.view_scale
	var alpha := clampf(life / 0.6, 0.0, 1.0)
	if life < 1.0 and fmod(life, 0.2) < 0.07:   # blink through the last second
		alpha *= 0.35
	var lift := -sin(_hop * PI) * 10.0 * s
	var r := 8.0 * s
	# Warm glow on the ground.
	draw_texture_rect(_glow_tex(), Rect2(-r * 3.2, -r * 2.2 + lift * 0.3, r * 6.4, r * 4.4), false, Color(1.0, 0.45, 0.12, 0.45 * alpha))
	draw_set_transform(Vector2(0, -r * 0.4 + lift))
	# The charred coal: dark body, a lighter top, and glowing cracks.
	var body := PackedVector2Array()
	for p in _shape:
		body.append(p * r)
	draw_colored_polygon(body, Color(0.13, 0.1, 0.1, alpha))
	var top := PackedVector2Array()
	for p in _shape:
		top.append(Vector2(p.x * 0.75, p.y * 0.6 - 0.18) * r)
	draw_colored_polygon(top, Color(0.24, 0.19, 0.18, alpha))
	var hot := Color(1.0, 0.5 + 0.15 * sin(_t * 9.0), 0.15, (0.75 + 0.25 * sin(_t * 5.0)) * alpha)
	draw_polyline(PackedVector2Array([Vector2(-0.6, -0.05) * r, Vector2(-0.2, 0.12) * r, Vector2(0.1, -0.08) * r, Vector2(0.55, 0.1) * r]), hot, maxf(1.2, 0.18 * r))
	# A slight flame dancing off the top: a short teardrop that sways and flickers.
	var sway := sin(_t * 7.0) * 0.22 + sin(_t * 11.3) * 0.1
	var h := r * (0.95 + 0.15 * sin(_t * 13.0))
	var base := Vector2(r * 0.1, -r * 0.3)
	for layer in [[1.0, Color(1.0, 0.45, 0.1, 0.85 * alpha)], [0.55, Color(1.0, 0.85, 0.35, 0.95 * alpha)]]:
		var k: float = layer[0]
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			var w := r * 0.4 * k * pow(sin(PI * minf(u * 1.25, 1.0) * 0.5 + PI * 0.5 * (1.0 if u > 0.8 else 0.0)), 1.0) * (1.0 - u)
			var x := sway * r * u * u
			left.append(base + Vector2(x - w, -u * h * k))
			right.append(base + Vector2(x + w, -u * h * k))
		right.reverse()
		left.append_array(right)
		draw_colored_polygon(left, layer[1])
	draw_set_transform(Vector2.ZERO)


static var _glow: Texture2D

static func _glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow
