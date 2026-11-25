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
var walls: Array = []                ## EmberWall nodes on the trails (set by the battle)
var mires: Array = []                ## Mire patches on the trails: {world, level} (set by the battle)
var tile_defense: Array = []          ## Defense node or null, per tile
var glow_face := ""                   ## face being placed: valid tiles glow
var hover_tile := -1
var lift_tile := -1                 ## defense being moved (Oath of Shifting Embers)
var shift_glow := false             ## a move is available: defenses / empty tiles glow
var shield := 0.0      ## set by the battle: a Reliquary's soak left this wave (gold ring)
var fire_glow := 1.0                  ## set by the battle (flicker, swells)

var _t := 0.0
var _tufts: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	_build_layout()
	if Run.autoplay and stop == "lake":
		print("  lake: side %d, %d tiles, dock %s" % [lake_side, tiles.size(), not dock.is_empty()])
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
	return Vector2(w.x, w.y * K + _drop(w.length())) * view_scale


func unproj(local: Vector2) -> Vector2:
	var w := Vector2(local.x, local.y / K) / view_scale
	if stop == "hill":   # undo the hill's slope (converges: the slope stays gentle)
		for i in 8:
			w.y = (local.y / view_scale - _drop(w.length())) / K
	return w


## Hillside Clearing: the camp sits on the summit and the ground falls away
## all round it. Lower ground shows lower on screen (camera tilt ~34 deg, so
## height reads at cos ~0.83), squeezing the far slope and stretching the near.
const HILL_DROP := 0.0003
const TILT_COS := 0.83

func _drop(rad: float) -> float:
	return HILL_DROP * rad * rad * TILT_COS if stop == "hill" else 0.0


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
		"water":   # dead straight across the lake
			return 0.0
		"shore":   # hugs the lakeshore (ph picks the precomputed table)
			var tb: PackedFloat32Array = _shore_tables[int(ph)]
			var kf := clampf(f, 0.0, 1.0) * 36.0
			var k := mini(int(kf), 35)
			return lerpf(tb[k], tb[k + 1], kf - k)
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
		for a in [paths, path_lengths, tiles, tile_defense, links, shapes, dock, tile_group, _patches, _slabs, pools]:
			a.clear()
		if not _build_once(r):
			continue
		if not links.is_empty() or not Defs.has_forks(stop):
			return
	# Every attempt failed (a lake that found no dock): keep the last layout
	# playable rather than leave its tiles without defense slots.
	if tile_defense.size() < tiles.size():
		while tile_defense.size() < tiles.size():
			tile_defense.append(null)
		group_count = (tiles.size() + 2) / 3


func _build_once(r: RandomNumberGenerator) -> bool:
	if stop == "cliff":
		return _build_cliff(r)
	if stop == "lake":
		return _build_lake(r)
	var hill := stop == "hill"
	var n := 4 if r.randf() < FOUR_LANE_CHANCE else 3
	if hill:   # Hillside Clearing: 3 trails spiral round the camp, all the same way
		n = 3
	if stop == "chapel":   # Sunken Chapel: 3-5 aisles
		n = r.randi_range(3, 5)
	var wrap := deg_to_rad(r.randf_range(Defs.HILL_WRAP_MIN, Defs.HILL_WRAP_MAX))
	var spin := -1.0 if r.randf() < 0.5 else 1.0
	var min_gap := deg_to_rad(44.0 if n == 5 else 52.0 if n == 4 else 72.0)
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
	lane_count = n
	if stop == "swamp":
		_build_pools(r)
	return _finish(r, mini(3 * n, 13))


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
	return _finish(r, 3 * (n + 1))


func _tile_spot_ok(p: Vector2) -> bool:
	if Defs.COACH_ZONE.grow(10.0).has_point(p):
		return false
	if stop == "cliff" and p.y < Defs.cliff_edge_y(p.x) + TILE_RADIUS + 25.0:
		return false
	if stop == "lake" and _near_lake(p, TILE_RADIUS + 12.0):
		return false
	if stop == "swamp" and _near_pool(p, TILE_RADIUS + 12.0):
		return false
	if absf(p.x) > VIEW_FIT.x - 10.0:
		return false
	for t in tiles:
		if p.distance_to(t) < TILE_RADIUS * 2.3:
			return false
	if absf(p.y) > VIEW_FIT.y - 10.0 or p.length() < 115.0:
		return false
	for pts in paths:   # trails and fork routes
		for q in pts:
			if p.distance_to(q) < TILE_RADIUS + 34.0:
				return false
	for L in links:
		for q in L["pts"]:
			if p.distance_to(q) < TILE_RADIUS + 34.0:
				return false
	if not dock.is_empty() and Geometry2D.get_closest_point_to_segment(p, dock[0], dock[1]).distance_to(p) < TILE_RADIUS + 20.0:
		return false
	return true


# ------------------------------------------------------------ tiles
const TILE_REACH := 180.0        ## just under the shortest defense range (Frost)
const TILE_MIN_COVER := 6        ## trail samples (15 units each) a tile must reach
const TILE_SPACING := TILE_RADIUS * 2.3

## Forks first, then tiles scattered round them. False if too few fit.
func _finish(r: RandomNumberGenerator, want: int) -> bool:
	if Defs.has_forks(stop):
		_build_forks(r)
	_scatter_tiles(r, want)
	if tiles.size() < want - 1:
		return false
	_group_tiles()
	for t in tiles:
		tile_defense.append(null)
	return true


## Candidate spots on a jittered grid, each scored by how much trail lies
## within reach (bonus for reaching two trails). Picks are weighted-random,
## favouring trails and rings (near / far) that are still short of tiles.
func _scatter_tiles(r: RandomNumberGenerator, want: int) -> void:
	var samples := []   # [pos, trail id]
	for i in lane_count:
		var d := 0.0
		while d < path_lengths[i]:
			samples.append([path_point(i, d), i])
			d += 15.0
	for k in links.size():
		for q in links[k]["pts"]:
			samples.append([q, 100 + k])
	var cands := []   # [pos, cover, trail ids]
	var step := 26.0
	var x := -VIEW_FIT.x
	while x <= VIEW_FIT.x:
		var y := -VIEW_FIT.y
		while y <= VIEW_FIT.y:
			var p := Vector2(x, y) + Vector2(r.randf_range(-11.0, 11.0), r.randf_range(-11.0, 11.0))
			y += step
			if not _tile_spot_ok(p):
				continue
			var per := {}
			var cover := 0
			for sm in samples:
				if p.distance_to(sm[0]) < TILE_REACH:
					cover += 1
					per[sm[1]] = per.get(sm[1], 0) + 1
			if cover < TILE_MIN_COVER:
				continue
			var ids := []
			for id in per:
				if per[id] >= 3 and id < 100:
					ids.append(id)
			cands.append([p, cover, ids])
		x += step
	var lane_hits := {}
	var near := 0
	while tiles.size() < want:
		var weights := PackedFloat32Array()
		var total := 0.0
		var fair := float(tiles.size()) / maxf(1.0, lane_count)
		for c in cands:
			var p: Vector2 = c[0]
			var gap := INF
			var crowd := 0   # tiles already nearby: spread them over the clearing
			for t in tiles:
				var dt := p.distance_to(t)
				gap = minf(gap, dt)
				if dt < 240.0:
					crowd += 1
			var w := 0.0
			if gap >= TILE_SPACING:
				w = float(c[1]) / (1.0 + 1.3 * crowd) * (1.0 + 0.5 * maxf(0.0, c[2].size() - 1))
				for id in c[2]:
					if lane_hits.get(id, 0) < fair:
						w *= 1.7
						break
				var is_near := p.length() < 230.0
				if is_near != (near * 3 < tiles.size() + 1):
					w *= 0.6
			weights.append(w)
			total += w
		if total <= 0.0:
			return
		var roll := r.randf() * total
		var pick := 0
		for k in weights.size():
			roll -= weights[k]
			if roll <= 0.0 and weights[k] > 0.0:
				pick = k
				break
		var c: Array = cands[pick]
		tiles.append(c[0])
		for id in c[2]:
			lane_hits[id] = lane_hits.get(id, 0) + 1
		if c[0].length() < 230.0:
			near += 1


## Groups of 3 neighbouring tiles: the most outlying tile left takes its two
## nearest. A Guide Light or Bellows boosts every other defense in its group.
func _group_tiles() -> void:
	tile_group.clear()
	tile_group.resize(tiles.size())
	tile_group.fill(-1)
	group_count = 0
	var left := range(tiles.size())
	while not left.is_empty():
		var mid := Vector2.ZERO
		for i in left:
			mid += tiles[i]
		mid /= left.size()
		var seed_i: int = left[0]
		for i in left:
			if tiles[i].distance_to(mid) > tiles[seed_i].distance_to(mid):
				seed_i = i
		left.erase(seed_i)
		left.sort_custom(func(a, b): return tiles[a].distance_to(tiles[seed_i]) < tiles[b].distance_to(tiles[seed_i]))
		var members := [seed_i] + left.slice(0, 2)
		for i in members:
			tile_group[i] = group_count
			left.erase(i)
		group_count += 1


# ------------------------------------------------------------ lake
var lake_side := 1.0                 ## +1 lake on the right, -1 on the left
var lake_c := Vector2.ZERO           ## lake centre (world)
var _lake_ph := [0.0, 0.0]
var dock: Array = []                 ## [start, end] world points, or empty
var spirits_ref: Array = []          ## set by the battle, for reflections


func _lake_r(ang: float) -> float:
	return 1.0 + 0.06 * sin(3.0 * ang + _lake_ph[0]) + 0.04 * sin(5.0 * ang + _lake_ph[1])


func in_lake(w: Vector2) -> bool:
	if stop != "lake":
		return false
	var d := w - lake_c
	var q := Vector2(d.x / Defs.LAKE_RX, d.y / Defs.LAKE_RY)
	return q.length() < _lake_r(d.angle())


func _near_lake(w: Vector2, margin: float) -> bool:
	if in_lake(w):
		return true
	for k in 8:
		if in_lake(w + Vector2.from_angle(TAU * k / 8.0) * margin):
			return true
	return false


func lake_point(ang: float) -> Vector2:
	return lake_c + Vector2(cos(ang) * Defs.LAKE_RX, sin(ang) * Defs.LAKE_RY) * _lake_r(ang)


## Spirits drift slower over open water.
func speed_at(w: Vector2) -> float:
	return Defs.LAKE_WATER_SPEED if in_lake(w) else 1.0


## Quiet Lakeside: a lake fills one side. Lane 0 crosses the water dead
## straight; the trails either side of it run right along the shore, and with
## 4 lanes one more comes from the far side. Land gaps get tile groups (two in
## a wide gap); the shore gets just 1-2 tiles, grouped with the dock's one.
func _build_lake(r: RandomNumberGenerator) -> bool:
	lake_side = 1.0 if r.randf() < 0.5 else -1.0
	lake_c = Vector2(lake_side * (Defs.LAKE_SHORE + Defs.LAKE_RX), r.randf_range(-40.0, 60.0))
	_lake_ph = [r.randf() * TAU, r.randf() * TAU]
	var n := 4 if r.randf() < Defs.LAKE_FOUR_LANE_CHANCE else 3
	var water_a := (0.0 if lake_side > 0.0 else PI) + deg_to_rad(r.randf_range(-8.0, 8.0))
	_shore_tables = [_shore_table(water_a, 1.0), _shore_table(water_a, -1.0)]
	var lanes := []
	var ok := false
	for attempt in 40:
		lanes.clear()
		lanes.append([water_a, "water", 0.0, 1.0])
		lanes.append([water_a, "shore", 0.0, 1.0])
		if n == 4:
			var shape: String = SHAPES[r.randi() % SHAPES.size()] if attempt < 30 else "straight"
			lanes.append([water_a + PI + deg_to_rad(r.randf_range(-20.0, 20.0)), shape,
				r.randf() * TAU, -1.0 if r.randf() < 0.5 else 1.0])
		lanes.append([water_a, "shore", 1.0, 1.0])
		ok = true
		for k in 21:
			var f := k / 20.0
			var rad := lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f)
			for i in n:
				var L: Array = lanes[i]
				var a: float = L[0] + _offset(L[1], f, L[2], L[3])
				if L[1] != "water" and _near_lake(Vector2.from_angle(a) * rad, 55.0):
					ok = false
				var M: Array = lanes[(i + 1) % n]
				if wrapf(M[0] + _offset(M[1], f, M[2], M[3]) - a, 0.0, TAU) < deg_to_rad(38.0):
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
			pts.append(Vector2.from_angle(a) * lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, f))
		paths.append(pts)
		var length := 0.0
		for k in range(1, pts.size()):
			length += pts[k].distance_to(pts[k - 1])
		path_lengths.append(length)
	lane_count = n
	if not _build_dock(r):
		return false
	return _finish(r, 3 * (n - 1))


var _shore_tables := []   ## per shore trail: angle offset from the crossing, per step


## A trail hugging the shore: at each distance from the fire, the first angle
## (turning away from the crossing) that clears the water by a trail's width.
func _shore_table(water_a: float, sgn: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 37:
		var rad := lerpf(SPAWN_RADIUS, FIRE_RADIUS - 6.0, k / 36.0)
		var d := 42.0
		for step in range(0, 170, 1):
			var a := water_a + sgn * deg_to_rad(step)
			if not _near_lake(Vector2.from_angle(a) * rad, 58.0):
				d = maxf(42.0, step)
				break
		out.append(sgn * deg_to_rad(d))
	for pass_ in 3:   # smooth out the corners
		var sm := out.duplicate()
		for k in range(1, 36):
			sm[k] = (out[k - 1] + out[k] * 2.0 + out[k + 1]) / 4.0
		out = sm
	return out


## A short dock out into the lake beside the crossing, with one tile at its end.
func _build_dock(r: RandomNumberGenerator) -> bool:
	var u := Vector2.from_angle(_lanes[0][0])
	var sides := [1.0, -1.0] if r.randf() < 0.5 else [-1.0, 1.0]
	for sd in sides:
		for dist_off in [108.0, 130.0, 90.0]:
			var off: Vector2 = u.orthogonal() * sd * dist_off
			var t0 := -1.0
			for t in range(60, 500, 5):
				if in_lake(off + u * t):
					t0 = t
					break
			if t0 < 0.0:
				continue
			var a := off + u * (t0 + 62.0)
			if absf(a.x) > VIEW_FIT.x - 40.0 or absf(a.y) > VIEW_FIT.y - 40.0 or Defs.COACH_ZONE.grow(40.0).has_point(a):
				continue
			var clear := true
			for t in tiles:
				if a.distance_to(t) < TILE_RADIUS * 2.2:
					clear = false
			for i in lane_count:
				for q in paths[i]:
					if a.distance_to(q) < TILE_RADIUS + 30.0:
						clear = false
					for k in 5:   # the planks stay clear of the trails too
						if (off + u * (t0 - 10.0 + k * 25.0)).distance_to(q) < 52.0 + 26.0 and i > 0:
							clear = false
			if not clear:
				continue
			tiles.append(a)
			dock = [off + u * (t0 - 10.0), off + u * (t0 + 108.0)]
			return true
	return false


var _lanes := []
var _steps := 36
var lane_count := 0          ## real trails; paths past this index are fork routes
var group_count := 0         ## tile groups of 3 neighbours
var tile_group: Array[int] = []   ## group id per tile
## One-way forks. Each: from (lane), to (lane), at (dist on `from` where it forks),
## path (index of the route that takes the fork), pts (connector, for drawing),
## gate (Char has cobbled one here), cross (gate sends spirits down the fork),
## cool (seconds until the gate can be switched again).
var links: Array = []


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
	if stop == "lake":
		_build_lake_branches(r)
		return
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


## Lake forks: out on the water the crossing splits, and a branch curves off
## to one side and runs on to the fire by itself (drawn as a dashed wake that
## turns from water-blue to trail-brown as it comes ashore).
func _build_lake_branches(r: RandomNumberGenerator) -> void:
	var want := r.randi_range(1, 2)
	var u := Vector2.from_angle(_lanes[0][0])
	var sides := [1.0, -1.0] if r.randf() < 0.5 else [-1.0, 1.0]
	var used_at := []
	for sd in sides:
		if links.size() >= want:
			break
		for attempt in 12:
			var f1 := _f_at(r.randf_range(300.0, 430.0))
			var p0 := _lane_pos(0, f1)
			if not in_lake(p0) or absf(p0.x) > VIEW_FIT.x - 20.0:
				continue
			var too_close := false
			for d in used_at:
				if absf(d - p0.length()) < 70.0:
					too_close = true
			if too_close:
				continue
			var end := Vector2.from_angle(_lanes[0][0] + sd * 0.35) * (FIRE_RADIUS - 6.0)
			var ctrl: Vector2 = p0 * 0.55 + u.orthogonal() * sd * r.randf_range(70.0, 120.0)
			var pts := PackedVector2Array()
			for k in 31:
				var t := k / 30.0
				pts.append(p0.lerp(ctrl, t).lerp(ctrl.lerp(end, t), t))
			if not _clear_of_tiles(pts.slice(0, 27)) or not _clear_of_trails(pts):
				continue
			_add_lake_branch(f1, pts)
			used_at.append(p0.length())
			break


func _clear_of_trails(pts: PackedVector2Array) -> bool:
	for p in pts:
		if p.length() < 140.0:
			continue
		for i in range(1, lane_count):
			for q in paths[i]:
				if p.distance_to(q) < 62.0:
					return false
		if _lane_dist(0, p) < 34.0 and p.distance_to(pts[0]) > 130.0:
			return false
		if not dock.is_empty() and Geometry2D.get_closest_point_to_segment(p, dock[0], dock[1]).distance_to(p) < 70.0:
			return false
	return true


func _lane_dist(i: int, p: Vector2) -> float:
	var best := INF
	var pts := paths[i]
	for k in range(1, pts.size()):
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[k - 1], pts[k]).distance_to(p))
	return best


func _add_lake_branch(f1: float, pts: PackedVector2Array) -> void:
	var route := PackedVector2Array()
	var la := paths[0]
	for k in int(f1 * _steps) + 1:
		route.append(la[k])
	route.append_array(pts)
	paths.append(route)
	var length := 0.0
	for k in range(1, route.size()):
		length += route[k].distance_to(route[k - 1])
	path_lengths.append(length)
	links.append({"from": 0, "to": -1, "at": _dist_at(0, f1), "path": paths.size() - 1,
		"pts": pts, "gate": false, "cross": false, "cool": 0.0, "wake": true})


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
var _hill_rocks: Array = []


## Hilltop at night: faint contour lines ring the summit (bunched up on the
## far slope, spread out on the near one), with a few rocks on the slope.
func _draw_hill() -> void:
	var s := view_scale
	if _hill_rocks.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = layout_seed + 31
		for i in 22:
			var a := r.randf() * TAU
			_hill_rocks.append([Vector2(cos(a), sin(a)) * r.randf_range(230.0, 640.0), r.randf_range(6.0, 13.0)])
	var ci := 0
	for rad in [215.0, 290.0, 365.0, 440.0, 515.0, 590.0, 665.0, 740.0]:
		ci += 1
		var line := PackedVector2Array()
		for j in 97:
			var a := TAU * j / 96.0
			var rr: float = rad * (1.0 + 0.04 * sin(3.0 * a + ci * 1.9 + layout_seed % 7) + 0.025 * sin(5.0 * a + ci * 0.7))
			line.append(proj(Vector2(cos(a), sin(a)) * rr))
		var lit := clampf(1.0 - (rad - 140.0) / (LIGHT_RADIUS * 1.4), 0.0, 1.0) * fire_glow
		draw_polyline(line, Color(0.0, 0.0, 0.0, 0.10), 3.0 * s, true)
		draw_polyline(line, Color(0.85, 0.62, 0.42, 0.03 + 0.07 * lit), 1.5 * s, true)
	for rk in _hill_rocks:
		var w: Vector2 = rk[0]
		var sz: float = rk[1] * s
		var c := proj(w)
		var lit := maxf(light_at(w) * fire_glow, 0.1)
		_ellipse_xy(c + Vector2(0, sz * 0.25), sz * 1.1, sz * 0.4, Color(0, 0, 0, 0.3))
		_ellipse_xy(c, sz, sz * 0.6, Color("#221e20").lerp(Color("#7a6a5e"), lit))
		_ellipse_xy(c - Vector2(sz * 0.2, sz * 0.18), sz * 0.5, sz * 0.25, Color("#2e2a2a").lerp(Color("#a8927e"), lit))


# ------------------------------------------------------------ swamp
## Swamp Turnpike: 1-3 murky pools the trails may wade through (no tiles on
## them), 1-3 gnarled dead trees, a grey haze and a few faint drifting orbs.
var pools: Array = []        ## [centre (world), rx, ry, phase]
var _trees: Array = []       ## [world, height, lean, seed]
var _swamp_reeds: Array = [] ## [world, height]
var _orbs: Array = []        ## [phase x, phase y, speed, size]


func in_pool(w: Vector2) -> bool:
	for P in pools:
		var d: Vector2 = w - P[0]
		var q := Vector2(d.x / P[1], d.y / P[2])
		if q.length() < _pool_r(P, d.angle()):
			return true
	return false


func _pool_r(P: Array, ang: float) -> float:
	return 1.0 + 0.1 * sin(3.0 * ang + P[3]) + 0.06 * sin(5.0 * ang + P[3] * 1.7)


func _near_pool(w: Vector2, margin: float) -> bool:
	if in_pool(w):
		return true
	for k in 8:
		if in_pool(w + Vector2.from_angle(TAU * k / 8.0) * margin):
			return true
	return false


func pool_point(P: Array, ang: float) -> Vector2:
	return P[0] + Vector2(cos(ang) * P[1], sin(ang) * P[2]) * _pool_r(P, ang)


## The first pool sits across a trail; the rest anywhere clear of the camp.
func _build_pools(r: RandomNumberGenerator) -> void:
	var want := r.randi_range(Defs.SWAMP_POOLS_MIN, Defs.SWAMP_POOLS_MAX)
	for attempt in 60:
		if pools.size() >= want:
			break
		var c: Vector2
		if pools.is_empty():
			var pts: PackedVector2Array = paths[r.randi() % paths.size()]
			c = pts[int(pts.size() * r.randf_range(0.5, 0.68))]
		else:
			c = Vector2(r.randf_range(-VIEW_FIT.x, VIEW_FIT.x) * 0.85, r.randf_range(-VIEW_FIT.y, VIEW_FIT.y) * 0.8)
		var rx := r.randf_range(55.0, 95.0)
		var ry := rx * r.randf_range(0.6, 0.85)
		if c.length() < 210.0 or Defs.COACH_ZONE.grow(rx + 20.0).has_point(c):
			continue
		var ok := true
		for P in pools:
			if c.distance_to(P[0]) < rx + P[1] + 50.0:
				ok = false
		if ok:
			pools.append([c, rx, ry, r.randf() * TAU])


func _build_swamp_art() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed + 71
	var want := r.randi_range(1, 3)
	for attempt in 200:
		if _trees.size() >= want:
			break
		var w := Vector2(r.randf_range(-VIEW_FIT.x - 30.0, VIEW_FIT.x + 30.0), r.randf_range(-VIEW_FIT.y + 150.0, VIEW_FIT.y - 20.0))
		if w.length() < 190.0 or Defs.COACH_ZONE.grow(60.0).has_point(w) or _near_pool(w, 30.0):
			continue
		var h := r.randf_range(110.0, 160.0)
		var top := w - Vector2(0, h * 1.2 / K)   # the crown, in ground terms
		var ok := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, w, top).length() > 230.0
		for t in tiles:
			if Geometry2D.get_closest_point_to_segment(t, w, top).distance_to(t) < TILE_RADIUS + 50.0:
				ok = false
		for p in paths:
			for q in p:
				if q.distance_to(w) < 55.0:
					ok = false
		for T in _trees:
			if T[0].distance_to(w) < 200.0:
				ok = false
		if ok:
			_trees.append([w, h, r.randf_range(-0.25, 0.25), r.randi()])
	for P in pools:
		for k in 18:
			if r.randf() < 0.4:
				var e := pool_point(P, TAU * k / 18.0)
				if not _near_water_path(e):
					_swamp_reeds.append([e, r.randf_range(12.0, 24.0)])
	for k in Defs.SWAMP_ORBS:
		_orbs.append([r.randf() * TAU, r.randf() * TAU, r.randf_range(0.04, 0.08), r.randf_range(0.8, 1.2)])


func _draw_swamp_ground() -> void:
	if _orbs.is_empty():
		_build_swamp_art()
	var s := view_scale
	for P in pools:
		var bank := PackedVector2Array()
		var water := PackedVector2Array()
		for k in 65:
			var a := TAU * k / 64.0
			bank.append(proj(P[0] + (pool_point(P, a) - P[0]) * 1.08))
			water.append(proj(pool_point(P, a)))
		var lit := light_at(P[0]) * fire_glow
		draw_colored_polygon(bank, Color("#161812").lerp(Color("#3a3628"), lit * 0.8))
		draw_colored_polygon(water, Color("#0f1712").lerp(Color("#24302a"), lit * 0.6))
		var inner := PackedVector2Array()
		for k in 65:
			inner.append(proj(P[0] + (pool_point(P, TAU * k / 64.0) - P[0]) * 0.6))
		draw_colored_polygon(inner, Color(0.02, 0.04, 0.03, 0.35))
		# Scum and a slow bubble.
		for k in 3:
			var a: float = P[3] + k * 1.3
			var c := proj(P[0] + Vector2(cos(a) * P[1] * 0.5, sin(a) * P[2] * 0.45))
			_ellipse_xy(c, (14.0 + 4.0 * k) * s, (5.0 + k) * s * K, Color(0.3, 0.38, 0.24, 0.1 + 0.12 * lit))
		var ph := fmod(_t * 0.3 + P[3], 1.0)
		var bc := proj(P[0] + Vector2(P[1] * 0.2, -P[2] * 0.15))
		_ring(bc, (3.0 + ph * 18.0) * s, (3.0 + ph * 18.0) * s * K, Color(0.6, 0.7, 0.6, 0.16 * (1.0 - ph)), 1.3 * s)
		for k in range(1, water.size()):
			draw_line(water[k - 1], water[k], Color(0.5, 0.56, 0.48, 0.1 + 0.25 * lit), 1.6 * s, true)
	for rd in _swamp_reeds:
		var c := proj(rd[0])
		var h: float = rd[1] * s
		var lit := maxf(light_at(rd[0]) * fire_glow, 0.12)
		var col := Color("#1a1e16").lerp(Color("#5d5c3a"), lit)
		for b in 3:
			var lean := (b - 1.0) * 0.22 + sin(_t * 0.6 + rd[0].x * 0.05) * 0.05
			draw_line(c + Vector2((b - 1) * 2.0 * s, 0), c + Vector2(sin(lean), -cos(lean)) * h * (0.8 + 0.1 * b), col, 1.5 * s, true)


## Dead trees and a grey haze over the ground, under the tiles.
func _draw_swamp_trees() -> void:
	for T in _trees:
		_draw_dead_tree(T)
	draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.42, 0.46, 0.44, 0.07))


## A few faint orbs drifting listlessly over the board (just for mood).
func _draw_swamp_orbs() -> void:
	var s := view_scale
	for k in _orbs.size():
		var O: Array = _orbs[k]
		var w := Vector2(sin(_t * O[2] + O[0]) * VIEW_FIT.x * 1.05, cos(_t * O[2] * 0.8 + O[1]) * VIEW_FIT.y * 0.95)
		w += Vector2(sin(_t * 0.37 + k), cos(_t * 0.29 + k * 2.0)) * 30.0
		var c := proj(w) - Vector2(0, (30.0 + sin(_t * 0.5 + k) * 10.0) * s)
		var glow := 0.6 + 0.4 * sin(_t * 0.7 + k * 1.9)
		var sz: float = O[3] * s
		draw_circle(c, 14.0 * sz, Color(0.7, 0.9, 0.85, 0.035 * glow))
		draw_circle(c, 7.0 * sz, Color(0.75, 0.95, 0.9, 0.06 * glow))
		draw_circle(c, 2.4 * sz, Color(0.85, 1.0, 0.95, 0.22 * glow))


## A Mire patch: a dark, wet mud splat across the trail with slow bubbles.
func _draw_mire(m: Dictionary) -> void:
	var s := view_scale
	var r: float = Defs.MIRE[m["level"] - 1]["r"]
	var c := proj(m["world"])
	var lit := maxf(light_at(m["world"]) * fire_glow, 0.2)
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		var rr := r * (1.0 + 0.12 * sin(a * 3.0 + m["world"].x) + 0.08 * sin(a * 5.0))
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * K) * s)
	draw_colored_polygon(pts, Color("#1e150c").lerp(Color("#5a4026"), lit))
	_ellipse_xy(c + Vector2(-r * 0.15, -r * 0.08 * K) * s, r * 0.6 * s, r * 0.6 * K * s, Color("#3a2a18").lerp(Color("#7a5a36"), lit * 0.7))
	for k in 3:
		var ph := fmod(_t * 0.5 + k * 0.37 + m["world"].y * 0.01, 1.0)
		var bp := c + Vector2(cos(k * 2.1) * r * 0.45, sin(k * 2.1) * r * 0.45 * K) * s
		_ring(bp, (2.0 + ph * 7.0) * s, (2.0 + ph * 7.0) * K * s, Color(0.75, 0.62, 0.42, 0.35 * (1.0 - ph)), 1.2 * s)


## A gnarled dead tree: a twisted, tapering trunk splitting into crooked bare
## branches, with roots splayed into the mud.
func _draw_dead_tree(T: Array) -> void:
	var s := view_scale
	var base := proj(T[0])
	var lit := maxf(light_at(T[0]) * fire_glow, 0.3)
	var bark := Color("#1c1b18").lerp(Color("#6a6052"), lit)
	var r := RandomNumberGenerator.new()
	r.seed = T[3]
	_ellipse_xy(base + Vector2(10.0 * s, 4.0 * s), 30.0 * s, 9.0 * s, Color(0, 0, 0, 0.3))
	for k in 4:   # roots
		var a := PI * (0.05 + 0.3 * k) + r.randf_range(-0.1, 0.1)
		var d := Vector2(cos(a) * 26.0, sin(a) * 7.0 - 2.0) * s
		if k >= 2:
			d.x = -d.x
		draw_line(base, base + d, bark, 7.0 * s, true)
	_branch(r, base, -PI / 2 + T[2], T[1] * s, 18.0 * s, bark, 0)


func _branch(r: RandomNumberGenerator, from: Vector2, ang: float, length: float, width: float, col: Color, depth: int) -> void:
	var p := from
	var a := ang
	var segs := 4
	for k in segs:   # a crooked limb: a few kinked segments
		a += r.randf_range(-0.35, 0.35)
		var q := p + Vector2.from_angle(a) * length / segs
		var w := lerpf(width, width * 0.55, float(k + 1) / segs)
		draw_line(p, q, col, w, true)
		draw_circle(q, w * 0.5, col)
		if depth < 3 and k >= 1 and r.randf() < 0.55:
			var side := -1.0 if r.randf() < 0.5 else 1.0
			_branch(r, q, a + side * r.randf_range(0.5, 1.0), length * 0.45, w * 0.6, col, depth + 1)
		p = q
	if depth < 3:   # fork at the tip
		_branch(r, p, a - r.randf_range(0.3, 0.6), length * 0.5, width * 0.45, col, depth + 1)
		_branch(r, p, a + r.randf_range(0.3, 0.6), length * 0.45, width * 0.4, col, depth + 1)


# ------------------------------------------------------------ chapel
## Sunken Chapel: a ruined nave half sunk in the earth. Flagstones, rows of
## broken pews, snapped pillars, candle clusters and shafts of stained-glass
## light falling through a roof that is no longer there.
var _pews: Array = []     ## [centre, width, tilt, broken, seed]
var _pillars: Array = []  ## [world, height, seed]
var _candles: Array = []  ## [world, height, phase]
var _shafts: Array = []   ## [world, rx, phase]
var _rubble: Array = []   ## [world, size, seed]
var _altar: Array = []    ## [world, seed] (empty if none fit)
const GLASS := [Color("#c0392b"), Color("#2e5aa8"), Color("#d9a13a"), Color("#3d8a5a"), Color("#7a3d9a"), Color("#2e5aa8")]


func _chapel_clear(w: Vector2, m: float) -> bool:
	if w.length() < 190.0 or Defs.COACH_ZONE.grow(m).has_point(w):
		return false
	if absf(w.x) > VIEW_FIT.x + 60.0 or absf(w.y) > VIEW_FIT.y + 20.0:
		return false
	for t in tiles:
		if t.distance_to(w) < TILE_RADIUS + m:
			return false
	var trails: Array = paths.duplicate()
	for L in links:
		trails.append(L["pts"])
	for p in trails:
		for q in p:
			if q.distance_to(w) < 28.0 + m:
				return false
	return true


func _build_chapel_art() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed + 83
	# The broken altar first, ideally toward the back of the nave.
	for attempt in 300:
		var far := attempt < 120
		var w := Vector2(r.randf_range(-VIEW_FIT.x * 0.85, VIEW_FIT.x * 0.85),
			r.randf_range(-VIEW_FIT.y + 70.0, -120.0) if far else r.randf_range(-VIEW_FIT.y + 70.0, VIEW_FIT.y - 40.0))
		var m := 40.0 if attempt < 200 else 26.0
		if _chapel_clear(w, m) and _chapel_clear(w + Vector2(56, 0), m * 0.4) and _chapel_clear(w - Vector2(56, 0), m * 0.4):
			_altar = [w, r.randi()]
			break
	# Pews: a few blocks of 2-4 rows facing the same way.
	var blocks := r.randi_range(3, 5)
	for attempt in 120:
		if blocks <= 0:
			break
		var start := Vector2(r.randf_range(-VIEW_FIT.x, VIEW_FIT.x), r.randf_range(-VIEW_FIT.y + 40.0, VIEW_FIT.y - 30.0))
		var wid := r.randf_range(64.0, 92.0)
		var placed := 0
		for j in r.randi_range(2, 4):
			var c := start + Vector2(r.randf_range(-6.0, 6.0), 42.0 * j)
			var broken := 0
			if r.randf() < 0.35:
				broken = r.randi_range(1, 2)
			var half := wid * (0.6 if broken == 1 else 1.0) / 2.0
			var ok := _chapel_clear(c, 16.0) and _chapel_clear(c + Vector2(half, 0), 12.0) and _chapel_clear(c - Vector2(half, 0), 12.0)
			if not _altar.is_empty() and _altar[0].distance_to(c) < wid / 2.0 + 70.0:
				ok = false
			for P in _pews:
				if P[0].distance_to(c) < 36.0 or (absf(P[0].y - c.y) < 34.0 and absf(P[0].x - c.x) < (P[1] + wid) / 2.0 + 10.0):
					ok = false
			if ok:
				_pews.append([c, wid * (0.6 if broken == 1 else 1.0), r.randf_range(-0.35, 0.35) if broken == 1 else r.randf_range(-0.04, 0.04), broken, r.randi()])
				placed += 1
		if placed > 0:
			blocks -= 1
	# Pillars: snapped columns round the edge of the nave.
	var want := r.randi_range(2, 4)
	for attempt in 200:
		if _pillars.size() >= want:
			break
		var w := Vector2(r.randf_range(-VIEW_FIT.x - 20.0, VIEW_FIT.x + 20.0), r.randf_range(-VIEW_FIT.y + 120.0, VIEW_FIT.y - 10.0))
		if not _chapel_clear(w, 26.0):
			continue
		var h := r.randf_range(70.0, 150.0)
		var top := w - Vector2(0, h * 1.1 / K)
		var ok := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, w, top).length() > 230.0
		for t in tiles:
			if Geometry2D.get_closest_point_to_segment(t, w, top).distance_to(t) < TILE_RADIUS + 40.0:
				ok = false
		for P in _pillars:
			if P[0].distance_to(w) < 180.0:
				ok = false
		if not _altar.is_empty() and _altar[0].distance_to(w) < 110.0:
			ok = false
		for P in _pews:
			if P[0].distance_to(w) < P[1] / 2.0 + 30.0:
				ok = false
		if ok:
			_pillars.append([w, h, r.randi()])
			for k in r.randi_range(1, 3):   # fallen drums beside it
				var d := w + Vector2.from_angle(r.randf() * TAU) * r.randf_range(34.0, 60.0)
				if _chapel_clear(d, 10.0):
					_rubble.append([d, r.randf_range(7.0, 13.0), r.randi()])
	# Candles: little clusters by pew ends and pillar feet.
	var anchors: Array = []
	if not _altar.is_empty():   # always a few at the altar's foot
		anchors.append(_altar[0] + Vector2(-58.0, 16.0))
	for P in _pews:
		anchors.append(P[0] + Vector2((P[1] / 2.0 + 14.0) * (-1.0 if r.randf() < 0.5 else 1.0), 6.0))
	for P in _pillars:
		anchors.append(P[0] + Vector2(r.randf_range(-24.0, 24.0), 18.0))
	if anchors.size() > 1:
		var first = anchors.pop_front()
		anchors.shuffle()
		anchors.push_front(first)
	var clusters := 0
	for a in anchors:
		if clusters >= r.randi_range(3, 5):
			break
		if not _chapel_clear(a, 8.0):
			continue
		clusters += 1
		for k in r.randi_range(2, 4):
			_candles.append([a + Vector2(r.randf_range(-11.0, 11.0), r.randf_range(-5.0, 5.0)), r.randf_range(7.0, 16.0), r.randf() * TAU])
	# Light shafts: 2-3 pools of coloured light on the floor.
	for k in r.randi_range(2, 3):
		for attempt in 30:
			var w := Vector2(r.randf_range(-VIEW_FIT.x * 0.9, VIEW_FIT.x * 0.9), r.randf_range(-VIEW_FIT.y * 0.8, VIEW_FIT.y * 0.85))
			if w.length() < 170.0 or Defs.COACH_ZONE.grow(40.0).has_point(w):
				continue
			var ok := true
			for S in _shafts:
				if S[0].distance_to(w) < 220.0:
					ok = false
			if ok:
				_shafts.append([w, r.randf_range(48.0, 66.0), r.randf() * TAU])
				break
	for k in r.randi_range(4, 7):   # loose rubble
		var w := Vector2(r.randf_range(-VIEW_FIT.x, VIEW_FIT.x), r.randf_range(-VIEW_FIT.y, VIEW_FIT.y))
		if _chapel_clear(w, 8.0):
			_rubble.append([w, r.randf_range(4.0, 8.0), r.randi()])


## Flagstones in staggered rows; the grout shows only where the fire reaches.
func _draw_chapel_floor() -> void:
	if _shafts.is_empty() and _pews.is_empty():
		_build_chapel_art()
	var s := view_scale
	var g := 64.0
	for row in range(-8, 9):
		var y := row * g * 0.8
		for col in range(-10, 10):
			var x := col * g + (g * 0.5 if row % 2 != 0 else 0.0)
			var a := Vector2(x, y)
			var lit := light_at(a + Vector2(g / 2, g * 0.4)) * fire_glow
			if lit < 0.04:
				continue
			var gc := Color(0.04, 0.035, 0.05, 0.5 * lit)
			draw_line(proj(a), proj(a + Vector2(g, 0)), gc, 1.6 * s)
			draw_line(proj(a), proj(a + Vector2(0, g * 0.8)), gc, 1.6 * s)
			var h := hash(Vector2i(row, col))
			if h % 7 == 0:   # a cracked flag
				var c := a + Vector2(g * 0.3, g * 0.3)
				draw_polyline(PackedVector2Array([proj(c), proj(c + Vector2(12, 6)), proj(c + Vector2(18, 20)), proj(c + Vector2(30, 24))]), gc, 1.2 * s)
			elif h % 5 == 0:   # a darker, sunken flag
				var q := PackedVector2Array([proj(a + Vector2(3, 3)), proj(a + Vector2(g - 3, 3)), proj(a + Vector2(g - 3, g * 0.8 - 3)), proj(a + Vector2(3, g * 0.8 - 3))])
				draw_colored_polygon(q, Color(0, 0, 0, 0.12 * lit))


## Floor light pools, rubble, pews, pillars and candles, back to front.
func _draw_chapel_props() -> void:
	var s := view_scale
	for S in _shafts:
		_draw_glass_pool(S)
	var items: Array = []
	for P in _pews:
		items.append([P[0].y, 0, P])
	for P in _pillars:
		items.append([P[0].y, 1, P])
	for P in _rubble:
		items.append([P[0].y, 2, P])
	for P in _candles:
		items.append([P[0].y, 3, P])
	if not _altar.is_empty():
		items.append([_altar[0].y, 4, _altar])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0: _draw_pew(it[2])
			1: _draw_pillar(it[2])
			2:
				var R: Array = it[2]
				var lit := maxf(light_at(R[0]) * fire_glow, 0.2)
				var c := proj(R[0])
				_ellipse_xy(c + Vector2(2, 2) * s, R[1] * 1.1 * s, R[1] * 0.6 * s, Color(0, 0, 0, 0.3))
				_ellipse_xy(c, R[1] * s, R[1] * 0.75 * s, Color("#1e1d22").lerp(Color("#77727e"), lit))
			3: _draw_candle(it[2])
			4: _draw_altar(it[2])
	draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.36, 0.38, 0.5, 0.05))


func _draw_glass_pool(S: Array) -> void:
	var s := view_scale
	var c := proj(S[0])
	var rx: float = S[1] * s
	var shim := 0.8 + 0.2 * sin(_t * 0.6 + S[2])
	_ellipse_xy(c, rx * 1.15, rx * 1.15 * K, Color(1.0, 0.95, 0.8, 0.05 * shim))
	var n := GLASS.size()
	for k in n:   # a rose window, cast on the floor
		var a0: float = TAU * k / n + S[2]
		var pts := PackedVector2Array([c])
		for j in 7:
			var a: float = a0 + TAU / n * j / 6.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * rx * K))
		var gc: Color = GLASS[k]
		gc.a = 0.16 * shim
		draw_colored_polygon(pts, gc)
		draw_line(c, c + Vector2(cos(a0) * rx, sin(a0) * rx * K), Color(0, 0, 0, 0.18), 1.5 * s)
	_ring(c, rx * 0.35, rx * 0.35 * K, Color(0, 0, 0, 0.16), 1.5 * s)
	_ellipse_xy(c, rx * 0.32, rx * 0.32 * K, Color(1.0, 0.9, 0.6, 0.1 * shim))


## Faint slanting beams over everything, with dust turning in them.
func _draw_chapel_beams() -> void:
	var s := view_scale
	for S in _shafts:
		var c := proj(S[0])
		var rx: float = S[1] * s
		var shim := 0.8 + 0.2 * sin(_t * 0.6 + S[2])
		var up := Vector2(-260.0, -900.0) * s
		var base := Color(1.0, 0.94, 0.82, 0.07 * shim)
		var top := Color(1.0, 0.94, 0.82, 0.0)
		draw_polygon(PackedVector2Array([c - Vector2(rx, 0), c + Vector2(rx, 0), c + up + Vector2(rx * 0.7, 0), c + up - Vector2(rx * 0.7, 0)]),
			PackedColorArray([base, base, top, top]))
		for k in 6:   # dust motes
			var f := fmod(_t * 0.03 + k * 0.17 + S[2], 1.0)
			var p := c + up * f * 0.6 + Vector2(sin(_t * 0.4 + k * 2.3) * rx * 0.6, 0)
			draw_circle(p, 1.3 * s, Color(1.0, 0.95, 0.85, 0.3 * sin(f * PI) * shim))


## A pew: a bench with a high back. Broken ones are short and skewed, or have
## lost half their back.
func _draw_pew(P: Array) -> void:
	var s := view_scale
	var w: float = P[1]
	var u := Vector2.from_angle(P[2])
	var v := Vector2(-u.y, u.x)
	var lit := maxf(light_at(P[0]) * fire_glow, 0.22)
	var wood := Color("#1a120d").lerp(Color("#6b4a30"), lit)
	var dark := wood.darkened(0.35)
	var seat_h := 10.0 * s
	var back_h := 22.0 * s
	var l: Vector2 = P[0] - u * w / 2.0
	var rr: Vector2 = P[0] + u * w / 2.0
	var d := v * 14.0   # seat depth (toward the viewer)
	var up := Vector2(0, -seat_h)
	_ellipse_xy(proj(P[0] + d * 0.5) + Vector2(4, 3) * s, w * 0.55 * s, 9.0 * s, Color(0, 0, 0, 0.3))
	# back panel (far edge)
	var bl := proj(l) + up
	var br := proj(rr) + up
	var cut := 0.5 if P[3] == 2 else 1.0
	var bm := bl.lerp(br, cut)
	draw_colored_polygon(PackedVector2Array([bl, bm, bm + Vector2(0, -back_h), bl + Vector2(0, -back_h)]), dark)
	draw_line(bl + Vector2(0, -back_h), bm + Vector2(0, -back_h), wood.lightened(0.1), 3.0 * s)
	if P[3] == 2:   # a jagged snapped end
		draw_line(bm, bm + Vector2(-4, -back_h * 0.7) * Vector2(s, 1), dark, 3.0 * s)
	# seat
	var seat := PackedVector2Array([proj(l) + up, proj(rr) + up, proj(rr + d) + up, proj(l + d) + up])
	draw_colored_polygon(seat, wood)
	# front board and legs
	draw_colored_polygon(PackedVector2Array([proj(l + d) + up, proj(rr + d) + up, proj(rr + d), proj(l + d)]), dark)
	for e in [l + d, rr + d]:
		draw_line(proj(e), proj(e) + up, dark.darkened(0.3), 3.0 * s)


## A snapped stone column on a square plinth, with a jagged top.
func _draw_pillar(P: Array) -> void:
	var s := view_scale
	var base := proj(P[0])
	var h: float = P[1] * s
	var r := RandomNumberGenerator.new()
	r.seed = P[2]
	var lit := maxf(light_at(P[0]) * fire_glow, 0.25)
	var stone := Color("#1e1d22").lerp(Color("#7a7582"), lit)
	var shade := stone.darkened(0.35)
	var hw := 14.0 * s
	_ellipse_xy(base + Vector2(14, 4) * s, 34.0 * s, 10.0 * s, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(base + Vector2(-hw * 1.5, -8.0 * s), Vector2(hw * 3.0, 10.0 * s)), shade)
	draw_rect(Rect2(base + Vector2(-hw * 1.5, -10.0 * s), Vector2(hw * 3.0, 3.0 * s)), stone)
	var top := PackedVector2Array()
	var n := 5
	for k in n + 1:   # jagged break
		top.append(base + Vector2(lerpf(hw, -hw, float(k) / n), -h + r.randf_range(-12.0, 6.0) * s))
	var body := PackedVector2Array([base + Vector2(-hw, -8.0 * s), base + Vector2(hw, -8.0 * s)])
	body.append_array(top)
	draw_colored_polygon(body, stone)
	draw_colored_polygon(PackedVector2Array([base + Vector2(hw * 0.3, -8.0 * s), base + Vector2(hw, -8.0 * s), top[0], top[1].lerp(top[0], 0.4)]), shade)
	for k in 3:   # fluting
		var x := lerpf(-hw * 0.6, hw * 0.1, k / 2.0)
		draw_line(base + Vector2(x, -10.0 * s), base + Vector2(x, -h + 10.0 * s), Color(0, 0, 0, 0.18), 1.4 * s)


## The broken altar: a heavy stone block split by a crack, its right end
## slumped and lower, a torn cloth over the top and chunks on the floor.
func _draw_altar(A: Array) -> void:
	var s := view_scale
	var r := RandomNumberGenerator.new()
	r.seed = A[1]
	var w: Vector2 = A[0]
	var lit := maxf(light_at(w) * fire_glow, 0.42)
	var stone := Color("#232128").lerp(Color("#8a8590"), lit)
	var front := stone.darkened(0.3)
	var side := stone.darkened(0.45)
	var hw := 54.0
	var dep := 24.0
	var H := 36.0 * s
	var c := proj(w)
	_ellipse_xy(c + Vector2(8, 6) * s, 62.0 * s, 16.0 * s, Color(0, 0, 0, 0.35))
	# step / plinth
	var st := PackedVector2Array([proj(w + Vector2(-hw - 10, -dep - 8)), proj(w + Vector2(hw + 10, -dep - 8)), proj(w + Vector2(hw + 10, 10)), proj(w + Vector2(-hw - 10, 10))])
	draw_colored_polygon(st, side)
	# the split: the left two-thirds stands, the right end has sunk and tipped
	var sx := 8.0   # crack x (world, from centre)
	var cr := [Vector2(sx, 0), Vector2(sx + 6, 0.35), Vector2(sx - 3, 0.65), Vector2(sx + 5, 1.0)]   # x, height fraction
	# left block: front face
	var lf := PackedVector2Array([proj(w + Vector2(-hw, 0)), proj(w + Vector2(-hw, 0)) + Vector2(0, -H)])
	for k in range(cr.size() - 1, -1, -1):
		lf.append(proj(w + Vector2(cr[k].x, 0)) + Vector2(0, -H * cr[k].y))
	draw_colored_polygon(lf, front)
	# left block: top
	var lt := PackedVector2Array([proj(w + Vector2(-hw, -dep)) + Vector2(0, -H), proj(w + Vector2(sx + 5, -dep)) + Vector2(0, -H),
		proj(w + Vector2(sx + 5, 0)) + Vector2(0, -H), proj(w + Vector2(-hw, 0)) + Vector2(0, -H)])
	draw_colored_polygon(lt, stone)
	draw_line(lt[3], lt[2], stone.lightened(0.15), 2.0 * s)
	# right chunk: lower and tilted
	var drop := Vector2(4.0 * s, H * 0.45)
	var rb := PackedVector2Array([proj(w + Vector2(sx + 10, 0)) + Vector2(0, -H * 0.55) + drop * 0.2, proj(w + Vector2(hw, 0)) + Vector2(0, -H) + drop,
		proj(w + Vector2(hw, 0)) + Vector2(2 * s, 0), proj(w + Vector2(sx + 12, 0))])
	draw_colored_polygon(rb, front.darkened(0.1))
	var rt := PackedVector2Array([rb[0], proj(w + Vector2(sx + 14, -dep)) + Vector2(0, -H * 0.6) + drop * 0.2,
		proj(w + Vector2(hw, -dep)) + Vector2(0, -H) + drop, rb[1]])
	draw_colored_polygon(rt, stone.darkened(0.08))
	# crack line
	var cl := PackedVector2Array()
	for k in cr.size():
		cl.append(proj(w + Vector2(cr[k].x, 0)) + Vector2(0, -H * cr[k].y))
	draw_polyline(cl, Color(0, 0, 0, 0.6), 2.2 * s)
	# carved band across the front
	draw_line(proj(w + Vector2(-hw + 6, 0)) + Vector2(0, -H * 0.5), proj(w + Vector2(sx - 6, 0)) + Vector2(0, -H * 0.5), Color(0, 0, 0, 0.22), 2.0 * s)
	# a torn, faded cloth hanging over the left end
	var cloth := Color("#3a1418").lerp(Color("#8a3a3a"), lit * 0.8)
	var c0 := proj(w + Vector2(-hw + 6, 0)) + Vector2(0, -H)
	var c1 := proj(w + Vector2(-8, 0)) + Vector2(0, -H)
	var torn := PackedVector2Array([c0 + Vector2(0, -2 * s), c1 + Vector2(0, -2 * s), c1 + Vector2(-2 * s, H * 0.45)])
	for k in 5:
		var f := 1.0 - (k + 1) / 6.0
		torn.append(c0.lerp(c1, f) + Vector2(0, H * (0.55 + 0.2 * r.randf())))
	torn.append(c0 + Vector2(0, H * 0.5))
	draw_colored_polygon(torn, cloth)
	draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -2 * s), c1 + Vector2(0, -2 * s), proj(w + Vector2(-8, -dep)) + Vector2(0, -H), proj(w + Vector2(-hw + 6, -dep)) + Vector2(0, -H)]), cloth.lightened(0.05))
	# fallen chunks on the floor
	for k in 3:
		var p := proj(w + Vector2(hw + 14 + k * 11, 10 - k * 9 + r.randf_range(-3, 3)))
		var sz := (8.0 - k * 2.0) * s
		draw_colored_polygon(PackedVector2Array([p + Vector2(-sz, 0), p + Vector2(-sz * 0.5, -sz * 0.9), p + Vector2(sz * 0.7, -sz * 0.6), p + Vector2(sz, 0)]), front)


## A stub of candle with a small living flame; they light their own patch.
func _draw_candle(C: Array) -> void:
	var s := view_scale
	var c := proj(C[0])
	var h: float = C[1] * s
	var fl := 0.75 + 0.25 * sin(_t * 9.0 + C[2]) * sin(_t * 5.3 + C[2] * 2.0)
	draw_circle(c + Vector2(0, -h), 22.0 * s * fl, Color(1.0, 0.7, 0.35, 0.05))
	_ellipse_xy(c, 9.0 * s, 4.0 * s, Color(1.0, 0.75, 0.4, 0.12 * fl))
	draw_line(c, c + Vector2(0, -h), Color("#cfc4a8").darkened(0.25), 3.4 * s)
	draw_circle(c + Vector2(0, -h), 1.7 * s, Color("#cfc4a8"))
	var tip := c + Vector2(sin(_t * 3.0 + C[2]) * 0.8 * s, -h - 7.0 * s * fl)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2.2 * s, -h - 1.0 * s), tip, c + Vector2(2.2 * s, -h - 1.0 * s), c + Vector2(0, -h + 1.0 * s)]), Color(1.0, 0.78, 0.35, 0.95))
	draw_circle(c + Vector2(0, -h - 2.5 * s), 1.3 * s, Color(1.0, 0.97, 0.85))


# ------------------------------------------------------------ lake art
var _pads: Array = []      ## lily pads: [world, size, has flower]
var _reeds: Array = []     ## reed clumps: [world, height]
var _ripples: Array = []   ## [world, phase]


func _build_lake_art() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed + 53
	for k in 64:
		var a := TAU * k / 64.0
		var shore := lake_point(a)
		var by_dock := not dock.is_empty() and Geometry2D.get_closest_point_to_segment(shore, dock[0], dock[1]).distance_to(shore) < 75.0
		if r.randf() < 0.45 and not by_dock:
			_reeds.append([shore + (lake_c - shore).normalized() * r.randf_range(-6.0, 10.0), r.randf_range(16.0, 30.0)])
		if r.randf() < 0.22:
			var w := lake_c + (shore - lake_c) * r.randf_range(0.7, 0.9)
			if not _near_water_path(w):
				_pads.append([w, r.randf_range(9.0, 15.0), r.randf() < 0.3])
	for k in 6:
		var w := lake_c + Vector2(r.randf_range(-0.8, 0.8) * Defs.LAKE_RX, r.randf_range(-0.7, 0.7) * Defs.LAKE_RY)
		if in_lake(w):
			_ripples.append([w, r.randf()])


func _near_water_path(w: Vector2) -> bool:
	for p in paths:
		for q in p:
			if q.distance_to(w) < 40.0:
				return true
	return not dock.is_empty() and Geometry2D.get_closest_point_to_segment(w, dock[0], dock[1]).distance_to(w) < 70.0


## A calm lake: dark still water with the moon and the campfire mirrored in
## it, reeds and lily pads round the shore, slow ripples, a little dock, and
## fireflies; spirits drifting over it leave a reflection and a wake.
func _draw_lake() -> void:
	if _reeds.is_empty():
		_build_lake_art()
	var s := view_scale
	var shore := PackedVector2Array()
	for k in 97:
		shore.append(proj(lake_point(TAU * k / 96.0)))
	# Muddy bank, then the water, deepening toward the middle.
	var bank := PackedVector2Array()
	for k in 97:
		var a := TAU * k / 96.0
		bank.append(proj(lake_c + (lake_point(a) - lake_c) * 1.05))
	draw_colored_polygon(bank, Color("#1c1915").lerp(Color("#3a3024"), light_at(lake_point(PI if lake_side > 0 else 0.0)) * fire_glow * 0.8))
	draw_colored_polygon(shore, Color("#0c1422"))
	for k in 3:
		var inner := PackedVector2Array()
		for j in 97:
			var a := TAU * j / 96.0
			inner.append(proj(lake_c + (lake_point(a) - lake_c) * (0.82 - k * 0.2)))
		draw_colored_polygon(inner, Color(0.02, 0.04, 0.08, 0.35))
	# Moon on the water: a broken shimmering column.
	var moon := lake_c + Vector2(-lake_side * Defs.LAKE_RX * 0.5, -Defs.LAKE_RY * 0.5)
	for k in 9:
		var w := moon + Vector2(sin(_t * 1.3 + k * 1.7) * 6.0, k * 26.0)
		if not in_lake(w):
			continue
		var half := (34.0 - k * 2.5) * (0.7 + 0.3 * sin(_t * 2.1 + k))
		var c := proj(w)
		draw_line(c - Vector2(half * s, 0), c + Vector2(half * s, 0), Color(0.75, 0.82, 1.0, 0.16 - k * 0.012), 3.0 * s, true)
	# The campfire's glow mirrored by the near shore.
	var near := lake_point(PI if lake_side > 0 else 0.0)
	for k in 6:
		var w := near + Vector2(lake_side * (24.0 + k * 22.0), sin(_t * 1.7 + k) * 5.0)
		var half := (26.0 - k * 3.0) * (0.75 + 0.25 * sin(_t * 3.0 + k * 2.0))
		var c := proj(w)
		draw_line(c - Vector2(half * s, 0), c + Vector2(half * s, 0), Color(1.0, 0.6, 0.25, (0.3 - k * 0.045) * fire_glow), 3.0 * s, true)
	# Slow ripples.
	for rp in _ripples:
		var ph := fmod(_t * 0.25 + rp[1], 1.0)
		var c := proj(rp[0])
		_ring(c, (6.0 + ph * 40.0) * s, (6.0 + ph * 40.0) * s * K, Color(0.6, 0.72, 0.95, 0.14 * (1.0 - ph)), 1.5 * s)
	# Wet edge of the shore.
	for k in range(1, shore.size()):
		var lit := light_at(lake_point(TAU * k / 96.0)) * fire_glow
		draw_line(shore[k - 1], shore[k], Color(0.45, 0.5, 0.6, 0.12 + 0.3 * lit), 2.0 * s, true)
	# Lily pads.
	for pd in _pads:
		var c := proj(pd[0])
		var sz: float = pd[1] * s
		var lit := maxf(light_at(pd[0]) * fire_glow, 0.15)
		_ellipse_xy(c, sz, sz * K, Color("#16261a").lerp(Color("#3f6a3a"), lit))
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(sz, -sz * K * 0.35), c + Vector2(sz, sz * K * 0.35)]), Color("#0c1422"))
		if pd[2]:
			draw_circle(c - Vector2(sz * 0.2, sz * 0.3), sz * 0.3, Color(0.95, 0.85, 0.9, 0.35 + 0.5 * lit))
	# The dock.
	if not dock.is_empty():
		_draw_dock()
	# Reeds round the shore.
	for rd in _reeds:
		var c := proj(rd[0])
		var h: float = rd[1] * s
		var lit := maxf(light_at(rd[0]) * fire_glow, 0.12)
		var col := Color("#1e2418").lerp(Color("#6d6a3a"), lit)
		for b in 4:
			var lean := (b - 1.5) * 0.18 + sin(_t * 0.8 + rd[0].x * 0.05) * 0.06
			var tip := c + Vector2(sin(lean), -cos(lean)) * h * (0.75 + 0.1 * b)
			draw_line(c + Vector2((b - 1.5) * 2.0 * s, 0), tip, col, 1.6 * s, true)
			if b == 1:   # a cattail head
				draw_line(tip + Vector2(0, h * 0.05), tip + Vector2(0, h * 0.25), Color("#3a2a1c").lerp(Color("#7a5232"), lit), 3.5 * s, true)
	# Spirits on the water: a faint reflection and a wake.
	for sp in spirits_ref:
		if not is_instance_valid(sp) or sp.dead or not in_lake(sp.world):
			continue
		var c := proj(sp.world)
		var col: Color = Defs.SPIRITS[sp.kind]["color"]
		var sz: float = 15.0 * sp.size_k * s
		_ellipse_xy(c + Vector2(0, sz * 1.6), sz * 0.8, sz * 0.5, Color(col, 0.16))
		var ph := fmod(_t * 0.9 + sp.dist * 0.01, 1.0)
		_ring(c + Vector2(0, sz * 0.6), sz * (1.0 + ph * 1.4), sz * (1.0 + ph * 1.4) * K, Color(0.7, 0.8, 1.0, 0.22 * (1.0 - ph)), 1.5 * s)
	# Fireflies over the water.
	for k in 10:
		var w := lake_c + Vector2(sin(_t * 0.31 + k * 2.3) * Defs.LAKE_RX * 0.75, cos(_t * 0.23 + k * 1.1) * Defs.LAKE_RY * 0.6)
		var c := proj(w) - Vector2(0, (18.0 + sin(_t + k) * 6.0) * s)
		var glow := 0.5 + 0.5 * sin(_t * 2.3 + k * 1.9)
		draw_circle(c, 5.0 * s, Color(0.85, 1.0, 0.45, 0.12 * glow))
		draw_circle(c, 1.8 * s, Color(0.9, 1.0, 0.6, 0.35 + 0.5 * glow))


## A lake branch: a dashed line all the way to the fire, water-blue on the
## lake, warming to the trail's brown over a short stretch once ashore.
func _draw_wake(p: PackedVector2Array) -> void:
	var blue := 1.0
	for k in range(1, p.size()):
		var mid := (p[k] + p[k - 1]) / 2.0
		blue = 1.0 if in_lake(mid) else maxf(0.0, blue - 0.12)
		if k % 2 == 1:
			continue
		var lit := light_at(mid) * fire_glow
		var brown := Color("#3a2a1e").lerp(Color("#a8744a"), clampf(lit, 0.0, 1.0))
		var dc := brown.lerp(Color(0.7, 0.82, 1.0), blue)
		dc.a = lerpf(0.75, 0.3 + 0.25 * lit, blue)
		draw_line(proj(p[k - 1]), proj(p[k]), Color(dc, dc.a * 0.35), 16.0 * view_scale, true)
		draw_line(proj(p[k - 1]), proj(p[k]), dc, 7.0 * view_scale, true)


func _draw_dock() -> void:
	var s := view_scale
	var a: Vector2 = dock[0]
	var b: Vector2 = dock[1]
	var u := (b - a).normalized()
	var n := u.orthogonal() * 52.0
	var lit := maxf(light_at((a + b) / 2.0) * fire_glow, 0.15)
	var wood := Color("#3a2618").lerp(Color("#a0703f"), lit)
	# Posts standing in the water.
	for t in [0.35, 0.68, 1.0]:
		for sd in [-1.0, 1.0]:
			var w: Vector2 = a.lerp(b, t) + n * sd * 0.92
			var c := proj(w)
			if in_lake(w):
				_ring(c + Vector2(0, 10 * s), 9 * s, 9 * s * K, Color(0.6, 0.72, 0.95, 0.18), 1.5 * s)
			draw_line(c, c + Vector2(0, 12 * s), wood.darkened(0.5), 6 * s, true)
	var deck := PackedVector2Array([proj(a + n), proj(b + n), proj(b - n), proj(a - n)])
	var shadow := PackedVector2Array()
	for p in deck:
		shadow.append(p + Vector2(0, 7 * s))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(deck, wood)
	var steps := int(a.distance_to(b) / 17.0)
	for k in range(1, steps):
		var w := a + u * k * 17.0
		draw_line(proj(w + n), proj(w - n), wood.darkened(0.35), 1.5 * s, true)
	draw_polyline(PackedVector2Array([proj(a + n), proj(b + n), proj(b - n), proj(a - n)]), wood.lightened(0.15), 1.5 * s, true)


# ------------------------------------------------------------ drawing
func _draw() -> void:
	# Ground: rings from deep night to the warm lit dirt by the fire.
	if stop == "hill":   # the slope falls away past the outer ring: all dark
		draw_rect(Rect2(-4000, -4000, 8000, 8000), Color("#0a080b"))
	var rings := 22
	for k in rings:
		var f := 1.0 - float(k) / rings          # 1 outer .. small inner
		var rad := lerpf(120.0, SPAWN_RADIUS * 1.25, f)
		var lit := clampf(1.0 - (rad - 140.0) / (LIGHT_RADIUS * 1.15), 0.0, 1.0)
		lit = pow(lit, 1.4) * fire_glow
		var col := Color("#0a080b").lerp(Color("#5e3d26"), clampf(lit, 0.0, 1.0))
		if stop == "swamp":   # boggy, grey-green murk
			col = Color("#0a0c0b").lerp(Color("#4a4434"), clampf(lit, 0.0, 1.0))
		elif stop == "chapel":   # cold old stone
			col = Color("#09090c").lerp(Color("#4d4742"), clampf(lit, 0.0, 1.0))
		_ellipse(Vector2.ZERO, rad, col)
	if stop == "cliff":
		_draw_cliff()
	elif stop == "hill":
		_draw_hill()
	elif stop == "lake":
		_draw_lake()
	elif stop == "swamp":
		_draw_swamp_ground()
	elif stop == "chapel":
		_draw_chapel_floor()
	_draw_group_patches()
	# Trails, lighter packed dirt, fading into the dark.
	var trails: Array = paths.slice(0, lane_count)
	if stop == "lake":   # the water crossing stays a dashed wake all the way in
		trails.remove_at(0)
		_draw_wake(paths[0])
	for L in links:
		if not L.get("wake", false):
			trails.append(L["pts"])
	for p: PackedVector2Array in trails:
		for k in range(1, p.size()):
			var mid := (p[k] + p[k - 1]) / 2.0
			var lit := light_at(mid) * fire_glow
			var col := Color("#17110f").lerp(Color("#7a5236"), clampf(lit, 0.0, 1.0))
			col.a = 0.55 + 0.45 * lit
			if stop == "chapel":   # dusty aisles worn into the flagstones
				col = Color("#121116").lerp(Color("#6e6658"), clampf(lit, 0.0, 1.0))
				col.a = 0.5 + 0.4 * lit
			if stop == "swamp":   # murkier, greyer trails
				col = Color("#121412").lerp(Color("#5e5444"), clampf(lit, 0.0, 1.0))
				col.a = 0.55 + 0.45 * lit
				if in_pool(mid):   # wading through a pool: a faint dashed wake
					if k % 2 == 0:
						draw_line(proj(p[k - 1]), proj(p[k]), Color(0.62, 0.7, 0.6, 0.18 + 0.2 * lit), 6.0 * view_scale, true)
					continue
			if stop == "lake" and in_lake(mid):   # crossing the water: a faint wake
				if k % 2 == 0:
					var dc := Color(0.7, 0.82, 1.0, 0.3 + 0.25 * lit)
					draw_line(proj(p[k - 1]), proj(p[k]), Color(dc, dc.a * 0.35), 16.0 * view_scale, true)
					draw_line(proj(p[k - 1]), proj(p[k]), dc, 7.0 * view_scale, true)
				continue
			draw_line(proj(p[k - 1]), proj(p[k]), col, 46.0 * view_scale, true)
			draw_circle(proj(p[k]), 23.0 * view_scale * Vector2(1, K).length() * 0.72, col)
	for L in links:
		if L.get("wake", false):
			_draw_wake(L["pts"])
	# Grass tufts and pebbles, only seen where the light reaches.
	for tf in _tufts:
		var w: Vector2 = tf[0]
		var lit := light_at(w) * fire_glow
		if lit < 0.05 or (stop == "cliff" and w.y < Defs.cliff_edge_y(w.x) + 20.0) or _near_lake(w, 14.0) or _near_pool(w, 14.0):
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
	for m in mires:
		_draw_mire(m)
	if stop == "swamp":
		_draw_swamp_trees()
	elif stop == "chapel":
		_draw_chapel_props()
	# Tiles: flat stone slabs. Valid ones glow while a die is being placed.
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for i in tiles.size():
		var w := tiles[i]
		var lit := maxf(light_at(w), 0.35)
		var c := proj(w)
		var rx := TILE_RADIUS * view_scale
		_draw_slab(i, w, lit)
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
					var mn: float = Defs.DEFENSES[face_now][0]["min"] * guide_boost_at(i, face_now).get("min_mult", 1.0)
					_ring(c, mn * view_scale, mn * view_scale * K, Color(1, 0.4, 0.3, 0.3), 2.0)
				if face_now in Defs.SUPPORT_FACES:   # light up the tiles it would boost
					for j in tiles.size():
						if j != i and tile_group[j] == tile_group[i]:
							var cj := proj(tiles[j])
							_ring(cj, rx * 1.3, rx * K * 1.3, Color(1, 0.92, 0.6, 0.45), 2.5 * view_scale)
	if stop == "swamp":
		_draw_swamp_orbs()
	elif stop == "chapel":
		_draw_chapel_beams()
	_draw_forks(pulse)
	# Fire target ring for the Kindle (★) die.
	if glow_face in ["wall", "mire"]:   # the stretch of each trail a wall (or mire) can go on
		var wc := Color("#d9743a", 0.25 + 0.35 * pulse)
		for pts in paths:
			var last := Vector2.INF
			for k in range(1, pts.size()):
				var q: Vector2 = pts[k]
				if q.length() < Defs.WALL_MIN_R or q.length() > Defs.WALL_MAX_R:
					last = Vector2.INF
					continue
				if last != Vector2.INF:
					draw_line(proj(last), proj(q), wc, 7.0 * view_scale)
				last = q
	if shield > 0.0:   # a Reliquary on the fire: a faint golden shield ring
		var sr := (78.0 + 2.0 * sin(_t * 2.0)) * view_scale
		var sa := clampf(shield / 8.0, 0.35, 1.0)
		_ring(Vector2.ZERO, sr, sr * K, Color(1.0, 0.85, 0.45, 0.45 * sa), 3.0 * view_scale)
		_ring(Vector2.ZERO, sr * 1.08, sr * 1.08 * K, Color(1.0, 0.9, 0.6, 0.15 * sa), 6.0 * view_scale)
	if glow_face in Defs.FIRE_FACES:
		var gc := Color("#fff0b0")
		gc.a = 0.35 + 0.4 * pulse + (0.25 if hover_tile == -2 else 0.0)
		_ring(Vector2.ZERO, 92.0 * view_scale, 92.0 * view_scale * K, gc, 4.0 * view_scale)


var gates_left := 0          ## set by the battle: junctions glow while gates remain


## Junction markers, and Char's gates with their cooldown flame.
var _patches: Array = []   ## per group: [4 hulls outer to inner, centre, flecks] (world)

## Each group of 3 sits on a patch of trodden-down ground, so the groups
## (and which defenses a Guide Light or Bellows boosts) read at a glance.
func _draw_group_patches() -> void:
	if _patches.size() != group_count:
		_patches.clear()
		var r := RandomNumberGenerator.new()
		r.seed = layout_seed + 77
		for g in group_count:
			var hulls := []
			var mid := Vector2.ZERO
			var n := 0
			for i in tiles.size():
				if tile_group[i] == g:
					mid += tiles[i]
					n += 1
			var ph := r.randf() * TAU
			for rad in [TILE_RADIUS * 1.75, TILE_RADIUS * 1.5, TILE_RADIUS * 1.25, TILE_RADIUS * 1.0]:
				var pts := PackedVector2Array()
				for i in tiles.size():
					if tile_group[i] == g:
						for k in 18:
							pts.append(tiles[i] + Vector2.from_angle(TAU * k / 18.0) * rad)
				var hull := Geometry2D.convex_hull(pts)
				hull.remove_at(hull.size() - 1)
				for k in hull.size():   # a gently uneven, trodden edge
					var out := (hull[k] - mid / n).normalized()
					hull[k] += out * 6.0 * sin(out.angle() * 4.0 + ph)
				hulls.append(hull)
			hulls.append(mid / maxf(n, 1))   # P[4]
			var flecks := []   # P[5]: [world, size, pale]
			var inner: PackedVector2Array = hulls[1]
			for k in 26:
				var q: Vector2 = hulls[4] + Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1)) * TILE_RADIUS * 2.6
				if Geometry2D.is_point_in_polygon(q, inner):
					flecks.append([q, r.randf_range(1.2, 2.6), r.randf() < 0.65])
			hulls.append(flecks)
			_patches.append(hulls)
	for P in _patches:
		var lit := light_at(P[4]) * fire_glow
		for h in 4:   # stacked soft layers: darkest in the middle
			var poly := PackedVector2Array()
			for w in P[h]:
				poly.append(proj(w))
			var ash := Color("#2a221d").lerp(Color("#5e5750"), float(h) / 3.0)   # charred rim, grey ash middle
			ash.a = (0.26 if h == 0 else 0.11) * clampf(lit + 0.4, 0.0, 1.0)
			draw_colored_polygon(poly, ash)
		for f in P[5]:   # flecks of ash and char
			var fc := Color("#8d867d") if f[2] else Color("#17110d")
			fc.a = 0.55 * clampf(lit + 0.3, 0.0, 1.0)
			draw_circle(proj(f[0]), f[1] * view_scale, fc)


var _slabs: Array = []   ## per tile: {edge, cracks, moss, ember} offsets (world)

## An irregular flat stone: a lumpy outline at a random turn, a worn top face,
## a crack or two, and now and then moss or a stray ember.
func _slab_shape(i: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = layout_seed * 131 + i * 7919
	var n := r.randi_range(7, 10)
	var rot := r.randf() * TAU
	var edge := PackedVector2Array()
	for k in n:
		var a := rot + TAU * (k + r.randf_range(-0.25, 0.25)) / n
		var lump := r.randf_range(0.95, 1.02) if _is_dock_tile(i) else r.randf_range(0.86, 1.06)
		edge.append(Vector2.from_angle(a) * TILE_RADIUS * lump)
	var cracks := []
	for k in r.randi_range(1, 2):
		var p0: Vector2 = edge[r.randi() % n] * 0.78
		var line := PackedVector2Array([p0])
		var dir := -p0.normalized().rotated(r.randf_range(-0.6, 0.6))
		for s in 3:
			line.append(line[line.size() - 1] + dir.rotated(r.randf_range(-0.5, 0.5)) * TILE_RADIUS * r.randf_range(0.14, 0.24))
		cracks.append(line)
	var moss := []
	if r.randf() < (0.0 if _is_dock_tile(i) else {"hill": 0.75, "cliff": 0.55}.get(stop, 0.4)):
		var at := Vector2.from_angle(r.randf() * TAU) * TILE_RADIUS * 0.62
		for k in r.randi_range(3, 5):
			moss.append([at + Vector2(r.randf_range(-9, 9), r.randf_range(-6, 6)), r.randf_range(2.5, 5.0)])
	var ember = null
	if r.randf() < 0.18:
		ember = Vector2.from_angle(r.randf() * TAU) * TILE_RADIUS * r.randf_range(0.2, 0.6)
	return {"edge": edge, "cracks": cracks, "moss": moss, "ember": ember, "rot": rot}


## Tile look per map: [side dark, side lit, top dark, top lit, moss dark, moss lit].
const SLAB_LOOK := {
	"road": ["#2e2725", "#6b5b4f", "#463c37", "#93806f", "#3e4a22", "#6d7d34"],   # warm fieldstone
	"cliff": ["#262a30", "#56606a", "#3a4048", "#8a939c", "#6b6a4c", "#aaa77a"],  # cold slate, pale lichen
	"hill": ["#2b2a22", "#5b5844", "#3d3c2f", "#837d5f", "#3d5222", "#73923a"],   # weathered, mossy
	"lake": ["#272624", "#5c5650", "#3b3936", "#8c8379", "#34472a", "#5f7a3e"],   # damp river stone
	"chapel": ["#26252b", "#5e5a64", "#38363e", "#8a8590", "#2c2f38", "#4c5468"],  # worn grey marble, dusty
	"swamp": ["#22241f", "#4e5148", "#33362f", "#74776a", "#2c3a22", "#55693a"],  # grey bog stone, thick moss
	"dock": ["#2a1d14", "#5e4430", "#3e2b1d", "#8a6644", "", ""],                # wooden decking
}


func _draw_slab(i: int, w: Vector2, lit: float) -> void:
	if _slabs.size() != tiles.size():
		_slabs.clear()
		for k in tiles.size():
			_slabs.append(_slab_shape(k))
	var S: Dictionary = _slabs[i]
	var up := Vector2(0, -2.0 * view_scale)
	var side := PackedVector2Array()
	var top := PackedVector2Array()
	var shadow := PackedVector2Array()
	for e in S["edge"]:
		var q := proj(w + e)
		side.append(q)
		shadow.append(q + Vector2(2.0, 5.0) * view_scale)
		top.append(proj(w + e * 0.86) + up)
	var deck := _is_dock_tile(i)
	var look: Array = SLAB_LOOK["dock"] if deck else SLAB_LOOK.get(stop, SLAB_LOOK["road"])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	draw_colored_polygon(side, Color(look[0]).lerp(Color(look[1]), lit))
	draw_colored_polygon(top, Color(look[2]).lerp(Color(look[3]), lit))
	if deck:
		_draw_planks(S, w, up, lit)
		return
	var hi := PackedVector2Array()   # a paler worn patch on the top face
	for e in S["edge"]:
		hi.append(proj(w + e * 0.5 + Vector2(-6, -4)) + up)
	draw_colored_polygon(hi, Color(1, 0.95, 0.85, 0.07 * lit))
	var crack_c := Color("#241d1a", 0.75)
	for L in S["cracks"]:
		var pts := PackedVector2Array()
		for e in L:
			pts.append(proj(w + e) + up)
		draw_polyline(pts, crack_c, 1.4 * view_scale, true)
	for m in S["moss"]:
		var mc := Color(look[4]).lerp(Color(look[5]), lit)
		_ellipse_xy(proj(w + m[0]) + up, m[1] * view_scale, m[1] * view_scale * K, mc)
	if S["ember"] != null:
		var ec := Color("#ff8a3a", 0.5 + 0.35 * sin(_t * 2.3 + i))
		draw_circle(proj(w + S["ember"]) + up, 1.8 * view_scale, ec)


## The dock's tile is built first, so it is tile 0.
func _is_dock_tile(i: int) -> bool:
	return i == 0 and stop == "lake" and not dock.is_empty()


## The dock's tile is a little wooden deck: planks with dark seams and nails.
func _draw_planks(S: Dictionary, w: Vector2, up: Vector2, lit: float) -> void:
	var poly := PackedVector2Array()
	for e in S["edge"]:
		poly.append(e * 0.86)
	var u := Vector2.from_angle(S["rot"])
	var v := u.orthogonal()
	var seam := Color("#1c130c", 0.8)
	var nail := Color("#c8b9a0", 0.5 * lit + 0.15)
	var k := 0
	var t := -TILE_RADIUS
	while t <= TILE_RADIUS:
		var cut := PackedVector2Array([v * t - u * TILE_RADIUS * 1.2, v * t + u * TILE_RADIUS * 1.2])
		for seg in Geometry2D.intersect_polyline_with_polygon(cut, poly):
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[seg.size() - 1]
			draw_line(proj(w + a) + up, proj(w + b) + up, seam, 1.6 * view_scale, true)
			if k % 2 == 0:   # nails along the plank's ends, just inside the seam
				for q in [a.lerp(b, 0.12), b.lerp(a, 0.12)]:
					draw_circle(proj(w + q + v * 6.0) + up, 1.3 * view_scale, nail)
		# a lighter grain streak on every other plank
		if k % 2 == 1:
			var g := PackedVector2Array([v * (t - 7.0) - u * TILE_RADIUS * 1.2, v * (t - 7.0) + u * TILE_RADIUS * 1.2])
			for seg in Geometry2D.intersect_polyline_with_polygon(g, poly):
				draw_line(proj(w + seg[0] * 0.9) + up, proj(w + seg[seg.size() - 1] * 0.9) + up,
					Color(1, 0.9, 0.7, 0.07 * lit), 2.0 * view_scale, true)
		t += 15.0
		k += 1
	if S["ember"] != null:
		draw_circle(proj(w + S["ember"]) + up, 1.8 * view_scale, Color("#ff8a3a", 0.5 + 0.35 * sin(_t * 2.3)))


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
	return Defs.DEFENSES[face][mini(lvl, 2)]["range"] * guide_boost_at(i, face).get("boost", 1.0)


## The best Guide Light boost a `face` defense on tile i would get from the
## rest of its group ({} if none). The tile being moved off doesn't count.
func guide_boost_at(i: int, face: String) -> Dictionary:
	if face in Defs.SUPPORT_FACES or i < 0 or i >= tile_group.size():
		return {}
	var best := {}
	for j in tiles.size():
		var o = tile_defense[j]
		if j == i or j == lift_tile or o == null or o.kind != "guide" or tile_group[j] != tile_group[i]:
			continue
		var g: Dictionary = Defs.DEFENSES["guide"][o.level - 1]
		if best.is_empty() or g["boost"] > best["boost"]:
			best = g
	return best


func _ellipse(c: Vector2, r: float, col: Color) -> void:
	# On the hill a ring round the summit sits at one height: shift it down by it.
	_ellipse_xy(proj(c) + Vector2(0, _drop(c.length() + r) - _drop(c.length())) * view_scale, r * view_scale, r * view_scale * K, col)


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
