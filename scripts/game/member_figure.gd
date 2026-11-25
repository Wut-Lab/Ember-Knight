extends Node2D
## A riding caravan member, drawn in 2.5D beside the fire. Purely visual:
## an idle loop per member, and react() makes them hop and glow when their
## ability fires. Drawn facing +x and mirrored so they always face the fire,
## which lights their front.

var kind := "cook"
var world := Vector2.ZERO
var board
var _t := 0.0
var _pulse := 0.0   # 1 right after react(), fading
var _flip := 1.0


func setup(k: String, w: Vector2, bd) -> void:
	kind = k
	world = w
	board = bd
	_flip = -1.0 if w.x > 0.0 else 1.0
	_t = randf() * 10.0
	position = board.proj(world)


func react() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 1.4)
	queue_redraw()


# ------------------------------------------------------------ primitives
func _ell(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(from, to, float(k) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _e(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(_ell(c, rx, ry), col)


## A rounded, fire-lit shape: shadowed back, lit front, a small sheen.
func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
	_e(c, rx, ry, col.darkened(0.45))
	_e(c + Vector2(rx * 0.16, -ry * 0.08), rx * 0.82, ry * 0.88, col)
	_e(c + Vector2(rx * 0.4, -ry * 0.36), rx * 0.3, ry * 0.26, col.lightened(0.28))


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


func _line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w, true)


## The shared upper half of the human members: torso, arms reaching to the
## given hands, and a head. Returns the head's centre for hats.
func _person(base: Vector2, coat: Color, hand_a: Vector2, hand_b: Vector2, wide := 1.0) -> Vector2:
	var skin := Color("#e0a77c")
	var sh := base + Vector2(1, -16)
	_line(sh + Vector2(-3, 0), hand_b, coat.darkened(0.5), 4.5)   # far arm
	draw_circle(hand_b, 2.2, skin.darkened(0.3))
	_blob(base + Vector2(0, -8), 10.0 * wide, 13.0, coat)
	var head := base + Vector2(2, -27)
	_e(head + Vector2(-0.5, 7), 4.0, 2.0, skin.darkened(0.5))      # neck
	_blob(head, 7.0, 7.5, skin)
	draw_circle(head + Vector2(4.6, -0.5), 1.0, Color("#2a1a14"))  # eye
	_e(head + Vector2(7, 1.5), 1.6, 1.3, skin.darkened(0.15))      # nose
	_line(sh + Vector2(3, 0), hand_a, coat.darkened(0.15), 4.5)    # near arm
	draw_circle(hand_a, 2.3, skin)
	return head


func _ring(u: float) -> void:
	if _pulse <= 0.0:
		return
	var r := 26.0 + 22.0 * (1.0 - _pulse)
	draw_polyline(_ell(Vector2.ZERO, r, r * 0.42, 0, TAU, 32), Color("#ffd58f", _pulse * 0.9), 2.0 / u, true)
	_e(Vector2.ZERO, r * 0.8, r * 0.33, Color("#ffb04a", _pulse * 0.18))


# ------------------------------------------------------------ draw
func _draw() -> void:
	var u: float = board.view_scale * 1.6
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(u * _flip, u))
	var calm := kind == "lamplighter"   # his lamp fires often: the lantern flares instead
	if not calm:
		_ring(u)
	_e(Vector2(2, 0), 22.0, 6.5, Color(0, 0, 0, 0.32))   # shadow
	var hop := 0.0 if calm else -sin(PI * _pulse) * 5.0
	draw_set_transform(Vector2(0, hop * u), 0.0, Vector2(u * _flip, u))
	match kind:
		"cook": _draw_cook()
		"tinker": _draw_tinker()
		"cat": _draw_cat()
		"hound": _draw_hound()
		"lamplighter": _draw_lamplighter()
		"smith": _draw_smith()
		"priest": _draw_priest()


## Carson: on a stool, stirring a stew pot over a little tripod fire.
func _draw_cook() -> void:
	var wood := Color("#6b4528")
	_line(Vector2(-6, 0), Vector2(-4, -11), wood.darkened(0.3), 2.5)
	_line(Vector2(6, 0), Vector2(4, -11), wood, 2.5)
	_e(Vector2(0, -11), 10.0, 3.0, wood.lightened(0.1))
	_e(Vector2(9, -1), 4.0, 2.0, Color("#2b2019"))   # boots
	_e(Vector2(12, 0), 4.0, 2.0, Color("#3a2a20"))
	_blob(Vector2(5, -12), 9.0, 5.0, Color("#4d5a73"))   # lap
	# the pot
	var p := Vector2(27, -6)
	draw_circle(p + Vector2(0, 5), 4.0 + sin(_t * 9.0) * 0.6, Color("#ff9a3a", 0.85))
	_line(p + Vector2(-9, 6), p + Vector2(0, -16), Color("#3b3633"), 1.6)
	_line(p + Vector2(9, 6), p + Vector2(0, -16), Color("#3b3633"), 1.6)
	_blob(p + Vector2(0, -4), 9.0, 7.0, Color("#3a3634"))
	_e(p + Vector2(0, -10), 9.0, 2.6, Color("#5a5450"))
	_e(p + Vector2(0, -10), 7.6, 1.9, Color("#c9672e"))
	for i in 3:   # steam
		var k := fmod(_t * 0.5 + i / 3.0, 1.0)
		var s := p + Vector2(-4 + i * 4 + sin(_t * 2.0 + i) * 2.5, -13 - k * 18)
		draw_circle(s, 2.0 + k * 2.5, Color(1, 1, 1, 0.22 * (1.0 - k)))
	var a := _t * 2.6
	var hand := p + Vector2(cos(a) * 4.0 - 2.0, -16 + sin(a) * 1.2)
	_line(hand, p + Vector2(cos(a) * 3.0, -10 + sin(a) * 1.0), Color("#b98a5a"), 1.6)
	var head := _person(Vector2(0, -12), Color("#4d5a73"), hand, Vector2(14, -17))
	_e(Vector2(4.5, -16), 4.5, 7.0, Color("#eee6da"))   # apron
	_e(Vector2(5.5, -17), 2.2, 4.0, Color("#ffffff", 0.35))
	# chef's hat
	_poly([head + Vector2(-6, -4), head + Vector2(6, -4), head + Vector2(6, -8), head + Vector2(-6, -8)], Color("#dcd6cc"))
	_blob(head + Vector2(0, -12), 7.5, 6.0, Color("#f4efe6"))


## Terry: kneeling, turning a brass gear in his hands; a toolbox beside him.
func _draw_tinker() -> void:
	var tb := Vector2(-17, -1)   # toolbox
	_poly([tb + Vector2(-8, 0), tb + Vector2(8, 0), tb + Vector2(8, -9), tb + Vector2(-8, -9)], Color("#7a2f22"))
	_poly([tb + Vector2(-8, -9), tb + Vector2(8, -9), tb + Vector2(10, -12), tb + Vector2(-6, -12)], Color("#a5443a"))
	_line(tb + Vector2(-3, -12), tb + Vector2(-2, -15), Color("#888"), 1.2)
	_line(tb + Vector2(-2, -15), tb + Vector2(4, -15), Color("#888"), 1.2)
	_line(tb + Vector2(4, -15), tb + Vector2(5, -12), Color("#888"), 1.2)
	_e(Vector2(10, -2), 9.0, 3.5, Color("#2e3a24"))   # kneeling legs
	_e(Vector2(15, -1), 3.5, 2.2, Color("#2b2019"))
	var g := Vector2(15, -16)
	var head := _person(Vector2(0, -4), Color("#4f6b3a"), g + Vector2(-2, 3), g + Vector2(3, -2))
	# the gear
	var rot := _t * 1.6
	var pts := []
	for k in 16:
		var a := rot + TAU * k / 16.0
		pts.append(g + Vector2.from_angle(a) * (6.5 if k % 2 == 0 else 4.8))
	_poly(pts, Color("#b8863a"))
	draw_circle(g, 3.6, Color("#d9a94e"))
	draw_circle(g, 1.4, Color("#5a3d1a"))
	if fmod(_t, 2.3) < 0.18:
		for i in 4:
			var d := Vector2.from_angle(i * 1.7 + _t * 3.0) * (6.0 + fmod(_t, 2.3) * 40.0)
			draw_circle(g + d, 0.9, Color("#ffe6a0"))
	# cap with goggles
	_e(head + Vector2(0, -4), 7.6, 5.0, Color("#5b3d28"))
	_e(head + Vector2(5, -4), 4.5, 1.6, Color("#4a311f"))
	draw_circle(head + Vector2(2, -3), 2.2, Color("#c99b45"))
	draw_circle(head + Vector2(5.5, -3), 2.2, Color("#c99b45"))
	draw_circle(head + Vector2(2, -3), 1.3, Color("#9fd7e8"))
	draw_circle(head + Vector2(5.5, -3), 1.3, Color("#9fd7e8"))


## Carl: curled up asleep on a crate; ears twitch now and then.
func _draw_cat() -> void:
	var wood := Color("#8a5f36")
	_poly([Vector2(-13, 0), Vector2(11, 0), Vector2(11, -16), Vector2(-13, -16)], wood.darkened(0.2))
	_poly([Vector2(11, 0), Vector2(16, -4), Vector2(16, -20), Vector2(11, -16)], wood.darkened(0.5))
	_poly([Vector2(-13, -16), Vector2(11, -16), Vector2(16, -20), Vector2(-8, -20)], wood.lightened(0.1))
	for y in [-5.5, -10.5]:
		_line(Vector2(-13, y), Vector2(11, y), wood.darkened(0.45), 0.8)
	_line(Vector2(-13, -16), Vector2(11, 0), wood.darkened(0.4), 1.0)
	var fur := Color("#c98a4b")
	var awake := _pulse > 0.0
	var tail := _t * 1.2
	var tp := []
	for k in 9:
		var a := lerpf(2.6, 5.2, k / 8.0)
		tp.append(Vector2(-1, -22) + Vector2(cos(a) * 11.0, sin(a) * 4.5 + sin(tail + k * 0.5) * 0.5 * k / 8.0))
	draw_polyline(PackedVector2Array(tp), fur.darkened(0.35), 3.2, true)
	_blob(Vector2(-1, -24), 10.5, 5.5, fur)
	for x in [-6, -2, 2]:   # stripes
		_line(Vector2(x, -29), Vector2(x + 1.5, -25), fur.darkened(0.35), 1.2)
	var hd := Vector2(8, -26 - (3.0 if awake else 0.0))
	var tw := 0.0
	if awake or fmod(_t, 3.1) < 0.25:
		tw = 1.0
	_poly([hd + Vector2(-4, -2), hd + Vector2(-3 - tw, -8), hd + Vector2(0, -3)], fur.darkened(0.2))
	_poly([hd + Vector2(1, -3), hd + Vector2(3 + tw, -8.5), hd + Vector2(5, -2)], fur)
	_poly([hd + Vector2(1.8, -3.5), hd + Vector2(3 + tw, -7), hd + Vector2(4, -3)], Color("#e8a0a0"))
	_blob(hd, 5.5, 4.6, fur)
	_e(hd + Vector2(3.5, 1.2), 2.4, 1.6, Color("#f0d4b0"))
	draw_circle(hd + Vector2(5.4, 0.6), 0.8, Color("#d77"))
	if awake:
		draw_circle(hd + Vector2(2.5, -1.2), 1.1, Color("#9be05a"))
	else:
		_line(hd + Vector2(1.2, -1.0), hd + Vector2(3.6, -0.8), Color("#3a2414"), 0.8)
		var z := fmod(_t * 0.4, 1.0)
		draw_string(ThemeDB.fallback_font, hd + Vector2(-2 + z * 4, -10 - z * 10), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.5 * (1.0 - z)))


## Hella: lying by the fire, head up, tail thumping; barks on react().
func _draw_hound() -> void:
	var fur := Color("#8b5a32")
	var wag := sin(_t * (9.0 if _pulse > 0.0 else 3.0)) * 0.5
	var tail_end := Vector2(-16, -8) + Vector2.from_angle(PI + 0.3 + wag) * 10.0
	_line(Vector2(-14, -8), tail_end, fur.darkened(0.3), 3.0)
	_blob(Vector2(-2, -7), 16.0, 7.0, fur)
	_e(Vector2(-6, -11), 6.0, 2.0, fur.lightened(0.15))
	_e(Vector2(20, -1.5), 5.0, 2.0, fur.darkened(0.15))   # paws
	_e(Vector2(15, 0), 5.0, 2.0, fur)
	_e(Vector2(10, -7), 3.6, 3.4, Color("#d9b58a"))   # chest
	var up := 4.0 if _pulse > 0.0 else 0.0
	var hd := Vector2(14, -15 - up)
	_line(Vector2(10, -10), hd + Vector2(-1, 4), Color("#b8322a"), 2.0)   # collar
	_blob(hd, 6.5, 5.5, fur)
	_blob(hd + Vector2(6.5, 2), 4.2, 2.8, Color("#c89868"))
	draw_circle(hd + Vector2(10.5, 0.8), 1.4, Color("#1c1210"))
	draw_circle(hd + Vector2(2.5, -1.8), 1.0, Color("#1c1210"))
	_e(hd + Vector2(-2.5, 1.5), 2.6, 4.8, fur.darkened(0.4))   # floppy ear
	if _pulse > 0.4:   # bark
		_poly([hd + Vector2(5, 4), hd + Vector2(10, 4), hd + Vector2(8, 7)], Color("#5a1f1f"))
		for i in 3:
			var r := 6.0 + i * 4.0 + (1.0 - _pulse) * 10.0
			draw_arc(hd + Vector2(12, 1), r, -0.6, 0.6, 8, Color("#ffd58f", _pulse * 0.8), 1.2, true)


## Leopold: tall in a top hat, his lamplighter's pole, a small hand lantern.
func _draw_lamplighter() -> void:
	var coat := Color("#2f4a45")
	_line(Vector2(-3, 0), Vector2(-2, -14), Color("#2a2420"), 3.5)
	_line(Vector2(3, 0), Vector2(3, -14), Color("#34302a"), 3.5)
	_e(Vector2(-2, 0), 3.5, 1.6, Color("#1d1814"))
	_e(Vector2(5, 0.5), 3.5, 1.6, Color("#1d1814"))
	_poly([Vector2(-8, -12), Vector2(9, -12), Vector2(7, -30), Vector2(-6, -30)], coat.darkened(0.2))
	_poly([Vector2(1, -12), Vector2(9, -12), Vector2(7, -30), Vector2(2, -30)], coat)
	var sway := sin(_t * 1.7) * 0.18
	var lh := Vector2(11, -20)
	var lc := lh + Vector2.from_angle(PI / 2 + sway) * 8.0
	var pole_hand := Vector2(-6, -26)
	var head := _person(Vector2(0, -18), coat, lh, pole_hand, 0.85)
	_line(Vector2(-9, -2), Vector2(-3, -60), Color("#6b4a2a"), 1.6)   # pole
	draw_arc(Vector2(-1.5, -60), 2.5, PI, TAU + 0.6, 8, Color("#c99b45"), 1.2, true)
	_line(lh, lc + Vector2(0, -3.5), Color("#333"), 0.8)
	var glow := 0.55 + 0.1 * sin(_t * 13.0) + _pulse * 0.5
	draw_circle(lc, 9.0, Color("#ffb04a", 0.16 * glow))
	_poly([lc + Vector2(-3, -3.5), lc + Vector2(3, -3.5), lc + Vector2(3, 3), lc + Vector2(-3, 3)], Color("#2a2622"))
	_poly([lc + Vector2(-2, -2.5), lc + Vector2(2, -2.5), lc + Vector2(2, 2), lc + Vector2(-2, 2)], Color("#ffd27a").lerp(Color.WHITE, _pulse * 0.6))
	_poly([lc + Vector2(-4, -3.5), lc + Vector2(4, -3.5), lc + Vector2(0, -6)], Color("#2a2622"))
	# top hat
	_e(head + Vector2(0, -5), 9.0, 2.2, Color("#151313"))
	_poly([head + Vector2(-5.5, -5), head + Vector2(5.5, -5), head + Vector2(5, -17), head + Vector2(-5, -17)], Color("#1d1a1a"))
	_poly([head + Vector2(1.5, -5), head + Vector2(5.5, -5), head + Vector2(5, -17), head + Vector2(2, -17)], Color("#2c2826"))
	_poly([head + Vector2(-5.4, -6), head + Vector2(5.4, -6), head + Vector2(5.3, -8.5), head + Vector2(-5.3, -8.5)], Color("#7a2a22"))


## Simon: a burly smith at his anvil; the hammer rings now and then.
func _draw_smith() -> void:
	var cyc := fmod(_t, 1.6)
	var strike := cyc > 1.35 and cyc < 1.5
	var ang := lerpf(-0.2, -2.2, smoothstep(0.0, 1.25, cyc)) if cyc < 1.25 else lerpf(-2.2, 0.15, smoothstep(1.25, 1.4, cyc))
	_line(Vector2(-4, 0), Vector2(-3, -12), Color("#3b2f26"), 4.5)
	_line(Vector2(4, 0), Vector2(4, -12), Color("#4a3a2e"), 4.5)
	_e(Vector2(-3, 0), 4.0, 1.8, Color("#1d1814"))
	_e(Vector2(6, 0.5), 4.0, 1.8, Color("#1d1814"))
	# anvil
	var an := Vector2(24, 0)
	_poly([an + Vector2(-4, 0), an + Vector2(4, 0), an + Vector2(3, -8), an + Vector2(-3, -8)], Color("#3a3a3e"))
	_poly([an + Vector2(-8, -8), an + Vector2(7, -8), an + Vector2(13, -11), an + Vector2(7, -12), an + Vector2(-8, -12)], Color("#55565c"))
	_poly([an + Vector2(-8, -12), an + Vector2(7, -12), an + Vector2(13, -11), an + Vector2(6, -13.5), an + Vector2(-7, -13.5)], Color("#8a8c94"))
	_e(an + Vector2(0, -13.5), 4.0, 1.2, Color("#ff8a2a"))
	draw_circle(an + Vector2(0, -14), 5.0, Color("#ff9a3a", 0.18))
	var sh := Vector2(2, -27)
	var hand := sh + Vector2.from_angle(ang) * 10.0 + Vector2(4, 2)
	var head := _person(Vector2(0, -12), Color("#7a5236"), hand, an + Vector2(-6, -15), 1.25)
	_poly([Vector2(-3, -6), Vector2(9, -6), Vector2(8, -24), Vector2(2, -24)], Color("#4a3020"))   # leather apron
	_e(head + Vector2(3, 5), 5.5, 4.0, Color("#3a2416"))   # beard
	_e(head + Vector2(-1, -4.5), 6.5, 3.0, Color("#3a2416"))   # hair
	var hd := hand + Vector2.from_angle(ang - PI / 2) * -9.0
	_line(hand, hd, Color("#6b4a2a"), 1.8)
	var hx := Vector2.from_angle(ang) * 3.5
	_line(hd - hx, hd + hx, Color("#4a4a50"), 4.5)
	if strike or _pulse > 0.5:
		for i in 6:
			var d := Vector2.from_angle(-PI * (0.1 + 0.8 * i / 5.0)) * (5.0 + (cyc - 1.35) * 90.0)
			draw_circle(an + Vector2(0, -14) + d, 0.9, Color("#ffd27a"))


## Paolo: a hooded priest in a grey-brown robe, swinging a smoking censer on
## a chain. Rounded, fire-lit volumes like the others: a bell-shaped robe with
## a lit front, a cowl around his face, a shoulder cape. Once his Last Rites
## are spent the censer burns low.
func _draw_priest() -> void:
	var robe := Color("#5e5048")
	var skin := Color("#e0a77c")
	var spent: bool = Run.rites_used
	_e(Vector2(-2, 0.5), 3.5, 1.6, Color("#1d1814"))   # toes peeking out
	_e(Vector2(6, 1), 3.5, 1.6, Color("#1d1814"))
	# bell-shaped robe: a curved hem, shadowed back, lit front, a sheen down the front
	var hem := _ell(Vector2(0.5, -1), 11.0, 3.4, 0.0, PI, 14)
	var body := PackedVector2Array([Vector2(-6, -28), Vector2(7, -28)])
	body.append_array(hem)
	_poly(Array(body), robe.darkened(0.45))
	var front := PackedVector2Array([Vector2(-2, -28), Vector2(7, -28)])
	front.append_array(_ell(Vector2(2.5, -1), 9.0, 3.0, 0.0, PI * 0.62, 10))
	_poly(Array(front), robe)
	_poly([Vector2(5.5, -27), Vector2(7, -27), Vector2(10, -3), Vector2(7.5, -2)], robe.lightened(0.22))
	draw_polyline(_ell(Vector2(0.5, -1), 11.0, 3.4, 0.0, PI, 14), robe.darkened(0.6), 1.0, true)   # hem edge
	_line(Vector2(-6, -15), Vector2(8.5, -15), Color("#c9b48a"), 1.5)   # rope belt
	_line(Vector2(6, -15), Vector2(7.5, -5), Color("#c9b48a"), 1.0)
	draw_circle(Vector2(7.6, -4.5), 1.0, Color("#c9b48a"))
	var swing := sin(_t * 1.8) * 0.5
	var hand := Vector2(11, -19)
	var cz := hand + Vector2.from_angle(PI / 2 - swing) * 13.0
	var head := _person(Vector2(0, -16), robe, hand, Vector2(-5, -18), 0.9)
	_blob(Vector2(1, -27), 9.5, 5.5, robe)   # shoulder cape
	# cowl: a rounded hood, the face set back in its opening
	_blob(head + Vector2(-1, -0.5), 8.5, 9.0, robe.darkened(0.08))
	_e(head + Vector2(3.2, 1.2), 4.4, 5.6, Color("#1e1916"))           # shadow inside the hood
	_e(head + Vector2(4.0, 1.6), 3.4, 4.6, skin.darkened(0.25))
	_e(head + Vector2(4.6, 1.2), 2.4, 3.6, skin)
	draw_circle(head + Vector2(5.2, 0.4), 0.9, Color("#2a1a14"))       # eye
	_e(head + Vector2(7.0, 2.2), 1.3, 1.1, skin.darkened(0.15))        # nose
	draw_arc(head + Vector2(3.2, 1.2), 5.0, -PI * 0.55, PI * 0.5, 12, robe.lightened(0.3), 1.2, true)   # lit hood rim
	# censer: chain, a little brass pot with a lid, its coals and smoke
	_line(hand, cz + Vector2(0, -4), Color("#8a7a5a"), 0.7)
	var brass := Color("#b8902e")
	_e(cz + Vector2(0, 0.5), 3.8, 3.2, brass.darkened(0.4))
	_e(cz + Vector2(0.6, 0.2), 3.0, 2.6, brass)
	_e(cz + Vector2(1.4, -0.6), 1.0, 0.8, brass.lightened(0.5))
	_poly([cz + Vector2(-2.8, -2.0), cz + Vector2(2.8, -2.0), cz + Vector2(0.4, -5.2)], Color("#d9ae4a"))
	draw_circle(cz + Vector2(0, 0.5), 5.0, Color("#ff9a3a", 0.0 if spent else 0.12 + 0.25 * _pulse))
	for k in 3:
		var f := fmod(_t * 0.35 + k / 3.0, 1.0)
		var sp := cz + Vector2(sin(_t + k * 2.0) * 3.0 + f * 4.0, -5.0 - f * 22.0)
		draw_circle(sp, 1.5 + f * 3.0, Color(0.85, 0.82, 0.78, (0.12 if spent else 0.3) * (1.0 - f)))
