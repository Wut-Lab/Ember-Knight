extends Node2D
## Short-lived effects: burst rings, sparks, spirit poofs and floating text.

var kind := "ring"
var color := Color.WHITE
var radius := 100.0
var text := ""
var life := 0.5
var board
var _age := 0.0
var _bits: Array = []


func setup(bd, k: String, at_world: Vector2, col: Color, r := 100.0, txt := "") -> void:
	board = bd
	kind = k
	color = col
	radius = r
	text = txt
	position = board.proj(at_world)
	match kind:
		"ring":
			life = 0.45
		"spark":
			life = 0.3
			_make_bits(6, 60.0)
		"poof":
			life = 0.7
			_make_bits(12, 90.0)
		"text":
			life = 1.1


func _make_bits(n: int, spd: float) -> void:
	for i in n:
		var a := randf() * TAU
		_bits.append([Vector2(cos(a), sin(a) * 0.6) * randf_range(0.4, 1.0) * spd, randf_range(2.0, 4.5)])


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := _age / life
	var v: float = board.view_scale
	match kind:
		"ring":
			var r := radius * v * (0.3 + 0.7 * ease(f, 0.4))
			var pts := PackedVector2Array()
			for i in 49:
				var a := TAU * i / 48.0
				pts.append(Vector2(cos(a) * r, sin(a) * r * board.K))
			draw_polyline(pts, Color(color, 0.8 * (1.0 - f)), 6.0 * v * (1.0 - f) + 1.0, true)
		"spark", "poof":
			for b in _bits:
				var p: Vector2 = b[0] * f * v + Vector2(0, -26.0 * v - (20.0 * f * v if kind == "poof" else 0.0))
				draw_circle(p, b[1] * v * (1.0 - f), Color(color, 1.0 - f))
		"text":
			var font := ThemeDB.fallback_font
			var y := -60.0 * v - 30.0 * f * v
			draw_string(font, Vector2(-40, y), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(color, 1.0 - f * f))
