extends Node2D
## Leopold, the Lamplighter's Lit Lamp: an iron lamp on a post beside Char.
## During a wave it fires a ring of Defs.LAMP_SHOTS unaimed white shots every
## Defs.LAMP_EVERY seconds; the ring turns a little each volley so no trail
## sits in a blind spot forever.

const Defs := preload("res://scripts/game/defs.gd")
const LampShot := preload("res://scripts/game/lamp_shot.gd")

var world := Vector2(-112, 22)
var battle
var board
var _cool := 1.5
var _turn := 0.0
var _flash := 0.0   # 1 just after a volley, fading
var _t := 0.0


func setup(b, bd) -> void:
	battle = b
	board = bd
	position = board.proj(world)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()
	if not battle.fighting:
		_cool = minf(_cool, 1.5)
		return
	_cool -= delta
	if _cool <= 0.0:
		_cool = Defs.LAMP_EVERY
		_volley()


func _volley() -> void:
	var reach := 0.0
	for i in board.lane_count:
		reach = maxf(reach, board.path_point(i, 0.0).length())
	reach *= Defs.LAMP_RANGE
	var dmg: float = battle.char_unit.stats()["damage"] * Defs.LAMP_DAMAGE
	for i in Defs.LAMP_SHOTS:
		var s := LampShot.new()
		battle.add_lamp_shot(s)
		s.setup(battle, board, world, Vector2.from_angle(_turn + TAU * i / Defs.LAMP_SHOTS), reach, dmg)
	_turn += Defs.LAMP_TURN
	_flash = 1.0
	AudioDirector.play_sfx("chime", -14.0)


## Glows brighter as the next volley nears.
func charge() -> float:
	if not battle.fighting:
		return 0.0
	return clampf(1.0 - _cool / 1.0, 0.0, 1.0)


func _ell(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(from, to, float(k) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A shaded upright band from y0 down to y1 (y1 > y0), w wide: a lit left
## side, a shadowed right side and a thin highlight, so it reads as round.
func _column(x: float, y0: float, y1: float, w: float, u: float, lit: Color, shade: Color) -> void:
	var h := w * 0.5
	draw_rect(Rect2(Vector2(x - h, y0) * u, Vector2(w, y1 - y0) * u), lit)
	draw_rect(Rect2(Vector2(x + h * 0.1, y0) * u, Vector2(h * 0.9, y1 - y0) * u), shade)
	draw_rect(Rect2(Vector2(x - h * 0.6, y0) * u, Vector2(w * 0.12, y1 - y0) * u), Color(1, 1, 1, 0.12))


func _draw() -> void:
	var u: float = board.view_scale * 1.35
	# Drawn mirrored: the arm reaches away from Char, lit sides face the fire.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	var glow := clampf(0.55 + 0.1 * sin(_t * 3.0) + 0.35 * maxf(charge(), _flash), 0.0, 1.0)
	var flick := 0.5 + 0.5 * sin(_t * 11.0) * sin(_t * 7.3)
	var iron := Color("#4d463f")
	var iron_dk := Color("#26221e")
	var iron_lt := Color("#7a7067")
	var stone := Color("#8a8178")
	var stone_dk := Color("#5b544d")
	var light := Color(1, 0.97, 0.88)

	# Light pool on the ground and the post's shadow.
	draw_colored_polygon(_ell(Vector2(8, 2) * u, 70 * u, 22 * u), Color(light, 0.05 + 0.07 * glow))
	draw_colored_polygon(_ell(Vector2(8, 2) * u, 36 * u, 11 * u), Color(light, 0.05 + 0.06 * glow))
	draw_colored_polygon(_ell(Vector2(-7, 2) * u, 15 * u, 4.5 * u), Color(0, 0, 0, 0.35))

	# Stone plinth: an elliptical drum.
	var pts := _ell(Vector2(0, 0) * u, 10 * u, 3.6 * u, 0.0, PI, 12)
	pts.append(Vector2(-10, -9) * u)
	pts.append_array(_ell(Vector2(0, -9) * u, 10 * u, 3.6 * u, PI, 0.0, 12))
	draw_colored_polygon(pts, stone_dk)
	var lit_side := _ell(Vector2(0, 0) * u, 10 * u, 3.6 * u, PI * 0.55, PI, 8)
	lit_side.append(Vector2(-10, -9) * u)
	lit_side.append(Vector2(-1.5, -9) * u)
	draw_colored_polygon(lit_side, stone)
	draw_colored_polygon(_ell(Vector2(0, -9) * u, 10 * u, 3.6 * u), Color("#a39a90"))
	draw_polyline(_ell(Vector2(0, -9) * u, 10 * u, 3.6 * u), iron_dk, 1.0 * u)

	# Post: a footing collar, the shaft, a mid collar and a top cap.
	draw_colored_polygon(_ell(Vector2(0, -11) * u, 5.5 * u, 2.0 * u), iron_dk)
	_column(0, -14, -11, 9, u, iron_lt, iron)
	_column(0, -84, -14, 5, u, iron, iron_dk)
	_column(0, -46, -42, 7, u, iron_lt, iron)
	_column(0, -88, -84, 8, u, iron_lt, iron)
	draw_colored_polygon(_ell(Vector2(0, -88) * u, 4 * u, 1.5 * u), iron_lt)
	draw_circle(Vector2(0, -91) * u, 2.4 * u, iron)
	draw_circle(Vector2(-0.8, -91.8) * u, 0.9 * u, iron_lt)

	# Bracket arm with a curl underneath, out to the right.
	draw_line(Vector2(0, -82) * u, Vector2(20, -82) * u, iron_dk, 3.2 * u)
	draw_line(Vector2(0, -82.8) * u, Vector2(20, -82.8) * u, iron_lt, 1.0 * u)
	var curl := PackedVector2Array()
	for k in 18:
		var a := PI * 0.5 + k / 17.0 * PI * 1.6
		var r := lerpf(7.0, 2.5, k / 17.0)
		curl.append(Vector2(8 + cos(a) * r, -75 + sin(a) * r) * u)
	draw_polyline(curl, iron_dk, 1.8 * u)
	draw_line(Vector2(2, -82) * u, Vector2(8, -82) * u, iron_dk, 1.8 * u)
	draw_circle(Vector2(20.5, -82) * u, 1.8 * u, iron)

	# The lantern hangs from the arm's end: a six-sided glass box, seen a
	# little from above, so three panes show (front bright, sides dimmer).
	var c := Vector2(20, -60)
	draw_line((c + Vector2(0, -22)) * u, Vector2(20, -82) * u, iron_dk, 1.2 * u)
	draw_arc((c + Vector2(0, -23.5)) * u, 2.2 * u, 0, TAU, 12, iron_dk, 1.0 * u)
	# Halo.
	draw_circle(c * u, 40 * u * (0.8 + 0.3 * glow), Color(light, 0.03 + 0.06 * glow))
	draw_circle(c * u, 20 * u, Color(light, 0.05 + 0.08 * glow))
	var tw := 9.5   # half-width at the top of the glass
	var bw := 7.5   # half-width at the bottom (it tapers)
	var top := c.y - 9.0
	var bot := c.y + 9.0
	var side := 0.42   # how much of each half the side panes take
	var tl := Vector2(c.x - tw, top); var tr := Vector2(c.x + tw, top)
	var bl := Vector2(c.x - bw, bot); var br := Vector2(c.x + bw, bot)
	var tml := Vector2(c.x - tw * side, top); var tmr := Vector2(c.x + tw * side, top)
	var bml := Vector2(c.x - bw * side, bot); var bmr := Vector2(c.x + bw * side, bot)
	var pane := func(a: Vector2, b: Vector2, cc: Vector2, d: Vector2, k: float):
		draw_colored_polygon(PackedVector2Array([a * u, b * u, cc * u, d * u]),
			Color(1.0, 0.9 + 0.08 * k, 0.6 + 0.3 * k, 0.72 + 0.28 * glow * k))
	pane.call(tl, tml, bml, bl, 0.65)
	pane.call(tmr, tr, br, bmr, 0.5)
	pane.call(tml, tmr, bmr, bml, 1.0)
	# The flame inside, flickering.
	var f := c + Vector2(0, 3)
	var fh := 7.0 + 1.5 * flick
	draw_colored_polygon(PackedVector2Array([(f + Vector2(-2.6, 0)) * u, (f + Vector2(0, -fh)) * u,
		(f + Vector2(2.6, 0)) * u, (f + Vector2(0, 2.2)) * u]), Color("#ffe9a8"))
	draw_circle(f * u, 1.6 * u, Color.WHITE)
	draw_rect(Rect2((f + Vector2(-0.6, 0)) * u, Vector2(1.2, 4) * u), iron_dk)   # wick holder
	# Frame: edges and the pane seams.
	for e in [[tl, bl], [tr, br], [tml, bml], [tmr, bmr]]:
		draw_line(e[0] * u, e[1] * u, iron_dk, 1.4 * u)
	draw_line(bl * u, br * u, iron_dk, 1.4 * u)
	# Glass glint on the front pane.
	draw_line((tml + Vector2(1.5, 2.5)) * u, (tml + Vector2(1.5, 9)) * u, Color(1, 1, 1, 0.75), 0.9 * u)
	# Cap: a hipped roof over the hexagon, lit on the left, then a finial.
	var rim_l := tl + Vector2(-1.8, 0); var rim_r := tr + Vector2(1.8, 0)
	var peak := Vector2(c.x, top - 8.0)
	draw_colored_polygon(PackedVector2Array([rim_l * u, Vector2(c.x - tw * side, top + 0.8) * u, peak * u]), iron_lt)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - tw * side, top + 0.8) * u, Vector2(c.x + tw * side, top + 0.8) * u, peak * u]), iron)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x + tw * side, top + 0.8) * u, rim_r * u, peak * u]), iron_dk)
	draw_line(rim_l * u, rim_r * u, iron_dk, 1.6 * u)
	draw_circle((peak + Vector2(0, -1.5)) * u, 1.8 * u, iron)
	draw_circle((peak + Vector2(-0.5, -2.0)) * u, 0.7 * u, iron_lt)
	# Base: a short tapered collar and a drip finial.
	draw_colored_polygon(PackedVector2Array([(bl + Vector2(-1, 0)) * u, (br + Vector2(1, 0)) * u,
		(Vector2(c.x + 4, bot + 3.5)) * u, (Vector2(c.x - 4, bot + 3.5)) * u]), iron)
	draw_colored_polygon(PackedVector2Array([(bl + Vector2(-1, 0)) * u, (Vector2(c.x - bw * side, bot)) * u,
		(Vector2(c.x - 1.5, bot + 3.5)) * u, (Vector2(c.x - 4, bot + 3.5)) * u]), iron_lt)
	draw_colored_polygon(PackedVector2Array([(Vector2(c.x - 2, bot + 3.5)) * u, (Vector2(c.x + 2, bot + 3.5)) * u,
		(Vector2(c.x, bot + 7.5)) * u]), iron_dk)
