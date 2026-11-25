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
##   forge  -> Bellows blowing on a flame (Roaring Forge)
##   wake   -> Brazier with a leaping spark (Ember Wake)
##   ash_heal -> ash heap with a small plus (Healing Ash)
##   sunrise -> half a sun on the horizon (Oath of Dawn Offerings)
##   cook / tinker / cat / hound / smith -> caravan members (pot, gear,
##       cat head, paw, hammer on anvil)
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
		"hand":
			_hand(ci, c, s, col)
		"devotion":
			_devotion(ci, c, s, col)
		"hourglass":
			_hourglass(ci, c, s, col)
		"ash_cloud":
			_ash_cloud(ci, c, s, col)
		"swamp":
			_swamp(ci, c, s, col)
		"altar":
			_altar(ci, c, s, col)
		"mire":   # a mud splat with bubbles
			var pts := PackedVector2Array()
			for k in 25:
				var a := TAU * k / 24.0
				var rr := s * 0.34 * (1.0 + 0.14 * sin(a * 3.0 + 0.6) + 0.08 * sin(a * 5.0))
				pts.append(c + Vector2(cos(a) * rr, s * 0.08 + sin(a) * rr * 0.6))
			ci.draw_polyline(pts, col, s * 0.07, true)
			ci.draw_arc(c + Vector2(-s * 0.1, 0.0), s * 0.07, 0.0, TAU, 12, col, s * 0.05, true)
			ci.draw_arc(c + Vector2(s * 0.12, s * 0.1), s * 0.05, 0.0, TAU, 12, col, s * 0.05, true)
			ci.draw_arc(c + Vector2(s * 0.03, -s * 0.24), s * 0.04, 0.0, TAU, 10, col, s * 0.04, true)
		"votive":   # three candles of different heights, flames lit
			for k in 3:
				var x := (k - 1) * s * 0.22
				var h := s * (0.3 + 0.12 * (1 - absi(k - 1)))
				var b := c + Vector2(x, s * 0.32)
				ci.draw_line(b, b - Vector2(0, h), col, s * 0.1, true)
				var tip := b - Vector2(0, h + s * 0.2)
				ci.draw_colored_polygon(PackedVector2Array([b - Vector2(s * 0.05, h + s * 0.05), tip, b - Vector2(-s * 0.05, h + s * 0.05), b - Vector2(0, h)]), col)
			ci.draw_line(c + Vector2(-s * 0.36, s * 0.34), c + Vector2(s * 0.36, s * 0.34), col, s * 0.06, true)
		"reliquary":   # a small casket with a peaked lid and a ring of light
			var bx := Rect2(c + Vector2(-s * 0.26, -s * 0.02), Vector2(s * 0.52, s * 0.3))
			ci.draw_rect(bx, col, false, s * 0.06)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.02), c + Vector2(0, -s * 0.2), c + Vector2(s * 0.3, -s * 0.02)]), col)
			ci.draw_line(c + Vector2(0, -s * 0.2), c + Vector2(0, -s * 0.34), col, s * 0.05, true)
			ci.draw_line(c + Vector2(-s * 0.07, -s * 0.28), c + Vector2(s * 0.07, -s * 0.28), col, s * 0.05, true)
			ci.draw_circle(c + Vector2(0, s * 0.13), s * 0.05, col)
			ci.draw_arc(c + Vector2(0, s * 0.05), s * 0.44, PI * 1.15, PI * 1.85, 20, col, s * 0.035, true)
		"lure":   # an orb in a wire cage hanging from a hook
			ci.draw_line(c + Vector2(-s * 0.18, -s * 0.38), c + Vector2(0, -s * 0.38), col, s * 0.06, true)
			ci.draw_line(c + Vector2(0, -s * 0.38), c + Vector2(0, -s * 0.22), col, s * 0.05, true)
			ci.draw_arc(c + Vector2(0, s * 0.02), s * 0.24, 0.0, TAU, 24, col, s * 0.06, true)
			ci.draw_line(c + Vector2(0, -s * 0.22), c + Vector2(0, s * 0.26), col, s * 0.04, true)
			ci.draw_circle(c + Vector2(0, s * 0.02), s * 0.11, col)
		"vent":
			_steam(ci, c, s, col)
		"kindle":
			_star(ci, c, s, col)
		"essence":
			_essence(ci, c, s, t)
		"cook":
			_cook(ci, c, s, col)
		"tinker":
			_tinker(ci, c, s, col)
		"cat":
			_cat(ci, c, s, col)
		"hound":
			_hound(ci, c, s, col)
		"smith":
			_smith(ci, c, s, col)
		"censer":   # a censer on its chain with a curl of smoke
			ci.draw_line(c + Vector2(-s * 0.02, -s * 0.42), c + Vector2(-s * 0.02, -s * 0.06), col, s * 0.04, true)
			ci.draw_arc(c + Vector2(-s * 0.02, -s * 0.44), s * 0.05, 0.0, TAU, 10, col, s * 0.04, true)
			var pot := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				pot.append(c + Vector2(cos(a) * s * 0.2, s * 0.1 + sin(a) * s * 0.18))
			pot.append(c + Vector2(-s * 0.2, s * 0.1))
			ci.draw_colored_polygon(pot, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.17, s * 0.06), c + Vector2(s * 0.17, s * 0.06), c + Vector2(0, -s * 0.08)]), col)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.3), c + Vector2(s * 0.1, s * 0.3), col, s * 0.05, true)
			var sm := PackedVector2Array()
			for k in 12:
				var f := k / 11.0
				sm.append(c + Vector2(s * (0.22 + 0.08 * sin(f * TAU * 1.2)) + f * s * 0.08, s * (0.0 - f * 0.4)))
			ci.draw_polyline(sm, col, s * 0.04, true)
		"shift":
			_shift(ci, c, s, col)
		"hearth":
			_hearth(ci, c, s, col)
		"mortar":
			_mortar(ci, c, s, col)
		"guide":
			_guide(ci, c, s, col)
		"bellows":
			_bellows(ci, c, s, col)
		"brazier":
			_brazier(ci, c, s, col)
		"wake":   # a brazier with a spark leaping off it (Ember Wake)
			_brazier(ci, c + Vector2(-s * 0.14, s * 0.06), s * 0.8, col)
			ci.draw_arc(c + Vector2(s * 0.12, -s * 0.12), s * 0.26, -PI * 0.9, -PI * 0.15, 10, col, s * 0.05, true)
			ci.draw_circle(c + Vector2(s * 0.36, -s * 0.06), s * 0.07, col)
		"forge":   # Bellows blowing on a flame (Roaring Forge)
			_bellows(ci, c + Vector2(-s * 0.16, s * 0.12), s * 0.7, col)
			var fl := c + Vector2(s * 0.3, -s * 0.02)
			ci.draw_colored_polygon(PackedVector2Array([fl + Vector2(-s * 0.12, s * 0.2), fl + Vector2(-s * 0.08, -s * 0.06),
				fl + Vector2(0, -s * 0.34), fl + Vector2(s * 0.09, -s * 0.06), fl + Vector2(s * 0.12, s * 0.2)]), col)
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


## Bellows: a wedge of two boards with a nozzle, a handle, and a puff of air.
static func _bellows(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var tip := c + Vector2(s * 0.22, 0)
	var back_t := c + Vector2(-s * 0.32, -s * 0.24)
	var back_b := c + Vector2(-s * 0.32, s * 0.2)
	ci.draw_polyline(PackedVector2Array([tip, back_t, back_b, tip]), col, s * 0.07, true)
	ci.draw_line(back_t + Vector2(s * 0.08, s * 0.1), back_b + Vector2(s * 0.08, -s * 0.1), col, s * 0.04, true)   # fold
	ci.draw_line(tip, tip + Vector2(s * 0.12, 0), col, s * 0.1)   # nozzle
	ci.draw_line(back_t, back_t + Vector2(-s * 0.1, -s * 0.1), col, s * 0.06, true)   # handle
	for k in 2:   # puff
		ci.draw_arc(tip + Vector2(s * 0.24, 0), s * (0.06 + 0.07 * k), -0.9, 0.9, 8, col, s * 0.04, true)


## Ember Brazier: a bowl on legs with three flames.
static func _brazier(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var bowl := PackedVector2Array()
	for k in 9:
		var a := PI * k / 8.0
		bowl.append(c + Vector2(cos(a) * s * 0.34, s * 0.02 + sin(a) * s * 0.18))
	ci.draw_colored_polygon(bowl, col)
	for lx in [-0.22, 0.0, 0.22]:
		ci.draw_line(c + Vector2(lx * s * 0.6, s * 0.18), c + Vector2(lx * s, s * 0.4), col, s * 0.06, true)
	for k in 3:
		var fx := (-0.16 + k * 0.16) * s
		var h := s * (0.36 if k == 1 else 0.24)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(fx - s * 0.08, 0), c + Vector2(fx, -h), c + Vector2(fx + s * 0.08, 0)]), col)


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


## An open hand, palm out, inside a ring.
static func _hand(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c, s * 0.44, 0.0, TAU, 40, col, s * 0.06, true)
	var p := c + Vector2(s * 0.03, s * 0.05)
	var fw := s * 0.055
	# Palm: a rounded block under the fingers.
	ci.draw_rect(Rect2(p + Vector2(-s * 0.12, -s * 0.03), Vector2(s * 0.24, s * 0.12)), col)
	ci.draw_circle(p + Vector2(0, s * 0.09), s * 0.12, col)
	# Four fingers with clear gaps, the middle two tallest.
	var tops: Array[float] = [0.2, 0.27, 0.25, 0.18]
	for i in 4:
		var x := -s * 0.0975 + i * s * 0.065
		var top: float = s * tops[i]
		ci.draw_line(p + Vector2(x, 0), p + Vector2(x, -top), col, fw * 0.8, true)
		ci.draw_circle(p + Vector2(x, -top), fw * 0.4, col)
	# Thumb, angled out to the left.
	var t0 := p + Vector2(-s * 0.1, s * 0.07)
	var t1 := p + Vector2(-s * 0.22, -s * 0.04)
	ci.draw_line(t0, t1, col, fw * 0.85, true)
	ci.draw_circle(t1, fw * 0.42, col)


## A heart outline with a single flame burning inside it.
static func _devotion(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 1.5) * s * 0.022)
	ci.draw_polyline(pts, col, s * 0.065, true)
	# The flame: a round base rising to a flickering tip.
	var r := s * 0.075
	var fc := c + Vector2(0, s * 0.13)
	var f := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		f.append(fc + Vector2(cos(a), sin(a)) * r)
	for q in [Vector2(-1.0, -0.4), Vector2(-0.95, -1.3), Vector2(-0.55, -2.1), Vector2(-0.05, -2.8), Vector2(0.0, -3.6), Vector2(0.4, -2.7), Vector2(0.6, -2.2), Vector2(0.85, -2.7), Vector2(1.05, -1.7), Vector2(1.05, -0.5)]:
		f.append(fc + q * r)
	ci.draw_colored_polygon(f, col)


## An hourglass with speed lines streaming off one side.
static func _swamp(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A bare, crooked dead tree over a pool with ripples.
	var w := s * 0.06
	var b := c + Vector2(-s * 0.05, s * 0.2)
	var m := b + Vector2(s * 0.04, -s * 0.22)
	var t := m + Vector2(-s * 0.03, -s * 0.16)
	ci.draw_line(b, m, col, w * 1.4, true)
	ci.draw_line(m, t, col, w, true)
	ci.draw_line(m, m + Vector2(s * 0.2, -s * 0.12), col, w * 0.8, true)
	ci.draw_line(m + Vector2(s * 0.12, -s * 0.07), m + Vector2(s * 0.16, -s * 0.2), col, w * 0.6, true)
	ci.draw_line(t, t + Vector2(-s * 0.15, -s * 0.1), col, w * 0.7, true)
	ci.draw_line(t, t + Vector2(s * 0.06, -s * 0.14), col, w * 0.6, true)
	for k in 2:
		var rx := s * (0.36 - k * 0.14)
		var pts := PackedVector2Array()
		for i in 33:
			var a := PI * i / 32.0
			pts.append(c + Vector2(cos(a) * rx, s * 0.24 + sin(a) * rx * 0.3))
		ci.draw_polyline(pts, col, w * 0.7, true)


static func _altar(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A stone altar: an overhanging slab on a block, split by a jagged crack,
	# the right end broken off and fallen, a chunk on the ground beside it.
	var w := s * 0.05
	var g := c.y + s * 0.26          # ground
	var sy := c.y - s * 0.14         # slab top
	var by := sy + s * 0.08          # slab underside / block top
	var cx := c.x + s * 0.04         # crack
	var crack := PackedVector2Array([Vector2(cx, sy), Vector2(cx + s * 0.05, by + s * 0.04), Vector2(cx - s * 0.03, by + s * 0.16), Vector2(cx + s * 0.03, g)])
	# left, still standing: slab (overhang) + block
	var left := PackedVector2Array([Vector2(c.x - s * 0.26, g), Vector2(c.x - s * 0.26, by), Vector2(c.x - s * 0.34, by), Vector2(c.x - s * 0.34, sy)])
	left.append_array(crack)
	left.append(Vector2(c.x - s * 0.26, g))
	ci.draw_polyline(left, col, w, true)
	ci.draw_line(Vector2(c.x - s * 0.26, by), Vector2(cx + s * 0.02, by), col, w * 0.7, true)
	# right, broken off: a tilted wedge slumped against the crack
	var o := Vector2(s * 0.05, 0)
	ci.draw_polyline(PackedVector2Array([crack[3] + o, crack[2] + o, crack[1] + o + Vector2(0, s * 0.06),
		Vector2(c.x + s * 0.3, by + s * 0.1), Vector2(c.x + s * 0.27, g), crack[3] + o]), col, w, true)
	# fallen chunk and the floor
	ci.draw_polyline(PackedVector2Array([Vector2(c.x + s * 0.32, g), Vector2(c.x + s * 0.35, g - s * 0.07), Vector2(c.x + s * 0.43, g - s * 0.05), Vector2(c.x + s * 0.44, g)]), col, w * 0.8, true)
	ci.draw_line(Vector2(c.x - s * 0.44, g), Vector2(c.x + s * 0.47, g), col, w * 0.8, true)


static func _ash_cloud(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A billowing cloud of three puffs over a flat base, with ash flecks falling.
	var w := s * 0.06
	var base := c + Vector2(0, s * 0.08)
	ci.draw_arc(base + Vector2(-s * 0.2, -s * 0.02), s * 0.14, PI * 0.5, PI * 1.6, 20, col, w, true)
	ci.draw_arc(base + Vector2(-s * 0.02, -s * 0.12), s * 0.18, PI * 1.05, TAU * 0.97, 24, col, w, true)
	ci.draw_arc(base + Vector2(s * 0.2, -s * 0.02), s * 0.13, PI * 1.45, TAU + PI * 0.5, 20, col, w, true)
	ci.draw_line(base + Vector2(-s * 0.2, s * 0.12), base + Vector2(s * 0.2, s * 0.11), col, w, true)
	for f in [Vector2(-0.16, 0.3), Vector2(0.0, 0.36), Vector2(0.15, 0.29), Vector2(-0.07, 0.43), Vector2(0.09, 0.45)]:
		ci.draw_circle(c + f * s, s * 0.032, col)


static func _hourglass(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.2
	var h := s * 0.3
	var o := c + Vector2(s * 0.08, 0)
	var line := s * 0.06
	ci.draw_line(o + Vector2(-w * 1.25, -h), o + Vector2(w * 1.25, -h), col, line * 1.3, true)   # caps
	ci.draw_line(o + Vector2(-w * 1.25, h), o + Vector2(w * 1.25, h), col, line * 1.3, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(-w, -h), o + Vector2(0, 0), o + Vector2(-w, h)]), col, line, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(w, -h), o + Vector2(0, 0), o + Vector2(w, h)]), col, line, true)
	# Sand: a little left on top, a heap below.
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-w * 0.45, -h * 0.45), o + Vector2(w * 0.45, -h * 0.45), o + Vector2(0, -h * 0.02)]), col)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-w * 0.85, h * 0.9), o + Vector2(w * 0.85, h * 0.9), o + Vector2(0, h * 0.35)]), col)
	for i in 3:   # speed lines
		var y := (i - 1) * h * 0.6
		var x0 := o.x - w * 1.6 - s * (0.02 if i == 1 else 0.06)
		ci.draw_line(Vector2(x0 - s * 0.16, c.y + y), Vector2(x0, c.y + y), col, line * 0.8, true)


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


static func _cook(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A round pot on a little fire, steam curling up.
	var w := s * 0.08
	var pot := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		pot.append(c + Vector2(cos(a) * s * 0.34, sin(a) * s * 0.26 - s * 0.02))
	ci.draw_colored_polygon(pot, col)
	ci.draw_line(c + Vector2(-s * 0.42, -s * 0.02), c + Vector2(s * 0.42, -s * 0.02), col, w, true)
	ci.draw_arc(c + Vector2(-s * 0.36, s * 0.06), s * 0.07, PI * 0.5, PI * 1.5, 8, col, w * 0.6, true)
	ci.draw_arc(c + Vector2(s * 0.36, s * 0.06), s * 0.07, -PI * 0.5, PI * 0.5, 8, col, w * 0.6, true)
	for k in [-1, 1]:
		var x: float = k * s * 0.1
		ci.draw_arc(c + Vector2(x - s * 0.04, -s * 0.2), s * 0.06, PI * 0.5, PI * 1.5, 8, col, w * 0.55, true)
		ci.draw_arc(c + Vector2(x + s * 0.04, -s * 0.32), s * 0.06, -PI * 0.5, PI * 0.5, 8, col, w * 0.55, true)


static func _tinker(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A cog with eight teeth.
	var pts := PackedVector2Array()
	for i in 64:
		var a := TAU * i / 64.0
		var r := s * (0.4 if (i / 4) % 2 == 0 else 0.3)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c, s * 0.12, Color(0, 0, 0, 0.75))


static func _cat(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A cat's head: round face, two pointed ears, dark eyes.
	var f := c + Vector2(0, s * 0.08)
	for k in [-1, 1]:
		ci.draw_colored_polygon(PackedVector2Array([
			f + Vector2(k * s * 0.36, -s * 0.05), f + Vector2(k * s * 0.33, -s * 0.46),
			f + Vector2(k * s * 0.08, -s * 0.24)]), col)
	ci.draw_circle(f, s * 0.32, col)
	var dark := Color(0, 0, 0, 0.7)
	for k in [-1, 1]:
		ci.draw_circle(f + Vector2(k * s * 0.13, -s * 0.04), s * 0.055, dark)
	ci.draw_colored_polygon(PackedVector2Array([f + Vector2(-s * 0.05, s * 0.08),
		f + Vector2(s * 0.05, s * 0.08), f + Vector2(0, s * 0.14)]), dark)


static func _hound(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A paw print.
	var pad := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pad.append(c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.16 + s * 0.14))
	ci.draw_colored_polygon(pad, col)
	for p in [Vector2(-0.27, -0.06), Vector2(-0.1, -0.24), Vector2(0.1, -0.24), Vector2(0.27, -0.06)]:
		ci.draw_circle(c + p * s, s * 0.085, col)


static func _smith(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# An anvil with a hammer raised over it.
	var o := c + Vector2(0, s * 0.12)
	ci.draw_colored_polygon(PackedVector2Array([
		o + Vector2(-s * 0.42, -s * 0.1), o + Vector2(s * 0.3, -s * 0.1), o + Vector2(s * 0.4, -s * 0.02),
		o + Vector2(s * 0.14, 0), o + Vector2(s * 0.1, s * 0.12), o + Vector2(s * 0.24, s * 0.24),
		o + Vector2(-s * 0.24, s * 0.24), o + Vector2(-s * 0.1, s * 0.12), o + Vector2(-s * 0.14, 0),
		o + Vector2(-s * 0.3, 0)]), col)
	var hc := c + Vector2(s * 0.08, -s * 0.3)
	ci.draw_line(hc, hc + Vector2(s * 0.3, s * 0.12), col, s * 0.06, true)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-s * 0.1, -s * 0.12), hc + Vector2(s * 0.04, -s * 0.06),
		hc + Vector2(-s * 0.04, s * 0.12), hc + Vector2(-s * 0.18, s * 0.06)]), col)
