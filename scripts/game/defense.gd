extends Node2D
## A defense built from a die on a tile. Placing another die with the same
## face on it raises its level (max Defs.MAX_LEVEL).
##
## To add a defense kind:
##   1. Add its stats to Defs.DEFENSES and its face to Defs.DIE_FACES / FACE_INFO,
##      then put the face on a die (Defs.STARTER_DIE or a new die).
##   2. Add its behaviour to _act() and its look to _draw_kind() below.
## Helpers on the battle: pick_target(world, range), shoot(...),
## spirits_in_range(world, range), ring_fx(...). A "slow" stat is applied by the
## battle automatically.

const Defs := preload("res://scripts/game/defs.gd")

var kind := ""
var level := 1
var tile := -1
var world := Vector2.ZERO
var _dimmed := 0.0   ## 0..1, eased: how dimmed by a Dark Wisp this looks
var _snuffed := 0.0  ## seconds left snuffed out by the Lantern Thief (can't fire)
var battle            ## the Battle node (targets, projectiles, passives)
var board

var _cool := 0.0
var _t := 0.0
var _pop := 0.0        ## build / level-up bounce
var _puff := 0.0       ## steam vent: 1 right after a puff, fades to 0


func setup(b, bd, k: String, tile_idx: int) -> void:
	battle = b
	board = bd
	kind = k
	tile = tile_idx
	world = board.tiles[tile_idx]
	position = board.proj(world)
	_pop = 1.0
	_cool = Run.rng.randf_range(0.1, 0.5)


## Oath of Shifting Embers: picked up and set down on another tile.
func move_to(tile_idx: int) -> void:
	tile = tile_idx
	world = board.tiles[tile_idx]
	position = board.proj(world)
	_pop = 1.0


func level_up() -> void:
	level = mini(level + 1, Defs.MAX_LEVEL)
	_pop = 1.0


## This defense's stats at its current level (passives can adjust them here).
func stats() -> Dictionary:
	var st: Dictionary = Defs.DEFENSES[kind][level - 1].duplicate()
	for stat in st:
		if typeof(st[stat]) in [TYPE_FLOAT, TYPE_INT]:
			st[stat] += Run.face_mod(kind, stat)
	if kind == "torch" and battle.pine_logs > 0:   # Pine Logs on the fire this wave
		st["range"] *= 1.0 + Defs.PINE_TORCH_RANGE * battle.pine_logs
	if kind == "torch" and Run.has_oath("gathered_flame"):
		st["damage"] += Run.owned(Defs.GATHERED_FLAME_DIE)
	if kind == "mortar" and Run.has_oath("crossfire"):
		st["damage"] += Defs.CROSSFIRE_MORTAR
	if kind == "mortar" and Run.has_oath("decimation"):
		var vents := 0
		for o in battle.defenses:
			if is_instance_valid(o) and o.kind == "vent":
				vents += o.level
		st["min"] *= 1.0 - minf(Defs.DECIMATION_CAP, Defs.DECIMATION_PER_VENT * vents)
	if st.has("slow"):
		st["slow"] = minf(st["slow"], Defs.SLOW_CAP)
	if st.has("rate") and kind in Defs.LIGHT_DEFENSES:   # a Dark Wisp's dimming
		st["rate"] *= 1.0 - battle.dim_at(world)
	if battle.banked > 0.0 and st.has("damage"):   # Oath of the Banked Fire
		st["damage"] *= 1.0 + battle.banked
	if battle.stoked and st.has("rate"):   # lull reward: Stoke
		st["rate"] *= Defs.STOKE_RATE
	var bw := group_best("bellows", "haste")
	if not bw.is_empty() and st.has("rate"):
		st["rate"] *= bw["haste"]
	var br := group_best("brazier", "burn_dps")
	if not br.is_empty():
		st["burn"] = Vector2(br["burn_dps"], br["burn_t"])
	var g := guide_bonus()
	if not g.is_empty():
		st["range"] *= g["boost"]
		if st.has("min"):
			st["min"] *= g["min_mult"]
		if st.has("damage"):
			st["damage"] += Run.face_mod("guide", "group_damage")
	return st


## The best Guide Light elsewhere in this tile's group ({} if none). Guides don't
## boost each other.
func guide_bonus() -> Dictionary:
	return group_best("guide", "boost")


## The best `src` support (Guide Light, Bellows) elsewhere in this tile's
## group, compared by `key` ({} if none). Supports don't boost each other.
func group_best(src: String, key: String) -> Dictionary:
	if kind in Defs.SUPPORT_FACES:
		return {}
	var best := {}
	for o in battle.defenses:
		if o == self or o.kind != src or board.tile_group[o.tile] != board.tile_group[tile]:
			continue
		var g: Dictionary = Defs.DEFENSES[src][o.level - 1]
		if best.is_empty() or g[key] > best[key]:
			best = g
	return best


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 3.0)
	_puff = maxf(0.0, _puff - delta * 1.5)
	# Dimmed by a Dark Wisp: fade to a cold, dark purple-grey while inside his circle.
	var was := _snuffed
	_snuffed = maxf(0.0, _snuffed - delta)
	if was > 0.0 and _snuffed == 0.0:
		_pop = 0.6   # relit
	var dimmed: float = 1.0 if _snuffed > 0.0 or kind in Defs.LIGHT_DEFENSES and battle.dim_at(world) > 0.0 else 0.0
	_dimmed = move_toward(_dimmed, dimmed, delta * 3.0)
	modulate = Color.WHITE.lerp(Color(0.42, 0.38, 0.58), _dimmed)
	queue_redraw()
	if battle.fighting and _snuffed <= 0.0:
		_act(delta, stats())


## The Lantern Thief dashes past: no firing for t seconds.
func snuff(t: float) -> void:
	if _snuffed <= 0.0:
		_puff = 1.0
		AudioDirector.play_sfx("snuff", -9.0)
	_snuffed = maxf(_snuffed, t)


## Per-kind behaviour while a wave is on.
func _act(delta: float, st: Dictionary) -> void:
	match kind:
		"torch":
			_cool -= delta
			if _cool <= 0.0:
				var target = battle.pick_target(world, st["range"])
				if target:
					battle.shoot(world, Vector2(0, -46.0 * board.view_scale * _scale()), target, st["damage"], "torch", 0.0, st.get("burn", Vector2.ZERO))
					_cool = 1.0 / st["rate"]
		"vent":
			_cool -= delta
			if _cool <= 0.0:
				var near: Array = battle.spirits_in_range(world, st["range"])
				if not near.is_empty():
					for sp in near:
						sp.hit(st["damage"])
						var bn: Vector2 = st.get("burn", Vector2.ZERO)
						sp.ignite(bn.x, bn.y)
					battle.ring_fx(world, st["range"], Color("#cfeee9"))
					_puff = 1.0
					_cool = 1.0 / st["rate"]
		"mortar":
			_cool -= delta
			if _cool <= 0.0:
				var target = battle.pick_rear_target(world, st["min"], st["range"])
				if target:
					battle.shoot(world, Vector2(0, -30.0 * board.view_scale * _scale()), target, st["damage"], "mortar", st["splash"], st.get("burn", Vector2.ZERO))
					_puff = 1.0
					_cool = 1.0 / st["rate"]


func _scale() -> float:
	return (0.9 + 0.12 * level) * (1.0 + 0.25 * sin(_pop * PI))


func _draw() -> void:
	var v: float = board.view_scale * _scale()
	var lit: float = maxf(board.light_at(world), 0.4)
	_draw_kind(v, lit)
	# Level pips on the slab.
	for i in level:
		var x: float = (i - (level - 1) / 2.0) * 10.0 * board.view_scale
		draw_circle(Vector2(x, 12.0 * board.view_scale), 3.2 * board.view_scale, Color("#ffb238"))


## Per-kind look. Until a kind has art, it shows as a plain marker post.
func _draw_kind(v: float, lit: float) -> void:
	var wood := Color("#3b2416").lerp(Color("#8b5a3a"), lit)
	match kind:
		"torch":
			# Post, iron cup and a flickering flame that grows with level.
			draw_rect(Rect2(-3.5 * v, -36 * v, 7 * v, 38 * v), wood)
			draw_rect(Rect2(-7 * v, -40 * v, 14 * v, 5 * v), Color("#4a4038"))
			var f := 1.0 + 0.08 * sin(_t * 11.0) + 0.05 * sin(_t * 17.0)
			var h := (12.0 + 3.0 * level) * v * f
			var sway := 1.5 * v * sin(_t * 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-6 * v, -40 * v), Vector2(sway, -40 * v - h * 1.6), Vector2(6 * v, -40 * v)]), Color("#ff7a1e"))
			draw_colored_polygon(PackedVector2Array([Vector2(-3 * v, -40 * v), Vector2(sway * 0.6, -40 * v - h), Vector2(3 * v, -40 * v)]), Color("#ffe27a"))
		"vent":
			# Brass boiler with a pressure gauge and a chimney; steam after a puff.
			var brass := Color("#5a4220").lerp(Color("#c9973f"), lit)
			draw_rect(Rect2(-11 * v, -26 * v, 22 * v, 28 * v), brass)
			draw_rect(Rect2(-11 * v, -28 * v, 22 * v, 3 * v), brass.darkened(0.3))
			draw_rect(Rect2(3 * v, -42 * v, 6 * v, 15 * v), Color("#4a4038"))
			draw_circle(Vector2(-3 * v, -13 * v), 5 * v, Color("#e8e2d0"))
			var a := -PI * 0.75 + PI * 1.5 * (0.3 + 0.7 * _puff)
			draw_line(Vector2(-3 * v, -13 * v), Vector2(-3 * v, -13 * v) + Vector2.from_angle(a) * 4 * v, Color("#a02a1a"), 1.2 * v)
			for k in 3:
				var age := fmod(_t * 0.6 + k / 3.0, 1.0)
				var alpha := 0.15 + 0.55 * _puff
				var r := (3.0 + 6.0 * age + 2.0 * level) * v
				draw_circle(Vector2(6 * v + 4 * v * sin(_t * 2.0 + k), -44 * v - 22 * v * age), r, Color(0.92, 0.96, 0.95, alpha * (1.0 - age)))
		"mortar":
			# Wooden block with a fat iron barrel angled up; recoils and glows after a shot.
			var iron := Color("#4a4440").lerp(Color("#9a8f86"), lit)
			draw_rect(Rect2(-14 * v, -10 * v, 28 * v, 12 * v), wood)
			draw_rect(Rect2(-14 * v, -10 * v, 28 * v, 2.5 * v), wood.lightened(0.2))
			var kick := 3.0 * v * _puff
			var dir := Vector2(0.55, -1.0).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var base := Vector2(-2 * v, -10 * v + kick)
			var w := (8.0 + level) * v
			var tip := base + dir * (22.0 + 2.0 * level) * v
			draw_colored_polygon(PackedVector2Array([base - nrm * w, tip - nrm * w * 1.15, tip + nrm * w * 1.15, base + nrm * w]), iron)
			draw_line(base - nrm * w * 0.6 + dir * 6 * v, tip - nrm * w * 0.8, iron.lightened(0.35), 2.0 * v)
			draw_circle(base, w, iron.darkened(0.15))
			draw_circle(tip, w * 1.15, iron.darkened(0.45))
			draw_circle(tip, w * 0.75, Color("#ff7a1e").lerp(Color("#5a2410"), 0.7 - 0.7 * _puff))
		"guide":
			# Tall pole with a hanging lantern and a soft halo.
			draw_rect(Rect2(-2.5 * v, -54 * v, 5 * v, 56 * v), wood)
			draw_line(Vector2(0, -54 * v), Vector2(9 * v, -54 * v), wood, 3 * v)
			var lp := Vector2(9 * v, -44 * v)
			var f := 1.0 + 0.06 * sin(_t * 4.0)
			draw_circle(lp, (16.0 + 4.0 * level) * v * f, Color(1.0, 0.92, 0.6, 0.12))
			draw_rect(Rect2(lp + Vector2(-5 * v, -7 * v), Vector2(10 * v, 13 * v)), Color("#4a4038"))
			draw_rect(Rect2(lp + Vector2(-3.5 * v, -5 * v), Vector2(7 * v, 9 * v)), Color("#ffe9a8"))
		"brazier":
			# An iron bowl on three legs, heaped with glowing coals and
			# flickering flames that grow with its level.
			var iron := Color("#3a3330")
			for lx in [-11.0, 0.0, 11.0]:
				draw_line(Vector2(lx * 0.6 * v, -18 * v), Vector2(lx * v, 2 * v), iron, 2.5 * v)
			var bowl := PackedVector2Array()
			for k in 9:
				var a := PI * k / 8.0
				bowl.append(Vector2(cos(a) * 15 * v, -20 * v + sin(a) * 8 * v))
			draw_colored_polygon(bowl, iron)
			var rim := PackedVector2Array()
			for k in 16:
				rim.append(Vector2(cos(TAU * k / 16.0) * 15 * v, -20 * v + sin(TAU * k / 16.0) * 5 * v))
			draw_colored_polygon(rim, Color("#5a2410"))
			for k in 6:   # coals
				var cx := (-10.0 + k * 4.0) * v
				var glow := 0.6 + 0.4 * sin(_t * 3.0 + k * 1.3)
				draw_circle(Vector2(cx, -21 * v + (k % 2) * 2 * v), 2.6 * v, Color("#ff5a1e").lerp(Color("#ffc46a"), glow * 0.6))
			var fh := (10.0 + 4.0 * level) * v
			for k in 3:   # flames
				var fx := (-6.0 + k * 6.0) * v
				var h := fh * (0.75 + 0.25 * sin(_t * 7.0 + k * 2.1)) * (1.0 if k == 1 else 0.7)
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 4 * v, -22 * v), Vector2(fx, -22 * v - h), Vector2(fx + 4 * v, -22 * v)]),
					Color(1.0, 0.55 + 0.15 * k, 0.15, 0.85))
			draw_circle(Vector2(0, -24 * v), (18.0 + 3.0 * level) * v, Color(1.0, 0.5, 0.2, 0.08))
		"bellows":
			# Two hinged boards with a leather middle on a little stand,
			# pumping (fast while a wave is on) toward an iron nozzle.
			var u := v * 1.75
			var pump := 0.5 + 0.5 * sin(_t * (9.0 if battle.fighting else 2.0))
			var leather := Color("#3f271a")
			draw_rect(Rect2(-12 * u, -14 * u, 3 * u, 16 * u), wood)
			draw_rect(Rect2(9 * u, -14 * u, 3 * u, 16 * u), wood)
			var hinge := Vector2(13 * u, -20 * u)
			var back := Vector2(-15 * u, -20 * u)
			var open_ := (4.0 + 6.0 * pump) * u
			var top := PackedVector2Array([hinge, back + Vector2(0, -open_), back + Vector2(0, -open_ - 3 * u), hinge + Vector2(0, -3 * u)])
			var bot := PackedVector2Array([hinge, back + Vector2(0, open_ * 0.4), back + Vector2(0, open_ * 0.4 + 3 * u), hinge + Vector2(0, 3 * u)])
			# The leather accordion: pleats that bulge out at the back and
			# alternate lit / shadowed faces, outlined dark.
			var pleats := 5
			var outline := PackedVector2Array([hinge])
			for k in range(pleats, -1, -1):
				var f := float(k) / pleats * 0.62
				var x := lerpf(back.x, hinge.x, f)
				var h := lerpf(open_, 0.0, f) + (1.6 * u if k % 2 == 0 else -0.4 * u)
				outline.append(Vector2(x - (1.5 * u if k % 2 == 0 else 0.0), back.y - h))
			for k in range(0, pleats + 1):
				var f := float(k) / pleats * 0.62
				var x := lerpf(back.x, hinge.x, f)
				var h := lerpf(open_ * 0.4, 0.0, f) + (1.0 * u if k % 2 == 0 else -0.3 * u)
				outline.append(Vector2(x - (1.5 * u if k % 2 == 0 else 0.0), back.y + h))
			draw_colored_polygon(outline, leather)
			for k in pleats:
				var f0 := float(k) / pleats * 0.62
				var f1 := float(k + 1) / pleats * 0.62
				var x0 := lerpf(back.x, hinge.x, f0)
				var x1 := lerpf(back.x, hinge.x, f1)
				var h0 := lerpf(open_, 0.0, f0)
				var h1 := lerpf(open_, 0.0, f1)
				var face := PackedVector2Array([Vector2(x0, back.y - h0), Vector2(x1, back.y - h1),
					Vector2(x1, back.y + h1 * 0.4), Vector2(x0, back.y + h0 * 0.4)])
				draw_colored_polygon(face, leather.lightened(0.18) if k % 2 == 0 else leather.darkened(0.3))
				draw_line(Vector2(x0, back.y - h0), Vector2(x0, back.y + h0 * 0.4), Color("#1a0f09"), 1.0 * u)
			draw_polyline(outline + PackedVector2Array([outline[0]]), Color("#1a0f09"), 1.2 * u, true)
			draw_colored_polygon(top, wood.lightened(0.1))
			draw_colored_polygon(bot, wood.darkened(0.1))
			draw_line(back + Vector2(0, -open_ - 1.5 * u), back + Vector2(-7 * u, -open_ - 5 * u), wood, 2.5 * u)   # handle
			draw_rect(Rect2(hinge + Vector2(0, -2 * u), Vector2(7 * u, 4 * u)), Color("#4a4038"))   # nozzle
			for k in level - 1:   # brass bands per level
				var x := lerpf(back.x, hinge.x, 0.55 + 0.15 * k)
				draw_line(Vector2(x, back.y - open_ * 0.5 - 2 * u), Vector2(x, back.y - open_ * 0.5 + 1 * u), Color("#d9b45a"), 2.0 * u)
			if battle.fighting and pump < 0.3:   # a puff of air
				draw_circle(hinge + Vector2(12 * u, 0), (2.0 + 3.0 * (0.3 - pump) * 10.0) * u, Color(1, 0.9, 0.75, 0.18))
		_:
			draw_rect(Rect2(-4 * v, -40 * v, 8 * v, 42 * v), wood)
