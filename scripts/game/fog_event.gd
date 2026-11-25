extends "res://scripts/game/road_event.gd"
## Road event: Fog Cloud. Press On risks a pothole; Make Camp Early heals but
## may draw a Mist Wisp ambush.


func _ready() -> void:
	_build("Fog Cloud", Color("#bcd2ff"), "A thick fog rolls over the road. Something drifts inside it.", [
		["Press On", "Drive through blind. The stagecoach may hit a pothole (%d%%: −%d flame)."
			% [roundi(Defs.POTHOLE_CHANCE * 100), roundi(Defs.POTHOLE_DAMAGE)], _press_on],
		["Make Camp Early", "Rest until it clears (+%d flame). Mist Wisps may find you first (%d%%)."
			% [roundi(Defs.CAMP_HEAL), roundi(Defs.AMBUSH_CHANCE * 100)], _make_camp],
	])


func _press_on() -> void:
	if Run.rng.randf() < Defs.POTHOLE_CHANCE:
		Run.flame = maxf(1.0, Run.flame - Defs.POTHOLE_DAMAGE)
		AudioDirector.play_sfx("hurt", -2.0)
		_result("Thunk! The stagecoach hits a pothole (−%d flame)." % roundi(Defs.POTHOLE_DAMAGE))
	else:
		_result("The wheels find the road. You come through the fog unharmed.")


func _make_camp() -> void:
	if Run.rng.randf() < Defs.AMBUSH_CHANCE:
		_result("Mist Wisps drift out of the fog toward your camp!", true, "Defend the Camp", "One wave, Mist Wisps only.")
	else:
		Run.flame = minf(Run.max_flame, Run.flame + Defs.CAMP_HEAL)
		_result("A quiet rest. The fog lifts by nightfall (+%d flame)." % roundi(Defs.CAMP_HEAL))


const MIST := Color("#bcd2ff")


## Slow banks of mist rolling across the whole screen.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	for k in 9:
		var speed := 14.0 + 9.0 * (k % 3)
		var w := sz.x * (0.35 + 0.08 * (k % 4))
		var x := fposmod(k * 397.0 + time * speed, sz.x + w * 2.0) - w
		var y := sz.y * (0.12 + 0.11 * k) + sin(time * 0.4 + k) * 14.0
		_soft(ci, Vector2(x, y), Vector2(w * 0.5, 46.0 + 10.0 * (k % 3)), 0.03)


## A road vanishing into fog, with something pale hanging in the murk.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var vp := Vector2(sz.x * 0.5, sz.y * 0.42)
	var steps := 10
	for k in steps:   # the road surface in strips, fading as it recedes
		var a := float(k) / steps
		var b := float(k + 1) / steps
		var ya := lerpf(sz.y, vp.y, a)
		var yb := lerpf(sz.y, vp.y, b)
		var wa := lerpf(200.0, 8.0, a)
		var wb := lerpf(200.0, 8.0, b)
		var fade := 1.0 - a
		ci.draw_colored_polygon(PackedVector2Array([Vector2(vp.x - wa, ya), Vector2(vp.x + wa, ya),
			Vector2(vp.x + wb, yb), Vector2(vp.x - wb, yb)]), Color("#2c2a3a", 0.9 * fade))
		for side in [-1.0, 1.0]:
			ci.draw_line(Vector2(vp.x + side * wa, ya), Vector2(vp.x + side * wb, yb), Color(MIST, 0.4 * fade), 2.5, true)
		if k % 2 == 0:
			ci.draw_line(Vector2(vp.x, ya), Vector2(vp.x, lerpf(ya, yb, 0.6)), Color("#e8d9a8", 0.5 * fade), lerpf(4.0, 1.0, a), true)
	# the wisp, half lost in the fog
	var wp := vp + Vector2(sin(time * 0.7) * 50.0, -34.0 + sin(time * 1.3) * 5.0)
	for r in [26.0, 18.0, 12.0]:
		ci.draw_circle(wp, r, Color(MIST, 0.1))
	ci.draw_circle(wp, 9.0, Color(1, 1, 1, 0.5))
	ci.draw_circle(wp + Vector2(-3.5, -1), 1.6, Color("#1d2233"))
	ci.draw_circle(wp + Vector2(3.5, -1), 1.6, Color("#1d2233"))
	# mist swallowing the far end of the road, and bands drifting in front
	_soft(ci, vp + Vector2(0, -6), Vector2(190.0, 34.0), 0.13)
	for k in 4:
		var x := fposmod(k * 151.0 + time * (18.0 + 6.0 * k), sz.x + 260.0) - 130.0
		var y := sz.y * (0.3 + 0.18 * k)
		_soft(ci, Vector2(x, y), Vector2(130.0, 14.0 + 3.0 * k), 0.09)


## Mist: a few stacked ellipses so the edges feather out.
func _soft(ci: CanvasItem, c: Vector2, r: Vector2, alpha: float) -> void:
	for k in 3:
		var f := 1.0 - k * 0.25
		_ellipse(ci, c, r * f, Color(MIST, alpha))
