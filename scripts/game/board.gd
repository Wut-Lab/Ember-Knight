extends Node2D
## The night camp clearing, drawn 2.5D: a lit dirt clearing fading into dark,
## three trails the spirits follow to the fire, and the stone tiles where dice
## become defenses. Gameplay runs in flat "world" units; `proj()` squashes
## them onto the screen (y * K) so the ground reads as seen from above at an angle.
## The node's origin is the fire.

const Defs := preload("res://scripts/game/defs.gd")

const K := 0.56                ## vertical squash of the ground plane
const FIRE_RADIUS := 70.0      ## a spirit this close hurts Char's flame
const SPAWN_RADIUS := 660.0
const LIGHT_RADIUS := 360.0
const TILE_RADIUS := 44.0
const PATH_ANGLES := [180.0, 300.0, 60.0]
const TILE_GROUP_ANGLES := [0.0, 120.0, 240.0]

var view_scale := 0.85
var paths: Array[PackedVector2Array] = []
var path_lengths: Array[float] = []
var tiles: Array[Vector2] = []
var tile_defense: Array = []          ## Defense node or null, per tile
var glow_face := ""                   ## face being placed: valid tiles glow
var hover_tile := -1
var fire_glow := 1.0                  ## set by the battle (flicker, swells)

var _t := 0.0
var _tufts: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	for i in PATH_ANGLES.size():
		var a0 := deg_to_rad(PATH_ANGLES[i])
		var pts := PackedVector2Array()
		var steps := 28
		for k in steps + 1:
			var f := float(k) / steps
			var rad := lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f)
			var wig := sin(f * PI * 1.6 + i * 1.7) * deg_to_rad(13.0) * (rad / SPAWN_RADIUS)
			pts.append(Vector2(cos(a0 + wig), sin(a0 + wig)) * rad)
		paths.append(pts)
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k].distance_to(pts[k - 1])
		path_lengths.append(length)
	for g in TILE_GROUP_ANGLES:
		for t in [[g, 168.0], [g - 23.0, 300.0], [g + 23.0, 300.0]]:
			var a := deg_to_rad(t[0])
			tiles.append(Vector2(cos(a), sin(a)) * t[1])
			tile_defense.append(null)
	for i in 70:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * LIGHT_RADIUS * 1.05 + 60.0
		_tufts.append([Vector2(cos(a), sin(a)) * d, r.randf_range(0.7, 1.3), r.randi() % 3])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ------------------------------------------------------------ geometry
func proj(w: Vector2) -> Vector2:
	return Vector2(w.x, w.y * K) * view_scale


func unproj(local: Vector2) -> Vector2:
	return Vector2(local.x, local.y / K) / view_scale


## World position `dist` units along path `i` (from the dark toward the fire).
func path_point(i: int, dist: float) -> Vector2:
	var pts := paths[i]
	var left := dist
	for k in range(1, pts.size()):
		var seg := pts[k].distance_to(pts[k - 1])
		if left <= seg:
			return pts[k - 1].lerp(pts[k], left / maxf(seg, 0.001))
		left -= seg
	return pts[pts.size() - 1]


## How lit a world point is, 0 (dark) .. 1 (by the fire).
func light_at(w: Vector2) -> float:
	return clampf(1.0 - (w.length() - LIGHT_RADIUS * 0.55) / (LIGHT_RADIUS * 0.85), 0.0, 1.0)


func tile_at(local: Vector2) -> int:
	var w := unproj(local)
	var best := -1
	var best_d := TILE_RADIUS * 1.5
	for i in tiles.size():
		var d := tiles[i].distance_to(w)
		if d < best_d:
			best_d = d
			best = i
	return best


func is_fire_at(local: Vector2) -> bool:
	return unproj(local).length() < 95.0


## Can a die with this face go on tile i?
func can_place(face: String, i: int) -> bool:
	if not Defs.DEFENSES.has(face) or i < 0:
		return false
	var d = tile_defense[i]
	if d == null:
		return true
	return d.kind == face and d.level < 3


# ------------------------------------------------------------ drawing
func _draw() -> void:
	# Ground: rings from deep night to the warm lit dirt by the fire.
	var rings := 22
	for k in rings:
		var f := 1.0 - float(k) / rings          # 1 outer .. small inner
		var rad := lerpf(120.0, SPAWN_RADIUS * 1.25, f)
		var lit := clampf(1.0 - (rad - 140.0) / (LIGHT_RADIUS * 1.15), 0.0, 1.0)
		lit = pow(lit, 1.4) * fire_glow
		var col := Color("#0a080b").lerp(Color("#5e3d26"), clampf(lit, 0.0, 1.0))
		_ellipse(Vector2.ZERO, rad, col)
	# Trails, lighter packed dirt, fading into the dark.
	for p in paths:
		for k in range(1, p.size()):
			var mid := (p[k] + p[k - 1]) / 2.0
			var lit := light_at(mid) * fire_glow
			var col := Color("#17110f").lerp(Color("#7a5236"), clampf(lit, 0.0, 1.0))
			col.a = 0.55 + 0.45 * lit
			draw_line(proj(p[k - 1]), proj(p[k]), col, 46.0 * view_scale, true)
			draw_circle(proj(p[k]), 23.0 * view_scale * Vector2(1, K).length() * 0.72, col)
	# Grass tufts and pebbles, only seen where the light reaches.
	for tf in _tufts:
		var w: Vector2 = tf[0]
		var lit := light_at(w) * fire_glow
		if lit < 0.05:
			continue
		var p := proj(w)
		var s: float = tf[1] * view_scale
		if tf[2] == 0:
			draw_circle(p, 2.6 * s, Color("#8a6446", 0.6 * lit))
		else:
			var g := Color("#4f5a2c").lerp(Color("#7d8a3c"), 0.5).darkened(0.3)
			g.a = 0.8 * lit
			for b in 3:
				var ang := -PI / 2 + (b - 1) * 0.45
				draw_line(p, p + Vector2(cos(ang), sin(ang)) * 9.0 * s, g, 2.0 * s, true)
	# Tiles: flat stone slabs. Valid ones glow while a die is being placed.
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for i in tiles.size():
		var w := tiles[i]
		var lit := maxf(light_at(w), 0.35)
		var c := proj(w)
		var rx := TILE_RADIUS * view_scale
		_ellipse_xy(c + Vector2(0, 4 * view_scale), rx * 1.04, rx * K * 1.04, Color(0, 0, 0, 0.45))
		_ellipse_xy(c, rx, rx * K, Color("#3a312f").lerp(Color("#7d6a5c"), lit))
		_ellipse_xy(c - Vector2(0, 2 * view_scale), rx * 0.82, rx * K * 0.78, Color("#4a3f3a").lerp(Color("#97806c"), lit))
		var ok := glow_face != "" and can_place(glow_face, i)
		if ok:
			var gc := Color("#ffb238")
			gc.a = 0.35 + 0.35 * pulse + (0.3 if i == hover_tile else 0.0)
			_ring(c, rx * 1.12, rx * K * 1.12, gc, 4.0 * view_scale)
			if i == hover_tile:
				var rng_r: float = _preview_range(glow_face, i)
				if rng_r > 0.0:
					_ring(Vector2.ZERO + c, rng_r * view_scale, rng_r * view_scale * K, Color(1, 0.75, 0.35, 0.35), 2.0)
	# Fire target ring for the Kindle (★) die.
	if glow_face == "kindle":
		var gc := Color("#fff0b0")
		gc.a = 0.35 + 0.4 * pulse + (0.25 if hover_tile == -2 else 0.0)
		_ring(Vector2.ZERO, 92.0 * view_scale, 92.0 * view_scale * K, gc, 4.0 * view_scale)


func _preview_range(face: String, i: int) -> float:
	if not Defs.DEFENSES.has(face):
		return 0.0
	var lvl := 0
	if tile_defense[i] != null:
		lvl = tile_defense[i].level
	return Defs.DEFENSES[face][mini(lvl, 2)]["range"]


func _ellipse(c: Vector2, r: float, col: Color) -> void:
	_ellipse_xy(proj(c), r * view_scale, r * view_scale * K, col)


func _ellipse_xy(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _ring(c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)
