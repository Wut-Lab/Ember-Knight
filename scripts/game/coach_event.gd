extends "res://scripts/game/road_event.gd"
## Road event: Abandoned Stagecoach (once per run). Search the wreck and it
## turns up one random die; taking it means its lost passengers follow you
## (extra Wisps every wave tonight). Or ride on and leave it be.

var _found := ""         ## die id turned up by the search ("" = none yet / nothing)
var _searched := false
var _haunt := 0.0        ## 0..1: pale lights in the coach windows once the die is taken
var _haunt_to := 0.0


func _ready() -> void:
	_build("Abandoned Stagecoach", PALE, "In the distance, a stagecoach lies broken down by the road. No horses. No driver. Its lantern still swings.", [
		["Search It", "Climb aboard and check it for supplies.", _search],
		["Ride On", "Leave it be and press on to camp.", _ride_on],
	])


func _search() -> void:
	_searched = true
	var offer := Defs.dawn_dice(Run.rng, Run.pool)
	if offer.is_empty():
		_result("Mouldy sacks and a cracked teacup. Whatever was here, someone got to it first.")
		return
	_found = offer[0]
	var die: Dictionary = Defs.DICE[_found]
	AudioDirector.play_sfx("dice_roll", -4.0)
	_reoffer("Under a torn seat, wrapped in an old coat: a %s. The coach creaks. Something inside it is still waiting for its stop." % die["name"], [
		["Take the %s" % die["name"], "New die:  %s.\nIts lost passengers will follow you: tonight every wave brings +%d Wisps."
			% [_tally(die["faces"]), Defs.COACH_HAUNT_SPIRITS], _take],
		["Leave It", "Put it back where you found it. Some things are left behind for a reason.", _leave],
	])


func _take() -> void:
	Run.pool.append(_found)
	Run.coach_haunt = true
	_haunt_to = 1.0
	_result("You tuck the %s into your bag. As you ride off, pale lights flicker on in the coach windows... and follow." % Defs.DICE[_found]["name"])


func _leave() -> void:
	_found = ""
	_result("You set it back under the seat and close the door gently. The lantern stops swinging.")


func _ride_on() -> void:
	_result("You give the wreck a wide berth. Its lantern swings after you for a long while.")


static func _tally(faces: Array) -> String:
	var parts := []
	for f in Defs.DIE_FACES:
		for up in ["++", "+", ""]:
			var n := faces.count(f + up)
			if n > 0:
				parts.append("%d %s%s" % [n, Defs.FACE_INFO[f]["name"], up])
	return ", ".join(parts)


const PALE := Color("#c9d6ee")
const LAMP := Color("#ffc46b")
const GHOST := Color("#bfe0ff")


func _process(delta: float) -> void:
	_haunt = lerpf(_haunt, _haunt_to, minf(1.0, delta * 0.9))
	super(delta)


## Cold moonlight from above, low fog along the ground, a few dead leaves
## tumbling past; once the die is taken, pale lights drift at the edges.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	for k in 14:   # moonlight wash from the top right
		_ellipse(ci, Vector2(sz.x * 0.78, -60.0), Vector2(sz.x * (0.12 + 0.04 * k), 120.0 + 26.0 * k), Color(PALE, 0.007))
	for k in 7:   # fog banks along the bottom, soft-edged
		var x := fposmod(k * 260.0 + time * (10.0 + k * 2.0), sz.x + 400.0) - 200.0
		for j in 4:
			_ellipse(ci, Vector2(x, sz.y - 40.0 - (k % 3) * 30.0), Vector2(260.0 - j * 50.0, 46.0 - j * 9.0), Color(PALE, 0.012))
	for k in 10:  # dead leaves
		var life := fposmod(time * (0.05 + 0.012 * (k % 4)) + k * 0.173, 1.0)
		var p := Vector2(sz.x * (1.1 - life * 1.3), sz.y * (0.3 + 0.5 * fposmod(k * 0.37, 1.0)) + sin(time * 1.5 + k) * 20.0)
		var r := 3.0 + (k % 3)
		var a := time * 3.0 + k
		ci.draw_line(p - Vector2(cos(a), sin(a)) * r, p + Vector2(cos(a), sin(a)) * r, Color("#6a4a2e", 0.55), 2.5, true)
	if _haunt > 0.02:
		for k in 8:
			var p := Vector2(fposmod(k * 191.0, sz.x), sz.y * (0.25 + 0.6 * fposmod(k * 0.41, 1.0)))
			p += Vector2(sin(time * 0.6 + k) * 30.0, cos(time * 0.5 + k * 1.3) * 20.0)
			var g := _haunt * (0.5 + 0.5 * sin(time * 1.7 + k))
			ci.draw_circle(p, 14.0, Color(GHOST, 0.06 * g))
			ci.draw_circle(p, 4.0, Color(GHOST, 0.35 * g))


## The wreck: a coach slumped on a broken axle, one wheel lying in the grass,
## its door hanging open, a lantern swinging from the box; spilled crates.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var ground := sz.y - 8.0
	var cx := sz.x * 0.5
	# Ground and the shadow under the wreck.
	_ellipse(ci, Vector2(cx, ground), Vector2(190, 12), Color(0, 0, 0, 0.45))
	ci.draw_line(Vector2(cx - 230, ground), Vector2(cx + 230, ground), Color("#2a2420"), 3.0)
	for k in 14:   # grass tufts
		var x := cx - 220 + k * 34.0 + fposmod(k * 13.0, 11.0)
		for b in 3:
			ci.draw_line(Vector2(x + b * 3, ground), Vector2(x + b * 3 + (b - 1) * 3, ground - 7 - (k + b) % 4 * 2), Color("#3c4a2a"), 1.5, true)
	# The fallen wheel, flat on the ground in front.
	_ellipse(ci, Vector2(cx + 118, ground - 4), Vector2(30, 9), Color("#3b2a1c"))
	_ellipse(ci, Vector2(cx + 118, ground - 5), Vector2(24, 6), Color("#1c1612"))
	for k in 6:
		var a := TAU * k / 6.0
		ci.draw_line(Vector2(cx + 118, ground - 5), Vector2(cx + 118, ground - 5) + Vector2(cos(a) * 24, sin(a) * 6), Color("#5a3e26"), 2.0, true)
	# Spilled crates and a sack.
	ci.draw_rect(Rect2(cx - 160, ground - 22, 26, 22), Color("#4a3624"))
	ci.draw_rect(Rect2(cx - 160, ground - 22, 26, 22), Color("#2a1e14"), false, 2.0)
	ci.draw_line(Vector2(cx - 160, ground - 22), Vector2(cx - 134, ground), Color("#2a1e14"), 2.0)
	ci.draw_rect(Rect2(cx - 128, ground - 14, 18, 14), Color("#3f2e20"))
	_ellipse(ci, Vector2(cx - 98, ground - 7), Vector2(13, 8), Color("#5a5040"))
	# The coach, slumped toward its broken corner.
	ci.draw_set_transform(Vector2(cx, ground - 24), deg_to_rad(6.0), Vector2.ONE)   # slumped onto the broken front
	var body := Color("#3a2a22")
	var trim := Color("#6a4a30")
	# remaining back wheel
	ci.draw_arc(Vector2(-62, 4), 22.0, 0.0, TAU, 28, Color("#2a1e16"), 5.0, true)
	for k in 8:
		var a := TAU * k / 8.0 + 0.3
		ci.draw_line(Vector2(-62, 4), Vector2(-62, 4) + Vector2(cos(a), sin(a)) * 20.0, Color("#4a3424"), 2.0, true)
	# broken front axle stub
	ci.draw_line(Vector2(54, 4), Vector2(74, 12), Color("#2a1e16"), 5.0, true)
	# cabin
	var cab := PackedVector2Array([Vector2(-86, -6), Vector2(70, -6), Vector2(78, -62), Vector2(-92, -62)])
	ci.draw_colored_polygon(cab, body)
	ci.draw_polyline(PackedVector2Array([cab[0], cab[1], cab[2], cab[3], cab[0]]), trim, 2.0, true)
	ci.draw_rect(Rect2(-96, -72, 178, 10), Color("#2a1e18"))     # roof
	ci.draw_rect(Rect2(-80, -84, 120, 12), Color("#1f1712"), false, 2.0)   # luggage rack
	ci.draw_rect(Rect2(-60, -82, 34, 10), Color("#3a2c20"))       # a trunk left on top
	# windows: dark, until the passengers wake
	for wx in [-72.0, 30.0]:
		var win := Rect2(wx, -52, 30, 22)
		ci.draw_rect(win, Color("#120e10").lerp(GHOST, 0.55 * _haunt))
		ci.draw_rect(win, trim, false, 2.0)
		if _haunt > 0.02:
			ci.draw_circle(win.get_center(), 18.0, Color(GHOST, 0.12 * _haunt))
	# door hanging open on one hinge
	var door := PackedVector2Array([Vector2(-26, -8), Vector2(6, -10), Vector2(10, -56), Vector2(-22, -54)])
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-22, -8), Vector2(10, -8), Vector2(10, -56), Vector2(-22, -56)]), Color("#0c0a0b"))
	if _searched and _found != "":   # the die, glowing in the doorway
		var dp := Vector2(-6, -20)
		var pulse := 0.6 + 0.4 * sin(time * 3.0)
		ci.draw_circle(dp, 16.0, Color(LAMP, 0.18 * pulse))
		ci.draw_rect(Rect2(dp - Vector2(7, 7), Vector2(14, 14)), Color("#f3e9dc"))
		ci.draw_circle(dp, 2.0, Color("#3a2a22"))
	# the door, swung out on its hinge toward us
	var dc := Color("#33251e")
	var dpoly := PackedVector2Array([Vector2(-22, -8), Vector2(-22, -56), Vector2(-46, -62), Vector2(-46, -2)])
	ci.draw_colored_polygon(dpoly, dc)
	ci.draw_polyline(PackedVector2Array([dpoly[0], dpoly[1], dpoly[2], dpoly[3], dpoly[0]]), trim, 2.0, true)
	ci.draw_rect(Rect2(-42, -50, 14, 14), Color("#120e10").lerp(GHOST, 0.4 * _haunt))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The lantern, swinging from the driver's box.
	var hook := Vector2(cx + 84, ground - 24 - 64)
	var swing := sin(time * 1.6) * 0.35
	var lamp := hook + Vector2(sin(swing), cos(swing)) * 22.0
	ci.draw_line(Vector2(cx + 68, hook.y - 6), hook, Color("#2a1e16"), 3.0, true)
	ci.draw_line(hook, lamp, Color("#1a1410"), 1.5, true)
	var flick := 0.75 + 0.25 * sin(time * 9.0) * sin(time * 5.3)
	for k in 8:
		ci.draw_circle(lamp, 10.0 + k * 7.0, Color(LAMP, 0.025 * flick))
	ci.draw_rect(Rect2(lamp - Vector2(6, 8), Vector2(12, 16)), Color("#2a1e16"))
	ci.draw_rect(Rect2(lamp - Vector2(4, 6), Vector2(8, 12)), Color(LAMP, 0.85 * flick))
