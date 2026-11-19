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
## World half-extents the battle camera fits on screen. The hill pulls back a
## little so its downhill shortcuts (which start further out) stay in view.
const VIEW_FIT := Vector2(420.0, 330.0)
const VIEW_FIT_HILL := Vector2(500.0, 390.0)
const SHAPES := ["straight", "wavy", "curved"]

var view_scale := 0.85
var stop := "road"                    ## map stop id; set by the battle
var layout_seed := 0                  ## set by the battle (Run.layout_seed) before _ready
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
		print("  map: %d lanes %s, %d forks %s" % [lane_count, shapes, links.size(), links.map(func(L): return snappedf(maxf(absf(L["pts"][0].x) / VIEW_FIT_HILL.x, absf(L["pts"][0].y) / VIEW_FIT_HILL.y), 0.01))])
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
	for attempt in 30:   # a hill reshapes its spiral until a shortcut fits
		for a in [paths, path_lengths, tiles, tile_defense, links, shapes]:
			a.clear()
		if not _build_once(r):
			continue
		if not links.is_empty() or not Defs.has_forks(stop):
			return


func _build_once(r: RandomNumberGenerator) -> bool:
	if stop == "cliff":
		return _build_cliff(r)
	var hill := stop == "hill"
	var n := 4 if r.randf() < FOUR_LANE_CHANCE else 3
	if hill:   # Hillside Clearing: 3 trails spiral round the camp, all the same way
		n = 3
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
		var inner := _gap_mid(i, Defs.INNER_TILE_R)
		tiles.append(Vector2(cos(inner[0]), sin(inner[0])) * Defs.INNER_TILE_R)
		var outer := _gap_mid(i, Defs.OUTER_TILE_R)
		var spread := minf(deg_to_rad(23.0), outer[1] / 2.0 - deg_to_rad(14.0))
		for s in [-1.0, 1.0]:
			var a: float = outer[0] + s * spread
			tiles.append(Vector2(cos(a), sin(a)) * Defs.OUTER_TILE_R)
	for t in tiles:
		tile_defense.append(null)
	lane_count = n
	group_count = n
	if Defs.has_forks(stop):
		_build_forks(r)
	return true


## Cliff Edge: 2-3 trails fan in from the front and sides, none from behind
## (the drop). Lanes run right to left so each gap sits between i and i+1.
## Tile groups: one in each gap, plus one on the outer flank of each side trail.
func _build_cliff(r: RandomNumberGenerator) -> bool:
	var n := 3 if r.randf() < Defs.CLIFF_THREE_LANE_CHANCE else 2
	var lanes := []
	var ok := false
	for attempt in 40:
		lanes.clear()
		var lo := deg_to_rad(r.randf_range(2.0, 30.0))
		var hi := deg_to_rad(r.randf_range(150.0, 178.0))
		if n == 2 and r.randf() < 0.5:   # two trails: sometimes front + one side
			if r.randf() < 0.5:
				lo = deg_to_rad(r.randf_range(65.0, 100.0))
			else:
				hi = deg_to_rad(r.randf_range(80.0, 115.0))
		for i in n:
			var base := lerpf(lo, hi, float(i) / (n - 1))
			if n == 3 and i == 1:
				base += deg_to_rad(r.randf_range(-15.0, 15.0))
			var shape: String = SHAPES[r.randi() % SHAPES.size()] if attempt < 30 else "straight"
			lanes.append([base, shape, r.randf() * TAU, -1.0 if r.randf() < 0.5 else 1.0])
		ok = true
		for k in 21:
			var f := k / 20.0
			var rad := lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f)
			for i in n:
				var L: Array = lanes[i]
				var a: float = L[0] + _offset(L[1], f, L[2], L[3])
				var p := Vector2(cos(a), sin(a)) * rad
				if rad > 120.0 and p.y < Defs.cliff_edge_y(p.x) + 70.0:
					ok = false
				if i + 1 < n:
					var M: Array = lanes[i + 1]
					var gap := wrapf(M[0] + _offset(M[1], f, M[2], M[3]) - a, -PI, PI)
					if gap < deg_to_rad(48.0):
						ok = false
		if ok:
			break
	if not ok:
		return false
	_lanes = lanes
	_steps = 36
	for L in lanes:
		shapes.append(L[1])
		var pts := PackedVector2Array()
		for k in _steps + 1:
			var f := float(k) / _steps
			var a: float = L[0] + _offset(L[1], f, L[2], L[3])
			pts.append(Vector2(cos(a), sin(a)) * lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f))
		paths.append(pts)
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k].distance_to(pts[k - 1])
		path_lengths.append(length)
	lane_count = n
	for i in n - 1:
		var inner := _gap_mid(i, Defs.INNER_TILE_R)
		tiles.append(Vector2(cos(inner[0]), sin(inner[0])) * Defs.INNER_TILE_R)
		var outer := _gap_mid(i, Defs.OUTER_TILE_R)
		var spread := minf(deg_to_rad(23.0), outer[1] / 2.0 - deg_to_rad(14.0))
		for s in [-1.0, 1.0]:
			var a: float = outer[0] + s * spread
			tiles.append(Vector2(cos(a), sin(a)) * Defs.OUTER_TILE_R)
	for side in [[0, -1.0], [n - 1, 1.0]]:
		if not _flank_group(side[0], side[1]):
			return false
	group_count = tiles.size() / 3
	for t in tiles:
		tile_defense.append(null)
	if Defs.has_forks(stop):
		_build_forks(r)
	return true


## Three tiles on the open side of an outer cliff trail (toward the drop),
## inner one first. False if they can't fit.
func _flank_group(lane: int, side: float) -> bool:
	for want in [[150.0, 210.0], [300.0, 380.0], [300.0, 380.0]]:
		var placed := false
		for rad in range(int(want[0]), int(want[1]) + 1, 15):
			var base := _lane_angle(lane, _f_at(rad))
			for step in range(8, 120, 4):
				var a := base + side * deg_to_rad(step)
				var p := Vector2(cos(a), sin(a)) * rad
				if _tile_spot_ok(p):
					tiles.append(p)
					placed = true
					break
			if placed:
				break
		if not placed:
			return false
	return true


func _tile_spot_ok(p: Vector2) -> bool:
	if Defs.COACH_ZONE.grow(10.0).has_point(p) or p.y < Defs.cliff_edge_y(p.x) + TILE_RADIUS + 25.0:
		return false
	if absf(p.x) > VIEW_FIT.x - 10.0:
		return false
	for t in tiles:
		if p.distance_to(t) < TILE_RADIUS * 2.3:
			return false
	for i in lane_count:
		for q in paths[i]:
			if p.distance_to(q) < TILE_RADIUS + 34.0:
				return false
	return true


var _lanes := []
var _steps := 36
var lane_count := 0          ## real trails; paths past this index are fork routes
var group_count := 0         ## tile groups of 3 (inner tile first)
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


## How many forks a stop's map gets with this seed (for the loadout screen).
static func fork_count(stop_id: String, seed_: int) -> int:
	var b = load("res://scripts/game/board.gd").new()
	b.stop = stop_id
	b.layout_seed = seed_
	b._build_layout()
	var n: int = b.links.size()
	b.free()
	return n


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


## 1-3 one-way forks. Each cuts across the gap between two neighbouring
## trails (or spiral arms), through the clear ring between the tile rows.
func _build_forks(r: RandomNumberGenerator) -> void:
	var n := lane_count
	var want := r.randi_range(Defs.FORKS_MIN, Defs.FORKS_MAX)
	var order := range(n - 1 if stop == "cliff" else n)   # no gap across the drop
	for i in range(order.size() - 1, 0, -1):   # shuffle which gaps / arms get forks
		var j := r.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for g in order:
		if links.size() >= want:
			break
		if stop == "hill":
			var rung := _hill_rung(g, r)
			if not rung.is_empty():
				_add_fork(rung)
			continue
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
		# Sweep through gap g itself (lane g to lane g+1 runs the positive way).
		var delta := wrapf(b2 - a1, 0.0, TAU) if a == g else -wrapf(a1 - b2, 0.0, TAU)
		var pts := PackedVector2Array()
		for k in 13:
			var t := k / 12.0
			var ang := a1 + delta * t
			pts.append(Vector2(cos(ang), sin(ang)) * lerpf(Defs.FORK_RADIUS, Defs.MERGE_RADIUS, t))
		var fk := [a, b, f1, f2, pts]   # from, to, f_from, f_to, connector
		if not _clear_of_tiles(fk[4]):
			continue
		_add_fork(fk)


## Hill fork: a straight shortcut down the slope, from arm i inward to the
## next arm, so it reads clearly against the curving spirals. Of those that
## clear the tiles, the one whose junction sits most in view wins.
func _hill_rung(i: int, r: RandomNumberGenerator) -> Array:
	var best := []
	var best_len := INF
	var off := r.randf()
	for k in 40:
		var f1 := lerpf(0.0, 0.7, (k + off) / 40.0)
		var p1 := _lane_pos(i, f1)
		var ang := p1.angle()
		var r1 := p1.length()
		var prev := {}
		var rad := r1 - 20.0
		while rad > FIRE_RADIUS + 60.0:
			var fb := _f_at(rad)
			var hit := -1
			for b in lane_count:
				if b == i:
					continue
				var diff := wrapf(_lane_angle(b, fb) - ang, -PI, PI)
				if prev.has(b) and signf(diff) != signf(prev[b]) and absf(diff) < 0.5:
					hit = b
				prev[b] = diff
			if hit >= 0:
				# Prefer the junction most in view (the screen is wider than tall).
				var seg_len := maxf(absf(p1.x) / VIEW_FIT_HILL.x, absf(p1.y) / VIEW_FIT_HILL.y)
				if seg_len < best_len and seg_len < 0.97:
					var pts := PackedVector2Array()
					for j in 9:
						pts.append(Vector2(cos(ang), sin(ang)) * lerpf(r1, rad, j / 8.0))
					if _clear_of_tiles(pts):
						best = [i, hit, f1, fb, pts]
						best_len = seg_len
				break
			rad -= 3.0
	return best


func _clear_of_tiles(pts: PackedVector2Array) -> bool:
	for p in pts:
		if Defs.COACH_ZONE.has_point(p):   # never hidden behind the stagecoach
			return false
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


# ------------------------------------------------------------ cliff art
var _rim: PackedVector2Array = []   ## jagged cliff edge, world points
var _rocks: Array = []              ## [world pos, size, shape seed]
var _ridge: PackedVector2Array = []
var _pines: Array = []              ## [world x, height]


func _build_cliff_art() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed + 77
	_rim.clear()
	var x := -1500.0
	while x <= 1500.0:
		var jag := r.randf_range(-9.0, 9.0) + sin(x * 0.013) * 10.0
		_rim.append(Vector2(x, Defs.cliff_edge_y(x) + jag))
		x += 22.0
	_rocks.clear()
	x = -900.0
	while x <= 900.0:
		var y := Defs.cliff_edge_y(x) + r.randf_range(4.0, 26.0)
		_rocks.append([Vector2(x, y), r.randf_range(12.0, 30.0), r.randi()])
		if r.randf() < 0.4:   # a smaller stone tucked beside it
			_rocks.append([Vector2(x + r.randf_range(14.0, 30.0), y + r.randf_range(8.0, 22.0)), r.randf_range(6.0, 12.0), r.randi()])
		x += r.randf_range(38.0, 80.0)
	_ridge.clear()
	_pines.clear()
	x = -900.0
	while x <= 900.0:
		var y := minf(-395.0 + sin(x * 0.006 + 1.3) * 22.0 + sin(x * 0.019) * 18.0, Defs.cliff_edge_y(x) - 110.0)
		_ridge.append(Vector2(x, y))
		if r.randf() < 0.5:
			_pines.append([x + r.randf_range(-10.0, 10.0), r.randf_range(26.0, 52.0)])
		x += 30.0


## Behind the stagecoach the ground ends at a rocky lip. Past it: a misty
## chasm and, far across, a dark ridge of pines.
func _draw_cliff() -> void:
	if _rim.is_empty():
		_build_cliff_art()
	var s := view_scale
	var far := -3000.0
	# The chasm.
	var void_pts := PackedVector2Array()
	for p in _rim:
		void_pts.append(proj(p))
	void_pts.append(proj(Vector2(_rim[_rim.size() - 1].x, far)))
	void_pts.append(proj(Vector2(_rim[0].x, far)))
	draw_colored_polygon(void_pts, Color("#070a12"))
	# Far ridge and pines, faintly moonlit.
	var ridge_col := Color("#1a2335")
	var rp := PackedVector2Array()
	for p in _ridge:
		rp.append(proj(p))
	rp.append(proj(Vector2(_ridge[_ridge.size() - 1].x, far)))
	rp.append(proj(Vector2(_ridge[0].x, far)))
	draw_colored_polygon(rp, ridge_col)
	for pn in _pines:
		var bx: float = pn[0]
		var by := proj(Vector2(bx, minf(-395.0 + sin(bx * 0.006 + 1.3) * 22.0 + sin(bx * 0.019) * 18.0, Defs.cliff_edge_y(bx) - 110.0)))
		var h: float = pn[1] * s * K
		var wdt := h * 0.42
		draw_colored_polygon(PackedVector2Array([by + Vector2(-wdt, 2), by + Vector2(0, -h), by + Vector2(wdt, 2)]), ridge_col)
	# Mist drifting in the chasm.
	for k in 9:
		var mx := -700.0 + k * 170.0 + sin(_t * 0.15 + k * 1.7) * 60.0
		var my := Defs.cliff_edge_y(mx) - 80.0 - (k % 3) * 30.0
		var a := 0.08 + 0.04 * sin(_t * 0.4 + k)
		_ellipse_xy(proj(Vector2(mx, my)), 150.0 * s, 26.0 * s, Color(0.55, 0.65, 0.85, a))
	# The rock face dropping away below the lip, fading into the dark.
	for k in 5:
		var band := PackedVector2Array()
		var depth := 70.0 - k * 13.0
		for p in _rim:
			band.append(proj(p))
		for j in range(_rim.size() - 1, -1, -1):
			band.append(proj(_rim[j] + Vector2(0, -depth)))
		var fc := Color("#3a2e28").lerp(Color("#070a12"), 1.0 - k / 4.0)
		draw_colored_polygon(band, fc)
	for j in range(0, _rim.size(), 2):   # cracks down the face
		var p: Vector2 = _rim[j]
		var lit := light_at(p) * fire_glow
		var drop := 30.0 + float((j * 37) % 30)
		draw_line(proj(p + Vector2(0, -4)), proj(p + Vector2(((j * 13) % 9) - 4.0, -drop)),
			Color(0, 0, 0, 0.35 + 0.2 * lit), 2.0 * s, true)
	# The lip itself: a lit rim of rock.
	var lip := PackedVector2Array()
	for p in _rim:
		lip.append(proj(p))
	for j in range(_rim.size() - 1, -1, -1):
		lip.append(proj(_rim[j] + Vector2(0, 14.0)))
	draw_colored_polygon(lip, Color("#2a2523").lerp(Color("#6a5a4c"), light_at(Vector2(0, Defs.CLIFF_EDGE_Y)) * fire_glow))
	for k in range(1, _rim.size()):
		var lit := light_at(_rim[k]) * fire_glow
		draw_line(proj(_rim[k - 1]), proj(_rim[k]), Color("#3a3230").lerp(Color("#b08a66"), lit), 3.0 * s, true)
	# Boulders along the edge.
	for rk in _rocks:
		var w: Vector2 = rk[0]
		var sz: float = rk[1]
		var rr := RandomNumberGenerator.new()
		rr.seed = rk[2]
		var lit := maxf(light_at(w) * fire_glow, 0.12)
		var c := proj(w)
		var poly := PackedVector2Array()
		var top := PackedVector2Array()
		for i in 7:
			var a := PI + PI * i / 6.0
			var rad := sz * rr.randf_range(0.75, 1.1) * s
			poly.append(c + Vector2(cos(a) * rad, sin(a) * rad * 0.9))
		poly.append(c + Vector2(sz * 0.9 * s, sz * 0.18 * s))
		poly.append(c + Vector2(-sz * 0.9 * s, sz * 0.18 * s))
		_ellipse_xy(c + Vector2(0, sz * 0.2 * s), sz * 1.05 * s, sz * 0.35 * s, Color(0, 0, 0, 0.35))
		draw_colored_polygon(poly, Color("#2b2626").lerp(Color("#7c6c60"), lit))
		for i in 4:
			var a := PI * 1.2 + PI * 0.6 * i / 3.0
			top.append(c + Vector2(cos(a) * sz * 0.6 * s, sin(a) * sz * 0.75 * s))
		draw_polyline(top, Color("#3c3634").lerp(Color("#b59d86"), lit), 2.0 * s, true)


# ------------------------------------------------------------ hill art
const HILL_CREST := 470.0   ## world radius where the hilltop rolls out of sight behind camp
var _hill_rocks: Array = []


## Hillside trails fade as they come up over the crest behind camp.
func _hill_trail_fade(w: Vector2) -> float:
	if stop != "hill" or w.y >= 0.0:
		return 1.0
	var back := -w.y / maxf(w.length(), 1.0)   # 1 straight behind camp
	return clampf((HILL_CREST + 40.0 - w.length()) / 90.0, 0.0, 1.0) * back + (1.0 - back)


## Hilltop at night: the ground rolls away out of sight behind camp, with
## misty lowlands and far hills beyond; faint contour lines ring the slope.
func _draw_hill() -> void:
	var s := view_scale
	if _hill_rocks.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = layout_seed + 31
		for i in 22:
			var a := r.randf() * TAU
			_hill_rocks.append([Vector2(cos(a), sin(a)) * r.randf_range(230.0, 600.0), r.randf_range(6.0, 13.0)])
	# Faint contour lines, wandering a little like real ground.
	var ci := 0
	for rad in [215.0, 290.0, 365.0, 440.0, 515.0, 590.0]:
		ci += 1
		var line := PackedVector2Array()
		for j in 97:
			var a := TAU * j / 96.0
			var rr: float = rad * (1.0 + 0.04 * sin(3.0 * a + ci * 1.9 + layout_seed % 7) + 0.025 * sin(5.0 * a + ci * 0.7))
			line.append(proj(Vector2(cos(a), sin(a)) * rr))
		var lit := clampf(1.0 - (rad - 140.0) / (LIGHT_RADIUS * 1.4), 0.0, 1.0) * fire_glow
		draw_polyline(line, Color(0.0, 0.0, 0.0, 0.10), 3.0 * s, true)
		draw_polyline(line, Color(0.85, 0.62, 0.42, 0.03 + 0.07 * lit), 1.5 * s, true)
	# Beyond the crest: the night sky over far hills and lowland mist.
	var crest := PackedVector2Array()
	for k in 61:
		var a := PI + PI * k / 60.0
		var rr := HILL_CREST * (1.0 + 0.03 * sin(a * 4.0 + 1.0))
		crest.append(proj(Vector2(cos(a), sin(a) * 1.0) * rr))
	var l := crest[0]
	var rgt := crest[crest.size() - 1]
	var sky := crest.duplicate()
	sky.append(rgt + Vector2(2000, 0))
	sky.append(rgt + Vector2(2000, -3000))
	sky.append(l + Vector2(-2000, -3000))
	sky.append(l + Vector2(-2000, 0))
	sky.reverse()
	draw_colored_polygon(sky, Color("#0b0f1c"))
	var top := crest[30].y
	for layer in 3:
		var base := top - (34.0 - layer * 13.0) * s
		var hp := PackedVector2Array()
		for k in 33:
			var x := (-1100.0 + k * 2200.0 / 32.0) * s
			var y := base - (12.0 + sin(k * 0.9 + layer * 2.1) * 8.0 + sin(k * 0.37 + layer) * 10.0) * s
			# Far hills sit behind the crest, never over the hilltop.
			var cy := _crest_y_at(crest, x)
			hp.append(Vector2(x, minf(y, cy)))
		for k in range(32, -1, -1):
			var x := (-1100.0 + k * 2200.0 / 32.0) * s
			hp.append(Vector2(x, _crest_y_at(crest, x)))
		draw_colored_polygon(hp, Color("#111829").lerp(Color("#0d1222"), layer / 2.0))
	for k in 7:
		var mx := (-600.0 + k * 200.0 + sin(_t * 0.12 + k) * 40.0) * s
		var my := _crest_y_at(crest, mx) - 10.0 * s
		_ellipse_xy(Vector2(mx, my), 170 * s, 14 * s, Color(0.55, 0.65, 0.85, 0.05 + 0.025 * sin(_t * 0.35 + k)))
	# Soften the crest: the ground darkens and rounds off as it rolls away.
	for k in 6:
		var band := PackedVector2Array()
		for p in crest:
			band.append(p + Vector2(0, (4.0 + k * 7.0) * s))
		draw_polyline(band, Color(0.04, 0.05, 0.09, 0.22 - k * 0.03), 9.0 * s, true)
	draw_polyline(crest, Color(0.6, 0.7, 0.95, 0.10), 2.0 * s, true)   # moonlit rim
	# Small rocks on the slope.
	for rk in _hill_rocks:
		var w: Vector2 = rk[0]
		if w.y < 0.0 and w.length() > HILL_CREST - 30.0:
			continue
		var sz: float = rk[1] * s
		var c := proj(w)
		var lit := maxf(light_at(w) * fire_glow, 0.1)
		_ellipse_xy(c + Vector2(0, sz * 0.25), sz * 1.1, sz * 0.4, Color(0, 0, 0, 0.3))
		_ellipse_xy(c, sz, sz * 0.6, Color("#221e20").lerp(Color("#7a6a5e"), lit))
		_ellipse_xy(c - Vector2(sz * 0.2, sz * 0.18), sz * 0.5, sz * 0.25, Color("#2e2a2a").lerp(Color("#a8927e"), lit))


## Screen y of the crest line at screen x (it is drawn left to right).
func _crest_y_at(crest: PackedVector2Array, x: float) -> float:
	if x <= crest[0].x:
		return crest[0].y
	for k in range(1, crest.size()):
		if x <= crest[k].x:
			var t := (x - crest[k - 1].x) / maxf(crest[k].x - crest[k - 1].x, 0.001)
			return lerpf(crest[k - 1].y, crest[k].y, t)
	return crest[crest.size() - 1].y


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
	if stop == "cliff":
		_draw_cliff()
	elif stop == "hill":
		_draw_hill()
	# Trails, lighter packed dirt, fading into the dark.
	var trails: Array = paths.slice(0, lane_count)
	for L in links:
		trails.append(L["pts"])
	for p: PackedVector2Array in trails:
		for k in range(1, p.size()):
			var mid := (p[k] + p[k - 1]) / 2.0
			var lit := light_at(mid) * fire_glow
			var col := Color("#17110f").lerp(Color("#7a5236"), clampf(lit, 0.0, 1.0))
			col.a = (0.55 + 0.45 * lit) * _hill_trail_fade(mid)
			if col.a < 0.02:
				continue
			draw_line(proj(p[k - 1]), proj(p[k]), col, 46.0 * view_scale, true)
			draw_circle(proj(p[k]), 23.0 * view_scale * Vector2(1, K).length() * 0.72, col)
	# Grass tufts and pebbles, only seen where the light reaches.
	for tf in _tufts:
		var w: Vector2 = tf[0]
		var lit := light_at(w) * fire_glow
		if lit < 0.05 or (stop == "cliff" and w.y < Defs.cliff_edge_y(w.x) + 20.0) or _hill_trail_fade(w) < 0.5:
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
		# Cooldown: the ring round the fork burns fire-bright when the gate is
		# ready, snuffs out when it's switched, then warms back up.
		var ready := 1.0 - clampf(L["cool"] / Defs.GATE_COOLDOWN, 0.0, 1.0)
		var hot := Color("#ff9a3c")
		var rc := Color("#3b3532").lerp(Color("#a8582a"), ready * 0.85)
		if ready >= 1.0:
			rc = hot
			_ellipse_xy(c, 44 * s, 44 * s * K, Color(1, 0.6, 0.25, 0.10 + 0.10 * pulse))
			_ring(c, 38 * s, 38 * s * K, Color(1, 0.7, 0.3, 0.25 + 0.2 * pulse), 9 * s)
		_ring(c, 36 * s, 36 * s * K, rc, 4.5 * s)


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
