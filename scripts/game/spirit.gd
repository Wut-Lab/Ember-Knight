extends Node2D
## A spirit drifting out of the dark along a trail toward the fire.
## A little ball of light with a faded glow and two grumpy black eyes.
## It makes its own light, so it shows up even far out in the dark.
## The Mist Wisp is a smaller, hazy blue version wrapped in drifting puffs.

signal banished(spirit)
signal reached_fire(spirit)
signal zapped(spirit)   ## a Charged Wisp hits the fire from range

const Defs := preload("res://scripts/game/defs.gd")

var kind := "wisp"
var hp := 1.0
var max_hp := 1.0
var speed := 50.0
var damage := 5.0
var size_k := 1.0
var base_color := Color.WHITE
var path_idx := 0
var dist := 0.0
var world := Vector2.ZERO
var slow := 0.0            ## 0..1, set by the battle from nearby slowing defenses
var dead := false
var zap_range := 0.0       ## >0: stops this close to the fire and zaps it
var zap_every := 2.0
var _zap_t := 0.0
var _arc := 0.0            ## time left on the visible zap arc

var board
var _t := 0.0
var _flash := 0.0
var _fade_in := 0.0
var _death := 0.0


func setup(b, k: String, path: int, hp_scale: float) -> void:
	board = b
	kind = k
	path_idx = path
	var d: Dictionary = Defs.SPIRITS[k]
	max_hp = d["hp"] * hp_scale
	hp = max_hp
	speed = d["speed"] * Run.rng.randf_range(0.92, 1.08)
	damage = d["damage"]
	size_k = d["size"]
	base_color = d["color"]
	zap_range = d.get("zap_range", 0.0)
	zap_every = d.get("zap_every", 2.0)
	_zap_t = zap_every * 0.5
	_t = randf() * 10.0
	world = board.path_point(path_idx, 0.0)
	position = board.proj(world)


func progress() -> float:
	return dist / board.path_lengths[path_idx]


func hit(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.12
	if hp <= 0.0:
		dead = true
		banished.emit(self)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_fade_in = minf(1.0, _fade_in + delta / 0.8)
	if dead:
		_death += delta
		if _death > 0.35:
			queue_free()
		queue_redraw()
		return
	_arc = maxf(0.0, _arc - delta)
	if zap_range > 0.0 and world.length() <= zap_range:
		# In range: hold still and zap the fire.
		_zap_t -= delta
		if _zap_t <= 0.0:
			_zap_t = zap_every
			_arc = 0.18
			zapped.emit(self)
		queue_redraw()
		return
	var d0 := dist
	dist += speed * (1.0 - slow) * board.speed_at(world) * delta   # water slows them
	path_idx = board.route(path_idx, d0, dist)   # forks: pick a way (or the gate's)
	if dist >= board.path_lengths[path_idx]:
		dead = true
		reached_fire.emit(self)
		queue_free()
		return
	world = board.path_point(path_idx, dist)
	position = board.proj(world)
	queue_redraw()


func _draw() -> void:
	var s: float = 15.0 * size_k * board.view_scale
	var bob: float = sin(_t * 3.0) * 4.0 * board.view_scale
	var lit: float = board.light_at(world)
	var alpha := _fade_in * (1.0 - _death / 0.35)
	var pulse := 1.0 + sin(_t * 4.0) * 0.06
	# Faint shadow, only visible near the fire.
	_oval(Vector2(0, 2), s * 0.7, s * 0.2, Color(0, 0, 0, 0.3 * lit * alpha))
	# On death the ball swells and fades out.
	var grow := 1.0 + _death * 2.0
	draw_set_transform(Vector2(0, -s * 1.9 + bob), 0.0, Vector2.ONE * grow)
	var col := base_color
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.8)
	# Faded glow: a soft radial falloff around the ball.
	var mist := kind == "mist_wisp"
	var charged := kind == "charged_wisp"
	var gr: float = s * (3.4 if mist else 2.8) * pulse
	var glow_col := Color("#ff9a3c") if charged else col
	draw_texture_rect(_glow_tex(), Rect2(-gr, -gr, gr * 2.0, gr * 2.0), false, Color(glow_col, (0.4 if mist else 0.7 if charged else 0.55) * alpha))
	if mist:
		# Haze: soft puffs drifting slowly around the ball.
		for i in 5:
			var a := _t * 0.7 + TAU * i / 5.0
			var off := Vector2(cos(a), sin(a) * 0.6) * s * (0.9 + 0.25 * sin(_t * 1.3 + i))
			var pr := s * (0.9 + 0.2 * sin(_t * 2.0 + i * 1.7))
			draw_texture_rect(_glow_tex(), Rect2(off.x - pr, off.y - pr, pr * 2.0, pr * 2.0), false, Color(col, 0.45 * alpha))
	# The ball of light, brighter at its heart (fainter and see-through for mist).
	draw_circle(Vector2.ZERO, s, Color(col, (0.7 if mist else 0.95) * alpha))
	draw_circle(Vector2(-s * 0.05, -s * 0.05), s * 0.78, Color(1, 1, 1, 0.25 * alpha))
	draw_circle(Vector2(-s * 0.42, -s * 0.48), s * 0.2, Color(1, 1, 1, 0.7 * alpha))
	if kind == "charged_wisp":
		_draw_crackle(s, alpha)
	# Two grumpy black eyes, glancing toward the fire: ovals with the top
	# sliced off at a slant (low toward the middle) for a scowl.
	var look: Vector2 = (-world).normalized() * s * 0.07
	var ink := Color(0.04, 0.03, 0.07, alpha)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * s * 0.34, s * 0.08) + look
		var pts := PackedVector2Array()
		for i in 28:
			var t := TAU * i / 28.0
			var p := Vector2(cos(t) * s * 0.16, sin(t) * s * 0.22)
			# Cut line: y = -0.02s at the inner edge, -0.26s at the outer edge.
			var cut := lerpf(-0.02, -0.26, (side * p.x / (s * 0.16) + 1.0) / 2.0) * s
			p.y = maxf(p.y, cut)
			pts.append(c + p)
		draw_colored_polygon(pts, ink)
	draw_set_transform(Vector2.ZERO)
	if _arc > 0.0 and not dead:
		_draw_arc(Vector2(0, -s * 1.9 + bob), board.proj(Vector2.ZERO) - position, s, alpha)
	# Health bar once hurt.
	if hp < max_hp and not dead:
		var w := s * 2.0
		var y: float = -s * 3.4 + bob
		draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.6 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 4), Color(1.0, 0.7, 0.3, alpha))


## Red crackle: short jagged bolts flicking around the ball, re-drawn every
## 0.07s. They grow and brighten in the half second before a zap.
func _draw_crackle(s: float, alpha: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(_t / 0.07) * 7919 + get_instance_id()
	var charge := 1.0
	if zap_range > 0.0 and world.length() <= zap_range:
		charge = 1.0 + clampf(1.0 - _zap_t / 0.5, 0.0, 1.0)
	for i in 3:
		# Each bolt hugs the surface: it creeps around the ball, hopping out and back.
		var a := r.randf() * TAU
		var dir := 1.0 if r.randf() < 0.5 else -1.0
		var pts := PackedVector2Array()
		for k in 4:
			var rad := s * (0.95 + (r.randf_range(0.1, 0.35) * charge if k % 2 == 1 else 0.0))
			pts.append(Vector2(cos(a), sin(a)) * rad)
			a += dir * r.randf_range(0.18, 0.32)
		draw_polyline(pts, Color(1.0, 0.25, 0.1, 0.35 * alpha), maxf(3.0, s * 0.22))
		draw_polyline(pts, Color(1.0, 0.18, 0.1, 0.95 * alpha), maxf(1.5, s * 0.08))


## The zap: a jagged red-white bolt from the ball to the fire.
func _draw_arc(from: Vector2, to: Vector2, s: float, alpha: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(_t / 0.05)
	var pts := PackedVector2Array()
	var n := 7
	var side := (to - from).orthogonal().normalized()
	for i in n + 1:
		var f := float(i) / n
		var j := 0.0 if i == 0 or i == n else r.randf_range(-1.0, 1.0) * s * 0.5
		pts.append(from.lerp(to, f) + side * j)
	draw_polyline(pts, Color(1.0, 0.3, 0.15, 0.8 * alpha), s * 0.22)
	draw_polyline(pts, Color(1.0, 0.95, 0.8, alpha), maxf(1.5, s * 0.08))


static var _glow: Texture2D

static func _glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
