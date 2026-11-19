extends Control
## Runs one game from Play to the end screen:
##   map (choose camp) -> night battle (3 waves) -> dawn (rest) -> map ...
##   -> after night 3, or if the flame goes out: end screen (Play again / Main Menu).

const Defs := preload("res://scripts/game/defs.gd")
const NightSky := preload("res://scripts/title/night_sky.gd")
const MapScreen := preload("res://scripts/game/map_screen.gd")
const Battle := preload("res://scripts/game/battle.gd")
const DawnScreen := preload("res://scripts/game/dawn_screen.gd")
const EndScreen := preload("res://scripts/game/end_screen.gd")
const LoadoutScreen := preload("res://scripts/game/loadout_screen.gd")
const OathsMenu := preload("res://scripts/ui/oaths_menu.gd")
const FogEvent := preload("res://scripts/game/fog_event.gd")
const ShrineEvent := preload("res://scripts/game/shrine_event.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"

var _screen: Control
var _fade := ColorRect.new()
var _sky: Control
var _ambush := false   ## Fog Cloud: fight a Mist Wisp ambush before the night


func _ready() -> void:
	# Clicks on the battle board must reach Battle._unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = NightSky.new()
	add_child(_sky)
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	AudioDirector.set_swells_enabled(false)
	AudioDirector.start_fire(0.5)
	AudioDirector.start_crickets(1.0)
	AudioDirector.start_music(1.0)
	if not (Run.resume and Run.load_run()):
		Run.clear_save()
		Run.new_run()
	Run.resume = false
	_show(_make_map(), false)


func _show(screen: Control, fade := true) -> void:
	if fade:
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.35)
		await t.finished
	if _screen:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
	move_child(_fade, -1)
	_sky.visible = not (screen is Battle)
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.45)


func _make_map() -> Control:
	Run.checkpoint()
	var m := MapScreen.new()
	m.stop_chosen.connect(_on_stop_chosen)
	m.save_and_quit.connect(_save_and_quit)
	m.oaths_requested.connect(show_oaths)
	return m


func _on_stop_chosen(id: String) -> void:
	Run.chosen_stops.append(id)
	Run.layout_seed = Run.rng.randi()   # tonight's map, known before the loadout
	_ambush = false
	Run.shrine_curse = false
	# Road events from night 2 on. Each rolls its own chance; at most one per night.
	var events := []
	if Run.night > 0:
		if Run.rng.randf() < Defs.FOG_CHANCE:
			events.append(FogEvent)
		if not Run.shrine_seen and Run.rng.randf() < Defs.SHRINE_CHANCE:
			events.append(ShrineEvent)
	if events.is_empty():
		_to_loadout()
		return
	var ev: Script = events[Run.rng.randi() % events.size()]
	if ev == ShrineEvent:
		Run.shrine_seen = true
	var e = ev.new()
	e.done.connect(func(ambush: bool):
		_ambush = ambush
		_to_loadout())
	_show(e)


func _to_loadout() -> void:
	var l := LoadoutScreen.new()
	l.confirmed.connect(_start_battle)
	l.oaths_requested.connect(show_oaths)
	_show(l)


## Opens the Oaths menu over whatever is showing.
func show_oaths() -> void:
	add_child(OathsMenu.new())


func _start_battle() -> void:
	var b := Battle.new()
	b.ambush = _ambush
	b.night_over.connect(_on_ambush_over if _ambush else _on_night_over)
	b.save_and_quit.connect(_save_and_quit)
	b.abandoned.connect(_abandon)
	b.oaths_requested.connect(show_oaths)
	_show(b)


func _on_night_over(survived: bool) -> void:
	if not survived:
		_end(false)
		return
	if Run.night + 1 >= Defs.NIGHTS:
		_end(true)
		return
	Run.flame = minf(Run.max_flame, Run.flame + Run.dawn_heal())
	var d := DawnScreen.new()
	d.continued.connect(_on_dawn_done)
	_show(d)


## The Fog Cloud ambush is over: heal, then the real night starts (same loadout).
func _on_ambush_over(survived: bool) -> void:
	_ambush = false
	if not survived:
		_end(false)
		return
	Run.flame = minf(Run.max_flame, Run.flame + Defs.CAMP_HEAL)
	_start_battle()


func _on_dawn_done() -> void:
	Run.night += 1
	_show(_make_map())


func _save_and_quit() -> void:
	Run.save_run()
	_to_title()


func _abandon() -> void:
	Run.clear_save()
	_to_title()


func _end(won: bool) -> void:
	Run.clear_save()
	var e := EndScreen.new()
	e.won = won
	e.play_again.connect(func():
		Run.new_run()
		Run.clear_save()
		_show(_make_map()))
	e.main_menu.connect(_to_title)
	_show(e)
	if Run.autoplay:
		print("RESULT won=%s nights=%d flame=%d/%d banished=%d stops=%s" % [won, Run.nights_survived,
			roundi(Run.flame), roundi(Run.max_flame), Run.spirits_banished, Run.chosen_stops])
		if "--quit-at-end" in OS.get_cmdline_user_args():
			get_tree().quit()


func _to_title() -> void:
	Engine.time_scale = 1.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.4)
	await t.finished
	get_tree().change_scene_to_file(TITLE_SCENE)
