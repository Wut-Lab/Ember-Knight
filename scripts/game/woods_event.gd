extends "res://scripts/game/road_event.gd"
## Road event: Lights in the Trees (repeatable). Follow the lights deep for an
## Uncommon-or-better Oath (or get lost and miss the next dawn's Oath), follow
## a little way for a small cache of flame (or lose a little), or stay on the road.

var _found := 0.0      ## 0..1: the cache glows open
var _found_to := 0.0
var _lost := 0.0       ## 0..1: the lights wink out, the trees close in
var _lost_to := 0.0
var _drift := 0.0      ## 0..1: lights pulled deeper once you follow


func _ready() -> void:
	_build("Lights in the Trees", PALE, "Pale lights drift between the trees beside the road, bobbing just out of reach, as if waiting for you to follow.", [
		["Follow Them Deep", "%d%%: a hidden cache. Swear 1 of %d Oaths (Uncommon+).\nElse lost: no Oath at the next dawn."
			% [roundi(Defs.WOODS_DEEP_CHANCE * 100), Defs.WOODS_OATHS], _deep],
		["A Little Way", "%d%%: a small cache, +%d flame.\nOtherwise you're turned around: −%d flame."
			% [roundi(Defs.WOODS_NEAR_CHANCE * 100), roundi(Defs.WOODS_NEAR_FLAME), roundi(Defs.WOODS_NEAR_LOSS)], _near],
		["Stay on the Road", "Let the lights drift. Nothing gained, nothing lost.", _stay],
	])


func _deep() -> void:
	_drift = 1.0
	if Run.rng.randf() >= Defs.WOODS_DEEP_CHANCE:
		Run.woods_lost = true
		_lost_to = 1.0
		_result("The lights wink out one by one. You wander until the sky greys and stumble into camp at last. (No Oath pick at the next dawn.)")
		return
	var offer := Defs.woods_oaths(Run.rng, Run.oaths, Defs.WOODS_OATHS)
	_found_to = 1.0
	AudioDirector.play_sfx("chime", -4.0)
	if offer.is_empty():
		Run.heal(Defs.WOODS_NEAR_FLAME)
		_result("Deep in the trees, a mossy chest: you know every oath it holds already. You take the embers inside. (+%d flame)" % roundi(Defs.WOODS_NEAR_FLAME))
		return
	var opts := []
	for id in offer:
		var o: Dictionary = Defs.OATHS[id]
		opts.append([o["name"], "%s Oath:  %s" % [Defs.RARITY[o.get("rarity", "uncommon")]["name"], o["short"]], _swear.bind(id)])
	_reoffer("Deep in the trees the lights gather round a mossy chest. Inside, old oaths, still warm. Swear one.", opts)


func _swear(id: String) -> void:
	Run.oaths.append(id)
	_result("You swear the %s. The lights scatter back toward the road, and you follow them home." % Defs.OATHS[id]["name"])


func _near() -> void:
	_drift = 0.5
	if Run.rng.randf() < Defs.WOODS_NEAR_CHANCE:
		Run.heal(Defs.WOODS_NEAR_FLAME)
		_found_to = 0.6
		_result("Just off the road, under a root: a traveller's tinderbox, still warm. (+%d flame)" % roundi(Defs.WOODS_NEAR_FLAME))
	else:
		Run.flame = maxf(1.0, Run.flame - Defs.WOODS_NEAR_LOSS)
		_lost_to = 0.6
		_result("The lights slip away and the road is gone. It's a cold hour before you find it again. (−%d flame)" % roundi(Defs.WOODS_NEAR_LOSS))


func _stay() -> void:
	_result("You keep to the road. Behind you, the lights drift deeper into the trees and are gone.")


const PALE := Color("#cfe2ff")
const WISP := Color("#d8e8ff")
const GOLD := Color("#ffd27a")
const MOON := Color("#8fa6c8")


func _process(delta: float) -> void:
	_found = lerpf(_found, _found_to, minf(1.0, delta * 1.5))
	_lost = lerpf(_lost, _lost_to, minf(1.0, delta * 0.8))
	super(delta)


## Low mist among the trees, fireflies, and the lights' cool glow drifting
## across the whole screen; darker when you're lost, warmer at a find.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	for k in 7:   # mist banks low on the ground
		var x := fposmod(k * 250.0 + time * (6.0 + k), sz.x + 400.0) - 200.0
		for j in 3:
			_ellipse(ci, Vector2(x, sz.y - 50.0 - (k % 3) * 34.0), Vector2(250.0 - j * 60.0, 34.0 - j * 8.0), Color(MOON, 0.012))
	for k in 5:   # fog clouds floating by at mid height, flattened by the angle
		var x := fposmod(k * 330.0 + time * (9.0 + k * 2.0), sz.x + 600.0) - 300.0
		var y := sz.y * (0.3 + 0.12 * k)
		for j in 5:
			_ellipse(ci, Vector2(x + j * 18.0, y - j * 3.0), Vector2(220.0 - j * 34.0, 40.0 - j * 6.0), Color(MOON, 0.012))
	var lit := 1.0 - _lost
	for k in 6:   # stray lights wandering the screen
		var p := Vector2(fposmod(k * 223.0 + sin(time * 0.21 + k) * 160.0, sz.x), sz.y * (0.2 + 0.6 * fposmod(k * 0.37, 1.0)) + cos(time * 0.3 + k * 1.7) * 40.0)
		for j in 4:
			ci.draw_circle(p, 10.0 + j * 9.0, Color(WISP, 0.012 * lit))
		ci.draw_circle(p, 2.5, Color(WISP, 0.25 * lit))
	for k in 14:  # fireflies
		var p := Vector2(fposmod(k * 97.0 + time * 9.0 * (1 + k % 3), sz.x), sz.y * (0.45 + 0.45 * fposmod(k * 0.61, 1.0)) + sin(time * 1.3 + k) * 14.0)
		var g := 0.5 + 0.5 * sin(time * 2.7 + k * 1.3)
		ci.draw_circle(p, 1.6, Color(0.85, 1.0, 0.5, 0.45 * g * lit))
	if _found > 0.02:
		for k in 8:
			_ellipse(ci, Vector2(sz.x * 0.5, sz.y * 0.3), Vector2(80.0 + k * 50.0, 50.0 + k * 30.0), Color(GOLD, 0.006 * _found))
	if _lost > 0.02:
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.35 * _lost))


## The edge of the woods: trunks in moonlit 2.5D with roots spreading at their
## feet, a faint path of paler grass leading in, the pale lights bobbing
## between the trees, and (if found) a glowing chest among the roots.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var ground := sz.y - 10.0
	var cx := sz.x * 0.5
	# Depth: two rows of oak and pine silhouettes behind the trunks, the far row
	# paler in the haze, with fog drifting between the rows.
	_silhouettes(ci, sz, ground - 22.0, 1.15, Color("#1c2532").lerp(Color("#0c0f14"), _lost * 0.7), 11.0, time)
	_fog(ci, sz, ground - 58.0, time, 0.045)
	_silhouettes(ci, sz, ground - 10.0, 1.55, Color("#131a20").lerp(Color("#080a0c"), _lost * 0.7), 37.0, time)
	_fog(ci, sz, ground - 30.0, time * 1.3 + 5.0, 0.06)
	# Canopy: overlapping clumps of dark leaves across the top.
	for k in 16:
		var x := fposmod(k * 37.0, sz.x + 40.0) - 20.0
		var r := 22.0 + fposmod(k * 13.0, 18.0)
		_ellipse(ci, Vector2(x, 4.0 + fposmod(k * 7.0, 16.0)), Vector2(r, r * 0.6), Color("#0a0e10") if k % 2 else Color("#0e1512"))
	# Ground, and a faint path of paler grass leading in.
	ci.draw_rect(Rect2(0, ground - 6, sz.x, 16), Color("#121812"))
	for k in 4:
		_ellipse(ci, Vector2(cx, ground + 2 - k * 5), Vector2(46.0 - k * 9.0, 7.0 - k), Color("#1e2a1c", 0.7))
	# Trunks, back row first (thinner, darker), then the front row: tapered,
	# leaning a little, shadowed on the left and moonlit on the right.
	var trees := [[-196, 11, 0, 2], [-126, 9, 0, -3], [-60, 8, 0, 2], [62, 8, 0, -2], [126, 10, 0, 3], [194, 12, 0, -2],
		[-232, 22, 1, -4], [-150, 17, 1, 3], [-88, 15, 1, -2], [90, 16, 1, 2], [160, 19, 1, -3], [236, 23, 1, 4]]
	for tr in trees:
		var x: float = cx + tr[0]
		var w: float = tr[1]
		var front: bool = tr[2] == 1
		var lean: float = tr[3]
		var base_y := ground + (4.0 if front else -10.0)
		var dark := Color("#0e1214") if front else Color("#0b0e10")
		var mid := Color("#1b2327") if front else Color("#141a1d")
		var rim := MOON.lerp(Color("#0e1214"), 0.35 if front else 0.6)
		rim = rim.lerp(Color("#05070a"), _lost * 0.7)
		var bl := Vector2(x - w * 0.5, base_y - w * 0.4)
		var br := Vector2(x + w * 0.5, base_y - w * 0.4)
		var tl := Vector2(x - w * 0.3 + lean, -10)
		var trp := Vector2(x + w * 0.3 + lean, -10)
		# roots flaring out at the base
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 1.5, base_y + 1), bl, br, Vector2(x + w * 1.6, base_y + 1), Vector2(x + w * 0.5, base_y + 3), Vector2(x - w * 0.5, base_y + 3)]), dark)
		ci.draw_colored_polygon(PackedVector2Array([bl, br, trp, tl]), mid)
		ci.draw_colored_polygon(PackedVector2Array([bl, bl.lerp(br, 0.38), tl.lerp(trp, 0.38), tl]), dark)
		ci.draw_line(br + Vector2(-1, 0), trp + Vector2(-1, 0), Color(rim, 0.8), 2.0, true)
		# a branch or two reaching up into the canopy
		var by := 30.0 + fposmod(x * 0.7, 30.0)
		var at := tl.lerp(bl, by / base_y).lerp(trp.lerp(br, by / base_y), 0.5)
		var side := 1.0 if fposmod(x, 2.0) < 1.0 else -1.0
		ci.draw_line(at, at + Vector2(side * w * 1.4, -w * 1.6), mid, maxf(2.0, w * 0.25), true)
		for b in 3:   # bark lines
			var yy := 24.0 + b * 30.0 + fposmod(x, 17.0)
			var cxx := lerpf(x + lean, x, yy / base_y)
			ci.draw_line(Vector2(cxx - w * 0.15, yy), Vector2(cxx + w * 0.1, yy + 9), Color(dark, 0.8), 1.0, true)
	_fog(ci, sz, ground - 4.0, time * 0.8 + 11.0, 0.05)   # a low wisp in front of the roots
	# The cache, glowing among the roots at the end of the path.
	if _found > 0.02:
		var c := Vector2(cx, ground - 20)
		for k in 6:
			ci.draw_circle(c + Vector2(0, -6), 10.0 + k * 8.0, Color(GOLD, 0.05 * _found))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -8), c + Vector2(16, -8), c + Vector2(12, -14), c + Vector2(-12, -14)]), Color("#5a4228"))   # top
		ci.draw_rect(Rect2(c + Vector2(-16, -8), Vector2(32, 14)), Color("#3a2a1a"))                                         # front
		ci.draw_rect(Rect2(c + Vector2(-16, -8), Vector2(32, 14)), Color("#7a6a50"), false, 1.0)
		ci.draw_line(c + Vector2(-8, -8), c + Vector2(-8, 6), Color("#6a6a6a"), 2.0)                                           # iron bands
		ci.draw_line(c + Vector2(8, -8), c + Vector2(8, 6), Color("#6a6a6a"), 2.0)
		ci.draw_line(c + Vector2(-14, -9), c + Vector2(14, -9), Color(GOLD, 0.8 * _found), 2.0, true)                          # light under the lid
		_ellipse(ci, c + Vector2(-12, 5), Vector2(6, 3), Color("#2e4a2a"))                                                    # moss
	# The lights, bobbing between the trunks and drawn deeper when followed.
	var vis := 1.0 - _lost
	for k in 7:
		var wink := clampf(vis * 7.0 - k, 0.0, 1.0)   # they go out one by one
		if wink <= 0.0:
			continue
		var home := Vector2(cx + (k - 3) * 52.0, ground - 52.0 - (k % 3) * 16.0)
		var p := home.lerp(Vector2(cx + (k - 3) * 10.0, ground - 40.0), _drift * 0.6)
		if _found > 0.02:
			p = p.lerp(Vector2(cx + cos(time + k) * 26.0, ground - 40.0 + sin(time * 1.3 + k) * 10.0), _found)
		p += Vector2(sin(time * 0.9 + k * 1.7) * 6.0, sin(time * 1.4 + k) * 5.0)
		var col := WISP.lerp(GOLD, _found * 0.5)
		for j in 5:
			ci.draw_circle(p, 4.0 + j * 4.0, Color(col, 0.05 * wink))
		ci.draw_circle(p, 3.0, Color(col, 0.9 * wink))


## A row of tree silhouettes (pines and oaks mixed) standing on base_y; scale
## shrinks the far row. seed shifts which tree stands where.
static func _silhouettes(ci: CanvasItem, sz: Vector2, base_y: float, scale: float, col: Color, seed: float, time: float) -> void:
	var x := -20.0 + fposmod(seed * 7.0, 30.0)
	var k := 0
	while x < sz.x + 30.0:
		var h := (46.0 + fposmod(seed * 3.0 + k * 17.0, 30.0)) * scale
		var pine := fposmod(seed + k * 5.0, 3.0) < 1.8
		var sway := sin(time * 0.4 + k + seed) * 1.0
		if pine:   # a pine: stacked, drooping tiers on a thin trunk
			ci.draw_line(Vector2(x, base_y), Vector2(x, base_y - h * 0.3), col, 2.0 * scale)
			for t in 4:
				var ty := base_y - h * (0.18 + t * 0.2)
				var tw := h * (0.34 - t * 0.07)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - tw, ty + h * 0.05), Vector2(x + tw, ty + h * 0.05), Vector2(x + sway * (t + 1) * 0.3, ty - h * 0.24)]), col)
		else:      # an oak: a short thick trunk and a broad, lumpy crown
			ci.draw_rect(Rect2(x - 3.0 * scale, base_y - h * 0.4, 6.0 * scale, h * 0.4), col)
			var c := Vector2(x + sway, base_y - h * 0.62)
			for b in 5:
				var off := Vector2(cos(b * 1.3 + seed) * h * 0.24, sin(b * 1.9 + seed) * h * 0.12)
				_ellipse(ci, c + off, Vector2(h * 0.24, h * 0.18), col)
		x += (26.0 + fposmod(seed * 11.0 + k * 13.0, 22.0)) * scale
		k += 1


## Soft fog clouds drifting along at height y: layered flat ellipses, the
## same height of ground so they read as lying in the scene, not on the screen.
static func _fog(ci: CanvasItem, sz: Vector2, y: float, time: float, alpha: float) -> void:
	for k in 4:
		var x := fposmod(k * 151.0 + time * (5.0 + k * 1.5), sz.x + 220.0) - 110.0
		var w := 50.0 + fposmod(k * 37.0, 40.0)
		# a puffy cloud: a few flattened lobes, wider at the base
		for j in 6:
			var lx := x + (j - 2.5) * w * 0.28
			var ly := y - absf(sin(j * 1.7 + k)) * 7.0 + sin(time * 0.3 + k) * 2.0
			_ellipse(ci, Vector2(lx, ly), Vector2(w * 0.32, 7.0 + (j % 3) * 2.0), Color(MOON.lightened(0.35), alpha))
		_ellipse(ci, Vector2(x, y + 4.0), Vector2(w * 1.0, 5.0), Color(MOON.lightened(0.35), alpha * 0.8))
