extends Node2D
## A spirit drifting out of the dark along a trail toward the fire.
## A little ball of light with a faded glow and two grumpy black eyes.
## It makes its own light, so it shows up even far out in the dark.
## The Mist Wisp is a smaller, hazy blue version wrapped in drifting puffs.

signal banished(spirit)
signal reached_fire(spirit)
signal zapped(spirit)
signal summoned(spirit, count)   ## Helio calls up Midnight Sun Rays   ## a Charged Wisp hits the fire from range

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
var boss := false
var dim_range := 0.0       ## >0 (Dark Wisp): light defenses within this of aura_center() fire slower
var dim := 0.0
var dim_bob := 0.0
var dash_every := 0.0      ## >0 (Lantern Thief): dashes every dash_every seconds
var dash_time := 0.0
var dash_mult := 1.0
var snuff_range := 0.0
var snuff_time := 0.0
var _dash_t := 0.0         ## counts up; dashing while it's past dash_every - dash_time
var _trail: Array = []     ## recent screen positions while dashing (afterimages)
var summon_at: Array = []  ## Helio: trail shares where he stops to call Rays
var summon_pause := 0.0
var burn_range := 0.0      ## >0 (Helio): holds here and sears the fire steadily
var burn_dps := 0.0
var _summon_i := 0
var _pause_t := 0.0        ## time left on a summoning stop
var _rage_t := 0.0         ## time left on an angry shake
var _rage_cd := 2.0
var _flares: Array = []    ## Helio's dark orange wisps: [angle, age, life, len]

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
	boss = d.get("boss", false)
	dim_range = d.get("dim_range", 0.0)
	dim = d.get("dim", 0.0)
	dim_bob = d.get("dim_bob", 0.0)
	dash_every = d.get("dash_every", 0.0)
	dash_time = d.get("dash_time", 0.0)
	dash_mult = d.get("dash_mult", 1.0)
	snuff_range = d.get("snuff_range", 0.0)
	snuff_time = d.get("snuff_time", 0.0)
	summon_at = d.get("summon_at", [])
	summon_pause = d.get("summon_pause", 0.0)
	burn_range = d.get("burn_range", 0.0)
	burn_dps = d.get("burn_dps", 0.0)
	_zap_t = zap_every * 0.5
	_t = randf() * 10.0
	world = board.path_point(path_idx, 0.0)
	position = board.proj(world)


## Slow bob for the Dark Wisp: -1..1. His body and his dimming circle move with it.
func _bob_k() -> float:
	return sin(_t * 1.4)


## Centre of the dimming circle: the boss's spot, bobbed back and forth on the ground
## (up and down on screen).
func aura_center() -> Vector2:
	return world + Vector2(0, -dim_bob * (_bob_k() * 0.5 + 0.5))


## Helio: close enough to sear the fire?
func burning() -> bool:
	return burn_range > 0.0 and not dead and world.length() <= burn_range


## Start partway down a trail (Rays rise from Helio's spot).
func place_at(d: float) -> void:
	dist = d
	world = board.path_point(path_idx, dist)
	position = board.proj(world)


## Lantern Thief: mid-dash right now?
func dashing() -> bool:
	return dash_every > 0.0 and _dash_t >= dash_every - dash_time


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
	if burn_range > 0.0:
		_helio_tick(delta)
		if burning() or _pause_t > 0.0:
			queue_redraw()
			return
	var d0 := dist
	var burst := 1.0
	if dash_every > 0.0:
		_dash_t += delta
		if _dash_t >= dash_every:
			_dash_t -= dash_every
		if not dead and _dash_t >= dash_every - dash_time and _dash_t - delta < dash_every - dash_time:
			AudioDirector.play_sfx("dash", -5.0)
		if dashing():
			burst = dash_mult
			_trail.push_front(position)
		elif not _trail.is_empty():
			_trail.pop_back()
		if _trail.size() > 6:
			_trail.pop_back()
	dist += speed * burst * (1.0 - slow) * board.speed_at(world) * delta   # water slows them
	path_idx = board.route(path_idx, d0, dist)   # forks: pick a way (or the gate's)
	if dist >= board.path_lengths[path_idx]:
		dead = true
		reached_fire.emit(self)
		queue_free()
		return
	world = board.path_point(path_idx, dist)
	position = board.proj(world)
	queue_redraw()


## Helio's moods: flares, angry shakes, summoning stops.
func _helio_tick(delta: float) -> void:
	for f in _flares:
		f[1] += delta
	_flares = _flares.filter(func(f): return f[1] < f[2])
	if randf() < delta * (5.0 if burning() else 2.2):   # semi-frequent dark orange wisps
		_flares.append([randf() * TAU, 0.0, randf_range(0.6, 1.0), randf_range(1.6, 2.4)])
	_rage_t = maxf(0.0, _rage_t - delta)
	_rage_cd -= delta
	if _rage_cd <= 0.0:
		_rage_cd = randf_range(2.5, 4.5) * (0.5 if burning() else 1.0)
		_rage_t = 0.6
	if _pause_t > 0.0:
		var was := _pause_t
		_pause_t -= delta
		if was > summon_pause * 0.5 and _pause_t <= summon_pause * 0.5:
			summoned.emit(self, 1 + Run.rng.randi() % 2)
		return
	if not burning() and _summon_i < summon_at.size() and progress() >= summon_at[_summon_i]:
		_summon_i += 1
		_pause_t = summon_pause
		_rage_t = summon_pause   # shakes while calling them up


func _draw() -> void:
	if burn_range > 0.0:
		_draw_helio()
		return
	if dim_range > 0.0:
		_draw_dark()
		return
	if dash_every > 0.0:
		_draw_thief()
		return
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
	if kind == "sun_ray":   # furious brows
		for side in [-1.0, 1.0]:
			draw_line(Vector2(side * s * 0.62, -s * 0.36) + look, Vector2(side * s * 0.08, -s * 0.08) + look, ink, maxf(2.0, s * 0.16))
	draw_set_transform(Vector2.ZERO)
	if _arc > 0.0 and not dead:
		_draw_arc(Vector2(0, -s * 1.9 + bob), board.proj(Vector2.ZERO) - position, s, alpha)
	# Health bar once hurt.
	if hp < max_hp and not dead:
		var w := s * 2.0
		var y: float = -s * 3.4 + bob
		draw_rect(Rect2(-w / 2, y, w, 4), Color(0, 0, 0, 0.6 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 4), Color(1.0, 0.7, 0.3, alpha))


## Carl, the Dark Wisp: a big black ball with a faint lavender glow, white and
## purple swirls that wrap around it every few seconds, and a dim circle on the
## ground that bobs up and down with him.
func _draw_dark() -> void:
	var s: float = 15.0 * size_k * board.view_scale
	var alpha := _fade_in * (1.0 - _death / 0.35)
	var lav := Color("#b9a3ff")
	# The dimming circle on the ground, centred on aura_center().
	if not dead:
		var c: Vector2 = aura_center()
		var ring := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			ring.append(board.proj(c + Vector2(cos(a), sin(a)) * dim_range) - position)
		draw_colored_polygon(ring, Color(0.05, 0.02, 0.12, 0.28 * alpha))
		draw_polyline(ring, Color(lav, 0.35 * alpha), 2.0, true)
	# The body rides the same bob (screen up = back on the ground).
	var lift: float = (board.proj(aura_center()) - position).y
	var y0: float = -s * 1.9 + lift
	_oval(Vector2(0, 2), s * 0.7, s * 0.2, Color(0, 0, 0, 0.35 * alpha))
	var grow := 1.0 + _death * 2.0
	draw_set_transform(Vector2(0, y0), 0.0, Vector2.ONE * grow)
	var pulse := 1.0 + sin(_t * 2.0) * 0.05
	var gr: float = s * 2.4 * pulse
	draw_texture_rect(_glow_tex(), Rect2(-gr, -gr, gr * 2.0, gr * 2.0), false, Color(lav, 0.32 * alpha))
	var body := Color(base_color, 0.97 * alpha)
	if _flash > 0.0:
		body = body.lerp(Color(lav, alpha), 0.6)
	draw_circle(Vector2.ZERO, s, body)
	draw_arc(Vector2.ZERO, s, 0, TAU, 48, Color(lav, 0.45 * alpha), 2.0, true)
	draw_circle(Vector2(-s * 0.4, -s * 0.45), s * 0.13, Color(lav, 0.35 * alpha))
	# Swirls: every ~4s, white and purple streaks wrap round him and fade.
	var cyc := fmod(_t, 4.0) / 4.0
	var sw := clampf(sin(cyc * PI) * 1.6 - 0.3, 0.0, 1.0)
	if sw > 0.0:
		for i in 2:
			var col := Color.WHITE if i == 0 else Color("#9b6bff")
			var rot := _t * 2.4 + PI * i
			var pts := PackedVector2Array()
			for j in 18:
				var a := rot + j * 0.16
				var r := s * (1.15 + 0.12 * sin(j * 0.5 + _t))
				pts.append(Vector2(cos(a) * r, sin(a) * r * 0.45))
			draw_polyline(pts, Color(col, 0.75 * sw * alpha), maxf(2.0, s * 0.09), true)
	# Pale glowing eyes with the same scowl as every Wisp.
	var look: Vector2 = (-world).normalized() * s * 0.07
	var eye := Color("#e9e0ff", alpha)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * s * 0.34, s * 0.08) + look
		var pts := PackedVector2Array()
		for i in 28:
			var t := TAU * i / 28.0
			var p := Vector2(cos(t) * s * 0.16, sin(t) * s * 0.22)
			var cut := lerpf(-0.02, -0.26, (side * p.x / (s * 0.16) + 1.0) / 2.0) * s
			p.y = maxf(p.y, cut)
			pts.append(c + p)
		draw_colored_polygon(pts, eye)
	draw_set_transform(Vector2.ZERO)
	# Boss health bar, always shown.
	if not dead:
		var w := s * 2.4
		var y: float = y0 - s * 1.5
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.7 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 6), Color(lav, alpha))


## The Lantern Thief: a quick gold Wisp in a dark bandit's mask, with a pilfered
## lantern swinging below him. Mid-dash he leaves golden afterimages, and a ring
## shows how far his snuffing reaches.
func _draw_thief() -> void:
	var s: float = 15.0 * size_k * board.view_scale
	var alpha := _fade_in * (1.0 - _death / 0.35)
	var bob: float = sin(_t * 5.0) * 3.0 * board.view_scale
	var col := base_color
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.8)
	var dash := dashing() and not dead
	# Afterimages along the trail.
	for i in _trail.size():
		var off: Vector2 = _trail[i] - position
		draw_circle(off + Vector2(0, -s * 1.9), s * (0.9 - i * 0.1), Color(col, 0.22 * (1.0 - i / 6.0) * alpha))
	if dash:   # snuff reach on the ground
		var ring := PackedVector2Array()
		for i in 41:
			var a := TAU * i / 40.0
			ring.append(board.proj(world + Vector2(cos(a), sin(a)) * snuff_range) - position)
		draw_polyline(ring, Color(col, 0.35 * alpha), 2.0, true)
	_oval(Vector2(0, 2), s * 0.7, s * 0.2, Color(0, 0, 0, 0.3 * alpha))
	var grow := 1.0 + _death * 2.0
	# Leans forward when dashing.
	draw_set_transform(Vector2(0, -s * 1.9 + bob), 0.25 if dash else 0.0, Vector2.ONE * grow)
	var gr: float = s * (3.2 if dash else 2.6)
	draw_texture_rect(_glow_tex(), Rect2(-gr, -gr, gr * 2.0, gr * 2.0), false, Color(col, 0.55 * alpha))
	# Stolen lantern swinging under him.
	var sw := sin(_t * 4.0) * 0.4
	var lp := Vector2(sin(sw), cos(sw)) * s * 1.35
	draw_line(Vector2(0, s * 0.8), lp, Color(0.2, 0.15, 0.1, alpha), 2.0, true)
	draw_rect(Rect2(lp + Vector2(-s * 0.18, 0), Vector2(s * 0.36, s * 0.42)), Color(0.25, 0.18, 0.1, alpha))
	draw_circle(lp + Vector2(0, s * 0.21), s * 0.12, Color("#fff0b0", alpha))
	draw_circle(Vector2.ZERO, s, Color(col, 0.95 * alpha))
	draw_circle(Vector2(-s * 0.42, -s * 0.48), s * 0.2, Color(1, 1, 1, 0.6 * alpha))
	# Bandit's mask: a dark band across the eyes, tails flapping behind.
	var mask := Color(0.12, 0.08, 0.1, alpha)
	draw_rect(Rect2(-s, -s * 0.12, s * 2.0, s * 0.42), mask)
	var flap := sin(_t * 9.0) * s * 0.1
	draw_colored_polygon(PackedVector2Array([Vector2(s * 0.9, -s * 0.05), Vector2(s * 1.55, -s * 0.2 + flap), Vector2(s * 1.5, s * 0.15 + flap), Vector2(s * 0.9, s * 0.25)]), mask)
	# Narrow sly eyes in the mask.
	var look: Vector2 = (-world).normalized() * s * 0.06
	for side in [-1.0, 1.0]:
		var c := Vector2(side * s * 0.36, s * 0.09) + look
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.17, 0), c + Vector2(s * 0.17, -side * s * 0.05), c + Vector2(0, s * 0.08)]), Color("#fff6d8", alpha))
	draw_set_transform(Vector2.ZERO)
	if not dead:
		var w := s * 2.6
		var y: float = -s * 3.6 + bob
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.7 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 6), Color(col, alpha))


## Helio, the Midnight Sun: a big yellow ball in an orange glow, dark orange
## wisps curling off him, furious slanted eyes under heavy brows. He shakes with
## rage now and then (all through a summoning stop, and more often when searing).
func _draw_helio() -> void:
	var s: float = 15.0 * size_k * board.view_scale
	var alpha := _fade_in * (1.0 - _death / 0.35)
	var bob: float = sin(_t * 2.2) * 3.0 * board.view_scale
	var shake := Vector2.ZERO
	if _rage_t > 0.0 and not dead:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s * 0.07
	var col := base_color
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.8)
	var sear := burning()
	_oval(Vector2(0, 2), s * 0.75, s * 0.22, Color(0, 0, 0, 0.3 * alpha))
	var grow := 1.0 + _death * 2.0
	draw_set_transform(Vector2(0, -s * 1.7 + bob) + shake, 0.0, Vector2.ONE * grow)
	var pulse := 1.0 + sin(_t * (7.0 if sear else 3.0)) * 0.06
	var gr: float = s * (3.6 if sear else 3.0) * pulse
	draw_texture_rect(_glow_tex(), Rect2(-gr, -gr, gr * 2.0, gr * 2.0), false, Color(1.0, 0.55, 0.12, (0.85 if sear else 0.65) * alpha))
	# Dark orange sun rays: straight tapered spikes that shoot out from his rim,
	# stretch, and fade, turning slowly with him.
	for f in _flares:
		var k: float = f[1] / f[2]
		var a: float = f[0] + _t * 0.15
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		var tip: float = s * (1.15 + (f[3] - 0.7) * sqrt(k))   # shoots out fast, then eases
		var fa := sin(k * PI) * alpha
		var w := s * 0.2
		# Soft outer glow, then the ray itself, then a bright core line.
		draw_colored_polygon(PackedVector2Array([dir * s * 0.85 + side * w * 1.8, dir * (tip + s * 0.15), dir * s * 0.85 - side * w * 1.8]), Color(1.0, 0.5, 0.1, 0.22 * fa))
		draw_colored_polygon(PackedVector2Array([dir * s * 0.9 + side * w, dir * tip, dir * s * 0.9 - side * w]), Color(0.85, 0.33, 0.04, 0.9 * fa))
		draw_line(dir * s * 0.95, dir * lerpf(s, tip, 0.7), Color(1.0, 0.65, 0.2, 0.7 * fa), maxf(1.0, s * 0.05), true)
	draw_circle(Vector2.ZERO, s, Color(col, 0.97 * alpha))
	draw_circle(Vector2(0, s * 0.1), s * 0.85, Color(1.0, 0.62, 0.15, 0.35 * alpha))
	draw_circle(Vector2(-s * 0.08, -s * 0.1), s * 0.7, Color(1, 1, 0.85, 0.3 * alpha))
	draw_circle(Vector2(-s * 0.42, -s * 0.48), s * 0.18, Color(1, 1, 1, 0.7 * alpha))
	# Extra angry eyes: glowing red slits under heavy V brows, glaring at the fire.
	var look: Vector2 = (-world).normalized() * s * 0.06
	var ink := Color(0.18, 0.05, 0.02, alpha)
	for side in [-1.0, 1.0]:
		var c := Vector2(side * s * 0.36, s * 0.05) + look
		var eye := PackedVector2Array([c + Vector2(-side * s * 0.05, -s * 0.06), c + Vector2(side * s * 0.26, -s * 0.2),
			c + Vector2(side * s * 0.22, s * 0.1), c + Vector2(-side * s * 0.06, s * 0.08)])
		draw_colored_polygon(eye, ink)
		draw_circle(c + Vector2(side * s * 0.08, -s * 0.01), s * 0.06, Color(1.0, 0.25, 0.1, alpha))
		draw_line(Vector2(side * s * 0.75, -s * 0.5) + look, Vector2(side * s * 0.06, -s * 0.12) + look, ink, maxf(3.0, s * 0.15))
	# A scowling mouth.
	draw_polyline(PackedVector2Array([Vector2(-s * 0.3, s * 0.52), Vector2(0, s * 0.4), Vector2(s * 0.3, s * 0.52)]), ink, maxf(2.0, s * 0.08), true)
	draw_set_transform(Vector2.ZERO)
	if not dead:
		var w := s * 2.6
		var y: float = -s * 3.3 + bob
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.7 * alpha))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 6), Color(1.0, 0.6, 0.15, alpha))


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
