extends Control
## Opening sequence and main menu, in one scene so the fire, title and music
## carry straight through:
##   0.0s  fire crackle starts (dark screen)
##   1.5s  campfire slowly fades in (3.5s), crickets start
##   2.0s  music starts (calm lullaby, loops every 2 minutes)
##   3.0s  title slowly fades in (3.5s); at 5.2s "Tap or Click Anywhere to Play"
##   tap   title rises and glows, fire settles low, menu fades in; the fire
##         swells now and then while the menu is open.
## Run with `-- --demo` to auto-play the sequence (used for preview videos).

const NightSky := preload("res://scripts/title/night_sky.gd")
const Campfire := preload("res://scripts/title/campfire.gd")
const GlowTitle := preload("res://scripts/title/glow_title.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const Style := preload("res://scripts/ui/ui_style.gd")

const T_FIRE_VISUAL := 1.5
const T_MUSIC := 2.0
const T_TITLE := 3.0
const T_PROMPT := 5.2
const FIRE_FADE := 3.5   ## seconds for the campfire to fade in
const TITLE_FADE := 3.5  ## seconds for the title to fade in
const PROMPT_FADE := 2.0

enum Stage { GATE, INTRO, TITLE, MENU }

var _stage := Stage.INTRO
var _menu_t := 0.0  ## 0 = title layout, 1 = menu layout (animated)
var _clock := 0.0
var _sky: Control
var _fire: Node2D
var _title: Control
var _prompt: Label
var _menu: Control
var _vignette: TextureRect
var _intro: Tween
var _fade: ColorRect

const RUN_SCENE := "res://scenes/run.tscn"


func _ready() -> void:
	# Let taps/clicks fall through to _unhandled_input (the full-screen root
	# would otherwise swallow them).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = NightSky.new()
	add_child(_sky)
	_fire = Campfire.new()
	_fire.modulate.a = 0.0
	add_child(_fire)
	_vignette = _make_vignette()
	add_child(_vignette)
	_title = GlowTitle.new()
	_title.modulate.a = 0.0
	add_child(_title)
	_prompt = _make_prompt()
	add_child(_prompt)
	_menu = MainMenu.new()
	add_child(_menu)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	resized.connect(_layout)
	AudioDirector.swell_changed.connect(func(v): _fire.swell = v)
	_menu.play_requested.connect(_start_game)
	_layout.call_deferred()
	if AudioDirector.is_music_playing():
		_return_to_menu()  # back from a run: skip the intro
		return
	if OS.has_feature("web"):
		_show_gate()  # browsers only allow sound after a tap
		return
	_run_intro()
	if "--demo" in OS.get_cmdline_user_args():
		_run_demo()


## Web only: a quiet "Tap to begin" so the opening fire crackle can be heard.
func _show_gate() -> void:
	_stage = Stage.GATE
	_prompt.text = "Tap or Click to Begin"
	_prompt.modulate.a = 0.85


func _run_intro() -> void:
	AudioDirector.start_fire()
	_intro = create_tween().set_parallel()
	_intro.tween_callback(AudioDirector.start_crickets).set_delay(T_FIRE_VISUAL)
	_intro.tween_property(_fire, "modulate:a", 1.0, FIRE_FADE).set_delay(T_FIRE_VISUAL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro.tween_callback(AudioDirector.start_music).set_delay(T_MUSIC)
	_intro.tween_property(_title, "modulate:a", 1.0, TITLE_FADE).set_delay(T_TITLE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro.tween_callback(func(): _stage = Stage.TITLE).set_delay(T_TITLE)
	_intro.tween_property(_prompt, "modulate:a", 0.85, PROMPT_FADE).set_delay(T_PROMPT)


func _process(delta: float) -> void:
	_clock += delta
	# Title breathes gently; brighter in the menu and when the fire swells.
	var breathe := 0.5 + 0.5 * sin(_clock * 1.3)
	_title.glow = lerpf(0.75, 1.05, _menu_t) + 0.12 * breathe + 0.35 * AudioDirector.swell_level
	if _stage == Stage.TITLE and not (_intro and _intro.is_running()):
		_prompt.modulate.a = 0.55 + 0.3 * (0.5 + 0.5 * sin(_clock * 2.2))


func _layout() -> void:
	var s := size
	var fire_scale := lerpf(1.0, 0.82, _menu_t)
	_fire.scale = Vector2.ONE * fire_scale
	_fire.position = Vector2(s.x / 2, lerpf(s.y * 0.74, s.y + 20.0, _menu_t))
	var ts := lerpf(1.0, 0.78, _menu_t)
	_title.scale = Vector2.ONE * ts
	_title.position = Vector2(s.x / 2, lerpf(s.y * 0.29, s.y * 0.17, _menu_t)) - _title.size / 2
	_prompt.reset_size()
	_prompt.position = Vector2((s.x - _prompt.size.x) / 2, s.y * 0.89)
	_vignette.size = s
	if _fade:
		_fade.size = s


# ------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if _stage == Stage.MENU:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _stage == Stage.GATE:
		_stage = Stage.INTRO
		var t := create_tween()
		t.tween_property(_prompt, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): _prompt.text = "Tap or Click Anywhere to Play")
		_run_intro()
	elif _stage == Stage.INTRO:
		_skip_intro()
	else:
		_open_menu()


## A tap during the intro jumps straight to the finished title screen.
func _skip_intro() -> void:
	if _intro:
		_intro.kill()
	AudioDirector.start_crickets(1.0)
	AudioDirector.start_music(0.8)
	var t := create_tween().set_parallel()
	t.tween_property(_fire, "modulate:a", 1.0, 0.4)
	t.tween_property(_title, "modulate:a", 1.0, 0.4)
	t.tween_property(_prompt, "modulate:a", 0.85, 0.4)
	_stage = Stage.TITLE


func _open_menu() -> void:
	_stage = Stage.MENU
	var t := create_tween().set_parallel()
	t.tween_property(_prompt, "modulate:a", 0.0, 0.3)
	t.tween_method(_set_menu_t, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_menu.appear(0.55)
	AudioDirector.set_swells_enabled(true)


func _return_to_menu() -> void:
	_fire.modulate.a = 1.0
	_title.modulate.a = 1.0
	_stage = Stage.MENU
	_set_menu_t(1.0)
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
	_menu.appear(0.2)
	AudioDirector.set_swells_enabled(true)


## Play: fade to black, then into the run.
func _start_game() -> void:
	AudioDirector.set_swells_enabled(false)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.6)
	await t.finished
	get_tree().change_scene_to_file(RUN_SCENE)


func _set_menu_t(v: float) -> void:
	_menu_t = v
	_layout()


# ------------------------------------------------------------ builders
func _make_prompt() -> Label:
	var l := Label.new()
	l.text = "Tap or Click Anywhere to Play"
	l.add_theme_font_override("font", Style.BODY_FONT)
	l.add_theme_font_size_override("font_size", 25)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.7)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.55)
	tex.fill_to = Vector2(1.05, 0.55)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ------------------------------------------------------------ preview autopilot
func _run_demo() -> void:
	var steps := [
		[9.0, func(): _open_menu()],
		[12.2, func(): _menu._buttons["Unlocks"].grab_focus()],
		[13.0, func(): _menu._on_pick("Unlocks")],
		[15.4, func(): _menu._close_card()],
		[16.6, func(): _menu._buttons["Credits"].grab_focus()],
		[17.3, func(): _menu._on_pick("Credits")],
		[21.0, func(): _menu._close_card()],
		[22.0, _demo_swell],
	]
	for st in steps:
		get_tree().create_timer(st[0]).timeout.connect(st[1])


func _demo_swell() -> void:
	AudioDirector.set_swells_enabled(false)
	AudioDirector.swell()
