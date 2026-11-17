extends RefCounted
## Simple vector icons for dice faces and cards, drawn on any CanvasItem.
##   bolt   -> ember arrow (Ember Lantern)
##   flare  -> flame (Brazier)
##   ward   -> rune diamond (Rune Stone)
##   kindle -> star (Kindle Char)


static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"bolt":
			_bolt(ci, c, s, col)
		"flare":
			_flame(ci, c, s, col)
		"ward":
			_rune(ci, c, s, col)
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
	var pts := PackedVector2Array()
	for i in 33:
		var t := float(i) / 32.0 * TAU
		# Teardrop: round bottom, pointed top, slight lick to the right.
		var r := s * 0.34
		var x := sin(t) * r * (0.75 + 0.25 * cos(t))
		var y := -cos(t) * r * 1.35 * (1.0 if cos(t) > 0 else 0.7)
		if cos(t) > 0.6:
			x += sin(t * 2.0) * s * 0.05
		pts.append(c + Vector2(x, y + s * 0.1))
	ci.draw_colored_polygon(pts, col)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + Vector2(0, s * 0.18) + (p - c - Vector2(0, s * 0.1)) * 0.45)
	ci.draw_colored_polygon(inner, col.lightened(0.6))


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
