extends "res://scripts/game/road_event.gd"
## Road event: The Old Ember Mine (repeatable, push your luck). Dig for
## burning ore: each dig adds more flame to the pile but is less safe. Leave
## any time to keep the pile; a cave-in loses it and costs flame besides.

var _digs := 0
var _pile := 0.0
var _caved := 0.0       ## 0..1: rocks fall, dust rises, the veins go dark
var _caved_to := 0.0
var _swing := -10.0     ## time of the last pick swing (dust shakes loose)
var _banked := 0.0      ## 0..1: the cart rolls off with its load


func _ready() -> void:
	_build("The Old Ember Mine", EMBER, "A collapsed mine shaft glows beside the road. Veins of ember ore still burn in the rock.", [
		["Dig", _dig_desc(), _dig],
		["Walk On", "Leave the old shaft alone.", _walk_on],
	])


func _safe() -> float:
	return Defs.MINE_SAFE[mini(_digs, Defs.MINE_SAFE.size() - 1)]


func _gain() -> float:
	return Defs.MINE_GAIN + _digs * Defs.MINE_GAIN_STEP


func _dig_desc() -> String:
	return "%d%% safe: +%d flame onto the pile.\nA cave-in loses the pile and −%d flame." % [roundi(_safe() * 100), roundi(_gain()), roundi(Defs.MINE_CAVE_IN)]


func _dig() -> void:
	_swing = _t
	AudioDirector.play_sfx("place", -4.0)
	if Run.rng.randf() >= _safe():
		_caved_to = 1.0
		Run.flame = maxf(1.0, Run.flame - Defs.MINE_CAVE_IN)
		var lost := " The pile is buried with it." if _pile > 0.0 else ""
		_pile = 0.0
		_result("The timbers groan, then give. Rock thunders down and you scramble out choking on dust.%s (−%d flame)" % [lost, roundi(Defs.MINE_CAVE_IN)])
		return
	_pile += _gain()
	_digs += 1
	if _digs >= Defs.MINE_SAFE.size():   # the vein runs out
		_bank("The last of the vein comes free and the rock beyond is cold.")
		return
	_reoffer("You pry loose a glowing chunk. The pile in the cart burns warm: %d flame so far. Dust trickles from the beams." % roundi(_pile), [
		["Dig Deeper", _dig_desc(), _dig],
		["Take It and Go", "Load up and leave: +%d flame." % roundi(_pile), _bank.bind("You haul the cart out into the night air.")],
	])


func _bank(text: String) -> void:
	Run.flame = minf(Run.max_flame, Run.flame + _pile)
	_banked = 0.01
	_result("%s (+%d flame)" % [text, roundi(_pile)])


func _walk_on() -> void:
	_result("You leave the shaft to its embers. Somewhere inside, a timber creaks.")


const EMBER := Color("#ff9a4c")
const ORE := Color("#ff7a2a")
const DUST := Color("#9a8a78")
const Woods := preload("res://scripts/game/woods_event.gd")   # shared tree silhouettes and fog


func _process(delta: float) -> void:
	_caved = lerpf(_caved, _caved_to, minf(1.0, delta * 2.5))
	if _banked > 0.0:
		_banked = minf(1.0, _banked + delta * 0.5)
	super(delta)


## A warm glow from below, sparks lifting, and dust motes; a dust cloud
## rolls across after a cave-in.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var g := 1.0 - 0.8 * _caved
	for k in 6:
		_ellipse(ci, Vector2(sz.x * 0.5, sz.y + 40.0), Vector2(sz.x * (0.22 + 0.09 * k), 200.0 + 60.0 * k), Color(EMBER, 0.018 * g))
	for k in 16:   # sparks
		var life := fposmod(time * (0.07 + 0.02 * (k % 4)) + k * 0.151, 1.0)
		var p := Vector2(fposmod(k * 211.0, sz.x) + sin(time + k) * 20.0, sz.y * (1.0 - life))
		ci.draw_circle(p, 1.5, Color(EMBER, 0.45 * (1.0 - life) * g))
	for k in 20:   # dust motes
		var p := Vector2(fposmod(k * 67.0 + time * 6.0, sz.x), fposmod(k * 113.0 + time * 4.0, sz.y))
		ci.draw_circle(p, 1.2, Color(DUST, 0.12))
	if _caved > 0.02:
		for k in 8:
			_ellipse(ci, Vector2(sz.x * (0.1 + 0.12 * k), sz.y * 0.4), Vector2(260.0, 120.0), Color(DUST, 0.05 * _caved))


## The mine mouth in a rocky hillside: a timber frame with lit edges, ember
## veins pulsing in the dark shaft, rails running out to a little cart whose
## load glows brighter as the pile grows, a pickaxe, and dust shaken loose
## with every swing. A cave-in fills the mouth with rubble.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var ground := sz.y - 10.0
	var cx := sz.x * 0.5 - 30.0
	var g := 1.0 - 0.85 * _caved
	var shake := Vector2.ZERO
	var since := _t - _swing
	if since >= 0.0 and since < 0.4:
		shake = Vector2(sin(since * 80.0), cos(since * 70.0)) * 2.0 * (1.0 - since / 0.4)
	# The forest it hides in: two rows of pine and oak silhouettes behind the
	# hill, the far row paler in the haze, with fog drifting between.
	Woods._silhouettes(ci, sz, ground - 40.0, 1.0, Color("#1a2230"), 5.0, time)
	Woods._fog(ci, sz, ground - 70.0, time * 0.9, 0.04)
	Woods._silhouettes(ci, sz, ground - 22.0, 1.45, Color("#12181d"), 29.0, time)
	# The hillside: a lumpy rock mound, warm where the mine's glow reaches.
	var hill := PackedVector2Array([Vector2(-10, ground)])
	for k in range(1, 24):   # (skip the ends: they'd repeat the corner points)
		var f := k / 24.0
		var x := lerpf(-10.0, sz.x + 10.0, f)
		var y := ground - sin(f * PI) * 120.0 - sin(f * 23.0) * 6.0 - sin(f * 9.0 + 1.0) * 8.0
		hill.append(Vector2(x, y))
	hill.append(Vector2(sz.x + 10, ground))
	ci.draw_colored_polygon(hill, Color("#2a2420"))
	var crest := hill.slice(1, hill.size() - 1)
	ci.draw_polyline(crest, Color("#4a4038"), 2.0, true)   # moonlit ridge
	for k in 4:   # darker toward the foot of the slope, like rock in shadow
		var band := PackedVector2Array()
		for p in crest:
			band.append(Vector2(p.x, lerpf(p.y, ground, 0.55 + k * 0.1)))
		band.append(Vector2(sz.x + 10, ground))
		band.append(Vector2(-10, ground))
		ci.draw_colored_polygon(band, Color(0, 0, 0, 0.12))
	for k in 6:   # warm glow on the rock round the mouth
		_ellipse(ci, Vector2(cx, ground - 50), Vector2(150.0 - k * 22.0, 70.0 - k * 10.0), Color(EMBER, 0.022 * g))
	for k in 9:   # boulders bulging from the slope, lit on top
		var bx := fposmod(k * 61.0 + 20.0, sz.x)
		if absf(bx - cx) < 70.0:
			continue
		var by := ground - 8.0 - fposmod(k * 29.0, 60.0) * sin(bx / sz.x * PI)
		var br := 8.0 + fposmod(k * 7.0, 10.0)
		_ellipse(ci, Vector2(bx, by), Vector2(br * 1.3, br), Color("#26201c"))
		_ellipse(ci, Vector2(bx - 1, by - br * 0.35), Vector2(br * 0.9, br * 0.45), Color("#3a302a"))
	for k in 14:   # dry grass along the crest
		var f := (k + 0.5) / 14.0
		var x := lerpf(10.0, sz.x - 10.0, f)
		var y := ground - sin(f * PI) * 120.0 - sin(f * 23.0) * 6.0 - sin(f * 9.0 + 1.0) * 8.0
		for b in 3:
			ci.draw_line(Vector2(x + b * 3, y + 2), Vector2(x + b * 3 + (b - 1) * 3, y - 6), Color("#3a3a24"), 1.2, true)
	ci.draw_rect(Rect2(0, ground - 4, sz.x, 14), Color("#191512"))
	# The shaft: a dark mouth that runs back into the hill, ember veins in its walls.
	var mouth := Rect2(cx - 44 + shake.x, ground - 92 + shake.y, 88, 92)
	ci.draw_rect(mouth, Color("#140f0c"))
	var inner := Rect2(cx - 24 + shake.x, ground - 62 + shake.y, 48, 56)
	ci.draw_rect(inner, Color("#050403"))
	for c in [[mouth.position, inner.position], [mouth.position + Vector2(mouth.size.x, 0), inner.position + Vector2(inner.size.x, 0)]]:
		ci.draw_line(c[0], c[1], Color("#0a0806"), 2.0, true)
	for k in 6:   # veins, pulsing, on the side walls and roof
		var a := mouth.position + Vector2(4 + (k % 2) * 66, 16 + (k / 2) * 24)
		var pulse := (0.55 + 0.45 * sin(time * 2.0 + k * 1.3)) * g
		ci.draw_polyline(PackedVector2Array([a, a + Vector2(5, 6), a + Vector2(9, 2), a + Vector2(14, 10)]), Color(ORE, 0.8 * pulse), 2.0, true)
		ci.draw_circle(a + Vector2(9, 2), 4.0, Color(ORE, 0.15 * pulse))
	ci.draw_polyline(PackedVector2Array([mouth.position + Vector2(30, 6), mouth.position + Vector2(40, 12), mouth.position + Vector2(52, 7)]), Color(ORE, 0.6 * g * (0.6 + 0.4 * sin(time * 1.7))), 2.0, true)
	# Timber frame: posts and lintel, firelit on their inner edges.
	var wood := Color("#4a3220")
	var lit := Color("#c07a40").lerp(Color("#3a2618"), _caved)
	for side in [-1.0, 1.0]:
		var px: float = cx + side * 48.0 + shake.x
		ci.draw_rect(Rect2(px - 6, ground - 98 + shake.y, 12, 98), wood)
		ci.draw_rect(Rect2(px - 6 if side > 0 else px + 3, ground - 98 + shake.y, 3, 98), Color(lit, 0.7))
	ci.draw_rect(Rect2(cx - 60 + shake.x, ground - 108 + shake.y, 120, 14), wood)
	ci.draw_rect(Rect2(cx - 60 + shake.x, ground - 96 + shake.y, 120, 2), Color(lit, 0.6))
	# Rubble filling the mouth after a cave-in.
	if _caved > 0.02:
		for k in 14:
			var r := 6.0 + fposmod(k * 7.0, 9.0)
			var p := Vector2(cx - 40 + fposmod(k * 23.0, 80.0), ground - r - fposmod(k * 17.0, 70.0) * _caved)
			_ellipse(ci, p, Vector2(r, r * 0.8), Color("#3a322c").lerp(Color("#5a4e44"), fposmod(k * 0.37, 1.0)))
	# Rails running out of the mine toward us: narrow at the mouth, wider near.
	var r0 := Vector2(cx, ground - 6)
	var r1 := Vector2(cx + 170, ground + 10)
	for side in [-1.0, 1.0]:
		ci.draw_line(r0 + Vector2(side * 10, 0), r1 + Vector2(side * 26, 0), Color("#6a6058"), 2.0, true)
	for k in 7:
		var f := k / 6.0
		var p := r0.lerp(r1, f)
		var half := lerpf(14.0, 32.0, f)
		ci.draw_line(p + Vector2(-half, 1), p + Vector2(half, 1), Color("#3a2a1c"), lerpf(2.0, 4.0, f))
	# The cart: a 2.5D box on the rails, its load glowing with the pile.
	var cart := Vector2(cx + 120, ground + 4) + Vector2(_banked * 140.0, _banked * 6.0)
	var load := clampf(_pile / 40.0, 0.0, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([cart + Vector2(-24, -24), cart + Vector2(24, -24), cart + Vector2(30, -30), cart + Vector2(-18, -30)]), Color("#5a4a3c"))   # rim/top
	if _pile > 0.0:
		for k in 7:
			var e := cart + Vector2(-16 + k * 6, -27 - load * 6.0 * sin(k * 0.9 + 0.5))
			ci.draw_circle(e, 4.0 + load * 2.0, Color(ORE.lerp(Color("#ffd27a"), (k % 3) / 3.0), 0.85 * (0.7 + 0.3 * sin(time * 3.0 + k))))
		for k in 5:
			ci.draw_circle(cart + Vector2(0, -30), 10.0 + k * 8.0 * (0.6 + load), Color(EMBER, 0.05))
	ci.draw_colored_polygon(PackedVector2Array([cart + Vector2(-24, -24), cart + Vector2(24, -24), cart + Vector2(20, -4), cart + Vector2(-20, -4)]), Color("#3a2e24"))      # front
	ci.draw_line(cart + Vector2(-24, -24), cart + Vector2(24, -24), Color("#8a6a4a"), 2.0, true)
	for w in [-12.0, 12.0]:
		ci.draw_circle(cart + Vector2(w, -2), 5.0, Color("#1a1410"))
		ci.draw_circle(cart + Vector2(w, -2), 2.0, Color("#5a5048"))
	# The pickaxe, leaning on the frame (lifting mid-swing).
	var lift := 0.0
	if since >= 0.0 and since < 0.4:
		lift = sin(since / 0.4 * PI) * 0.6
	var pk := Vector2(cx - 74, ground)
	var head := pk + Vector2(14, -54).rotated(-lift)
	ci.draw_line(pk, head, Color("#6a4a2e"), 3.0, true)
	var dir := (head - pk).normalized().orthogonal()
	ci.draw_line(head - dir * 14.0, head + dir * 12.0 + (head - pk).normalized() * 4.0, Color("#8a8f94"), 3.0, true)
	# Trees closing in on either side, in front: 2.5D pines and an oak,
	# shadowed on the outside and touched by the mine's glow on the inside.
	_near_pine(ci, Vector2(28, ground + 6), 96.0, -1.0, g, time)
	_near_oak(ci, Vector2(70, ground + 8), 62.0, -1.0, g, time)
	_near_pine(ci, Vector2(sz.x - 24, ground + 6), 104.0, 1.0, g, time)
	_near_pine(ci, Vector2(sz.x - 66, ground + 8), 74.0, 1.0, g, time)
	Woods._fog(ci, sz, ground - 2.0, time * 0.7 + 3.0, 0.045)
	# Faint lights dancing round the clearing: little wandering motes, warm
	# near the mine, cool out among the trees.
	for k in 7:
		var c := Vector2(fposmod(k * 71.0 + 30.0, sz.x), ground - 30.0 - fposmod(k * 23.0, 70.0))
		var p := c + Vector2(sin(time * (0.7 + k * 0.13) + k) * 22.0, sin(time * (1.3 + k * 0.11) + k * 2.0) * 12.0)
		var near := clampf(1.0 - absf(p.x - cx) / 160.0, 0.0, 1.0)
		var col := Color("#cfe2ff").lerp(Color("#ffd27a"), near)
		var tw := 0.5 + 0.5 * sin(time * 3.1 + k * 1.7)
		for j in 3:
			ci.draw_circle(p, 3.0 + j * 4.0, Color(col, 0.04 * tw))
		ci.draw_circle(p, 1.6, Color(col, 0.55 * tw))
	# Dust trickling from the lintel: more the deeper you've dug.
	var trickle := 2 + _digs * 3
	for k in trickle:
		var life := fposmod(time * 0.9 + k * 0.37, 1.0)
		var p := Vector2(cx - 50 + fposmod(k * 29.0, 100.0), ground - 94 + life * 60.0)
		ci.draw_circle(p, 1.3, Color(DUST, 0.6 * (1.0 - life)))


## A near pine at the edge of the clearing: a trunk and drooping tiers with a
## dark outer side and a warm-lit inner side (side = -1 on the left).
static func _near_pine(ci: CanvasItem, base: Vector2, h: float, side: float, g: float, time: float) -> void:
	var dark := Color("#0c1110")
	var mid := Color("#152019")
	var warm := Color("#4a3a22").lerp(Color("#1a1f1a"), 1.0 - g)
	ci.draw_rect(Rect2(base.x - 3, base.y - h * 0.25, 6, h * 0.25), Color("#1a120c"))
	for t in 5:
		var ty := base.y - h * (0.16 + t * 0.17)
		var tw := h * (0.3 - t * 0.05)
		var tip := Vector2(base.x + sin(time * 0.5 + base.x) * 0.8 * (t + 1), ty - h * 0.2)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - tw, ty + h * 0.03), Vector2(base.x + tw, ty + h * 0.03), tip]), mid)
		var outer := Vector2(base.x + side * tw, ty + h * 0.03)
		var inner := Vector2(base.x - side * tw, ty + h * 0.03)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x, ty + h * 0.03), outer, tip]), dark)
		ci.draw_line(inner, tip, Color(warm, 0.9), 1.5, true)


## A near oak: a short trunk and a broad lumpy crown, lit on its inner side.
static func _near_oak(ci: CanvasItem, base: Vector2, h: float, side: float, g: float, time: float) -> void:
	var warm := Color("#4a3a22").lerp(Color("#1a1f1a"), 1.0 - g)
	ci.draw_rect(Rect2(base.x - 4, base.y - h * 0.45, 8, h * 0.45), Color("#1e150e"))
	ci.draw_rect(Rect2(base.x - 4 if side > 0 else base.x + 1, base.y - h * 0.45, 3, h * 0.45), Color(warm, 0.6))
	var c := Vector2(base.x + sin(time * 0.4 + base.x) * 1.0, base.y - h * 0.7)
	for b in 6:
		var off := Vector2(cos(b * 1.3) * h * 0.26, sin(b * 1.9) * h * 0.14)
		_ellipse(ci, c + off, Vector2(h * 0.24, h * 0.18), Color("#122018"))
	for b in 3:   # the lit inner lobes
		var off := Vector2(-side * h * (0.1 + b * 0.08), -h * 0.08 + b * h * 0.07)
		_ellipse(ci, c + off, Vector2(h * 0.14, h * 0.1), Color(warm, 0.55))
