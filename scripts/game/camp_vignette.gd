extends RefCounted
## Little animated scenes of each camp for the route map: a moonlit window
## onto the place, with the caravan's fire burning in it. `dawn` warms the
## sky for the camp just cleared. Drawn into a box of size `sz` at the origin.

const SKY_TOP := Color("#0b0e1c")
const SKY_LOW := Color("#1b2038")
const DAWN_TOP := Color("#2a2140")
const DAWN_LOW := Color("#a8634a")
const GROUND := Color("#17161a")
const DIRT := Color("#3b3226")
const RUT := Color("#1f1a16")
const GRASS := Color("#5f6d4f")
const STONE := Color("#4a4650")
const STONE_LIT := Color("#6d6674")
const WATER := Color("#1a3140")
const SHINE := Color("#7fb2c8")
const BOG := Color("#1a2219")
const BOG_GLOW := Color("#b6e36a")
const FIRE := Color("#ffb547")
const FIRE_HOT := Color("#fff0b8")


static func draw(ci: CanvasItem, id: String, sz: Vector2, t: float, dawn := false) -> void:
	_sky(ci, sz, t, dawn)
	match id:
		"hill": _hill(ci, sz, t)
		"cliff": _cliff(ci, sz, t)
		"lake": _lake(ci, sz, t)
		"swamp": _swamp(ci, sz, t)
		"chapel": _chapel(ci, sz, t)
		_: _road(ci, sz, t)
	if dawn:   # first light washes over everything
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(1.0, 0.75, 0.5, 0.08))
	# a thin frame
	ci.draw_rect(Rect2(Vector2(0.5, 0.5), sz - Vector2.ONE), Color(1, 1, 1, 0.12), false, 1.0)


static func _sky(ci: CanvasItem, sz: Vector2, t: float, dawn: bool) -> void:
	var top := DAWN_TOP if dawn else SKY_TOP
	var low := DAWN_LOW if dawn else SKY_LOW
	var bands := 8
	for i in bands:
		var y0 := sz.y * i / bands
		ci.draw_rect(Rect2(0, y0, sz.x, sz.y / bands + 1), top.lerp(low, float(i) / (bands - 1)))
	if dawn:
		return
	for i in 9:   # stars, twinkling
		var p := Vector2(_r(i, 1) * sz.x, _r(i, 2) * sz.y * 0.45)
		var a := 0.35 + 0.35 * sin(t * (1.5 + _r(i, 3) * 2.0) + i)
		ci.draw_circle(p, 0.9, Color(1, 1, 1, a))
	var m := Vector2(sz.x * 0.8, sz.y * 0.18)   # moon
	ci.draw_circle(m, 9.0, Color(0.85, 0.9, 1.0, 0.04))
	ci.draw_circle(m, 7.0, Color(0.85, 0.9, 1.0, 0.04))
	ci.draw_circle(m, 5.0, Color("#e6ecff"))
	ci.draw_circle(m + Vector2(2, -1.5), 4.2, top.lerp(low, 0.15))


## A campfire with a flickering flame and a soft glow on the ground.
static func _fire(ci: CanvasItem, p: Vector2, t: float, s := 1.0) -> void:
	var f := 0.85 + 0.15 * sin(t * 11.0) * sin(t * 7.3)
	for g in 4:   # soft glow, built from faint rings
		ci.draw_circle(p, (13.0 - g * 3.0) * s, Color(FIRE, 0.045 * f))
	ci.draw_line(p + Vector2(-4, 2) * s, p + Vector2(4, 0) * s, Color("#4a3322"), 2.0 * s)
	ci.draw_line(p + Vector2(-4, 0) * s, p + Vector2(4, 2) * s, Color("#5a3d27"), 2.0 * s)
	var h := 7.0 * s * f
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0) * s, p + Vector2(0, -h / s) * s, p + Vector2(3, 0) * s]), FIRE)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-1.4, 0) * s, p + Vector2(0, -h * 0.55 / s) * s, p + Vector2(1.4, 0) * s]), FIRE_HOT)
	for k in 2:   # a spark
		var u := fmod(t * 0.7 + k * 0.5, 1.0)
		ci.draw_circle(p + Vector2(sin(t * 3.0 + k * 2.0) * 3.0, -6.0 - u * 16.0) * s, 0.8 * s, Color(FIRE, 1.0 - u))


static func _tuft(ci: CanvasItem, p: Vector2, h: float, i: int) -> void:
	for k in 4:
		var lean := (_r(i, 10 + k) - 0.5) * 5.0
		var hh := h * (0.6 + 0.5 * _r(i, 20 + k))
		var x := p.x + (k - 1.5) * 1.6
		ci.draw_line(Vector2(x, p.y), Vector2(x + lean, p.y - hh), GRASS.lerp(Color("#8e9a6c"), _r(i, 30 + k) * 0.6), 1.2)


# ------------------------------------------------------------------ camps
## Old Road: a wagon trail running off to the horizon, a signpost by the fire.
static func _road(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var hy := sz.y * 0.55
	ci.draw_rect(Rect2(0, hy, sz.x, sz.y - hy), GROUND)
	var vp := Vector2(sz.x * 0.62, hy)
	var steps := 10
	for i in steps:
		var f0 := float(i) / steps
		var f1 := float(i + 1) / steps
		var a := _road_pt(vp, sz, f0)
		var b := _road_pt(vp, sz, f1)
		var w0 := lerpf(30.0, 2.0, f0)
		var w1 := lerpf(30.0, 2.0, f1)
		ci.draw_colored_polygon(PackedVector2Array([a - Vector2(w0, 0), a + Vector2(w0, 0), b + Vector2(w1, 0), b - Vector2(w1, 0)]), DIRT)
		for side in [-0.5, 0.5]:
			ci.draw_line(a + Vector2(w0 * side, 0), b + Vector2(w1 * side, 0), RUT, 1.0)
	for i in 7:
		var f := _r(i, 4) * 0.85
		var p := _road_pt(vp, sz, f) + Vector2((1 if i % 2 else -1) * (lerpf(30.0, 2.0, f) + 4 + _r(i, 5) * 10), 0)
		_tuft(ci, p, lerpf(7.0, 2.0, f), i)
	# signpost
	var s := Vector2(sz.x * 0.2, sz.y * 0.8)
	ci.draw_line(s, s + Vector2(0, -24), Color("#5a4632"), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([s + Vector2(-2, -24), s + Vector2(14, -24), s + Vector2(18, -20.5), s + Vector2(14, -17), s + Vector2(-2, -17)]), Color("#6b5239"))
	_fire(ci, Vector2(sz.x * 0.36, sz.y * 0.86), t)


static func _road_pt(vp: Vector2, sz: Vector2, f: float) -> Vector2:
	return Vector2(lerpf(sz.x * 0.45, vp.x, f) + 10.0 * f * f, lerpf(sz.y, vp.y, f))


## Hillside Clearing: a round hill with a trail spiralling up to the fire.
static func _hill(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var far := PackedVector2Array([Vector2(0, sz.y * 0.62)])
	for i in 9:
		var x := sz.x * i / 8.0
		far.append(Vector2(x, sz.y * (0.6 - 0.06 * sin(i * 1.7))))
	far.append(Vector2(sz.x, sz.y))
	far.append(Vector2(0, sz.y))
	ci.draw_colored_polygon(far, Color("#141520"))
	var c := Vector2(sz.x * 0.5, sz.y * 1.18)
	var r := Vector2(sz.x * 0.52, sz.y * 0.75)
	var pts := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, Color("#1e1d20"))
	ci.draw_polyline(pts, Color(GRASS, 0.5), 1.2, true)
	# the trail winds up the hill
	var trail := PackedVector2Array()
	for i in 41:
		var u := float(i) / 40.0
		var a := lerpf(0.15, TAU * 1.15, u)
		trail.append(c + Vector2(cos(a) * r.x * 0.8 * (1.0 - u * 0.82), -r.y * (0.08 + 0.82 * u) + sin(a) * 6.0 * (1.0 - u)))
	ci.draw_polyline(trail, DIRT, 3.0, true)
	ci.draw_polyline(trail, Color(RUT, 0.7), 1.0, true)
	for i in 6:
		_tuft(ci, c + Vector2((_r(i, 6) - 0.5) * r.x * 1.4, -r.y * (0.1 + 0.25 * _r(i, 7))), 5.0, i)
	_fire(ci, trail[40] + Vector2(0, -1), t)


## Cliff Edge: the camp at the brink, a drop and far peaks beyond.
static func _cliff(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var peaks := PackedVector2Array([Vector2(sz.x * 0.35, sz.y)])
	for i in 7:
		var x := lerpf(sz.x * 0.35, sz.x, i / 6.0)
		peaks.append(Vector2(x, sz.y * (0.55 + (0.12 if i % 2 else 0.0) - 0.05 * _r(i, 8))))
	peaks.append(Vector2(sz.x, sz.y))
	ci.draw_colored_polygon(peaks, Color("#1f2338"))
	for i in 3:   # mist down in the gorge
		var y := sz.y * (0.78 + 0.07 * i)
		var x := sz.x * 0.45 + fmod(t * (6.0 + i * 3.0) + i * 40.0, sz.x * 0.7)
		ci.draw_rect(Rect2(x - 30, y, 60, 3), Color(0.74, 0.82, 1.0, 0.06))
		ci.draw_rect(Rect2(x - 60 - sz.x * 0.35, y + 4, 50, 3), Color(0.74, 0.82, 1.0, 0.05))
	var edge := PackedVector2Array([Vector2(0, sz.y * 0.62), Vector2(sz.x * 0.44, sz.y * 0.6),
		Vector2(sz.x * 0.47, sz.y * 0.68), Vector2(sz.x * 0.43, sz.y * 0.8), Vector2(sz.x * 0.46, sz.y),
		Vector2(0, sz.y)])
	ci.draw_colored_polygon(edge, Color("#1f1d22"))
	ci.draw_polyline(PackedVector2Array([edge[1], edge[2], edge[3], edge[4]]), STONE, 1.5, true)
	ci.draw_line(edge[0], edge[1], Color(GRASS, 0.6), 1.5)
	for i in 4:
		_tuft(ci, Vector2(sz.x * (0.05 + 0.1 * i), sz.y * 0.615), 4.0, i)
	ci.draw_circle(Vector2(sz.x * 0.36, sz.y * 0.66), 2.2, STONE_LIT)   # a stone at the brink
	_fire(ci, Vector2(sz.x * 0.22, sz.y * 0.78), t)


## Quiet Lakeside: still water under the moon, its path rippling, mist rising.
static func _lake(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var hy := sz.y * 0.5
	ci.draw_rect(Rect2(0, hy - 4, sz.x, 6), Color("#141520"))   # far shore
	ci.draw_rect(Rect2(0, hy, sz.x, sz.y - hy), WATER)
	for i in 6:   # the moon's path, broken by ripples
		var y := hy + 4 + i * 6.0
		var w := 6.0 + i * 3.0 + 2.0 * sin(t * 2.0 + i)
		ci.draw_line(Vector2(sz.x * 0.8 - w, y), Vector2(sz.x * 0.8 + w, y), Color(SHINE, 0.55 - i * 0.07), 1.2)
	for i in 3:
		var x := fmod(t * (4.0 + i * 2.0) + i * 47.0, sz.x + 60.0) - 30.0
		ci.draw_rect(Rect2(x - 25, hy + 6 + i * 9, 50, 3), Color(0.8, 0.86, 1.0, 0.07))
	var shore := PackedVector2Array([Vector2(0, sz.y * 0.72), Vector2(sz.x * 0.35, sz.y * 0.8),
		Vector2(sz.x * 0.62, sz.y), Vector2(0, sz.y)])
	ci.draw_colored_polygon(shore, GROUND)
	ci.draw_polyline(PackedVector2Array([shore[0], shore[1], shore[2]]), Color(SHINE, 0.18), 1.0, true)
	for i in 5:   # reeds
		var p := Vector2(sz.x * (0.28 + 0.05 * i), sz.y * (0.78 + 0.02 * i))
		var sway := sin(t * 1.4 + i) * 1.5
		ci.draw_line(p, p + Vector2(sway, -10 - 4 * _r(i, 9)), GRASS, 1.2)
	_fire(ci, Vector2(sz.x * 0.14, sz.y * 0.86), t)


## Swamp Turnpike: a causeway between murky pools, a dead tree, will-o'-wisps.
static func _swamp(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var hy := sz.y * 0.55
	ci.draw_rect(Rect2(0, hy, sz.x, sz.y - hy), BOG)
	for i in 3:
		var c := Vector2(sz.x * (0.15 + 0.33 * i), sz.y * (0.68 + 0.1 * (i % 2)))
		_oval(ci, c, Vector2(16 + 6 * i, 4 + i), Color("#152025"))
		ci.draw_line(c + Vector2(-6, 0), c + Vector2(2, 0), Color(SHINE, 0.2), 1.0)
	var road := PackedVector2Array([Vector2(sz.x * 0.4, sz.y), Vector2(sz.x * 0.54, hy), Vector2(sz.x * 0.57, hy), Vector2(sz.x * 0.62, sz.y)])
	ci.draw_colored_polygon(road, DIRT)
	# dead tree
	var b := Vector2(sz.x * 0.82, sz.y * 0.72)
	var col := Color("#2a2622")
	ci.draw_line(b, b + Vector2(1, -34), col, 3.0)
	ci.draw_line(b + Vector2(1, -22), b + Vector2(-10, -32), col, 1.6)
	ci.draw_line(b + Vector2(1, -28), b + Vector2(10, -38), col, 1.4)
	ci.draw_line(b + Vector2(-6, -29), b + Vector2(-9, -38), col, 1.0)
	for i in 4:   # wisps bobbing over the pools
		var p := Vector2(sz.x * (0.12 + 0.22 * i), sz.y * (0.5 + 0.05 * (i % 2)) + sin(t * 1.6 + i * 1.9) * 3.0)
		var a := 0.55 + 0.35 * sin(t * 2.3 + i)
		ci.draw_circle(p, 5.0, Color(BOG_GLOW, 0.12 * a))
		ci.draw_circle(p, 1.6, Color(BOG_GLOW, a))
	_fire(ci, Vector2(sz.x * 0.56, sz.y * 0.86), t)


## Sunken Chapel: a broken arch and a leaning wall sunk to the knees, a bell's glow.
static func _chapel(ci: CanvasItem, sz: Vector2, t: float) -> void:
	var hy := sz.y * 0.7
	ci.draw_rect(Rect2(0, hy, sz.x, sz.y - hy), GROUND)
	var c := Vector2(sz.x * 0.56, hy + 6)
	var w := sz.x * 0.2
	var h := sz.y * 0.46
	# the arch: two pillars and a pointed top, the right half broken away
	ci.draw_rect(Rect2(c.x - w - 6, c.y - h, 7, h), STONE)
	ci.draw_rect(Rect2(c.x + w - 1, c.y - h * 0.62, 7, h * 0.62), STONE)
	var arch := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		arch.append(Vector2(lerpf(c.x - w - 2, c.x + 2, u), c.y - h - sin(u * PI * 0.5) * 18.0))
	ci.draw_polyline(arch, STONE_LIT, 4.0, true)
	var g := 0.5 + 0.5 * sin(t * 1.3)   # the bell, glowing faintly in the arch
	var bell := Vector2(c.x - w * 0.35, c.y - h * 0.62)
	ci.draw_circle(bell, 10.0, Color(FIRE, 0.07 + 0.06 * g))
	ci.draw_colored_polygon(PackedVector2Array([bell + Vector2(-4, 4), bell + Vector2(-3, -3), bell + Vector2(0, -5),
		bell + Vector2(3, -3), bell + Vector2(4, 4)]), Color("#9a7d4a"))
	# a tilted wall stub and some rubble
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sz.x * 0.08, hy + 2), Vector2(sz.x * 0.12, hy - 18), Vector2(sz.x * 0.24, hy - 14), Vector2(sz.x * 0.24, hy + 2)]), Color("#3d3a42"))
	for i in 5:
		ci.draw_circle(Vector2(sz.x * (0.3 + 0.12 * i), hy + 3 + 2 * _r(i, 11)), 1.6 + _r(i, 12) * 1.4, STONE)
	for i in 4:
		_tuft(ci, Vector2(sz.x * (0.06 + 0.24 * i), hy + 1), 5.0, i)
	_fire(ci, Vector2(sz.x * 0.3, sz.y * 0.88), t)


static func _oval(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


## A fixed pseudo-random number in 0..1 for (i, salt).
static func _r(i: int, salt: int) -> float:
	var v := sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return v - floor(v)
