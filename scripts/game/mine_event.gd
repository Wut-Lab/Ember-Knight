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
			_haze(ci, Vector2(sz.x * (0.1 + 0.12 * k), sz.y * 0.4), Vector2(260.0, 120.0), DUST, 0.03 * _caved)


## A 2.5D scene: a forest clearing seen from a little above, its ground
## receding toward a mine mouth dug into a hill at the back. Rails run from the
## mouth toward us, widening as they come; the cart, trees and pickaxe shrink
## with distance and sit on soft ground shadows. Fog hangs in the far trees.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var g := 1.0 - 0.85 * _caved
	var hb := sz.y * 0.4                       # the far edge of the clearing
	var gy := func(f: float) -> float: return lerpf(hb, sz.y + 16.0, f)      # depth 0 far .. 1 near
	var sc := func(f: float) -> float: return lerpf(0.42, 1.5, f)             # size at that depth
	var cx := sz.x * 0.5
	var shake := Vector2.ZERO
	var since := _t - _swing
	if since >= 0.0 and since < 0.4:
		shake = Vector2(sin(since * 80.0), cos(since * 70.0)) * 1.5 * (1.0 - since / 0.4)
	# Far forest: two rows of silhouettes at the back of the clearing, hazed.
	Woods._silhouettes(ci, sz, hb + 2.0, 0.75, Color("#1c2532"), 5.0, time)
	_haze(ci, Vector2(cx, hb), Vector2(sz.x * 0.6, 22.0), Color("#8fa6c8"), 0.05)
	Woods._silhouettes(ci, sz, hb + 10.0, 1.0, Color("#141b21"), 29.0, time)
	# The clearing floor: a wide oval of ground seen at an angle, feathered at
	# its edges so it melts into the dark, lighter toward us.
	for k in 6:
		var f := 1.0 - k * 0.1
		_ellipse(ci, Vector2(cx, sz.y + 4.0), Vector2(sz.x * 0.62 * f, (sz.y + 4.0 - hb) * 1.05 * f), Color("#2a231c", 0.22 if k == 0 else 0.16))
	for k in 6:   # the mine's warm light pooled on the ground in front of it
		_ellipse(ci, Vector2(cx, gy.call(0.2)), Vector2(130.0 - k * 18.0, 22.0 - k * 3.0), Color(EMBER, 0.03 * g))
	# The hill at the back, a rounded mound with a moonlit crown and a shadowed
	# front slope, with the mine mouth cut into the front.
	var hill_base: float = gy.call(0.12)
	var mound := PackedVector2Array()
	for k in 21:
		var a := PI + PI * k / 20.0
		mound.append(Vector2(cx + cos(a) * 150.0, hill_base + sin(a) * 58.0 + sin(k * 1.7) * 2.0))
	ci.draw_colored_polygon(mound, Color("#2a2420"))
	var top := PackedVector2Array()
	for k in 21:
		var a := PI * 1.12 + PI * 0.76 * k / 20.0
		top.append(Vector2(cx + cos(a) * 130.0, hill_base - 8.0 + sin(a) * 50.0))
	ci.draw_polyline(top, Color("#4a4038"), 2.0, true)   # moonlit crown
	for k in 3:
		_ellipse(ci, Vector2(cx, hill_base - 4.0), Vector2(150.0 - k * 20.0, 14.0), Color(0, 0, 0, 0.12))   # shadowed foot
	for k in 7:   # boulders on the mound, lit on top
		var a := PI * 1.15 + PI * 0.7 * k / 6.0
		var b := Vector2(cx + cos(a) * 110.0, hill_base + sin(a) * 36.0 + 6.0)
		if absf(b.x - cx) < 34.0:
			continue
		_ellipse(ci, b, Vector2(9, 6), Color("#221c18"))
		_ellipse(ci, b - Vector2(0, 2.5), Vector2(6.5, 3), Color("#3c332c"))
	# The mouth: a dark opening with depth, the inner walls veined with ember ore.
	var mw := 34.0
	var mh := 40.0
	var mb := Vector2(cx, hill_base + 2.0) + shake
	ci.draw_colored_polygon(PackedVector2Array([mb + Vector2(-mw, 0), mb + Vector2(mw, 0), mb + Vector2(mw, -mh), mb + Vector2(-mw, -mh)]), Color("#120d0a"))
	ci.draw_colored_polygon(PackedVector2Array([mb + Vector2(-mw * 0.5, -3), mb + Vector2(mw * 0.5, -3), mb + Vector2(mw * 0.5, -mh * 0.72), mb + Vector2(-mw * 0.5, -mh * 0.72)]), Color("#040302"))
	for side in [-1.0, 1.0]:   # receding side walls
		ci.draw_colored_polygon(PackedVector2Array([mb + Vector2(side * mw, 0), mb + Vector2(side * mw * 0.5, -3), mb + Vector2(side * mw * 0.5, -mh * 0.72), mb + Vector2(side * mw, -mh)]), Color("#1a120d"))
		for v in 2:
			var a := mb + Vector2(side * mw * 0.78, -10 - v * 13)
			var pulse := (0.55 + 0.45 * sin(time * 2.0 + v + side)) * g
			ci.draw_polyline(PackedVector2Array([a, a + Vector2(side * -4, -4), a + Vector2(side * -2, -8)]), Color(ORE, 0.85 * pulse), 2.0, true)
			ci.draw_circle(a, 3.0, Color(ORE, 0.18 * pulse))
	# Timber frame: square posts showing a front and an inner side face, and a
	# lintel showing its top.
	var wood := Color("#4a3220")
	var lit := Color("#c07a40").lerp(Color("#3a2618"), _caved)
	for side in [-1.0, 1.0]:
		var px: float = mb.x + side * (mw + 3.0)
		ci.draw_rect(Rect2(px - 4, mb.y - mh - 4, 8, mh + 4), wood)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(px - side * 4, mb.y), Vector2(px - side * 7, mb.y - 3), Vector2(px - side * 7, mb.y - mh - 6), Vector2(px - side * 4, mb.y - mh - 4)]), Color(lit, 0.75))
	var lt := mb + Vector2(0, -mh - 4)
	ci.draw_colored_polygon(PackedVector2Array([lt + Vector2(-mw - 12, 0), lt + Vector2(mw + 12, 0), lt + Vector2(mw + 9, -4), lt + Vector2(-mw - 9, -4)]), Color("#6a4a2e"))   # top face
	ci.draw_rect(Rect2(lt + Vector2(-mw - 12, 0), Vector2(2 * mw + 24, 7)), wood)
	ci.draw_rect(Rect2(lt + Vector2(-mw - 12, 6), Vector2(2 * mw + 24, 1.5)), Color(lit, 0.6))
	if _caved > 0.02:   # rubble spilling out of the mouth
		for k in 14:
			var r := 4.0 + fposmod(k * 7.0, 6.0)
			var p := mb + Vector2(-mw * 0.9 + fposmod(k * 23.0, mw * 1.8), -r - fposmod(k * 17.0, mh * 0.8) * _caved + 2.0)
			_ellipse(ci, p, Vector2(r, r * 0.75), Color("#3a322c").lerp(Color("#5a4e44"), fposmod(k * 0.37, 1.0)))
	# Dust trickling from the lintel: more the deeper you've dug.
	for k in 2 + _digs * 3:
		var life := fposmod(time * 0.9 + k * 0.37, 1.0)
		ci.draw_circle(lt + Vector2(-mw + fposmod(k * 29.0, mw * 2.0), 8.0 + life * 26.0), 1.1, Color(DUST, 0.6 * (1.0 - life)))
	# Trees standing in the clearing, back to front: [x, depth, kind, side]
	var trees := [[40.0, 0.18, 0, -1.0], [430.0, 0.2, 1, 1.0], [96.0, 0.33, 1, -1.0], [392.0, 0.36, 0, 1.0]]
	for tr in trees:
		_tree(ci, Vector2(tr[0], gy.call(tr[1])), sc.call(tr[1]), tr[2], tr[3], g, time)
	# Rails from the mouth toward us: converging lines and ties spaced by depth.
	var r0 := mb + Vector2(0, -1)
	var near_x := cx + 70.0
	for side in [-1.0, 1.0]:
		ci.draw_line(r0 + Vector2(side * 9, 0), Vector2(near_x + side * 44.0, sz.y + 10), Color("#6a6058"), 2.0, true)
	for k in 9:
		var f := pow((k + 0.5) / 9.0, 1.5)
		var p := r0.lerp(Vector2(near_x, sz.y + 10), f)
		var half := lerpf(13.0, 56.0, f)
		ci.draw_line(p + Vector2(-half, 0), p + Vector2(half, 0), Color("#3a2a1c"), lerpf(1.5, 5.0, f))
	# The cart, partway down the rails: a box seen from above at an angle,
	# its load glowing in the open top.
	var cf := 0.55 - _banked * 0.35
	var cp := r0.lerp(Vector2(near_x, sz.y + 10), cf)
	var cs := lerpf(0.5, 1.2, cf) * (1.0 - _banked * 0.3)
	_ellipse(ci, cp + Vector2(0, 4) * cs, Vector2(30, 6) * cs, Color(0, 0, 0, 0.4))
	for w in [-14.0, 14.0]:
		ci.draw_circle(cp + Vector2(w, 0) * cs, 5.0 * cs, Color("#1a1410"))
	var fl := cp + Vector2(-24, -6) * cs
	var fr := cp + Vector2(24, -6) * cs
	var tl := cp + Vector2(-24, -24) * cs
	var trr := cp + Vector2(24, -24) * cs
	var bl := cp + Vector2(-19, -34) * cs
	var br := cp + Vector2(19, -34) * cs
	ci.draw_colored_polygon(PackedVector2Array([fl, fr, trr, tl]), Color("#3a2e24"))           # front face
	ci.draw_colored_polygon(PackedVector2Array([tl, trr, br, bl]), Color("#120d0a"))           # open top (inside)
	if _pile > 0.0:
		var load := clampf(_pile / 40.0, 0.0, 1.0)
		for k in 7:
			var e := tl.lerp(trr, (k + 0.5) / 7.0).lerp(bl.lerp(br, (k + 0.5) / 7.0), 0.5) + Vector2(0, -load * 4.0 * cs * sin(k * 0.9 + 0.5))
			ci.draw_circle(e, (2.5 + load * 1.5) * cs, Color(ORE.lerp(Color("#ffd27a"), (k % 3) / 3.0), 0.85 * (0.7 + 0.3 * sin(time * 3.0 + k))))
		for k in 5:
			ci.draw_circle(tl.lerp(br, 0.5), (8.0 + k * 7.0 * (0.6 + load)) * cs, Color(EMBER, 0.05))
	ci.draw_polyline(PackedVector2Array([tl, trr, br, bl, tl]), Color("#8a6a4a"), 1.5, true)   # rim
	ci.draw_line(fl, fr, Color("#2a2018"), 1.5, true)
	# The pickaxe, stuck in the ground by the near rail.
	var lift := 0.0
	if since >= 0.0 and since < 0.4:
		lift = sin(since / 0.4 * PI) * 0.5
	var pk := Vector2(cx - 120, gy.call(0.8))
	_ellipse(ci, pk + Vector2(4, 1), Vector2(16, 3), Color(0, 0, 0, 0.4))
	var head := pk + Vector2(18, -64).rotated(-lift)
	ci.draw_line(pk, head, Color("#6a4a2e"), 4.0, true)
	ci.draw_line(pk + Vector2(1, 0), head + Vector2(1, 0), Color("#a07a50", 0.5), 1.2, true)
	var dir := (head - pk).normalized().orthogonal()
	ci.draw_line(head - dir * 18.0, head + dir * 15.0 + (head - pk).normalized() * 5.0, Color("#8a8f94"), 4.0, true)
	ci.draw_line(head - dir * 18.0 + Vector2(0, -1.5), head + dir * 15.0 + Vector2(0, -1.5), Color("#c8ccd0", 0.6), 1.2, true)
	# Near trees framing the scene, partly cut off at the edges.
	_tree(ci, Vector2(-6, gy.call(0.92)), sc.call(0.92), 0, -1.0, g, time)
	_tree(ci, Vector2(sz.x + 4, gy.call(0.95)), sc.call(0.95), 0, 1.0, g, time)
	_tree(ci, Vector2(sz.x - 40, gy.call(0.7)), sc.call(0.7), 1, 1.0, g, time)
	# Low fog drifting over the clearing floor, and dancing lights.
	for k in 3:
		var x := fposmod(k * 190.0 + time * (6.0 + k * 2.0), sz.x + 300.0) - 150.0
		_haze(ci, Vector2(x, gy.call(0.25 + k * 0.22)), Vector2(110.0 + k * 30.0, 9.0 + k * 3.0), Color("#8fa6c8"), 0.035)
	for k in 7:
		var c := Vector2(fposmod(k * 71.0 + 30.0, sz.x), gy.call(0.1 + fposmod(k * 0.29, 0.7)) - 20.0 - fposmod(k * 13.0, 26.0))
		var p := c + Vector2(sin(time * (0.7 + k * 0.13) + k) * 22.0, sin(time * (1.3 + k * 0.11) + k * 2.0) * 10.0)
		var near := clampf(1.0 - absf(p.x - cx) / 160.0, 0.0, 1.0)
		var col := Color("#cfe2ff").lerp(Color("#ffd27a"), near)
		var tw := 0.5 + 0.5 * sin(time * 3.1 + k * 1.7)
		for j in 3:
			ci.draw_circle(p, 3.0 + j * 4.0, Color(col, 0.04 * tw))
		ci.draw_circle(p, 1.6, Color(col, 0.55 * tw))


## A tree standing on the clearing at `base`, scaled by depth: a pine (kind 0,
## stacked drooping tiers) or an oak (kind 1, lumpy crown). Dark on the side
## away from the mine, warm-lit on the side facing it; a soft ground shadow.
static func _tree(ci: CanvasItem, base: Vector2, s: float, kind: int, side: float, g: float, time: float) -> void:
	var warm := Color("#5a4326").lerp(Color("#1a1f1a"), 1.0 - g)
	_ellipse(ci, base + Vector2(-side * 6.0 * s, 2.0 * s), Vector2(26.0 * s, 5.0 * s), Color(0, 0, 0, 0.35))
	var sway := sin(time * 0.5 + base.x) * 0.8 * s
	if kind == 0:
		var h := 92.0 * s
		ci.draw_rect(Rect2(base.x - 2.5 * s, base.y - h * 0.22, 5.0 * s, h * 0.22), Color("#1a120c"))
		for t in 5:
			var ty := base.y - h * (0.16 + t * 0.17)
			var tw := h * (0.3 - t * 0.05)
			var tip := Vector2(base.x + sway * (t + 1) * 0.4, ty - h * 0.2)
			var l := Vector2(base.x - tw, ty + h * 0.04)
			var r := Vector2(base.x + tw, ty + h * 0.04)
			var front := Vector2(base.x - side * tw * 0.15, ty + h * 0.07)   # the tier's near edge, curving toward us
			ci.draw_colored_polygon(PackedVector2Array([l, front, r, tip]), Color("#162219"))
			var outer := r if side > 0 else l
			ci.draw_colored_polygon(PackedVector2Array([front, outer, tip]), Color("#0b110d"))
			ci.draw_line(l if side > 0 else r, tip, Color(warm, 0.9), maxf(1.0, 1.4 * s), true)
	else:
		var h := 70.0 * s
		ci.draw_rect(Rect2(base.x - 3.5 * s, base.y - h * 0.45, 7.0 * s, h * 0.45), Color("#1e150e"))
		ci.draw_rect(Rect2(base.x + (-3.5 if side > 0 else 1.0) * s, base.y - h * 0.45, 2.5 * s, h * 0.45), Color(warm, 0.6))
		var c := Vector2(base.x + sway, base.y - h * 0.72)
		for b in 7:
			var off := Vector2(cos(b * 1.3) * h * 0.27, sin(b * 1.9) * h * 0.13)
			_ellipse(ci, c + off, Vector2(h * 0.24, h * 0.17), Color("#122018"))
		for b in 4:   # shadowed underside, lit lobes on the mine side
			_ellipse(ci, c + Vector2(side * h * 0.1, h * 0.12), Vector2(h * 0.3, h * 0.08), Color(0, 0, 0, 0.12))
		for b in 3:
			var off := Vector2(-side * h * (0.12 + b * 0.08), -h * 0.1 + b * h * 0.06)
			_ellipse(ci, c + off, Vector2(h * 0.13, h * 0.09), Color(warm, 0.55))


## Hazy fog: many faint, feathered layers so the edges melt into the night.
static func _haze(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, alpha: float) -> void:
	for k in 7:
		var f := 1.0 - k * 0.11
		_ellipse(ci, c, r * f, Color(col, alpha * 0.5))
