extends Control
## Runs one game from Play to the end screen:
##   map (choose camp) -> night battle (3 waves) -> dawn (pick passive) -> map ...
##   -> after night 3, or if the flame goes out: end screen (Play again / Main Menu).

const Defs := preload("res://scripts/game/defs.gd")
const NightSky := preload("res://scripts/title/night_sky.gd")
const MapScreen := preload("res://scripts/game/map_screen.gd")
const Battle := preload("res://scripts/game/battle.gd")
const DawnScreen := preload("res://scripts/game/dawn_screen.gd")
const EndScreen := preload("res://scripts/game/end_screen.gd")

const TITLE_SCENE := "res://scenes/title_screen.tscn"

var _screen: Control
var _fade := ColorRect.new()
var _sky: Control


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
	Run.new_run()
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
	var m := MapScreen.new()
	m.stop_chosen.connect(_on_stop_chosen)
	return m


func _on_stop_chosen(id: String) -> void:
	AudioDirector.play_sfx("tap", -6.0)
	Run.chosen_stops.append(id)
	var b := Battle.new()
	b.night_over.connect(_on_night_over)
	b.quit_to_menu.connect(_to_title)
	_show(b)


func _on_night_over(survived: bool) -> void:
	if not survived:
		_end(false)
		return
	if Run.night + 1 >= Defs.NIGHTS:
		_end(true)
		return
	Run.flame = minf(Run.max_flame, Run.flame + Defs.DAWN_HEAL)
	var d := DawnScreen.new()
	d.passive_chosen.connect(_on_passive)
	_show(d)


func _on_passive(id: String) -> void:
	Run.add_passive(id)
	Run.night += 1
	_show(_make_map())


func _end(won: bool) -> void:
	var e := EndScreen.new()
	e.won = won
	e.play_again.connect(func():
		Run.new_run()
		_show(_make_map()))
	e.main_menu.connect(_to_title)
	_show(e)
	if Run.autoplay:
		print("RESULT won=%s nights=%d flame=%d/%d banished=%d stops=%s passives=%s" % [won, Run.nights_survived,
			roundi(Run.flame), roundi(Run.max_flame), Run.spirits_banished, Run.chosen_stops, Run.passives])
		if "--quit-at-end" in OS.get_cmdline_user_args():
			get_tree().quit()


func _to_title() -> void:
	Engine.time_scale = 1.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.4)
	await t.finished
	get_tree().change_scene_to_file(TITLE_SCENE)
