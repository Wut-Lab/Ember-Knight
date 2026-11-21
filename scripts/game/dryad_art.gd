class_name DryadArt
## The Forest Friend's dryad, drawn in code: a tiny walking figure with a slim
## bark body, a leafy hood and twig arms, glowing spring green.
## `at` is her feet; `s` is her scale (a Wisp's 15 * view_scale);
## `t` drives the walk and sway; `facing` is 1 (right) or -1 (left);
## `walk` is 0 standing still to 1 walking.

const GLOW := Color("#8cf06a")
const LEAF := Color("#6fd64a")
const LEAF_DARK := Color("#3f9a36")
const BARK := Color("#6b4a2e")
const BARK_LIGHT := Color("#9a7048")
const FACE := Color("#d8efb8")
const EYE := Color("#f4ffe0")
const PETAL := Color("#ffd1e6")

static var _glow: Texture2D


static func draw(ci: CanvasItem, at: Vector2, s: float, t: float, facing: float, walk: float, alpha := 1.0) -> void:
	var k := s / 15.0
	var step := sin(t * 7.0) * walk
	var bob := absf(sin(t * 7.0)) * 1.5 * k * walk + sin(t * 2.0) * 0.8 * k
	# Soft green glow and a shadow at her feet.
	var gr := s * 2.6
	ci.draw_texture_rect(glow_tex(), Rect2(at + Vector2(-gr, -gr - s * 1.6), Vector2(gr, gr) * 2.0), false, Color(GLOW, 0.32 * alpha))
	_oval(ci, at + Vector2(0, 1.5 * k), s * 0.55, s * 0.16, Color(0, 0, 0, 0.35 * alpha))
	var hip := at + Vector2(0, -s * 0.9 - bob)
	# Legs: two thin roots that step in turn.
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector2((side * 3.0 + step * side * 4.0 * facing) * k, 0)
		ci.draw_line(hip + Vector2(side * 2.0 * k, 0), foot, Color(BARK, alpha), 2.6 * k, true)
	# Body: a slim tapered trunk with a strip of light bark.
	var neck := hip + Vector2(0, -s * 1.05)
	var body := PackedVector2Array([hip + Vector2(-4.5 * k, 1 * k), hip + Vector2(4.5 * k, 1 * k), neck + Vector2(3 * k, 0), neck + Vector2(-3 * k, 0)])
	ci.draw_colored_polygon(body, Color(BARK, alpha))
	ci.draw_line(hip + Vector2(1.5 * k * facing, -2 * k), neck + Vector2(1.2 * k * facing, 2 * k), Color(BARK_LIGHT, alpha), 1.4 * k, true)
	# A moss sash.
	ci.draw_line(hip + Vector2(-4 * k, -5 * k), hip + Vector2(4 * k, -9 * k), Color(LEAF_DARK, alpha), 2.0 * k, true)
	# Twig arms, swinging against the legs, each ending in a little fork.
	for side: float in [-1.0, 1.0]:
		var sh := neck + Vector2(side * 3 * k, 3 * k)
		var sw: float = -step * side * facing * 0.5
		var hand := sh + Vector2(side * 6 * k, 9 * k).rotated(sw * side)
		ci.draw_line(sh, hand, Color(BARK, alpha), 1.8 * k, true)
		ci.draw_line(hand, hand + Vector2(side * 2.5 * k, 1.5 * k), Color(BARK, alpha), 1.2 * k, true)
		ci.draw_line(hand, hand + Vector2(side * 0.5 * k, 3 * k), Color(BARK, alpha), 1.2 * k, true)
		_leaf(ci, hand + Vector2(side * 2.5 * k, 1.5 * k), 2.6 * k, side * 0.8, Color(LEAF, alpha))
	# Head: a round pale face inside a leafy hood that peaks into a point.
	var head := neck + Vector2(0.8 * k * facing, -5.5 * k)
	# The hood: a rounded cowl peaking into a curled sprout, with a mantle of
	# leaves hanging down over the shoulders.
	for i in 8:   # four leaves each side, from the temple down to the shoulder
		var th := deg_to_rad((70.0 + 22.0 * (i % 4)) * (1.0 if i < 4 else -1.0))
		var rim := head + Vector2(sin(th), -cos(th)) * 6.2 * k
		_leaf(ci, rim + Vector2(sin(th), -cos(th)) * 1.5 * k, 4.2 * k, th, Color(LEAF_DARK if i % 2 else LEAF, alpha))
	var cowl := PackedVector2Array()
	for i in 24:
		var u := TAU * i / 24.0
		var r := 6.6 * k * (1.0 + 0.55 * maxf(0.0, -cos(u)) ** 4)   # stretched up into a peak
		cowl.append(head + Vector2(sin(u) * 6.6 * k, cos(u) * r))
	ci.draw_colored_polygon(cowl, Color(LEAF_DARK, alpha))
	for i in 5:   # overlapping leaf scales on the cowl
		var th2 := deg_to_rad(-70.0 + 35.0 * i)
		_leaf(ci, head + Vector2(sin(th2), -cos(th2)) * 4.6 * k, 4.0 * k, th2, Color(LEAF, alpha))
	var tip := head + Vector2(0, -10.5 * k)
	_leaf(ci, tip + Vector2(1.2 * facing, -1.5) * k, 3.4 * k, 0.5 * facing + sin(t * 2.5) * 0.2, Color(LEAF, alpha))
	ci.draw_circle(head + Vector2(0, 0.6 * k), 4.0 * k, Color(FACE, alpha))
	# Bright eyes, looking the way she walks; she blinks now and then.
	var blink := fmod(t + 1.0, 3.7) < 0.12
	for ex: float in [-1.6, 1.6]:
		var e := head + Vector2((ex + 0.9 * facing) * k, -0.3 * k)
		if blink:
			ci.draw_line(e - Vector2(0.9 * k, 0), e + Vector2(0.9 * k, 0), Color(LEAF_DARK, alpha), 0.9 * k, true)
		else:
			ci.draw_circle(e, 1.0 * k, Color(LEAF_DARK, alpha))
			ci.draw_circle(e + Vector2(0.3, -0.3) * k, 0.4 * k, Color(EYE, alpha))
	# A little blossom tucked into the hood.
	var fl := head + Vector2(-5.0 * facing, -4.0) * k
	for i in 5:
		ci.draw_circle(fl + Vector2(1.3 * k, 0).rotated(TAU * i / 5.0 + t * 0.3), 1.0 * k, Color(PETAL, alpha))
	ci.draw_circle(fl, 0.8 * k, Color("#ffe27a", alpha))


## A leaf: a pointed oval along angle `a` (0 points up).
static func _leaf(ci: CanvasItem, at: Vector2, size: float, a: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var u := TAU * i / 12.0
		pts.append(Vector2(sin(u) * size * 0.45, -cos(u) * size * (1.0 if cos(u) > 0 else 0.7)).rotated(a) + at)
	ci.draw_colored_polygon(pts, col)


static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var u := TAU * i / 20.0
		pts.append(c + Vector2(cos(u) * rx, sin(u) * ry))
	ci.draw_colored_polygon(pts, col)


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow = tex
	return _glow
