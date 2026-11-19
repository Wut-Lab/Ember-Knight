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
const FOUR_LANE_CHANCE := 0.5
const SHAPES := ["straight", "wavy", "curved"]

var view_scale := 0.85
var stop := "road"                    ## map stop id; set by the battle
var layout_seed := 0                  ## set by the battle (from Run.rng) before _ready
var shapes: Array[String] = []        ## per lane: straight / wavy / curved
var paths: Array[PackedVector2Array] = []
var path_lengths: Array[float] = []
var tiles: Array[Vector2] = []
var tile_defense: Array = []          ## Defense node or null, per tile
var glow_face := ""                   ## face being placed: valid tiles glow
var hover_tile := -1
var lift_tile := -1                 ## defense being moved (Oath of Shifting Embers)
var shift_glow := false             ## a move is available: defenses / empty tiles glow
var fire_glow := 1.0                  ## set by the battle (flicker, swells)

var _t := 0.0
var _tufts: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	_build_layout()
	if Run.autoplay:
		print("  map: %d lanes %s, %d forks" % [lane_count, shapes, links.size()])
	for i in 70:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * LIGHT_RADIUS * 1.05 + 60.0
		_tufts.append([Vector2(cos(a), sin(a)) * d, r.randf_range(0.7, 1.3), r.randi() % 3])


func _process(delta: float) -> void:
	_t += delta
	for L in links:
		L["cool"] = maxf(0.0, L["cool"] - delta)
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


## Can a lifted defense be moved to tile i? Only onto an empty tile.
func can_move_to(i: int) -> bool:
	return lift_tile >= 0 and i >= 0 and i != lift_tile and tile_defense[i] == null


# ------------------------------------------------------------ layout

## Lane angle offset (radians) along the trail; f goes 0 at spawn .. 1 at the fire.
func _offset(shape: String, f: float, ph: float, dir: float) -> float:
	match shape:
		"wavy":
			return sin(f * PI * 2.4 + ph) * deg_to_rad(11.0) * (1.0 - f * 0.7)
		"spiral":
			return dir * ph * (1.0 - f)   # ph holds the total wrap (radians)
		"curved":
			return dir * deg_to_rad(38.0) * pow(1.0 - f, 1.3)
	return sin(f * PI * 0.9 + ph) * deg_to_rad(5.0) * (1.0 - f)


func _f_at(rad: float) -> float:
	return (SPAWN_RADIUS - rad) / (SPAWN_RADIUS - FIRE_RADIUS + 6.0)


## 3-4 lanes, each a random shape; retried until no two lanes crowd each other.
func _build_layout() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed
	var hill := stop == "hill"
	var n := 4 if r.randf() < FOUR_LANE_CHANCE else 3
	if hill:   # Hillside Clearing: 2-3 trails spiral round the camp, all the same way
		n = 3 if r.randf() < 0.5 else 2
	var wrap := deg_to_rad(r.randf_range(Defs.HILL_WRAP_MIN, Defs.HILL_WRAP_MAX))
	var spin := -1.0 if r.randf() < 0.5 else 1.0
	var min_gap := deg_to_rad(52.0 if n == 4 else 72.0)
	var lanes := []   # [base angle, shape, phase, dir]
	for attempt in 30:
		lanes.clear()
		var rot := r.randf() * TAU
		if hill:
			for i in n:
				lanes.append([rot + TAU * i / n, "spiral", wrap, spin])
			break
		for i in n:
			var shape: String = SHAPES[r.randi() % SHAPES.size()] if attempt < 25 else "straight"
			lanes.append([rot + TAU * i / n + deg_to_rad(r.randf_range(-8.0, 8.0)), shape,
				r.randf() * TAU, -1.0 if r.randf() < 0.5 else 1.0])
		var ok := true
		for k in 11:
			var f := k / 10.0
			for i in n:
				var a: Array = lanes[i]
				var b: Array = lanes[(i + 1) % n]
				var gap := wrapf(b[0] + _offset(b[1], f, b[2], b[3]) - a[0] - _offset(a[1], f, a[2], a[3]), 0.0, TAU)
				if gap < min_gap or gap > TAU - min_gap * (n - 1):
					ok = false
		if ok:
			break
	_lanes = lanes
	for L in lanes:
		shapes.append(L[1])
		var pts := PackedVector2Array()
		_steps = 72 if hill else 36
		var steps := _steps
		for k in steps + 1:
			var f := float(k) / steps
			var rad := lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f)
			var a: float = L[0] + _offset(L[1], f, L[2], L[3])
			pts.append(Vector2(cos(a), sin(a)) * rad)
		paths.append(pts)
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k].distance_to(pts[k - 1])
		path_lengths.append(length)
	# A tile group sits between each pair of neighbouring lanes, centred in the gap.
	for i in n:
		var inner := _gap_mid(i, 168.0)
		tiles.append(Vector2(cos(inner[0]), sin(inner[0])) * 168.0)
		var outer := _gap_mid(i, 300.0)
		var spread := minf(deg_to_rad(23.0), outer[1] / 2.0 - deg_to_rad(14.0))
		for s in [-1.0, 1.0]:
			var a: float = outer[0] + s * spread
			tiles.append(Vector2(cos(a), sin(a)) * 300.0)
	for t in tiles:
		tile_defense.append(null)
	lane_count = n
	_build_forks(r, hill)


var _lanes := []
var _steps := 36
var lane_count := 0          ## real trails; paths past this index are fork routes
## One-way forks. Each: from (lane), to (lane), at (dist on `from` where it forks),
## path (index of the route that takes the fork), pts (connector, for drawing),
## gate (Char has cobbled one here), cross (gate sends spirits down the fork),
## cool (seconds until the gate can be switched again).
var links: Array = []


## [mid angle, gap width] between lane i and lane i+1 at this radius.
func _gap_mid(i: int, rad: float) -> Array:
	var f := _f_at(rad)
	var a: Array = _lanes[i]
	var b: Array = _lanes[(i + 1) % _lanes.size()]
	var a0: float = a[0] + _offset(a[1], f, a[2], a[3])
	var gap := wrapf(b[0] + _offset(b[1], f, b[2], b[3]) - a0, 0.0, TAU)
	return [a0 + gap / 2.0, gap]


func _lane_angle(i: int, f: float) -> float:
	var L: Array = _lanes[i]
	return L[0] + _offset(L[1], f, L[2], L[3])


func _lane_pos(i: int, f: float) -> Vector2:
	var a := _lane_angle(i, f)
	return Vector2(cos(a), sin(a)) * lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f)


## Distance along lane i at fraction f (lane points are evenly spaced in f).
func _dist_at(i: int, f: float) -> float:
	var pts := paths[i]
	var kf := f * _steps
	var k := int(kf)
	var d := 0.0
	for j in range(1, k + 1):
		d += pts[j].distance_to(pts[j - 1])
	if k < _steps:
		d += pts[k].distance_to(pts[k + 1]) * (kf - k)
	return d


## 1-3 one-way forks. On the road a fork cuts across the gap between two
## neighbouring trails, out past the tiles; on the hill it is a shortcut
## straight down the slope to the next spiral arm in.
func _build_forks(r: RandomNumberGenerator, hill: bool) -> void:
	var n := lane_count
	var want := r.randi_range(Defs.FORKS_MIN, Defs.FORKS_MAX)
	var order := range(n)
	for i in range(n - 1, 0, -1):   # shuffle which gaps / arms get forks
		var j := r.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for g in order:
		if links.size() >= want:
			break
		var fk := []   # [from, to, f_from, f_to, connector pts]
		if hill:
			fk = _hill_fork(g, r)
		else:
			var a: int = g
			var b: int = (g + 1) % n
			if r.randf() < 0.5:
				var t := a
				a = b
				b = t
			var f1 := _f_at(Defs.FORK_RADIUS)
			var f2 := _f_at(Defs.MERGE_RADIUS)
			var a1 := _lane_angle(a, f1)
			var b2 := _lane_angle(b, f2)
			var delta := wrapf(b2 - a1, -PI, PI)
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				var ang := a1 + delta * t
				pts.append(Vector2(cos(ang), sin(ang)) * lerpf(Defs.FORK_RADIUS, Defs.MERGE_RADIUS, t))
			fk = [a, b, f1, f2, pts]
		if fk.is_empty() or not _clear_of_tiles(fk[4]):
			continue
		_add_fork(fk)


## A hill fork: from arm i, straight down the slope to the next arm inward.
func _hill_fork(i: int, r: RandomNumberGenerator) -> Array:
	var best := []
	var best_len := INF
	for tries in 16:
		var f1 := _f_at(r.randf_range(360.0, 520.0))
		var p1 := _lane_pos(i, f1)
		for b in lane_count:
			if b == i:
				continue
			for k in 40:   # chords down the slope to points further in on arm b
				var fb := lerpf(f1 + 0.08, 0.85, k / 39.0)
				var p2 := _lane_pos(b, fb)
				var d := p1.distance_to(p2)
				if d >= best_len or d < 90.0:
					continue
				var pts := PackedVector2Array()
				for j in 9:
					pts.append(p1.lerp(p2, j / 8.0))
				if _clear_of_tiles(pts) and _clear_of_lanes(pts, i, b):
					best = [i, b, f1, fb, pts]
					best_len = d
	return best


## The fork's middle mustn't run over another trail.
func _clear_of_lanes(pts: PackedVector2Array, a: int, b: int) -> bool:
	for j in range(2, pts.size() - 2):
		for L in lane_count:
			for q in paths[L]:
				if q.distance_to(pts[j]) < 40.0:
					return false
	return true


func _clear_of_tiles(pts: PackedVector2Array) -> bool:
	for p in pts:
		for t in tiles:
			if p.distance_to(t) < TILE_RADIUS + 22.0:
				return false
	return true


## The route a spirit takes down the fork: lane `from` up to the fork, the
## connector, then lane `to` on to the fire. It shares the lane's start, so a
## spirit can switch onto it without changing its distance travelled.
func _add_fork(fk: Array) -> void:
	var a: int = fk[0]
	var b: int = fk[1]
	var route := PackedVector2Array()
	var la := paths[a]
	var lb := paths[b]
	var ka := int(fk[2] * _steps)
	for k in ka + 1:
		route.append(la[k])
	route.append_array(fk[4])
	for k in range(int(fk[3] * _steps) + 1, lb.size()):
		route.append(lb[k])
	paths.append(route)
	var length := 0.0
	for k in range(1, route.size()):
		length += route[k].distance_to(route[k - 1])
	path_lengths.append(length)
	links.append({"from": a, "to": b, "at": _dist_at(a, fk[2]), "path": paths.size() - 1,
		"pts": fk[4], "gate": false, "cross": false, "cool": 0.0})


## Called by a spirit each step: does it hit a fork, and which way does it go?
func route(path_idx: int, d0: float, d1: float) -> int:
	if path_idx >= lane_count:
		return path_idx
	for L in links:
		if L["from"] == path_idx and d0 < L["at"] and d1 >= L["at"]:
			var cross: bool = L["cross"] if L["gate"] else Run.rng.randf() < 0.5
			return L["path"] if cross else path_idx
	return path_idx


## Index of the fork whose junction is near this local point, or -1.
func link_at(local: Vector2) -> int:
	var w := unproj(local)
	for i in links.size():
		if links[i]["pts"][0].distance_to(w) < 60.0:
			return i
	return -1


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
	var trails: Array = paths.slice(0, lane_count)
	for L in links:
		trails.append(L["pts"])
	for p: PackedVector2Array in trails:
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
		if lift_tile >= 0:
			ok = can_move_to(i)
		if i == lift_tile or (shift_glow and lift_tile < 0 and tile_defense[i] != null):
			var lc := Color("#fff0b0")
			lc.a = 0.3 + 0.4 * pulse if i == lift_tile else 0.12 + 0.18 * pulse
			_ring(c, rx * 1.2, rx * K * 1.2, lc, 3.0 * view_scale)
		if ok:
			var gc := Color("#ffb238")
			gc.a = 0.35 + 0.35 * pulse + (0.3 if i == hover_tile else 0.0)
			_ring(c, rx * 1.12, rx * K * 1.12, gc, 4.0 * view_scale)
			if i == hover_tile:
				var rng_r: float = _preview_range(glow_face if lift_tile < 0 else tile_defense[lift_tile].kind, i)
				if rng_r > 0.0:
					_ring(Vector2.ZERO + c, rng_r * view_scale, rng_r * view_scale * K, Color(1, 0.75, 0.35, 0.35), 2.0)
				var face_now: String = glow_face if lift_tile < 0 else tile_defense[lift_tile].kind
				if Defs.DEFENSES.has(face_now) and Defs.DEFENSES[face_now][0].has("min"):
					var mn: float = Defs.DEFENSES[face_now][0]["min"]
					_ring(c, mn * view_scale, mn * view_scale * K, Color(1, 0.4, 0.3, 0.3), 2.0)
				if face_now == "guide":   # light up the tiles it would boost
					for j in tiles.size():
						if j != i and j / 3 == i / 3:
							var cj := proj(tiles[j])
							_ring(cj, rx * 1.3, rx * K * 1.3, Color(1, 0.92, 0.6, 0.45), 2.5 * view_scale)
	_draw_forks(pulse)
	# Fire target ring for the Kindle (★) die.
	if glow_face == "kindle":
		var gc := Color("#fff0b0")
		gc.a = 0.35 + 0.4 * pulse + (0.25 if hover_tile == -2 else 0.0)
		_ring(Vector2.ZERO, 92.0 * view_scale, 92.0 * view_scale * K, gc, 4.0 * view_scale)


var gates_left := 0          ## set by the battle: junctions glow while gates remain


## Junction markers, and Char's gates with their cooldown flame.
func _draw_forks(pulse: float) -> void:
	for L in links:
		var pts: PackedVector2Array = L["pts"]
		var w := pts[0]
		var c := proj(w)
		var lit := maxf(light_at(w), 0.45)
		var s := view_scale
		# Little arrows down the fork show which way it runs.
		var mid: Vector2 = pts[pts.size() / 2]
		var dir: Vector2 = (proj(pts[pts.size() / 2 + 1]) - proj(mid)).normalized()
		var tip := proj(mid)
		var arrow := Color(1, 0.85, 0.6, 0.35 * lit)
		draw_line(tip, tip - dir.rotated(0.6) * 12 * s, arrow, 3 * s, true)
		draw_line(tip, tip - dir.rotated(-0.6) * 12 * s, arrow, 3 * s, true)
		if not L["gate"]:
			var gc := Color("#ffb238")
			gc.a = (0.3 + 0.4 * pulse) if gates_left > 0 else 0.25
			_ring(c, 30 * s, 30 * s * K, gc, 3 * s)
			continue
		# The gate: two posts and a plank barring the way not taken.
		var lane_dir: Vector2 = (proj(path_point(L["from"], L["at"] + 30.0)) - c).normalized()
		var fork_dir: Vector2 = (proj(pts[2]) - c).normalized()
		var barred: Vector2 = lane_dir if L["cross"] else fork_dir
		var open: Vector2 = fork_dir if L["cross"] else lane_dir
		var wood := Color("#8a5a32").lerp(Color("#c88a50"), lit)
		var across := barred.orthogonal()
		var bc := c + barred * 26 * s
		for side in [-1.0, 1.0]:
			var post: Vector2 = bc + across * 20 * s * side
			draw_line(post, post - Vector2(0, 22 * s), wood.darkened(0.3), 5 * s, true)
		draw_line(bc - across * 22 * s - Vector2(0, 8 * s), bc + across * 22 * s - Vector2(0, 8 * s), wood, 6 * s, true)
		draw_line(bc - across * 22 * s - Vector2(0, 17 * s), bc + across * 22 * s - Vector2(0, 17 * s), wood, 5 * s, true)
		var go := c + open * 30 * s
		var ac := Color("#ffd27a", 0.8)
		draw_line(go, go - open.rotated(0.6) * 14 * s, ac, 4 * s, true)
		draw_line(go, go - open.rotated(-0.6) * 14 * s, ac, 4 * s, true)
		# Cooldown: a small flame above the gate fills up, then glows when ready.
		var ready := 1.0 - clampf(L["cool"] / Defs.GATE_COOLDOWN, 0.0, 1.0)
		var fc := c - Vector2(0, 52 * s)
		_flame(fc, 13 * s, Color(0.2, 0.15, 0.12, 0.8))
		if ready >= 1.0:
			_ellipse_xy(fc, 22 * s, 22 * s, Color(1, 0.7, 0.3, 0.12 + 0.12 * pulse))
		_flame(fc + Vector2(0, 13 * s * (1.0 - ready) * 0.5), 13 * s * maxf(ready, 0.05),
			Color("#ff9a3c") if ready >= 1.0 else Color("#b8642a"))


func _flame(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var y := sin(a)
		var x := cos(a) * (1.0 - 0.35 * maxf(-y, 0.0))
		pts.append(c + Vector2(x * r * 0.75, y * r * 0.8 - (r * 0.9 * maxf(-y, 0.0) ** 3)))
	draw_colored_polygon(pts, col)


func _preview_range(face: String, i: int) -> float:
	if not Defs.DEFENSES.has(face):
		return 0.0
	var lvl := 0
	if lift_tile >= 0:
		lvl = tile_defense[lift_tile].level - 1   # moving keeps its level
	elif tile_defense[i] != null:
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
