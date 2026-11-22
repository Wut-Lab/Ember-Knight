extends Control
## Night backdrop: deep sky, a treeline on the horizon, the dark ground the
## camp sits on, and faint twinkling stars.

const SKY_TOP := Color("#06050c")
const SKY_LOW := Color("#171427")
const GROUND_FAR := Color("#0f0c12")
const GROUND_NEAR := Color("#09070a")
const TREES := Color("#0b090f")
const HORIZON := 0.6   ## fraction of height

## Dawn sky: purple through crimson and orange to a gold horizon; stars fade.
var dawn := false
var _stars: Array = []
var _trees: Array = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 120:
		# [pos (fraction), radius, alpha, phase, twinkle speed]
		_stars.append([Vector2(r.randf(), pow(r.randf(), 1.4) * HORIZON * 0.95),
			r.randf_range(0.5, 1.6), r.randf_range(0.15, 0.75), r.randf() * TAU,
			r.randf_range(0.3, 1.3)])
	var x := -0.02
	while x < 1.04:
		_trees.append([x, r.randf_range(0.03, 0.085), r.randf_range(0.012, 0.022)])
		x += r.randf_range(0.012, 0.03)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var hy := s.y * HORIZON
	if dawn:
		var cols := [Color("#2a1840"), Color("#6b2448"), Color("#c2502e"), Color("#f2a24a")]
		for i in 3:
			_quad(Vector2(0, hy * i / 3.0), Vector2(s.x, hy * (i + 1) / 3.0), cols[i], cols[i + 1])
	else:
		_quad(Vector2.ZERO, Vector2(s.x, hy), SKY_TOP, SKY_LOW)
	for st in _stars:
		var tw: float = 0.65 + 0.35 * sin(_t * st[4] + st[3])
		var a: float = st[2] * tw * (0.25 if dawn and st[0].y < 0.3 else 0.0 if dawn else 1.0)
		if a > 0.0:
			draw_circle(st[0] * s, st[1], Color(1.0, 0.94, 0.84, a))
	# Pine treeline: layered triangles along the horizon.
	for tr in _trees:
		var cx: float = tr[0] * s.x
		var h: float = tr[1] * s.y
		var w: float = tr[2] * s.x
		for k in 3:
			var top := hy - h + k * h * 0.28
			var half := w * (0.55 + k * 0.3)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, top), Vector2(cx + half, top + h * 0.5), Vector2(cx - half, top + h * 0.5)]),
				TREES)
	draw_rect(Rect2(0, hy - 2, s.x, s.y * 0.02 + 2), TREES)
	_quad(Vector2(0, hy + s.y * 0.02), Vector2(s.x, s.y), GROUND_FAR, GROUND_NEAR)


func _quad(a: Vector2, b: Vector2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]),
		PackedColorArray([top, top, bottom, bottom]))
