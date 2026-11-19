extends Control
## One night at camp: 3 waves. Before each wave you roll dice and place them;
## then spirits drift out of the dark along the trails and the defenses and
## Char fight them off. Ends with night_over(true) at dawn, or
## night_over(false) if Char's flame goes out.
##
## Controls (touch, mouse and keyboard all work):
##   tap/click a die      hold it (kept on reroll) and select it for placing
##   tap/click a tile     place the selected die there
##   drag a die           place it directly on a tile (★ dice go on the fire)
##   Roll / Space         reroll every die that isn't held
##   Fight! / Enter       start the wave (also starts once every die is placed)
##   1-4                  same as tapping die 1-4;  Esc  pause / back

signal night_over(survived: bool)
signal save_and_quit
signal abandoned
signal oaths_requested

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const EssenceTracker := preload("res://scripts/ui/essence_tracker.gd")
const VolumeSliders := preload("res://scripts/ui/volume_sliders.gd")
const Board := preload("res://scripts/game/board.gd")
const Spirit := preload("res://scripts/game/spirit.gd")
const Defense := preload("res://scripts/game/defense.gd")
const CharUnit := preload("res://scripts/game/char_unit.gd")
const Projectile := preload("res://scripts/game/projectile.gd")
const Fx := preload("res://scripts/game/fx.gd")
const DieView := preload("res://scripts/game/die_view.gd")
const Campfire := preload("res://scripts/title/campfire.gd")
const CampProp := preload("res://scripts/game/camp_prop.gd")
const FlameBar := preload("res://scripts/game/flame_bar.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

enum Phase { PREP, FIGHT, DONE }

var phase := Phase.PREP
var fighting := false
var wave := 0
var spirits: Array = []
var defenses: Array = []

var board
var char_unit
var _world := Node2D.new()
var _entities := Node2D.new()
var _fx := Node2D.new()
var _campfire
var ambush := false      ## Fog Cloud ambush: one wave of Mist Wisps in the mist
var mod := ""            ## this wave's modifier (Defs.WAVE_MODS id) or ""
var _swarm_lane := -1
var _gates_left := 0       ## gates Char can still cobble tonight
var _ap_gate_t := 0.0
var _mark_t := 0.0
var _props: Array = []   ## the stagecoach and horse Char is guarding
var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _dice: Array = []
var _rerolls := 0
var _selected = null
var _drag_die = null
var _drag_pos := Vector2.ZERO
var _ghost: Control
var _hover := -1
var _auto_begin := -1.0
var _ap_timer := 1.2
var _shift_ready := false  ## Oath of Shifting Embers: a move is available this prep
var _lifted = null         ## the defense being moved, or null

# HUD
var _flame_bar
var _night_label: Label
var _wave_label: Label
var _banner: Label
var _hint: Label
var _tray: HBoxContainer
var _roll_btn: Button
var _fight_btn: Button
var _speed_btn: Button
var _pause_card: PanelContainer
var _dim: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()

	board = Board.new()
	board.layout_seed = Run.layout_seed
	board.stop = Run.current_stop()
	board.spirits_ref = spirits   # the lake draws their reflections
	_world.add_child(board)
	_entities.y_sort_enabled = true
	_world.add_child(_entities)
	_world.add_child(_fx)
	add_child(_world)
	if ambush:   # the camp sits in the fog
		var mist := ColorRect.new()
		mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mist.color = Color(0.72, 0.8, 0.95, 0.16)
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mist)

	_campfire = Campfire.new()
	_entities.add_child(_campfire)
	for p in [["stagecoach", Vector2(10, -66)], ["horse", Vector2(94, 26)]]:
		var prop := CampProp.new()
		prop.setup(p[0], p[1], board)
		_entities.add_child(prop)
		_props.append(prop)
	char_unit = CharUnit.new()
	_entities.add_child(char_unit)
	char_unit.setup(self, board)

	_build_hud()
	resized.connect(_layout)
	_layout()

	_start_prep.call_deferred()


func _exit_tree() -> void:
	AudioDirector.set_tension(false)
	Engine.time_scale = 1.0


# ------------------------------------------------------------ layout
func _layout() -> void:
	var s := size
	var top := 78.0
	var tray_h := 150.0
	var avail_h := s.y - top - tray_h
	var fit: Vector2 = Board.VIEW_FIT_HILL if board.stop == "hill" else Board.VIEW_FIT
	board.view_scale = clampf(minf(s.x * 0.5 / fit.x, avail_h * 0.5 / (fit.y * Board.K)), 0.6, 1.35)
	_world.position = Vector2(s.x / 2, top + avail_h * 0.5 + 6.0)
	_campfire.scale = Vector2.ONE * 0.36 * board.view_scale
	_campfire.position = board.proj(Vector2.ZERO)
	char_unit.position = board.proj(char_unit.world)
	for p in _props:
		p.position = board.proj(p.world)
	for d in defenses:
		d.position = board.proj(d.world)
	if _tray:
		_tray.reset_size()
		_tray.position = Vector2((s.x - _tray.size.x) / 2, s.y - _tray.size.y - 12)
		_hint.size = Vector2(s.x, 30)
		_hint.position = Vector2(0, _tray.position.y - 34)
		_banner.size = Vector2(s.x, 80)
		_banner.position = Vector2(0, s.y * 0.2)
	if _pause_card:
		_pause_card.reset_size()
		_pause_card.position = (s - _pause_card.size) / 2
		_dim.size = s


# ------------------------------------------------------------ phases
func _start_prep() -> void:
	phase = Phase.PREP
	if wave == 0:
		_gates_left = Run.gates if Defs.has_forks(Run.current_stop()) else 0
	fighting = false
	char_unit.set_mood("open")
	_rerolls = Defs.REROLLS_PER_WAVE + Run.bonus_rerolls
	var n: int = Run.dice.size()
	for d in _dice:
		d.queue_free()
	_dice.clear()
	for i in n:
		var d := DieView.new()
		d.index = i
		d.faces = Run.dice[i]
		d.tapped.connect(_on_die_tapped)
		d.drag_started.connect(_on_drag_started)
		d.drag_moved.connect(_on_drag_moved)
		d.drag_ended.connect(_on_drag_ended)
		_tray.add_child(d)
		_tray.move_child(d, i)
		_dice.append(d)
	_select(null)
	_lifted = null
	_shift_ready = wave > 0 and Run.has_oath("shifting_embers") and not defenses.is_empty()
	_roll(true)
	mod = "" if ambush else Defs.roll_wave_mod(Run.night, Run.rng)
	_swarm_lane = Run.rng.randi() % board.lane_count if mod == "swarmy" else -1
	_update_hud()
	if ambush:
		_show_banner("Ambush in the fog!")
	elif mod != "":
		_show_banner("Wave %d of %d  ·  %s!" % [wave + 1, Defs.WAVES_PER_NIGHT, Defs.WAVE_MODS[mod]["name"]])
	else:
		_show_banner("Wave %d of %d" % [wave + 1, Defs.WAVES_PER_NIGHT])
	if Run.night == 0 and wave == 0:
		_hint.text = "Tap a die to hold it, then tap a glowing tile.  Or drag it there.  Star dice go on the fire."
	elif mod != "":
		_hint.text = "%s: %s  Place your dice, then Fight!" % [Defs.WAVE_MODS[mod]["name"], Defs.WAVE_MODS[mod]["desc"]]
	else:
		_hint.text = "Place your dice, then Fight!"
	if _gates_left > 0 and not board.links.is_empty():
		_hint.text += "   Tap a glowing fork to cobble a gate (%d left)." % _gates_left
	if _shift_ready:
		_hint.text += "   Tap a defense to move it (−%d flame)." % roundi(Defs.SHIFT_COST)
	_layout.call_deferred()


func _roll(first := false) -> void:
	var any := false
	for d in _dice:
		if d.placed or (d.held and not first):
			continue
		d.roll(Run.rng.randi() % d.faces.size(), 0.45 + 0.12 * d.index)
		any = true
	if any:
		AudioDirector.play_sfx("dice_roll", -3.0)
	if not first:
		_rerolls -= 1
	_update_hud()


func reroll() -> void:
	if phase != Phase.PREP or _rerolls <= 0 or _any_rolling():
		return
	var can := false
	for d in _dice:
		if not d.placed and not d.held:
			can = true
	if can:
		_roll()


func begin_wave() -> void:
	if phase != Phase.PREP:
		return
	phase = Phase.FIGHT
	fighting = true
	_auto_begin = -1.0
	_select(null)
	_drop_lift()
	_shift_ready = false
	for d in _dice:
		if not d.placed:
			d.placed = true  # unused dice fade back into the bag
	var kinds: Array = Defs.ambush_spirits(Run.night) if ambush else Defs.wave_spirits(Run.night, wave, Run.current_stop(), Run.rng)
	# Each queue entry: [kind, lane (-1 = random), hearty]
	_spawn_queue = []
	for k in kinds:
		var lane := _swarm_lane if mod == "swarmy" and Run.rng.randf() < Defs.SWARM_SHARE else -1
		var hearty: bool = mod == "hearty" and Run.rng.randf() < Defs.HEARTY_SHARE
		_spawn_queue.append([k, lane, hearty])
	_spawn_timer = 0.6
	if Run.autoplay and (ambush or mod != ""):
		print("  night %d wave %d: %s" % [Run.night + 1, wave + 1, "fog ambush" if ambush else mod])
	char_unit.set_mood("determined")
	_hint.text = ""
	_show_banner("Here they come!")
	AudioDirector.play_sfx("wave", -4.0)
	AudioDirector.set_tension(true)
	_update_hud()


func _wave_cleared() -> void:
	if Run.autoplay:
		var desc := []
		for d in defenses:
			desc.append("%s%d@%d" % [d.kind, d.level, d.tile])
		print("  night %d wave %d cleared  flame=%d  char_kindle=%d  defenses=%s" % [Run.night + 1, wave + 1, roundi(Run.flame), char_unit.kindle, desc])
	fighting = false
	AudioDirector.set_tension(false)
	wave += 1
	if ambush:
		phase = Phase.DONE
		char_unit.set_mood("happy")
		_show_banner("The mist lifts  ·  +%d flame" % roundi(Defs.CAMP_HEAL))
		AudioDirector.play_sfx("chime", -2.0)
		get_tree().create_timer(2.0).timeout.connect(func(): night_over.emit(true))
	elif wave >= Defs.WAVES_PER_NIGHT:
		phase = Phase.DONE
		Run.nights_survived += 1
		char_unit.set_mood("happy")
		var gained := Defs.essence_for_night(Run.flame, Run.night)
		Profile.add_essence(gained)
		_show_banner("Dawn breaks!  +%d Essence" % gained)
		AudioDirector.play_sfx("chime", -2.0)
		get_tree().create_timer(2.0).timeout.connect(func(): night_over.emit(true))
	else:
		_show_banner("Wave cleared")
		get_tree().create_timer(1.1).timeout.connect(_start_prep)


func _flame_out() -> void:
	phase = Phase.DONE
	fighting = false
	AudioDirector.set_tension(false)
	char_unit.set_mood("hurt")
	Profile.add_essence(Defs.essence_for_lost_night(Run.night))
	_show_banner("Char's flame went out...")
	get_tree().create_timer(2.2).timeout.connect(func(): night_over.emit(false))


func _process(delta: float) -> void:
	# The board's light follows the campfire's flicker.
	board.fire_glow = 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.006) * sin(Time.get_ticks_msec() * 0.0017)
	board.hover_tile = _hover
	board.gates_left = _gates_left if phase == Phase.PREP else 0
	if Run.autoplay and phase == Phase.FIGHT:
		_autoplay_gates(delta)
	board.glow_face = _drag_die.face if _drag_die else (_selected.face if _selected else "")
	board.shift_glow = _shift_ready and _selected == null and _drag_die == null
	if _ghost:
		_ghost.queue_redraw()
	if _auto_begin > 0.0:
		_auto_begin -= delta
		if _auto_begin <= 0.0:
			begin_wave()
	if Run.autoplay and phase == Phase.PREP:
		_autoplay_step(delta)
	if _swarm_lane >= 0 and phase == Phase.PREP:   # point out the swarm trail
		_mark_t -= delta
		if _mark_t <= 0.0:
			_mark_t = 0.25
			var p = board.path_point(_swarm_lane, randf() * board.path_lengths[_swarm_lane] * 0.85)
			_add_fx("ring", p, Color("#ff8f6b"), 40.0)
	if not fighting:
		return
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var e: Array = _spawn_queue.pop_front()
			_spawn(e[0], e[1], e[2])
			_spawn_timer = Defs.spawn_gap(Run.night, wave) * Run.rng.randf_range(0.8, 1.2)
			if e[1] >= 0:
				_spawn_timer *= Defs.SWARM_GAP
	# Defenses with a "slow" stat slow spirits inside their reach (strongest wins).
	for sp in spirits:
		var slow := 0.0
		for d in defenses:
			var st: Dictionary = d.stats()
			if st.get("slow", 0.0) > 0.0 and d.world.distance_to(sp.world) <= st["range"]:
				slow = maxf(slow, st["slow"])
		sp.slow = slow
	# Mist Wisps near Char slow its attacks (strongest wins, no stacking).
	var chill := 0.0
	for sp in spirits:
		var r: float = Defs.SPIRITS[sp.kind].get("chill_range", 0.0)
		if r > 0.0 and not sp.dead and sp.world.distance_to(char_unit.world) <= r:
			chill = maxf(chill, Defs.SPIRITS[sp.kind]["chill"])
	char_unit.chill = chill
	if _spawn_queue.is_empty() and spirits.is_empty():
		_wave_cleared()


func _spawn(kind: String, lane := -1, hearty := false) -> void:
	var sp := Spirit.new()
	_entities.add_child(sp)
	if lane < 0:
		lane = Run.rng.randi() % board.lane_count
	var hp_scale := Defs.spirit_hp_scale(Run.night, Run.current_stop())
	if Run.shrine_curse:
		hp_scale *= Defs.SHRINE_CURSE_HP
	sp.setup(board, kind, lane, hp_scale * (Defs.HEARTY_HP if hearty else 1.0))
	if hearty:
		sp.size_k *= 1.2
	if mod == "angry":
		sp.speed *= Defs.ANGRY_SPEED
	if board.stop == "hill":
		sp.speed *= Defs.HILL_SPEED
	sp.banished.connect(_on_banished)
	sp.reached_fire.connect(_on_reached_fire)
	spirits.append(sp)


func _on_banished(sp) -> void:
	spirits.erase(sp)
	Run.spirits_banished += 1
	_add_fx("poof", sp.world, Color("#bfc8ff"))
	AudioDirector.play_sfx("pop", -6.0)


func _on_reached_fire(sp) -> void:
	spirits.erase(sp)
	if phase == Phase.DONE:
		return
	Run.flame = maxf(0.0, Run.flame - sp.damage)
	char_unit.hurt()
	_flame_bar.flash()
	_add_fx("ring", Vector2.ZERO, Color("#8fa0ff"), 110.0)
	AudioDirector.play_sfx("hurt", -2.0)
	_update_hud()
	if Run.flame <= 0.0:
		_flame_out()


# ------------------------------------------------------------ targeting (used by defenses & Char)
## The spirit in range that is closest to reaching the fire.
func pick_target(from: Vector2, rng: float):
	var best = null
	var best_p := -1.0
	for sp in spirits:
		if sp.dead:
			continue
		if sp.world.distance_to(from) <= rng and sp.progress() > best_p:
			best_p = sp.progress()
			best = sp
	return best


## Cinder Mortar: the spirit farthest back on its trail between lo and hi.
func pick_rear_target(from: Vector2, lo: float, hi: float):
	var best = null
	var best_p := 2.0
	for sp in spirits:
		if sp.dead:
			continue
		var d: float = sp.world.distance_to(from)
		if d >= lo and d <= hi and sp.progress() < best_p:
			best_p = sp.progress()
			best = sp
	return best


func spirits_in_range(at: Vector2, rng: float) -> Array:
	var out := []
	for sp in spirits:
		if not sp.dead and sp.world.distance_to(at) <= rng:
			out.append(sp)
	return out


func shoot(origin_world: Vector2, muzzle: Vector2, target, damage: float, style: String, splash := 0.0) -> void:
	var p := Projectile.new()
	_fx.add_child(p)
	p.setup(self, board, origin_world + Vector2(muzzle.x / board.view_scale, 0), -muzzle.y / board.view_scale, target, damage, style)
	p.splash = splash
	p.position = board.proj(p.world) + Vector2(0, muzzle.y)
	AudioDirector.play_sfx("bolt", -12.0 if style == "bolt" else -14.0)


func ring_fx(at: Vector2, r: float, col: Color) -> void:
	_add_fx("ring", at, col, r)


func spark_fx(at: Vector2, style: String) -> void:
	_add_fx("spark", at, Color("#ffb238") if style == "bolt" else Color("#ffd27a"))


func _add_fx(kind: String, at: Vector2, col: Color, r := 100.0, txt := "") -> void:
	var f := Fx.new()
	_fx.add_child(f)
	f.setup(board, kind, at, col, r, txt)


# ------------------------------------------------------------ dice placement
func _on_die_tapped(d) -> void:
	if phase != Phase.PREP:
		return
	AudioDirector.play_sfx("tap", -8.0)
	if d.held:
		d.held = false
		if _selected == d:
			_select(null)
			for o in _dice:
				if o.held and not o.placed:
					_select(o)
	else:
		d.held = true
		_select(d)
	_update_hud()


func _select(d) -> void:
	if d:
		_drop_lift()
	if _selected:
		_selected.selected = false
	_selected = d
	if d:
		d.selected = true
		var info: Dictionary = Defs.FACE_INFO[d.face]
		_hint.text = "%s: %s" % [info["name"], info["desc"]]


func _on_drag_started(d) -> void:
	if phase != Phase.PREP:
		return
	_drag_die = d
	_select(d)


func _on_drag_moved(_d, pos: Vector2) -> void:
	_drag_pos = pos
	_hover = _target_at(board.get_global_transform_with_canvas().affine_inverse() * pos, _drag_die.face if _drag_die else "")


func _on_drag_ended(d, pos: Vector2) -> void:
	_drag_die = null
	_hover = -1
	if phase != Phase.PREP:
		return
	var local: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * pos
	if not _try_place(d, local):
		_select(d if d.held else null)


## Tile index under a point, -2 for the fire (★ dice), -1 for nothing valid.
func _target_at(local: Vector2, face: String) -> int:
	if face == "kindle":
		return -2 if (board.is_fire_at(local) or char_unit.world.distance_to(board.unproj(local)) < 70.0) else -1
	var t: int = board.tile_at(local)
	return t if board.can_place(face, t) else -1


func _try_place(d, local: Vector2) -> bool:
	if d == null or d.placed or d.is_rolling():
		return false
	var target := _target_at(local, d.face)
	if target == -1:
		return false
	if target == -2:
		char_unit.kindle_up()
		Run.flame = minf(Run.max_flame, Run.flame + Run.kindle_heal())
		_add_fx("ring", Vector2.ZERO, Color("#fff0b0"), 130.0)
	else:
		_build_defense(d.face, target)
	d.placed = true
	d.held = false
	if _selected == d:
		_select(null)
	AudioDirector.play_sfx("place", -3.0)
	_hover = -1
	_update_hud()
	var all_placed := true
	for o in _dice:
		if not o.placed and o.face != "ashes":
			all_placed = false
	if all_placed:
		_auto_begin = 0.7
	return true


func _build_defense(face: String, tile: int) -> void:
	var existing = board.tile_defense[tile]
	if existing:
		existing.level_up()
		_add_fx("ring", existing.world, Color("#ffb238"), 60.0)
		return
	var df := Defense.new()
	_entities.add_child(df)
	df.setup(self, board, face, tile)
	board.tile_defense[tile] = df
	defenses.append(df)
	_add_fx("ring", df.world, Color("#ffb238"), 60.0)


# ------------------------------------------------------------ Oath of Shifting Embers
## Tap a defense to lift it, tap an empty tile to move it there (costs flame),
## tap it again to put it back.
func _try_shift(tile: int) -> bool:
	if tile < 0:
		return false
	if _lifted == null:
		var df = board.tile_defense[tile]
		if df == null:
			return false
		if Run.flame <= Defs.SHIFT_COST:
			_hint.text = "Char's flame is too low to move a defense."
			return true
		_lifted = df
		board.lift_tile = tile
		_hint.text = "Tap an empty glowing tile to move the %s there (−%d flame).  Tap it again to cancel." % [
			Defs.FACE_INFO[df.kind]["name"], roundi(Defs.SHIFT_COST)]
		AudioDirector.play_sfx("tap", -8.0)
		return true
	if tile == _lifted.tile:
		_drop_lift()
		_hint.text = "Tap a defense to move it (−%d flame)." % roundi(Defs.SHIFT_COST)
		return true
	if not board.can_move_to(tile):
		return false
	var df = _lifted
	_drop_lift()
	board.tile_defense[df.tile] = null
	board.tile_defense[tile] = df
	df.move_to(tile)
	Run.flame -= Defs.SHIFT_COST
	_shift_ready = false
	_add_fx("ring", df.world, Color("#ffb238"), 60.0)
	AudioDirector.play_sfx("place", -3.0)
	_hint.text = "Moved.  Place your dice, then Fight!"
	_update_hud()
	return true


func _drop_lift() -> void:
	_lifted = null
	board.lift_tile = -1


func _any_rolling() -> bool:
	for d in _dice:
		if d.is_rolling():
			return true
	return false


# ------------------------------------------------------------ autoplay
## A simple stand-in player: ★ on the fire, otherwise upgrade a matching
## defense or build on the nearest empty tile. With `--idle` it places
## nothing and just starts each wave.
func _autoplay_step(delta: float) -> void:
	if _any_rolling():
		return
	_ap_timer -= delta
	if _ap_timer > 0.0:
		return
	_ap_timer = 0.7
	if "--idle" in OS.get_cmdline_user_args():   # do nothing, just start waves
		begin_wave()
		return
	for i in board.links.size():
		if _gates_left > 0 and not board.links[i]["gate"]:
			_tap_fork(i)
			board.links[i]["cross"] = _fork_score(board.links[i]["path"]) > _fork_score(board.links[i]["from"])
			return
	for d in _dice:
		if d.placed or d.face == "ashes":
			continue
		if d.face == "kindle":
			_try_place(d, board.proj(Vector2.ZERO))
			return
		var best := -1
		for i in board.tiles.size():
			var t = board.tile_defense[i]
			if t != null and t.kind == d.face and t.level < 3:
				best = i
				break
		if best == -1 and d.face == "guide":   # next to an existing defense
			for i in board.tiles.size():
				if board.tile_defense[i] == null and _has_neighbour(i):
					best = i
					break
		if best == -1:
			for k in board.group_count * 3:  # inner tiles round the fire first
				var i: int = (k % board.group_count) * 3 + k / board.group_count
				if i < board.tiles.size() and board.tile_defense[i] == null:
					best = i
					break
		if best != -1:
			_try_place(d, board.proj(board.tiles[best]))
		else:
			begin_wave()
		return
	begin_wave()   # only Ashes left


## Autoplay: how much defense covers a route past the forks.
func _fork_score(path_idx: int) -> float:
	var score := 0.0
	var pts: PackedVector2Array = board.paths[path_idx]
	for df in defenses:
		var rng_r: float = Defs.DEFENSES[df.kind][mini(df.level - 1, 2)]["range"] if Defs.DEFENSES.has(df.kind) else 0.0
		for p in pts:
			if p.distance_to(df.world) < rng_r:
				score += df.level
	return score


## Autoplay: now and then, point a ready gate at the better-covered way.
func _autoplay_gates(delta: float) -> void:
	_ap_gate_t -= delta
	if _ap_gate_t > 0.0:
		return
	_ap_gate_t = 1.5
	for i in board.links.size():
		var L: Dictionary = board.links[i]
		if L["gate"] and L["cool"] <= 0.0:
			var want := _fork_score(L["path"]) > _fork_score(L["from"])
			if want != L["cross"] or Run.rng.randf() < 0.15:
				_tap_fork(i)
				return


func _has_neighbour(i: int) -> bool:
	for df in defenses:
		if df.kind != "guide" and df.tile / 3 == i / 3:
			return true
	return false


# ------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				reroll()
			KEY_ENTER, KEY_KP_ENTER:
				begin_wave()
			KEY_1, KEY_2, KEY_3, KEY_4:
				var i: int = event.keycode - KEY_1
				if i < _dice.size() and not _dice[i].placed and not _dice[i].is_rolling():
					_on_die_tapped(_dice[i])
		return
	var local: Vector2
	if event is InputEventMouseMotion:
		local = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if _lifted:
			var t: int = board.tile_at(local)
			_hover = t if board.can_move_to(t) else -1
		else:
			_hover = _target_at(local, _selected.face) if _selected else -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		local = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if _selected and phase == Phase.PREP:
			if _try_place(_selected, local):
				get_viewport().set_input_as_handled()
		elif _tap_fork(board.link_at(local)):
			get_viewport().set_input_as_handled()
		elif _shift_ready and phase == Phase.PREP:
			if _try_shift(board.tile_at(local)):
				get_viewport().set_input_as_handled()


## Prep: cobble a gate on a bare fork, or flip one for free. In a wave: flip
## a gate if its flame has filled, then it cools down again.
func _tap_fork(i: int) -> bool:
	if i < 0 or phase == Phase.DONE:
		return false
	var L: Dictionary = board.links[i]
	if not L["gate"]:
		if phase != Phase.PREP or _gates_left <= 0:
			return false
		L["gate"] = true
		L["cross"] = true
		_gates_left -= 1
		AudioDirector.play_sfx("place", -4.0)
		_start_hint_refresh()
		return true
	if phase == Phase.FIGHT and L["cool"] > 0.0:
		AudioDirector.play_sfx("tap", -10.0)
		return true
	L["cross"] = not L["cross"]
	if phase == Phase.FIGHT:
		L["cool"] = Defs.GATE_COOLDOWN
	AudioDirector.play_sfx("tap", -4.0)
	return true


func _start_hint_refresh() -> void:
	_hint.text = _hint.text.split("   Tap a glowing fork")[0]
	if _gates_left > 0:
		_hint.text += "   Tap a glowing fork to cobble a gate (%d left)." % _gates_left


# ------------------------------------------------------------ HUD
func _build_hud() -> void:
	_flame_bar = FlameBar.new()
	_flame_bar.position = Vector2(20, 18)
	add_child(_flame_bar)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", -6)
	_night_label = Label.new()
	_night_label.add_theme_font_override("font", Style.display_font())
	_night_label.add_theme_font_size_override("font_size", 34)
	_night_label.add_theme_color_override("font_color", Style.ACCENT)
	_night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_night_label)
	_wave_label = Label.new()
	_wave_label.add_theme_color_override("font_color", Style.MUTE)
	_wave_label.add_theme_font_size_override("font_size", 19)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_wave_label)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 8
	add_child(top)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_top = 14
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(EssenceTracker.new())
	var oaths := _small_button("Oaths", func(): oaths_requested.emit())
	oaths.custom_minimum_size.x = 96
	right.add_child(oaths)
	_speed_btn = _small_button("1×", _toggle_speed)
	right.add_child(_speed_btn)
	right.add_child(_small_button("II", _toggle_pause))
	add_child(right)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 12)
	_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_child(gap)
	_roll_btn = Button.new()
	_roll_btn.custom_minimum_size = Vector2(150, 64)
	_roll_btn.pressed.connect(reroll)
	_roll_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_tray.add_child(_roll_btn)
	_fight_btn = Button.new()
	_fight_btn.text = "Fight!"
	_fight_btn.custom_minimum_size = Vector2(150, 64)
	_fight_btn.pressed.connect(begin_wave)
	_fight_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_tray.add_child(_fight_btn)
	add_child(_tray)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", Style.display_font())
	_banner.add_theme_font_size_override("font_size", 60)
	_banner.add_theme_color_override("font_color", Style.ACCENT)
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_banner.add_theme_constant_override("shadow_outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)

	_ghost = DrawProxy.new()
	_ghost.draw_fn = _draw_ghost
	_ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(60, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _draw_ghost(ci: CanvasItem) -> void:
	if _drag_die:
		DieView.draw_die(ci, _drag_pos - ci.get_global_transform().origin, 80.0, _drag_die.faces, _drag_die.side, true, false, 0.0)


func _update_hud() -> void:
	_flame_bar.set_value(Run.flame, Run.max_flame)
	var stop_name: String = Defs.STOPS[Run.current_stop()]["name"]
	_night_label.text = "Night %d/%d" % [Run.night + 1, Defs.NIGHTS]
	_wave_label.text = "%s  ·  Wave %d/%d" % [stop_name, mini(wave + 1, Defs.WAVES_PER_NIGHT), Defs.WAVES_PER_NIGHT]
	if ambush:
		_wave_label.text = "Fog Camp  ·  Ambush"
	elif mod != "":
		_wave_label.text += "  ·  " + Defs.WAVE_MODS[mod]["name"]
	if Run.shrine_curse:
		_wave_label.text += "  ·  Shrine's Wrath"
	var prep := phase == Phase.PREP
	_roll_btn.text = "Roll (%d)" % _rerolls
	_roll_btn.disabled = not prep or _rerolls <= 0
	_fight_btn.disabled = not prep
	_roll_btn.visible = prep
	_fight_btn.visible = prep


func _show_banner(text: String) -> void:
	_banner.text = text
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.0)
	t.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _toggle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	_speed_btn.text = "2×" if Engine.time_scale > 1.5 else "1×"


func _toggle_pause() -> void:
	if phase == Phase.DONE:
		return
	if _pause_card and _pause_card.has_meta("sub"):
		_show_pause_menu()   # Esc in Options goes back to the pause menu
		return
	if _pause_card:
		_close_pause()
		return
	get_tree().paused = true
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dim)
	_layout()
	_show_pause_menu()


## Pause menu: Back, Options, Abandon Run, Save and Quit.
func _show_pause_menu() -> void:
	var box := _pause_panel("Paused")
	for item in [["Back", _close_pause], ["Options", _show_pause_options],
			["Abandon Run", _abandon], ["Save and Quit", _save_quit]]:
		box.add_child(_pause_button(item[0], item[1]))
	(box.get_child(1) as Button).grab_focus()


## Same volume sliders as the main menu's Options.
func _show_pause_options() -> void:
	var box := _pause_panel("Options")
	_pause_card.set_meta("sub", true)
	box.add_child(VolumeSliders.build())
	var back := _pause_button("Back", _show_pause_menu)
	box.add_child(back)
	back.grab_focus()


## Replaces whatever pause card is showing with a fresh one; returns its column.
func _pause_panel(heading: String) -> VBoxContainer:
	if _pause_card:
		_pause_card.queue_free()
	_pause_card = PanelContainer.new()
	_pause_card.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_card.custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 52)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	_pause_card.add_child(box)
	add_child(_pause_card)
	_layout.call_deferred()
	return box


func _pause_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(cb)
	return b


func _close_pause() -> void:
	get_tree().paused = false
	if _pause_card:
		_pause_card.queue_free()
		_dim.queue_free()
		_pause_card = null


func _abandon() -> void:
	_close_pause()
	phase = Phase.DONE
	abandoned.emit()


func _save_quit() -> void:
	_close_pause()
	phase = Phase.DONE
	save_and_quit.emit()
