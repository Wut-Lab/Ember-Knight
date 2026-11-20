extends Node2D
const Defs := preload("res://scripts/game/defs.gd")
## Ember Drop: a small charred coal with a little flame dancing off it, left
## behind by a banished spirit. Tap it to heal Char's flame. It fades after
## Defs.EMBER_LIFE seconds, blinking through its last second.

var board
var world := Vector2.ZERO
var life := Defs.EMBER_LIFE
var picked := false
var _t := 0.0
var _hop := 0.0          ## 0..1 little bounce as it lands
var _shape := PackedVector2Array()   ## per rim corner: (radius, height) factors
var _ash := PackedVector2Array()     ## pale ash flecks on the top face
const RIM := 8
const SQUASH := 0.56                 ## the board's ground squash, for the 2.5D look


func setup(b, at: Vector2) -> void:
	board = b
	world = at
	position = board.proj(world)
	_t = randf() * 10.0
	# A lumpy coal, fixed for this ember: rim radii and per-corner heights.
	for i in RIM:
		_shape.append(Vector2(randf_range(0.82, 1.12), randf_range(0.85, 1.15)))
	for i in 5:
		_ash.append(Vector2(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5)))


## Is a board-local point close enough to count as a tap on this ember?
func hit(local: Vector2) -> bool:
	var s: float = board.view_scale
	return not picked and (local - (position + Vector2(0, -6.0 * s))).length() <= 28.0 * s


func _process(delta: float) -> void:
	_t += delta
	_hop = minf(1.0, _hop + delta / 0.35)
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var s: float = board.view_scale
	var alpha := clampf(life / 0.6, 0.0, 1.0)
	if life < 1.0 and fmod(life, 0.2) < 0.07:   # blink through the last second
		alpha *= 0.35
	var lift := -sin(_hop * PI) * 10.0 * s
	var r := 10.0 * s   # a touch bigger than a plain coal, so it's easy to spot
	var hc := r * 0.55                            # coal height
	var pulse := 0.8 + 0.2 * sin(_t * 5.0) * sin(_t * 2.3 + 1.0)
	# On the ground: a soft shadow under the coal, and its warm light around it.
	# A slight green aura so embers stand out on the board, then the coal's warm light.
	var aura := 0.8 + 0.2 * sin(_t * 3.2)
	draw_texture_rect(_glow_tex(), Rect2(-r * 2.6, -hc * 0.5 - r * 2.6 * 0.75, r * 5.2, r * 5.2 * 0.75), false, Color(0.25, 1.0, 0.5, 0.3 * aura * alpha))
	draw_texture_rect(_glow_tex(), Rect2(-r * 2.0, -r * 2.0 * SQUASH, r * 4.0, r * 4.0 * SQUASH), false, Color(1.0, 0.42, 0.1, 0.3 * pulse * alpha))
	draw_texture_rect(_glow_tex(), Rect2(-r * 1.6, -r * 1.6 * SQUASH * 0.8 + r * 0.08, r * 3.2, r * 3.2 * SQUASH * 0.8), false, Color(0, 0, 0, 0.35 * alpha))
	# A dusting of ash on the ground around the base, so the coal sits in it.
	draw_texture_rect(_glow_tex(), Rect2(-r * 1.5, -r * 1.5 * SQUASH + r * 0.1, r * 3.0, r * 3.0 * SQUASH), false, Color(0.55, 0.5, 0.47, 0.22 * alpha))
	draw_set_transform(Vector2(0, lift))
	# The coal as a squat faceted lump: a bottom rim on the ground, a smaller
	# top face raised by its height, and the side facets facing us between them.
	var bot := PackedVector2Array()
	var top := PackedVector2Array()
	for i in RIM:
		var a := TAU * (i + 0.5) / RIM
		var d := Vector2(cos(a), sin(a) * SQUASH)
		bot.append(d * r * _shape[i].x)
		top.append(d * r * _shape[i].x * 0.72 + Vector2(0, -hc * _shape[i].y))
	for i in RIM:
		var j := (i + 1) % RIM
		var mid := (TAU * (i + 1.0) / RIM)
		if sin(mid) < -0.05:
			continue                              # back facets are hidden
		var shade := 0.19 + 0.08 * clampf(-cos(mid - 0.6), 0.0, 1.0)   # lit from the upper left
		var quad := PackedVector2Array([top[i], top[j], bot[j], bot[i]])
		# Each facet warms toward the ground, where the glow bounces up into it.
		var warm := Color(shade + 0.1 * pulse, shade * 0.8 + 0.02, shade * 0.7, alpha)
		draw_polygon(quad, PackedColorArray([Color(shade, shade * 0.9, shade * 0.86, alpha), Color(shade, shade * 0.9, shade * 0.86, alpha), warm, warm]))
		# Embers glowing through the cracks low on the front facets.
		var glow := clampf(sin(mid), 0.0, 1.0) * pulse
		draw_line(bot[i].lerp(top[i], 0.25), bot[j].lerp(top[j], 0.35), Color(1.0, 0.42, 0.1, 0.55 * glow * alpha), maxf(1.0, r * 0.08))
	draw_colored_polygon(top, Color(0.27, 0.23, 0.21, alpha))
	# Ash dusts the top: paler toward its back, so it fades into the light.
	var dust := PackedVector2Array()
	for p in top:
		dust.append(p.lerp(Vector2(0, -hc), 0.35))
	draw_colored_polygon(dust, Color(0.45, 0.41, 0.38, 0.35 * alpha))
	# Ashy rim on the top face's front edge.
	var rim := PackedVector2Array()
	for i in range(0, RIM / 2 + 1):
		rim.append(top[i % RIM])
	draw_polyline(rim, Color(0.62, 0.58, 0.55, 0.3 * alpha), maxf(1.0, r * 0.06))
	# Soften the silhouette: a faint warm haze over the coal's outline.
	draw_texture_rect(_glow_tex(), Rect2(-r * 1.4, -hc - r * 0.9, r * 2.8, r * 2.2), false, Color(0.6, 0.35, 0.2, 0.12 * pulse * alpha))
	# Glowing cracks across the top, hot yellow at their heart.
	var cy := -hc
	var crack := PackedVector2Array([Vector2(-0.5, 0.05), Vector2(-0.15, -0.12), Vector2(0.12, 0.08), Vector2(0.45, -0.06)])
	var pts := PackedVector2Array()
	for p in crack:
		pts.append(Vector2(p.x * r, cy + p.y * r * SQUASH * 1.6))
	draw_polyline(pts, Color(1.0, 0.45, 0.1, 0.85 * pulse * alpha), maxf(1.6, r * 0.2))
	draw_polyline(pts, Color(1.0, 0.85, 0.4, pulse * alpha), maxf(1.0, r * 0.07))
	for p in _ash:
		_ellipse(Vector2(p.x * r * 0.6, cy + p.y * r * SQUASH * 0.7), r * 0.07, r * 0.05, Color(0.75, 0.72, 0.7, 0.6 * alpha))
	# A slight flame dancing off the top: a short teardrop that sways and flickers.
	var sway := sin(_t * 7.0) * 0.22 + sin(_t * 11.3) * 0.1
	var h := r * (0.95 + 0.15 * sin(_t * 13.0))
	var base := Vector2(r * 0.08, cy + r * 0.05)
	for layer in [[1.0, Color(1.0, 0.45, 0.1, 0.85 * alpha)], [0.55, Color(1.0, 0.88, 0.45, 0.95 * alpha)]]:
		var k: float = layer[0]
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			var w := r * 0.36 * k * sin(PI * minf(u * 1.25, 1.0) * 0.5 + (PI * 0.5 if u > 0.8 else 0.0)) * (1.0 - u)
			var x := sway * r * u * u
			left.append(base + Vector2(x - w, -u * h * k))
			right.append(base + Vector2(x + w, -u * h * k))
		right.reverse()
		left.append_array(right)
		draw_colored_polygon(left, layer[1])
	# Charged smoke: soft gray-to-white puffs curling up and away, with a
	# few sparks riding them.
	for i in 6:
		var u := fmod(_t * 0.42 + i / 6.0, 1.0)
		var curl := sin(_t * 1.7 + i * 2.1) * r * 0.5 * u + sin(u * 5.0 + i) * r * 0.25
		var c := base + Vector2(curl + r * 0.3 * u, -r * 0.6 - u * r * 3.4)
		var pr := r * (0.35 + 0.75 * u)
		var grey := lerpf(0.5, 0.96, u)
		var a := sin(PI * u) * 0.46 * alpha
		draw_texture_rect(_glow_tex(), Rect2(c.x - pr, c.y - pr * 0.85, pr * 2.0, pr * 1.7), false, Color(grey, grey, grey * 1.02, a))
	for i in 3:
		var u := fmod(_t * 0.9 + i / 3.0, 1.0)
		var c := base + Vector2(sin(_t * 3.0 + i * 2.0) * r * 0.4 * u, -r * 0.4 - u * r * 2.2)
		draw_circle(c, maxf(1.0, r * 0.07 * (1.0 - u)), Color(1.0, 0.75, 0.3, (1.0 - u) * 0.9 * alpha))
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


static var _glow: Texture2D

static func _glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow
