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
const Icons := preload("res://scripts/game/icons.gd")
const EssenceTracker := preload("res://scripts/ui/essence_tracker.gd")
const VolumeSliders := preload("res://scripts/ui/volume_sliders.gd")
const Board := preload("res://scripts/game/board.gd")
const EmberDrop := preload("res://scripts/game/ember_drop.gd")
const BossBar := preload("res://scripts/game/boss_bar.gd")
var _boss_bar
const TOP := 78.0         ## the map's top edge, under the HUD
const TOP_BOSS := 150.0   ## on a boss wave, the map eases down under the boss bar
var _top := TOP
const Spirit := preload("res://scripts/game/spirit.gd")
const Defense := preload("res://scripts/game/defense.gd")
const CharUnit := preload("res://scripts/game/char_unit.gd")
const Projectile := preload("res://scripts/game/projectile.gd")
const Fx := preload("res://scripts/game/fx.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")
const DieView := preload("res://scripts/game/die_view.gd")
const Campfire := preload("res://scripts/title/campfire.gd")
const CampProp := preload("res://scripts/game/camp_prop.gd")
const FlameBar := preload("res://scripts/game/flame_bar.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")
const MemberFigure := preload("res://scripts/game/member_figure.gd")
const LitLamp := preload("res://scripts/game/lit_lamp.gd")

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
var _planned: Array = []      # Carl, the Caravan Cat: next wave's spawn queue, lanes fixed in prep
var _carl_lanes: Array = []   # the lane(s) with the most spirits coming
var _carl_count := 0
var _carl_view: Control       # the badge, over everything
var _carl_trail: Control      # the glowing lane, under spirits and Char
var _props: Array = []   ## the stagecoach and horse Char is guarding
var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _dice: Array = []
var _rerolls := 0
var _fire_heals := 0   ## Kindle/Pine heals on the fire this wave (Defs.FIRE_HEAL_FALLOFF)
var _sixth_used := false    ## Oath of the Sixth Face: used this wave
var _choose_btn: Button
var _choose_card: PanelContainer
var _selected = null
var _drag_die = null
var _drag_pos := Vector2.ZERO
var _ghost: Control
var _hover := -1
var _auto_begin := -1.0
var _ap_timer := 1.2
var _shift_ready := false  ## Oath of Shifting Embers: a move is available this prep
var _shift_free := false   ## lull reward Adjustment: the next move costs nothing
var _parts_view: Control     ## Terry, the Tinker: cog + pips above the Roll button
var _parts_pulse := 0.0
var _hella_left := 0          # Hella, the Caravan Hound: scares left this wave
var _badges := {}   ## rider id -> HUD badge (DrawProxy)
var _badge_pulse := {}
var _lamp = null
var _figures := {}   ## rider id -> MemberFigure by the fire
var _lull_rerolls := 0     ## lull reward Spare Luck: extra rerolls next prep
var banked := 0.0          ## Oath of the Banked Fire: + damage this wave (read by Defense, Char)
var shield := 0.0          ## Reliquaries on the fire: damage left to soak up this wave
var wards := 0             ## Ash Wards on the fire this wave, waiting to pulse
var ward_t := 0.0          ## seconds left on the Ash Ward slow
var pine_logs := 0         ## Pine Logs on the fire this wave (Torches reach farther; read by Defense)
var heavy := false         ## lull reward Heavy Support Fire: Char lobs mortar shots (read by CharUnit)
var stoked := false        ## lull reward Stoke: defenses fire faster (read by Defense)
var boss_wave := false     ## this wave brings the leg's boss
var _glare: ColorRect
var _glare_k := 0.0
var _sear_tick := 0.0
var _boss_intro := false   ## the music has dropped out and the wind blown for the coming boss
const BOSS_INTRO := 1.1    ## seconds of wind, without music, before a boss arrives
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

var _mire_hit := -1   ## Mire being levelled (index into board.mires), or -1
var _ash_clouds := 0   ## Oath of Ash Clouds: spirits still to slow this wave


func _ready() -> void:
	if Run.autoplay and Run.test_speed > 1.0:
		Engine.time_scale = Run.test_speed
		Engine.physics_ticks_per_second = roundi(60 * Run.test_speed)
		Engine.max_physics_steps_per_frame = 8 * ceili(Run.test_speed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()

	if not ambush:   # tonight's numbers for the dawn recap
		Run.recap = {"flame": Run.flame, "banished": Run.spirits_banished,
			"essence": Profile.essence, "hits": 0, "low": Run.flame}
	board = Board.new()
	board.layout_seed = Run.layout_seed
	board.stop = Run.current_stop()
	board.spirits_ref = spirits   # the lake draws their reflections
	_world.add_child(board)
	_entities.y_sort_enabled = true
	_carl_trail = DrawProxy.new()
	_carl_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carl_trail.draw_fn = _draw_carl_trail
	_world.add_child(_carl_trail)
	_world.add_child(_entities)
	_world.add_child(_fx)
	_carl_view = DrawProxy.new()
	_carl_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carl_view.visible = false
	_carl_view.draw_fn = _draw_carl
	_world.add_child(_carl_view)
	add_child(_world)
	if ambush:   # the camp sits in the fog
		var mist := ColorRect.new()
		mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mist.color = Color(0.72, 0.8, 0.95, 0.16)
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mist)

	_glare = ColorRect.new()   # Helio's glare, faded in while he sears the fire
	_glare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glare.color = Color(1, 1, 1, 0)
	_glare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glare.material = add
	add_child(_glare)

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
	if Run.has_rider("lamplighter"):   # Leopold's Lit Lamp
		var lamp := LitLamp.new()
		_entities.add_child(lamp)
		lamp.setup(self, board)
		_lamp = lamp
		_props.append(lamp)
	var spots := [Vector2(70, 118), Vector2(170, -80)]   # seat spots, clear of lanes
	var seated: Array = Run.riders.duplicate()
	if seated.has("lamplighter"):   # Leopold stands nearer his lamp
		seated.erase("lamplighter")
		seated.push_front("lamplighter")
	for i in mini(seated.size(), spots.size()):
		var fig := MemberFigure.new()
		_entities.add_child(fig)
		fig.setup(seated[i], spots[i], board)
		_props.append(fig)
		_figures[seated[i]] = fig
	if Run.has_oath("forest_friend"):
		var dr := Dryad.new()
		_entities.add_child(dr)
		dr.setup(self, board)

	_build_hud()
	resized.connect(_layout)
	_layout()

	_start_prep.call_deferred()


func _exit_tree() -> void:
	AudioDirector.set_tension(false)
	AudioDirector.end_boss_music(0.8)
	Engine.time_scale = 1.0


# ------------------------------------------------------------ layout
func _layout() -> void:
	var s := size
	var top := _top
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
	if _boss_bar:
		_boss_bar.position = Vector2((s.x - _boss_bar.size.x) / 2.0, 62.0)
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
	_rerolls = mini(Defs.MAX_REROLLS, Defs.REROLLS_PER_WAVE + Run.bonus_rerolls)
	var built := 0
	if Run.has_rider("tinker"):   # banked parts become free rerolls this wave
		built = Run.spare_parts / Defs.TINKER_PARTS
		Run.spare_parts %= Defs.TINKER_PARTS
		_rerolls += built
	_rerolls += _lull_rerolls   # Spare Luck goes past the cap
	_fire_heals = 0
	_sixth_used = false
	_lull_rerolls = 0
	_hella_left = Defs.HOUND_SCARES if Run.has_rider("hound") else 0
	if wave == 0:
		member_react("cook")   # Carson's stew is on for the night
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
	_shift_ready = (_shift_free or wave > 0 and Run.has_oath("shifting_embers")) and not defenses.is_empty()
	_roll(true)
	boss_wave = not ambush and Defs.is_boss_wave(Run.night, wave)
	if boss_wave:   # the bar waits, dormant, from prep, so the room it takes is plain
		var bd: Dictionary = Defs.SPIRITS[Run.boss_for(Run.night)]
		_boss_bar.reserve(bd["name"], bd.get("bar_color", bd["color"]))
	_boss_intro = false
	mod = "" if ambush or boss_wave else Defs.roll_wave_mod(Run.night, Run.rng)
	_swarm_lane = Run.rng.randi() % board.lane_count if mod == "swarmy" else -1
	_plan_carl()
	_update_hud()
	if ambush:
		_show_banner("Ambush in the fog!")
	elif boss_wave:
		_show_banner("Wave %d of %d  ·  %s approaches!" % [wave + 1, Defs.WAVES_PER_NIGHT, Defs.SPIRITS[Run.boss_for(Run.night)]["name"]])
	elif mod != "":
		_show_banner("Wave %d of %d  ·  %s!" % [wave + 1, Defs.WAVES_PER_NIGHT, Defs.WAVE_MODS[mod]["name"]])
	else:
		_show_banner("Wave %d of %d" % [wave + 1, Defs.WAVES_PER_NIGHT])
	if Run.night == 0 and wave == 0:
		_hint.text = "Tap a die to hold it, then tap a glowing tile.  Or drag it there.  Star and Pine Log dice go on the fire."
	elif mod != "":
		_hint.text = "%s: %s  Place your dice, then Fight!" % [Defs.WAVE_MODS[mod]["name"], Defs.WAVE_MODS[mod]["desc"]]
	elif boss_wave:
		var bd: Dictionary = Defs.SPIRITS[Run.boss_for(Run.night)]
		_hint.text = "Boss wave!  %s %s.  Place your dice, then Fight!" % [bd["name"].get_slice(",", 0), bd["blurb"]]
	else:
		_hint.text = "Place your dice, then Fight!"
	if _gates_left > 0 and not board.links.is_empty():
		_hint.text += "   Tap a glowing fork to cobble a gate (%d left)." % _gates_left
	if _shift_ready:
		_hint.text += "   " + _shift_hint()
	if built > 0:
		_hint.text += "   %s built %s from spare parts." % [Defs.CARAVAN["tinker"]["name"], "a free reroll" if built == 1 else "%d free rerolls" % built]
	if Run.night == 0 and wave == 0 and Run.forge_text() != "":
		_hint.text += "   Simon, the Smith forged a %s." % Run.forge_text()
		member_react("smith")
	if not _carl_lanes.is_empty():
		_hint.text += "   Carl's ears twitch toward %s." % ("the glowing trail" if _carl_lanes.size() == 1 else "the glowing trails")
	elif not _planned.is_empty():
		_hint.text += "   Carl yawns: the Wisps are spread evenly."
	_layout.call_deferred()


func _roll(first := false) -> void:
	var any := false
	for d in _dice:
		if d.placed or (d.held and not first):
			continue
		var side: int = Run.rng.randi() % d.faces.size()
		if not first and Run.has_oath("steady_hands"):   # rerolls never land on Ashes
			var sides := []
			for i in d.faces.size():
				if d.faces[i] != "ashes":
					sides.append(i)
			if not sides.is_empty():
				side = sides[Run.rng.randi() % sides.size()]
		d.roll(side, 0.45 + 0.12 * d.index)
		any = true
		if d.faces[side] == "ashes":
			Profile.add_stat("ashes_rolled")
		if d.faces[side] == "ashes" and Run.has_rider("tinker"):
			Run.spare_parts += 1
			member_react("tinker")
			_parts_pulse = 1.0
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
	_embers_this_wave = 0
	fighting = true
	_auto_begin = -1.0
	_select(null)
	_drop_lift()
	_shift_ready = false
	_shift_free = false
	_ash_clouds = 0
	if Run.has_oath("ash_clouds"):
		for d in _dice:
			if not d.placed and d.face == "ashes":
				_ash_clouds += 1
	_warm_ashes()
	for d in _dice:
		if not d.placed:
			d.placed = true  # unused dice fade back into the bag
	_spawn_queue = _planned if not _planned.is_empty() else _plan_spawns(false)
	_planned = []
	_carl_lanes = []
	_carl_view.visible = false
	_carl_trail.queue_redraw()
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
		for w in board.walls:
			if is_instance_valid(w) and not w.broken:
				desc.append("wall%d(%d hp)" % [w.level, roundi(w.hp)])
		print("  night %d wave %d cleared  flame=%d  char_kindle=%d  defenses=%s" % [Run.night + 1, wave + 1, roundi(Run.flame), char_unit.kindle, desc])
	fighting = false
	pine_logs = 0
	wards = 0
	shield = 0.0
	board.shield = 0.0
	ward_t = 0.0
	banked = 0.0
	AudioDirector.set_tension(false)
	AudioDirector.end_boss_music()
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
		Profile.add_stat("nights_won")
		Profile.add_stat("night_%d_won" % (Run.night + 1))
		char_unit.set_mood("happy")
		var gained := Defs.essence_for_night(Run.flame, Run.night)
		if Run.current_stop() == "swamp":
			gained *= Defs.SWAMP_ESSENCE
		elif Run.current_stop() == "chapel":
			gained *= Defs.CHAPEL_ESSENCE
			Profile.add_stat("chapel_nights_won")   # for Paolo the Priest, later
		Profile.add_essence(gained)
		_show_banner("Dawn breaks!  +%d Essence" % gained)
		AudioDirector.play_sfx("chime", -2.0)
		get_tree().create_timer(2.0).timeout.connect(func(): night_over.emit(true))
	else:
		_show_banner("Wave cleared")
		var next := _show_lull if wave == Defs.WAVES_PER_NIGHT - 1 else _start_prep
		get_tree().create_timer(1.1).timeout.connect(next)


# ------------------------------------------------------------ the lull before wave 3
## Pick 1 of LULL_QUICK quick-use rewards and 1 permanent one, then prep wave 3.
func _show_lull() -> void:
	var quick_ok := ["second_wind", "spare_luck", "stoke"]
	for id in Defs.LOCKED_QUICK:
		if Profile.is_unlocked(id):
			quick_ok.append(id)
	if not defenses.is_empty() and board.tile_defense.has(null):
		quick_ok.append("adjustment")
	var hone_kinds := []
	for df in defenses:
		if Defs.HONE.has(df.kind) and not df.kind in hone_kinds:
			hone_kinds.append(df.kind)
	var offer := Defs.lull_offer(Run.rng, Run.perks, quick_ok, hone_kinds)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.theme = Style.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	layer.add_child(root)
	var h := Label.new()
	h.text = "A Lull Before the Last Wave"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 48)
	h.add_theme_color_override("font_color", Color("#ffd58f"))
	root.add_child(h)
	var sub := Label.new()
	sub.text = "CHOOSE ONE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Style.MUTE)
	sub.add_theme_font_size_override("font_size", 16)
	root.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	root.add_child(row)
	var cards := []
	for o in offer:
		var title: String
		var desc: String
		if o["type"] == "quick":
			title = Defs.QUICK_REWARDS[o["id"]]["name"]
			desc = "Quick use:  " + Defs.QUICK_REWARDS[o["id"]]["desc"]
		elif o["id"] == "hone":
			var kname: String = Defs.FACE_INFO[o["kind"]]["name"]
			title = "Hone: " + kname
			desc = "Permanent:  " + Defs.PERKS["hone"]["desc"] % [kname, Defs.hone_text(o["kind"])]
		else:
			title = Defs.PERKS[o["id"]]["name"]
			desc = "Permanent:  " + Defs.PERKS[o["id"]]["desc"]
		var card := ChoiceCard.make(title, desc, 260.0)
		card.custom_minimum_size.y = 150
		card.pressed.connect(func():
			layer.queue_free()
			_take_lull(o))
		row.add_child(card)
		cards.append(card)
	add_child(layer)
	if cards.is_empty():
		layer.queue_free()
		_start_prep()
		return
	cards[0].grab_focus.call_deferred()
	if Run.autoplay:
		var pick: Button = cards[Run.rng.randi() % cards.size()]
		get_tree().create_timer(1.0).timeout.connect(pick.emit_signal.bind("pressed"))


func _take_lull(o: Dictionary) -> void:
	AudioDirector.play_sfx("chime", -4.0)
	if Run.autoplay:
		print("  lull: %s %s" % [o["id"], o.get("kind", "")])
	if o["type"] == "perk":
		Run.take_perk(o)
	else:
		match o["id"]:
			"second_wind":
				Run.flame = minf(Run.max_flame, Run.flame + Defs.LULL_HEAL)
				_add_fx("ring", Vector2.ZERO, Color("#fff0b0"), 130.0)
			"spare_luck":
				_lull_rerolls = Defs.LULL_REROLLS
			"stoke":
				stoked = true
			"heavy_support":
				heavy = true
			"adjustment":
				_shift_free = true
	_update_hud()
	_start_prep()


func _flame_out() -> void:
	if Run.has_rider("priest") and not Run.rites_used:   # Paolo's Last Rites: once per run
		Run.rites_used = true
		Run.flame = Run.max_flame * Defs.PRIEST_RITES
		member_react("priest")
		char_unit.set_mood("happy")
		_flame_bar.flash()
		_add_fx("ring", Vector2.ZERO, Color("#fff2c8"), 260.0)
		_add_fx("ring", Vector2.ZERO, Color("#ffd58f"), 160.0)
		AudioDirector.play_sfx("bell_toll", -4.0, 0.0)
		_show_banner("Last Rites!  Paolo relights Char's flame.")
		_update_hud()
		if Run.autoplay:
			print("  last rites: flame relit to %d" % roundi(Run.flame))
		return
	phase = Phase.DONE
	fighting = false
	AudioDirector.set_tension(false)
	AudioDirector.end_boss_music()
	char_unit.set_mood("hurt")
	Profile.add_essence(Defs.essence_for_lost_night(Run.night))
	_show_banner("Char's flame went out...")
	get_tree().create_timer(2.2).timeout.connect(func(): night_over.emit(false))


func _process(delta: float) -> void:
	# The board's light follows the campfire's flicker.
	board.fire_glow = 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.006) * sin(Time.get_ticks_msec() * 0.0017)
	board.hover_tile = _hover
	for id in _badges:
		_badge_pulse[id] = maxf(0.0, _badge_pulse[id] - delta * 1.6)
		_badges[id].queue_redraw()
	if _parts_pulse > 0.0:
		_parts_pulse = maxf(0.0, _parts_pulse - delta * 2.5)
		_parts_view.queue_redraw()
	# Boss waves: ease the map down to make room for the boss bar.
	var top_to := TOP_BOSS if boss_wave else TOP
	if not is_equal_approx(_top, top_to):
		_top = move_toward(_top, top_to, delta * 120.0)
		_layout()
	# The boss bar fades back while a die is in hand or something's under it.
	if _boss_bar.visible:
		var r: Rect2 = _boss_bar.bar_rect()
		var under: bool = _drag_die != null or _selected != null
		for sp in spirits:
			if not sp.boss and r.grow(12).has_point(_world.position + sp.position - Vector2(0, 30)):
				under = true
				break
		for e in _embers:
			if r.grow(12).has_point(_world.position + e.position):
				under = true
		_boss_bar.dim(under)
	board.gates_left = _gates_left if phase == Phase.PREP else 0
	if Run.autoplay and phase == Phase.FIGHT:
		_autoplay_gates(delta)
	if Run.autoplay:
		_autoplay_embers()
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
	if _carl_view.visible:
		_carl_view.queue_redraw()
		_carl_trail.queue_redraw()
	if _swarm_lane >= 0 and phase == Phase.PREP:   # point out the swarm trail
		_mark_t -= delta
		if _mark_t <= 0.0:
			_mark_t = 0.25
			var p = board.path_point(_swarm_lane, randf() * board.path_lengths[_swarm_lane] * 0.85)
			_add_fx("ring", p, Color("#ff8f6b"), 40.0)
	if not fighting:
		return
	if wards > 0 and Run.flame <= Run.max_flame * Defs.WARD_AT:
		ward_t = Defs.WARD_TIME + Defs.WARD_EXTRA * (wards - 1)
		wards = 0
		_add_fx("ring", Vector2.ZERO, Color("#b9a8d8"), 900.0)
		if Run.autoplay:
			print("  ash ward pulse (%.1fs)" % ward_t)
	if ward_t > 0.0:
		ward_t -= delta
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if not _boss_intro and Defs.SPIRITS[_spawn_queue[0][0]].get("boss", false) and _spawn_timer <= BOSS_INTRO:
			_boss_intro = true   # the music drops out and the wind blows by first
			_spawn_timer = BOSS_INTRO
			AudioDirector.boss_intro()
		if _spawn_timer <= 0.0:
			var e: Array = _spawn_queue.pop_front()
			_spawn(e[0], e[1], e[2])
			_spawn_timer = Defs.spawn_gap(Run.night, wave) * Run.rng.randf_range(0.8, 1.2)
			if e[1] >= 0:
				_spawn_timer *= Defs.SWARM_GAP
	# Bellringers' tolls hasten the other spirits around them.
	for b in spirits:
		if b.tolled:
			b.tolled = false
			if b.dead:
				continue
			var bd: Dictionary = Defs.SPIRITS[b.kind]
			for o in spirits:
				if o != b and not o.dead and not o.boss and o.world.distance_to(b.world) <= bd["ring_range"]:
					o.haste = bd["haste"]
					o.haste_t = bd["haste_time"]
	# Defenses with a "slow" stat slow spirits inside their reach (strongest wins).
	for sp in spirits:
		var slow := 0.0
		for d in defenses:
			var st: Dictionary = d.stats()
			if st.get("slow", 0.0) > 0.0 and d.world.distance_to(sp.world) <= st["range"]:
				slow = maxf(slow, st["slow"])
		for m in board.mires:   # wading a Mire patch
			var ms: Dictionary = Defs.MIRE[m["level"] - 1]
			if m["world"].distance_to(sp.world) <= ms["r"]:
				sp.mire_t = ms["t"]
				sp.mire_slow = maxf(sp.mire_slow if sp.mire_t > 0.0 else 0.0, ms["slow"])
		if sp.mire_t > 0.0:
			sp.mire_t -= delta
			slow = maxf(slow, sp.mire_slow)
		for d in defenses:   # Wisp Lanterns: the leader of a pack in the light slows
			if d.kind != "lure" or sp.dead or d.world.distance_to(sp.world) > d.stats()["range"]:
				continue
			for o in spirits:
				if o != sp and not o.dead and o.path_idx == sp.path_idx and sp.dist - o.dist > Defs.LURE_GAP \
						and d.world.distance_to(o.world) <= d.stats()["range"]:
					slow = maxf(slow, d.stats()["lure"])
					break
		if sp.vine_t > 0.0:   # wrapped by the Forest Friend's dryad
			sp.vine_t -= delta
			slow = maxf(slow, Defs.DRYAD_SLOW)
		if ward_t > 0.0:   # Ash Ward stacks with the rest
			slow = 1.0 - (1.0 - slow) * (1.0 - Defs.WARD_SLOW)
		sp.slow = minf(slow, 1.0 - Defs.MIN_SPEED)
	# A dashing Lantern Thief snuffs out every defense he passes.
	for sp in spirits:
		if sp.dashing() and not sp.dead:
			for d in defenses:
				if d.world.distance_to(sp.world) <= sp.snuff_range:
					d.snuff(sp.snuff_time)
	# Mist Wisps near Char slow its attacks (strongest wins, no stacking).
	var chill := 0.0
	for sp in spirits:
		var r: float = Defs.SPIRITS[sp.kind].get("chill_range", 0.0)
		if r > 0.0 and not sp.dead and sp.world.distance_to(char_unit.world) <= r:
			chill = maxf(chill, Defs.SPIRITS[sp.kind]["chill"])
	char_unit.chill = chill
	# Helio near the fire: the camp glares bright and the fire burns away steadily.
	var sear := 0.0
	for sp in spirits:
		if sp.burning():
			sear += sp.burn_dps
	_glare_k = move_toward(_glare_k, 1.0 if sear > 0.0 else 0.0, delta * 1.5)
	_glare.color = Color(1.0, 0.85, 0.45, 0.22 * _glare_k)
	if sear > 0.0 and phase != Phase.DONE:
		Run.flame = maxf(0.0, Run.flame - sear * delta)
		if Run.recap.has("low"):
			Run.recap["low"] = minf(Run.recap["low"], Run.flame)
		_sear_tick -= delta
		if _sear_tick <= 0.0:
			_sear_tick = 1.0
			_flame_bar.flash()
			_add_fx("ring", Vector2.ZERO, Color("#ffb238"), 90.0)
		_update_hud()
		if Run.flame <= 0.0:
			_flame_out()
	if _spawn_queue.is_empty() and spirits.is_empty():
		_wave_cleared()


## How much a Dark Wisp dims light at this spot (0 = not at all). Strongest wins.
func dim_at(at: Vector2) -> float:
	var dim := 0.0
	for sp in spirits:
		if sp.dim > 0.0 and not sp.dead and at.distance_to(sp.aura_center()) <= sp.dim_range:
			dim = maxf(dim, sp.dim)
	return dim


## Each queue entry: [kind, lane (-1 = random at spawn), hearty]. With
## fix_lanes every lane is picked now, so Carl can tell where they'll come.
func _plan_spawns(fix_lanes: bool) -> Array:
	var kinds: Array = Defs.ambush_spirits(Run.night) if ambush else Defs.wave_spirits(Run.night, wave, Run.current_stop(), Run.rng, Run.boss_for(Run.night))
	if Run.coach_haunt and not ambush:   # the stagecoach's lost passengers follow
		for i in Defs.COACH_HAUNT_SPIRITS:
			kinds.append("wisp")
	var q := []
	for k in kinds:
		var lane := _swarm_lane if mod == "swarmy" and Run.rng.randf() < Defs.SWARM_SHARE else -1
		var hearty: bool = mod == "hearty" and Run.rng.randf() < Defs.HEARTY_SHARE
		if fix_lanes and lane < 0:
			lane = Run.rng.randi() % board.lane_count
		q.append([k, lane, hearty])
	return q


## Carl, the Caravan Cat: plan the wave now and point at its busiest lane(s).
func _plan_carl() -> void:
	_planned = []
	_carl_lanes = []
	_carl_count = 0
	if not Run.has_rider("cat"):
		_carl_view.visible = false
		return
	_planned = _plan_spawns(true)
	var per := []
	per.resize(board.lane_count)
	per.fill(0)
	for e in _planned:
		per[e[1]] += 1
	_carl_count = per.max()
	for i in board.lane_count:
		if per[i] == _carl_count:
			_carl_lanes.append(i)
	if _carl_lanes.size() > 2:   # spread evenly: nothing worth pointing at
		_carl_lanes = []
	_carl_view.visible = true
	_carl_view.queue_redraw()
	if not _carl_lanes.is_empty():
		member_react("cat")


## Carl's trail: a soft gold band down the lane (under the spirits and Char),
## fading in and out at the ends, with sparks drifting toward camp.
func _draw_carl_trail(ci: CanvasItem) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var gold := Color("#ffd58f")
	var breathe := 0.85 + 0.15 * sin(t * 2.2)
	for i in _carl_lanes:
		var L: float = board.path_lengths[i] * 0.93
		var pts := PackedVector2Array()
		var outer := PackedColorArray()
		var inner := PackedColorArray()
		var d := 0.0
		while d <= L:
			var f := clampf(minf(d / 160.0, (L - d) / 90.0), 0.0, 1.0)
			pts.append(board.path_point(i, d))
			outer.append(Color(gold, 0.13 * f * breathe))
			inner.append(Color(gold, 0.26 * f * breathe))
			d += 10.0
		if pts.size() < 2:
			continue
		ci.draw_polyline_colors(pts, outer, 46.0, true)
		ci.draw_polyline_colors(pts, inner, 16.0, true)
		var gap := 110.0
		var s := fmod(t * 70.0, gap)
		while s < L:
			var f := clampf(minf(s / 160.0, (L - s) / 90.0), 0.0, 1.0)
			var p: Vector2 = board.path_point(i, s)
			ci.draw_circle(p, 7.0, Color(gold, 0.18 * f))
			ci.draw_circle(p, 3.5, Color(1, 0.95, 0.8, 0.75 * f))
			s += gap


func _draw_carl(ci: CanvasItem) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var gold := Color("#ffd58f")
	for i in _carl_lanes:
		var L: float = board.path_lengths[i]
		# Badge at the first spot on the trail that sits well inside the screen.
		var xf: Transform2D = _carl_view.get_global_transform_with_canvas()
		var safe := Rect2(Vector2.ZERO, get_viewport_rect().size).grow_individual(-80, -110, -80, -240)
		var at: Vector2 = board.path_point(i, L * 0.5)
		var s := 0.0
		while s < L * 0.9:
			if safe.has_point(xf * board.path_point(i, s)):
				at = board.path_point(i, s)
				break
			s += 20.0
		ci.draw_circle(at, 30.0, Color(0, 0, 0, 0.6))
		ci.draw_arc(at, 30.0, 0, TAU, 32, gold, 2.0)
		Icons.draw(ci, "cat", at + Vector2(0, -4), 40.0, gold)
		ci.draw_string(ThemeDB.fallback_font, at + Vector2(-40, 50), "×%d" % _carl_count,
			HORIZONTAL_ALIGNMENT_CENTER, 80, 22, gold)


func _spawn(kind: String, lane := -1, hearty := false):
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
	if Run.has_oath("urgency") and Run.rng.randf() < Defs.URGENCY_SHARE:
		sp.speed *= Defs.URGENCY_SPEED
	if board.stop == "hill":
		sp.speed *= Defs.HILL_SPEED
	if _ash_clouds > 0 and not sp.boss:
		_ash_clouds -= 1
		sp.speed *= Defs.ASH_CLOUD_SLOW
	sp.banished.connect(_on_banished)
	sp.downed.connect(_on_downed)
	sp.reached_fire.connect(_on_reached_fire)
	sp.scare_fn = _hella_scare
	sp.zapped.connect(_on_zapped)
	sp.summoned.connect(_on_summoned)
	if sp.zap_range > 0.0:
		AudioDirector.play_sfx("charge_hum", -5.0)
	if sp.ring_every > 0.0:   # a Bellringer drifts in tolling
		AudioDirector.play_sfx("bell_toll", -6.0, 0.03)
	if sp.boss:
		AudioDirector.play_sfx(Defs.SPIRITS[kind].get("arrive_sfx", "charge_hum"), -4.0, 0.0)
		AudioDirector.start_boss_music()
		var bd: Dictionary = Defs.SPIRITS[kind]
		_boss_bar.show_boss(sp, bd["name"], bd.get("bar_color", bd["color"]))
		if Run.autoplay:
			print("  boss: %s (%d hp)" % [kind, roundi(sp.max_hp)])
	spirits.append(sp)
	return sp


## Helio stops and calls up Midnight Sun Rays from his spot.
func _on_summoned(boss, count: int) -> void:
	if phase == Phase.DONE:
		return
	_add_fx("ring", boss.world, Color("#ffb238"), 70.0)
	AudioDirector.play_sfx("charge_hum", -6.0)
	for i in count:
		var r = _spawn("sun_ray", boss.path_idx)
		r.place_at(maxf(0.0, boss.dist - 6.0 * i))


## A Mud Wisp sinks into the mud; it will get back up, slower.
func _on_downed(sp) -> void:
	_add_fx("ring", sp.world, Color("#7a5530"), 50.0)


func _on_banished(sp) -> void:
	spirits.erase(sp)
	if sp.kind == "mud_wisp":
		Profile.add_essence(Defs.MUD_ESSENCE)
		_add_fx("text", sp.world, Color("#9fd0ff"), 100.0, "+%d" % Defs.MUD_ESSENCE)
	var mend := 0.0   # Votive Candles: the strongest one in reach mends the fire
	for d in defenses:
		if d.kind == "votive" and d.world.distance_to(sp.world) <= d.stats()["range"]:
			mend = maxf(mend, d.stats()["heal"])
	if mend > 0.0 and phase != Phase.DONE:
		Run.flame = minf(Run.max_flame, Run.flame + mend)
		_add_fx("text", sp.world + Vector2(0, -20), Color("#ffd98a"), 100.0, "+%s" % str(mend).trim_suffix(".0"))
		_update_hud()
	if sp.kind == "bellringer":
		Profile.add_essence(Defs.BELL_ESSENCE)
		_add_fx("text", sp.world, Color("#9fd0ff"), 100.0, "+%d" % Defs.BELL_ESSENCE)
	if sp.smoulder_t > 0.0 and Run.has_oath("smouldering_wake"):   # the burn jumps on
		var best = null
		for o in spirits:
			if not o.dead and o.world.distance_to(sp.world) <= Defs.WAKE_RANGE and (best == null or o.world.distance_to(sp.world) < best.world.distance_to(sp.world)):
				best = o
		if best != null and sp.wake_jumps < Defs.WAKE_MAX_JUMPS:
			best.wake_jumps = sp.wake_jumps + 1
			best.smoulder_t = 0.0
			best.ignite(sp.smoulder_dps, Defs.DEFENSES["brazier"][0]["burn_t"])
			_add_fx("spark", best.world, Color("#ff7a3a"))
	Run.spirits_banished += 1
	_add_fx("poof", sp.world, Color("#bfc8ff"))
	AudioDirector.play_sfx("pop", -6.0)
	if _embers_this_wave < Defs.EMBER_MAX_PER_WAVE and Run.rng.randf() < Defs.EMBER_DROP_CHANCE:
		_embers_this_wave += 1
		_drop_ember(sp.world)


# ------------------------------------------------------------ ember drops
var _embers: Array = []
var _embers_this_wave := 0   ## drops so far this wave (capped)

func _drop_ember(at: Vector2) -> void:
	var e := EmberDrop.new()
	_fx.add_child(e)
	e.setup(board, at)
	e.tree_exited.connect(func(): _embers.erase(e))
	_embers.append(e)
	if Run.autoplay:   # the bot is a decent but not perfect collector
		e.set_meta("ap_at", Defs.EMBER_LIFE - randf_range(0.8, 2.5) if randf() < 0.75 else -99.0)


## Tap an ember: heal, a little burst, then it's gone.
func _try_pick_ember(local: Vector2) -> bool:
	if phase == Phase.DONE:
		return false
	for e in _embers:
		if e.hit(local):
			_pick_ember(e)
			return true
	return false


func _pick_ember(e) -> void:
	e.picked = true
	var heal := Defs.EMBER_HEAL + (Defs.WARM_COALS_BONUS if Run.has_oath("warm_coals") else 0.0)
	Run.flame = minf(Run.max_flame, Run.flame + heal)
	_add_fx("ring", e.world, Color("#ffb238"), 40.0)
	_add_fx("text", e.world, Color("#ffd27a"), 100.0, "+%d" % int(heal))
	AudioDirector.play_sfx("ember_pickup", -3.0)
	_flame_bar.flash()
	_update_hud()
	e.queue_free()


func _autoplay_embers() -> void:
	for e in _embers.duplicate():
		if not e.picked and e.life <= e.get_meta("ap_at", -99.0):
			_pick_ember(e)


## Hella, the Caravan Hound: the first Wisp to reach the fire each wave
## (not a boss) is scared back to the start of a random lane.
func _hella_scare(sp) -> bool:
	if _hella_left <= 0 or sp.boss or phase != Phase.FIGHT:
		return false
	_hella_left -= 1
	member_react("hound")
	_add_fx("ring", sp.world, Color("#e0b07a"), 70.0)
	_add_fx("ring", Vector2.ZERO, Color("#e0b07a"), 140.0)
	_add_fx("text", sp.world, Color("#ffd58f"), 100.0, "Scared!")
	AudioDirector.play_sfx("hound", -2.0)
	sp.scared_to(Run.rng.randi() % board.lane_count)
	return true


func _on_reached_fire(sp) -> void:
	spirits.erase(sp)
	_hurt_fire(sp)


## A Charged Wisp's zap: the same hurt as reaching the fire, but it stays.
func _on_zapped(sp) -> void:
	_hurt_fire(sp, "zap")


func _hurt_fire(sp, sfx := "hurt") -> void:
	if phase == Phase.DONE:
		return
	var dmg: float = sp.damage
	if shield > 0.0:   # the Reliquary takes it first
		var soak := minf(shield, dmg)
		shield -= soak
		dmg -= soak
		board.shield = shield
		_add_fx("ring", Vector2.ZERO, Color("#ffe39a"), 120.0)
		if dmg <= 0.0:
			AudioDirector.play_sfx("chime", -8.0)
			return
	Run.flame = maxf(0.0, Run.flame - dmg)
	if not ambush and Run.recap.has("hits"):
		Run.recap["hits"] += 1
		Run.recap["low"] = minf(Run.recap["low"], Run.flame)
	char_unit.hurt()
	_flame_bar.flash()
	_add_fx("ring", Vector2.ZERO, Color("#8fa0ff"), 110.0)
	AudioDirector.play_sfx(sfx, -2.0 if sfx == "hurt" else -4.0)
	_update_hud()
	if Run.flame <= 0.0:
		_flame_out()


# ------------------------------------------------------------ targeting (used by defenses & Char)
## The spirit in range that is closest to reaching the fire.
func pick_target(from: Vector2, rng: float):
	var best = null
	var best_p := -1.0
	for sp in spirits:
		if sp.dead or sp.down_t > 0.0:
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
		if sp.dead or sp.down_t > 0.0:
			continue
		var d: float = sp.world.distance_to(from)
		if d >= lo and d <= hi and sp.progress() < best_p:
			best_p = sp.progress()
			best = sp
	return best


func spirits_in_range(at: Vector2, rng: float) -> Array:
	var out := []
	for sp in spirits:
		if not sp.dead and sp.down_t <= 0.0 and sp.world.distance_to(at) <= rng:
			out.append(sp)
	return out


func shoot(origin_world: Vector2, muzzle: Vector2, target, damage: float, style: String, splash := 0.0, burn := Vector2.ZERO) -> void:
	var p := Projectile.new()
	_fx.add_child(p)
	p.setup(self, board, origin_world + Vector2(muzzle.x / board.view_scale, 0), -muzzle.y / board.view_scale, target, damage, style)
	p.splash = splash
	p.burn = burn
	p.position = board.proj(p.world) + Vector2(0, muzzle.y)
	AudioDirector.play_sfx("bolt", -12.0 if style == "bolt" else -14.0)


func add_lamp_shot(s) -> void:
	_fx.add_child(s)


func lamp_spark(at: Vector2) -> void:
	_add_fx("spark", at, Color.WHITE)


func ring_fx(at: Vector2, r: float, col: Color) -> void:
	_add_fx("ring", at, col, r)


func spark_fx(at: Vector2, style: String) -> void:
	_add_fx("spark", at, Color("#ffb238") if style == "bolt" else Color("#ffd27a"))


func _add_fx(kind: String, at: Vector2, col: Color, r := 100.0, txt := "") -> void:
	var f := Fx.new()
	_fx.add_child(f)
	f.setup(board, kind, at, col, r, txt)


## Oath of the Immortals: a spirit Char banished himself may heal him.
func char_kill(at: Vector2) -> void:
	if Run.has_oath("immortals") and Run.rng.randf() < Defs.IMMORTAL_CHANCE:
		Run.flame = minf(Run.max_flame, Run.flame + Defs.IMMORTAL_HEAL)
		_add_fx("text", at, Color("#ffd27a"), 100.0, "+%d" % int(Defs.IMMORTAL_HEAL))
		_update_hud()


## Oath of the Sixth Face: pick which face the selected die shows.
func _open_choose() -> void:
	var d = _selected
	if _sixth_used or d == null or d.placed or phase != Phase.PREP:
		return
	if _choose_card:
		_choose_card.queue_free()
	_choose_card = PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var h := Label.new()
	h.text = "Choose a face"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 40)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var seen := {}
	for i in d.faces.size():
		var f: String = d.faces[i]
		if seen.has(f):
			continue
		seen[f] = true
		var b := Button.new()
		b.text = Defs.FACE_INFO[Defs.base_face(f)]["name"] + "+".repeat(Defs.face_levels(f) - 1)
		b.custom_minimum_size = Vector2(200, 56)
		b.pressed.connect(_choose_face.bind(d, i))
		grid.add_child(b)
	box.add_child(grid)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(200, 52)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_close_choose)
	box.add_child(cancel)
	_choose_card.add_child(box)
	add_child(_choose_card)
	_choose_card.reset_size()
	_choose_card.position = (size - _choose_card.size) * 0.5


func _close_choose() -> void:
	if _choose_card:
		_choose_card.queue_free()
		_choose_card = null


func _choose_face(d, i: int) -> void:
	_close_choose()
	if not is_instance_valid(d) or d.placed or phase != Phase.PREP:
		return
	d.roll(i, 0.25)
	_sixth_used = true
	AudioDirector.play_sfx("tap", -6.0)
	_select(d)
	_update_hud()


## Ash Oaths, for each Ashes die still showing when the wave starts:
## Healing Ash may heal, Ash Buckets heals 1, Banked Fire adds damage.
func _warm_ashes() -> void:
	var left := 0
	for d in _dice:
		if not d.placed and d.face == "ashes":
			left += 1
	if left > 0 and Run.has_oath("ash_buckets"):
		Run.flame = minf(Run.max_flame, Run.flame + Defs.ASH_BUCKET_HEAL * left)
		_add_fx("text", Vector2(0, -110), Color("#ffd27a"), 100.0, "+%d" % int(Defs.ASH_BUCKET_HEAL * left))
	if left > 0 and Run.has_oath("banked_fire"):
		banked = minf(Defs.BANKED_CAP, Defs.BANKED_PER_ASH * left)
		_add_fx("text", Vector2(0, -140), Color("#ff8a4c"), 100.0, "+%d%% damage" % roundi(banked * 100.0))
	var heal := Run.face_mod("ashes", "heal")
	if heal <= 0.0:
		return
	var chance := Run.face_mod("ashes", "heal_chance")
	var n := 0
	for d in _dice:
		if d.placed or d.face != "ashes":
			continue
		var at := Vector2(-40.0 + 40.0 * n, -60.0 - 22.0 * n)
		n += 1
		if Run.rng.randf() < chance:
			Run.flame = minf(Run.max_flame, Run.flame + heal)
			_add_fx("text", at, Color("#ffd27a"), 100.0, "+%d" % int(heal))
		else:
			_add_fx("text", at, Color("#8a8078"), 100.0, "fizzle")


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
var _wall_at := Vector2.ZERO     ## where a dropped wall die would go (world)
var _wall_tan := Vector2.RIGHT
var _wall_hit = null             ## an existing wall it would level up


## Ember Wall: the nearest trail point to `local`, if a wall can go there.
## Returns -3 when it can (sets _wall_at/_wall_tan/_wall_hit), else -1.
func _wall_target(local: Vector2) -> int:
	var p: Vector2 = board.unproj(local)
	_wall_hit = null
	for w in board.walls:
		if is_instance_valid(w) and not w.broken and w.world.distance_to(p) < 40.0:
			if w.level >= 3:
				return -1
			_wall_hit = w
			return -3
	var best := 45.0
	var found := false
	for pts in board.paths:
		for k in range(1, pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(p, pts[k - 1], pts[k])
			var dd := q.distance_to(p)
			if dd < best and q.length() > Defs.WALL_MIN_R and q.length() < Defs.WALL_MAX_R:
				best = dd
				_wall_at = q
				_wall_tan = pts[k] - pts[k - 1]
				found = true
	if not found:
		return -1
	for w in board.walls:
		if is_instance_valid(w) and not w.broken and w.world.distance_to(_wall_at) < Defs.WALL_GAP:
			return -1
	return -3


func _build_wall(levels: int) -> void:
	if _wall_hit:
		for i in levels:
			_wall_hit.level_up()
		_add_fx("ring", _wall_hit.world, Color("#d9743a"), 50.0)
		return
	var w := EmberWall.new()
	_entities.add_child(w)
	w.setup(self, board, _wall_at, _wall_tan)
	for i in levels - 1:
		w.level_up()
	board.walls.append(w)
	_add_fx("ring", _wall_at, Color("#d9743a"), 50.0)


## Mire: a spot on a trail (like a Wall), or an existing patch to level up.
## Returns -4, or -1 if nowhere fits.
func _mire_target(local: Vector2) -> int:
	var p: Vector2 = board.unproj(local)
	_mire_hit = -1
	for i in board.mires.size():
		if board.mires[i]["world"].distance_to(p) < 45.0:
			if board.mires[i]["level"] >= 3:
				return -1
			_mire_hit = i
			return -4
	if _wall_target(local) != -3 or _wall_hit != null:
		return -1
	for m in board.mires:
		if m["world"].distance_to(_wall_at) < Defs.WALL_GAP * 1.5:
			return -1
	return -4


func _build_mire(levels: int) -> void:
	if _mire_hit >= 0:
		var m: Dictionary = board.mires[_mire_hit]
		m["level"] = mini(3, m["level"] + levels)
		_add_fx("ring", m["world"], Color("#8a6a3e"), 55.0)
		return
	board.mires.append({"world": _wall_at, "level": mini(3, levels)})
	_add_fx("ring", _wall_at, Color("#8a6a3e"), 55.0)


func _target_at(local: Vector2, face: String) -> int:
	if face == "wall":
		return _wall_target(local)
	if face == "mire":
		return _mire_target(local)
	if face in Defs.FIRE_FACES:
		return -2 if (board.is_fire_at(local) or char_unit.world.distance_to(board.unproj(local)) < 70.0) else -1
	var t: int = board.tile_at(local)
	return t if board.can_place(face, t) else -1


## Heals from dice on the fire fall off within a wave, so stacking healers
## can't outpace a whole wave of damage.
func _fire_heal(amount: float) -> void:
	Run.flame = minf(Run.max_flame, Run.flame + amount * maxf(Defs.FIRE_HEAL_FLOOR, 1.0 - Defs.FIRE_HEAL_FALLOFF * _fire_heals))
	_fire_heals += 1


func _try_place(d, local: Vector2) -> bool:
	if d == null or d.placed or d.is_rolling():
		return false
	var target := _target_at(local, d.face)
	if target == -1:
		return false
	if target == -2 and d.face == "pine":
		pine_logs += 1
		_fire_heal(Run.pine_heal() * (1.0 + Defs.PINE_PLUS_HEAL * (d.levels - 1)))
		_add_fx("ring", Vector2.ZERO, Color("#c98a4a"), 130.0)
	elif target == -2 and d.face == "reliquary":
		shield += Defs.RELIQUARY[mini(d.levels, 3) - 1]
		board.shield = shield
		_add_fx("ring", Vector2.ZERO, Color("#e8c66a"), 130.0)
	elif target == -2 and d.face == "ward":
		wards += d.levels
		_add_fx("ring", Vector2.ZERO, Color("#b9a8d8"), 130.0)
	elif target == -2:
		char_unit.kindle_up()
		_fire_heal(Run.kindle_heal())
		_add_fx("ring", Vector2.ZERO, Color("#fff0b0"), 130.0)
	elif target == -3:
		_build_wall(d.levels)
	elif target == -4:
		_build_mire(d.levels)
	else:
		_build_defense(d.face, target, d.levels)
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


func _build_defense(face: String, tile: int, levels := 1) -> void:
	var existing = board.tile_defense[tile]
	if existing:
		for i in levels:
			existing.level_up()
		_add_fx("ring", existing.world, Color("#ffb238"), 60.0)
		return
	var df := Defense.new()
	_entities.add_child(df)
	df.setup(self, board, face, tile)
	for i in levels - 1:
		df.level_up()
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
		if Run.flame <= _shift_cost() and _shift_cost() > 0.0:
			_hint.text = "Char's flame is too low to move a defense."
			return true
		_lifted = df
		board.lift_tile = tile
		_hint.text = "Tap an empty glowing tile to move the %s there%s.  Tap it again to cancel." % [
			Defs.FACE_INFO[df.kind]["name"], _cost_text()]
		AudioDirector.play_sfx("tap", -8.0)
		return true
	if tile == _lifted.tile:
		_drop_lift()
		_hint.text = _shift_hint()
		return true
	if not board.can_move_to(tile):
		return false
	var df = _lifted
	_drop_lift()
	board.tile_defense[df.tile] = null
	board.tile_defense[tile] = df
	df.move_to(tile)
	Run.flame -= _shift_cost()
	if _shift_free:   # Adjustment used; the Oath's paid move is still there
		_shift_free = false
		_shift_ready = wave > 0 and Run.has_oath("shifting_embers")
	else:
		_shift_ready = false
	_add_fx("ring", df.world, Color("#ffb238"), 60.0)
	AudioDirector.play_sfx("place", -3.0)
	_hint.text = "Moved.  Place your dice, then Fight!"
	_update_hud()
	return true


func _shift_cost() -> float:
	return 0.0 if _shift_free else Defs.SHIFT_COST


func _cost_text() -> String:
	return " (free)" if _shift_free else " (−%d flame)" % roundi(Defs.SHIFT_COST)


func _shift_hint() -> String:
	return "Tap a defense to move it%s." % _cost_text()


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
		if d.face in Defs.FIRE_FACES:
			_try_place(d, board.proj(Vector2.ZERO))
			return
		if d.face in ["wall", "mire"]:   # across a trail, ~230 out (a Mire a little farther)
			var spots := []
			for i in board.paths.size():
				spots.append(board.path_point(i, board.path_lengths[i] - (230.0 if d.face == "wall" else 300.0)))
			spots.shuffle()
			for s in spots:
				if _target_at(board.proj(s), d.face) in [-3, -4]:
					_try_place(d, board.proj(s))
					return
			d.placed = true   # nowhere left: let it go
			return
		var best := -1
		for i in board.tiles.size():
			var t = board.tile_defense[i]
			if t != null and t.kind == d.face and t.level < 3:
				best = i
				break
		if best == -1 and Defs.base_face(d.face) in Defs.SUPPORT_FACES:   # next to an existing defense
			for i in board.tiles.size():
				if board.tile_defense[i] == null and _has_neighbour(i):
					best = i
					break
		if best == -1:
			var order := range(board.tiles.size())   # tiles nearest the fire first
			order.sort_custom(func(x, y): return board.tiles[x].length() < board.tiles[y].length())
			for i in order:
				if board.tile_defense[i] == null:
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
		if not df.kind in Defs.SUPPORT_FACES and board.tile_group[df.tile] == board.tile_group[i]:
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
		if _try_pick_ember(local):   # embers first: they don't wait
			get_viewport().set_input_as_handled()
		elif _selected and phase == Phase.PREP:
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
	for i in mini(Run.riders.size(), Defs.CARAVAN_SEATS):   # a badge per riding member
		var id: String = Run.riders[i]
		var bv := DrawProxy.new()
		bv.position = Vector2(328 + i * 46, 18)
		bv.size = Vector2(40, 40)
		bv.draw_fn = _draw_badge.bind(id)
		bv.tooltip_text = Defs.CARAVAN[id]["name"]
		add_child(bv)
		_badges[id] = bv
		_badge_pulse[id] = 0.0
	_boss_bar = BossBar.new()
	add_child(_boss_bar)

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
	_parts_view = DrawProxy.new()
	_parts_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts_view.position = Vector2(0, -30)
	_parts_view.size = Vector2(150, 26)
	_parts_view.draw_fn = _draw_parts
	_parts_view.tooltip_text = "Spare parts"
	_roll_btn.add_child(_parts_view)
	_choose_btn = Button.new()   # Oath of the Sixth Face
	_choose_btn.text = "Choose"
	_choose_btn.custom_minimum_size = Vector2(130, 64)
	_choose_btn.pressed.connect(_open_choose)
	_choose_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_choose_btn.visible = false
	_tray.add_child(_choose_btn)
	var fight_gap := Control.new()   # keeps Fight! clear of the dice and Reroll, against mis-taps
	fight_gap.custom_minimum_size = Vector2(48, 0)
	fight_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_child(fight_gap)
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
	_night_label.text = "Leg %d · Night %d/%d" % [Defs.leg_of(Run.night) + 1, Run.night + 1, Defs.NIGHTS]
	_wave_label.text = "%s  ·  Wave %d/%d" % [stop_name, mini(wave + 1, Defs.WAVES_PER_NIGHT), Defs.WAVES_PER_NIGHT]
	if ambush:
		_wave_label.text = "Fog Camp  ·  Ambush"
	elif mod != "":
		_wave_label.text += "  ·  " + Defs.WAVE_MODS[mod]["name"]
	if Run.shrine_curse:
		_wave_label.text += "  ·  Shrine's Wrath"
	if Run.coach_haunt and not ambush:
		_wave_label.text += "  ·  Lost Passengers"
	var prep := phase == Phase.PREP
	_roll_btn.text = "Roll (%d)" % _rerolls
	_roll_btn.disabled = not prep or _rerolls <= 0
	_fight_btn.disabled = not prep
	_roll_btn.visible = prep
	_parts_view.visible = prep and Run.has_rider("tinker")
	_parts_view.queue_redraw()
	_choose_btn.visible = prep and Run.has_oath("sixth_face")
	_choose_btn.disabled = _sixth_used or _selected == null or _selected.placed or _selected.is_rolling()
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


## Terry, the Tinker: a cog, one pip per part toward the next reroll, and
## "+N" for rerolls already built for next wave. Pulses on a new part.
func _draw_parts(ci: Control) -> void:
	var ready := Run.spare_parts / Defs.TINKER_PARTS
	var rem := Run.spare_parts % Defs.TINKER_PARTS
	var col := Color("#d9cbb8")
	var cy := 13.0
	var x0 := ci.size.x / 2 - 22.0 - Defs.TINKER_PARTS * 9.0
	Icons.draw(ci, "tinker", Vector2(x0, cy), 22.0 * (1.0 + 0.25 * _parts_pulse), Style.ACCENT if ready > 0 else col)
	for i in Defs.TINKER_PARTS:
		var p := Vector2(x0 + 22.0 + i * 18.0, cy)
		ci.draw_circle(p, 6.0, Color(0, 0, 0, 0.45))
		if i < rem:
			ci.draw_circle(p, 4.5 + (1.5 * _parts_pulse if i == rem - 1 else 0.0), col)
	if ready > 0:
		ci.draw_string(Style.BODY_FONT, Vector2(x0 + 14.0 + Defs.TINKER_PARTS * 18.0, cy + 6.0), "+%d roll" % ready, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Style.ACCENT)


## A riding member's badge: their icon on a warm disc. It rings when their
## ability fires; Hella's dims once her scare is spent, and Leopold's fills
## like a clock toward the lamp's next volley.
func _draw_badge(ci: CanvasItem, id: String) -> void:
	var c := Vector2(20, 18)
	var p: float = _badge_pulse.get(id, 0.0)
	var on := not (id == "hound" and _hella_left <= 0) and not (id == "priest" and Run.rites_used)
	ci.draw_circle(c + Vector2(0, 2), 19.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, 18.0, Color("#3a2418"))
	ci.draw_circle(c + Vector2(-2, -3), 13.0, Color("#5a3820", 0.8))
	if id == "lamplighter" and _lamp != null and fighting:
		var f: float = _lamp.progress()
		ci.draw_arc(c, 15.0, -PI / 2, -PI / 2 + TAU * f, 32, Color("#fff2c8", 0.55), 3.0, true)
	ci.draw_arc(c, 18.0, 0, TAU, 40, Style.ACCENT.lerp(Color.WHITE, p * 0.6) if on else Color(0.4, 0.34, 0.3), 2.0, true)
	if p > 0.0:
		ci.draw_arc(c, 18.0 + 12.0 * (1.0 - p), 0, TAU, 40, Color("#ffd58f", p), 2.0, true)
	var col: Color = Color("#ffe3b0").lerp(Color.WHITE, p) if on else Color(0.55, 0.5, 0.45, 0.6)
	Icons.draw(ci, Defs.CARAVAN[id]["icon"], c, 24.0 * (1.0 + 0.15 * sin(PI * p)), col)


## A riding member's figure hops and glows (their ability just fired).
func member_react(id: String) -> void:
	if _figures.has(id):
		_figures[id].react()
	if _badges.has(id):
		_badge_pulse[id] = 1.0
