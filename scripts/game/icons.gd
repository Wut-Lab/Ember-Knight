extends RefCounted
## Simple vector icons for dice faces and cards, drawn on any CanvasItem.
##   bolt   -> ember arrow (Ember Lantern)
##   flare  -> flame (Brazier)
##   rune   -> rune diamond (Rune Stone)
##   ward   -> parchment scroll (Ash Ward)
##   torch  -> flame (Torch)
##   vent   -> steam wisps (Steam Vent)
##   kindle -> star (Kindle Char)
##   shift  -> flame with a curved arrow (Oath of Shifting Embers)
##   hearth -> flame cradled in a heart (Hearth-Bound)
##   beacon -> Guide Light lantern with a crown of rays (Bright Beacon)
##   ash_heal -> ash heap with a small plus (Healing Ash)
##   sunrise -> half a sun on the horizon (Oath of Dawn Offerings)
##   essence -> blue orb with a flame (the Essence currency; `t` waves the flame)


static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color, t := 0.0) -> void:
	match kind:
		"bolt":
			_bolt(ci, c, s, col)
		"flare", "torch":
			_flame(ci, c, s, col)
		"rune":
			_rune(ci, c, s, col)
		"ward":
			_parchment(ci, c, s, col)
		"vent":
			_steam(ci, c, s, col)
		"kindle":
			_star(ci, c, s, col)
		"essence":
			_essence(ci, c, s, t)
		"shift":
			_shift(ci, c, s, col)
		"hearth":
			_hearth(ci, c, s, col)
		"mortar":
			_mortar(ci, c, s, col)
		"guide":
			_guide(ci, c, s, col)
		"wall":   # three courses of bricks
			for row in 3:
				var y := c.y + s * (0.18 - 0.2 * row)
				var off := s * 0.11 if row % 2 == 1 else 0.0
				for k in (2 if row % 2 == 1 else 3):
					var x := c.x - s * 0.34 + off + s * 0.23 * k
					ci.draw_rect(Rect2(x, y - s * 0.08, s * 0.2, s * 0.16), col)
		"ashes":
			_ashes(ci, c, s, col)
		"beacon":
			_guide(ci, c + Vector2(0, s * 0.08), s * 0.85, col)
			for a in [-0.3, -0.15, 0.0, 0.15, 0.3]:
				var d := Vector2.from_angle(-PI * 0.5 + a * PI)
				ci.draw_line(c + d * s * 0.36, c + d * s * 0.48, col, s * 0.05, true)
		"sunrise":   # half a sun on the horizon, with rays
			var hc := c + Vector2(0, s * 0.16)
			var pts := PackedVector2Array()
			for k in 17:
				pts.append(hc + Vector2.from_angle(PI + PI * k / 16.0) * s * 0.26)
			ci.draw_colored_polygon(pts, col)
			for a in [0.1, 0.3, 0.5, 0.7, 0.9]:
				var d := Vector2.from_angle(PI + PI * a)
				ci.draw_line(hc + d * s * 0.33, hc + d * s * 0.45, col, s * 0.06, true)
			ci.draw_line(hc + Vector2(-s * 0.46, s * 0.04), hc + Vector2(s * 0.46, s * 0.04), col, s * 0.06, true)
		"pine":   # a log end-on at the left, with a pine sprig on top
			var r := Rect2(c + Vector2(-s * 0.36, -s * 0.06), Vector2(s * 0.72, s * 0.3))
			ci.draw_rect(r, col)
			ci.draw_circle(c + Vector2(-s * 0.36, s * 0.09), s * 0.15, col.lightened(0.3))
			ci.draw_arc(c + Vector2(-s * 0.36, s * 0.09), s * 0.08, 0, TAU, 12, col.darkened(0.3), s * 0.03)
			ci.draw_line(c + Vector2(-s * 0.15, s * 0.0), c + Vector2(s * 0.3, s * 0.0), col.darkened(0.3), s * 0.03)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.16), c + Vector2(s * 0.34, s * 0.16), col.darkened(0.3), s * 0.03)
			var g := col.lerp(Color("#3f9a36"), 0.85)
			var base := c + Vector2(s * 0.08, -s * 0.06)
			ci.draw_line(base, base + Vector2(s * 0.1, -s * 0.34), g, s * 0.05)
			for k in 3:
				var p := base + Vector2(s * 0.1, -s * 0.34) * (0.35 + 0.25 * k)
				ci.draw_line(p, p + Vector2(-s * 0.14, s * 0.03), g, s * 0.04)
				ci.draw_line(p, p + Vector2(s * 0.13, s * 0.06), g, s * 0.04)
		"leaf":
			var pts := PackedVector2Array()
			for i in 16:
				var u := TAU * i / 16.0
				pts.append(c + Vector2(sin(u) * s * 0.22, -cos(u) * s * (0.4 if cos(u) > 0 else 0.3)).rotated(0.6))
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, s * 0.42).rotated(0.6), c + Vector2(0, -s * 0.3).rotated(0.6), col.darkened(0.45), s * 0.05, true)
		"heart":
			var r := s * 0.17
			ci.draw_circle(c + Vector2(-r * 0.95, -s * 0.08), r, col)
			ci.draw_circle(c + Vector2(r * 0.95, -s * 0.08), r, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.9, -s * 0.02), c + Vector2(r * 1.9, -s * 0.02), c + Vector2(0, s * 0.36)]), col)
		"ash_heal":
			_ashes(ci, c + Vector2(-s * 0.08, s * 0.06), s * 0.9, col)
			var p := c + Vector2(s * 0.26, -s * 0.24)
			ci.draw_line(p - Vector2(s * 0.12, 0), p + Vector2(s * 0.12, 0), col, s * 0.07)
			ci.draw_line(p - Vector2(0, s * 0.12), p + Vector2(0, s * 0.12), col, s * 0.07)


## Cinder Mortar: a stubby barrel tilted up with a cinder arcing out.
static func _mortar(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# Block base, a fat barrel angled up-right, and a cinder flying out.
	ci.draw_rect(Rect2(c + Vector2(-s * 0.38, s * 0.18), Vector2(s * 0.56, s * 0.18)), col)
	var dir := Vector2(0.6, -1.0).normalized()
	var n := Vector2(-dir.y, dir.x)
	var b0 := c + Vector2(-s * 0.12, s * 0.16)
	var tip := b0 + dir * s * 0.42
	ci.draw_colored_polygon(PackedVector2Array([b0 - n * s * 0.13, tip - n * s * 0.16, tip + n * s * 0.16, b0 + n * s * 0.13]), col)
	ci.draw_circle(c + Vector2(s * 0.34, -s * 0.36), s * 0.09, col)


## Guide Light: a lantern hanging from a hook, with light rays.
static func _guide(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_line(c + Vector2(0, -s * 0.42), c + Vector2(0, -s * 0.24), col, s * 0.06, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.24), Vector2(s * 0.3, s * 0.4)), col, false, s * 0.07)
	ci.draw_circle(c + Vector2(0, -s * 0.04), s * 0.08, col)
	for a in [-0.35, 0.0, 0.35]:
		var d := Vector2.from_angle(PI * 0.5 + a * PI)
		ci.draw_line(c + Vector2(0, -s * 0.04) + d * s * 0.3, c + Vector2(0, -s * 0.04) + d * s * 0.44, col, s * 0.05, true)


## Ashes: a small grey heap with a wisp of smoke.
static func _ashes(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.3), c + Vector2(-s * 0.15, s * 0.02),
		c + Vector2(s * 0.12, s * 0.06), c + Vector2(s * 0.4, s * 0.3)]), col)
	var pts := PackedVector2Array()
	for i in 7:
		var t := float(i) / 6.0
		pts.append(c + Vector2(sin(t * TAU) * s * 0.07, -t * s * 0.4))
	ci.draw_polyline(pts, col, s * 0.05, true)


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


static func _parchment(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.5
	var h := s * 0.62
	var line := s * 0.06
	ci.draw_rect(Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h)), col, false, line)
	for y in [-h * 0.5, h * 0.5]:   # rolled ends
		ci.draw_line(c + Vector2(-w * 0.62, y), c + Vector2(w * 0.62, y), col, s * 0.11, true)
	for i in 3:   # lines of writing
		var y := -h * 0.22 + i * h * 0.22
		ci.draw_line(c + Vector2(-w * 0.3, y), c + Vector2(w * (0.3 if i < 2 else 0.05), y), col, s * 0.045, true)


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


## Essence: a small blue orb with one flame waving off its top and a faint
## white glow. Ignores the tint; it always looks the same.
static func _essence(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var r := s * 0.3
	var o := c + Vector2(0, s * 0.12)
	for k in 4:  # faint white glow
		ci.draw_circle(o, r * (1.25 + 0.22 * k), Color(1, 1, 1, 0.07))
	# Flame off the top, its tip swaying.
	var sway := sin(t * 4.0) * r * 0.35
	var tip := o + Vector2(sway, -r * 2.15)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(o + Vector2(cos(a), sin(a) * 0.6) * r * 0.62 + Vector2(0, -r * 0.55))
	var right := pts[pts.size() - 1]
	var left := pts[0]
	var out := PackedVector2Array()
	for i in 10:
		out.append(_qbez(right, o + Vector2(r * 0.55 + sway * 0.3, -r * 1.45), tip, i / 9.0))
	for i in 10:
		out.append(_qbez(tip, o + Vector2(-r * 0.6 + sway * 0.5, -r * 1.3), left, i / 9.0))
	ci.draw_colored_polygon(out, Color("#8fd0ff"))
	# The orb: deep blue rim, brighter body, a white highlight.
	ci.draw_circle(o, r, Color("#1f4fa8"))
	ci.draw_circle(o + Vector2(-r * 0.08, -r * 0.08), r * 0.82, Color("#3d86e6"))
	ci.draw_circle(o + Vector2(-r * 0.15, -r * 0.15), r * 0.5, Color("#7fbaff"))
	ci.draw_circle(o + Vector2(-r * 0.35, -r * 0.38), r * 0.18, Color(1, 1, 1, 0.85))
	ci.draw_arc(o, r, 0, TAU, 32, Color(0.8, 0.92, 1.0, 0.5), maxf(1.0, s * 0.03), true)


static func _shift(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A small flame with an arrow sweeping over it, from left to right.
	_flame(ci, c + Vector2(0, s * 0.12), s * 0.62, col)
	var r := s * 0.36
	var o := c + Vector2(0, s * 0.08)
	var a0 := PI * 1.05
	var a1 := TAU - PI * 0.12
	ci.draw_arc(o, r, a0, a1, 20, col, s * 0.08, true)
	var end := o + Vector2(cos(a1), sin(a1)) * r
	var dir := Vector2(-sin(a1), cos(a1))   # along the arc
	var n := Vector2(cos(a1), sin(a1))
	ci.draw_colored_polygon(PackedVector2Array([end + dir * s * 0.16,
		end - dir * s * 0.04 + n * s * 0.12, end - dir * s * 0.04 - n * s * 0.12]), col)


static func _hearth(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A heart outline with a flame burning inside it.
	var pts := PackedVector2Array()
	for i in 33:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(c + Vector2(x, -y - 2.0) * s * 0.026)
	ci.draw_polyline(pts, col, s * 0.08, true)
	_flame(ci, c + Vector2(0, s * 0.02), s * 0.5, col)
