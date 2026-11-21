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
	var g := guide_bonus()
	if not g.is_empty():
		st["range"] *= g["boost"]
		if st.has("min"):
			st["min"] *= g["min_mult"]
		if st.has("damage"):
			st["damage"] += Run.face_mod("guide", "group_damage")
	return st


## The best Guide Light on a neighbouring tile ({} if none). Guides don't
## boost each other.
func guide_bonus() -> Dictionary:
	if kind == "guide":
		return {}
	var best := {}
	for o in battle.defenses:
		if o == self or o.kind != "guide" or o.tile / 3 != tile / 3:
			continue
		var g: Dictionary = Defs.DEFENSES["guide"][o.level - 1]
		if best.is_empty() or g["boost"] > best["boost"]:
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
					battle.shoot(world, Vector2(0, -46.0 * board.view_scale * _scale()), target, st["damage"], "torch")
					_cool = 1.0 / st["rate"]
		"vent":
			_cool -= delta
			if _cool <= 0.0:
				var near: Array = battle.spirits_in_range(world, st["range"])
				if not near.is_empty():
					for sp in near:
						sp.hit(st["damage"])
					battle.ring_fx(world, st["range"], Color("#cfeee9"))
					_puff = 1.0
					_cool = 1.0 / st["rate"]
		"mortar":
			_cool -= delta
			if _cool <= 0.0:
				var target = battle.pick_rear_target(world, st["min"], st["range"])
				if target:
					battle.shoot(world, Vector2(0, -30.0 * board.view_scale * _scale()), target, st["damage"], "mortar", st["splash"])
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
		_:
			draw_rect(Rect2(-4 * v, -40 * v, 8 * v, 42 * v), wood)
