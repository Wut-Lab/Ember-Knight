extends RefCounted
## Simple vector icons for dice faces and cards, drawn on any CanvasItem.
##   bolt   -> ember arrow (Ember Lantern)
##   flare  -> flame (Brazier)
##   ward   -> rune diamond (Rune Stone)
##   torch  -> flame (Torch)
##   vent   -> steam wisps (Steam Vent)
##   kindle -> star (Kindle Char)


static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"bolt":
			_bolt(ci, c, s, col)
		"flare", "torch":
			_flame(ci, c, s, col)
		"ward":
			_rune(ci, c, s, col)
		"vent":
			_steam(ci, c, s, col)
		"kindle":
			_star(ci, c, s, col)


static func _bolt(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# Diagonal arrow with an ember head and two trailing sparks.
	var d := Vector2(1, -1).normalized()
	var n := Vector2(d.y, -d.x)
	var tip := c + d * s * 0.42
	var tail := c - d * s * 0.38
	ci.draw_line(tail, tip - d * s * 0.12, col, s * 0.11, true)
	ci.draw_colored_polygon(PackedVector2Array([
		tip, tip - d * s * 0.28 + n * s * 0.17, tip - d * s * 0.2, tip - d * s * 0.28 - n * s * 0.17]), col)
	for k in 2:
		var sp := tail + n * s * (0.16 if k == 0 else -0.16) + d * s * 0.06
		ci.draw_line(sp - d * s * 0.14, sp, col, s * 0.07, true)


static func _flame(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# Round base, pointed tip leaning a little right, with a lighter core.
	var outer := _flame_pts(c + Vector2(0, s * 0.14), s * 0.27, s * 0.62)
	ci.draw_colored_polygon(outer, col)
	var inner := _flame_pts(c + Vector2(0, s * 0.2), s * 0.13, s * 0.34)
	ci.draw_colored_polygon(inner, col.lightened(0.55))


## Flame outline: half circle of radius r at `base`, rising to a tip `tall` up.
static func _flame_pts(base: Vector2, r: float, tall: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:  # bottom half circle, left to right
		var a := PI - PI * i / 12.0
		pts.append(base + Vector2(cos(a) * r, -sin(a) * r * -1.0))
	var tip := base + Vector2(r * 0.25, -tall)
	var right := base + Vector2(r, 0)
	var left := base + Vector2(-r, 0)
	for i in range(1, 13):  # right side up to the tip
		var t := i / 12.0
		pts.append(_qbez(right, base + Vector2(r * 1.05, -tall * 0.55), tip, t))
	for i in range(1, 12):  # tip back down the left side
		var t := i / 12.0
		pts.append(_qbez(tip, base + Vector2(-r * 0.85, -tall * 0.4), left, t))
	return pts


static func _qbez(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


static func _rune(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var r := s * 0.4
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.72, 0), c + Vector2(0, r),
		c + Vector2(-r * 0.72, 0), c + Vector2(0, -r)])
	ci.draw_polyline(pts, col, s * 0.09, true)
	ci.draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.55), col, s * 0.08, true)
	ci.draw_line(c + Vector2(-r * 0.3, -r * 0.15), c + Vector2(0, r * 0.15), col, s * 0.07, true)
	ci.draw_line(c + Vector2(r * 0.3, -r * 0.15), c + Vector2(0, r * 0.15), col, s * 0.07, true)


static func _star(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var r := s * (0.42 if i % 2 == 0 else 0.18)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)


static func _steam(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A nozzle with three wavy steam wisps rising from it.
	ci.draw_rect(Rect2(c + Vector2(-s * 0.22, s * 0.22), Vector2(s * 0.44, s * 0.16)), col)
	for k in 3:
		var x := (k - 1) * s * 0.2
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(c + Vector2(x + sin(t * TAU) * s * 0.06, s * 0.16 - t * s * 0.56))
		ci.draw_polyline(pts, col, s * 0.08, true)
