extends Node
## Owns the title/menu soundscape: the looping music, crickets and campfire,
## plus the menu's occasional fire swells. Autoloaded, so it survives scene
## changes and the music never restarts between the title and the menu.

signal swell_changed(level: float)  ## 0 = calm fire, 1 = peak of a swell

const MUSIC := preload("res://assets/audio/campfire_lullaby.ogg")
## Same key, tempo and length as MUSIC; plays in sync and fades in during waves.
const TENSION := preload("res://assets/audio/campfire_tension.ogg")
const FIRE := preload("res://assets/audio/fire_crackle.ogg")
const CRICKETS := preload("res://assets/audio/crickets.ogg")

const SILENT_DB := -60.0
const MUSIC_DB := -5.0
const CRICKETS_DB := -11.0
const FIRE_SOLO_DB := -1.0   ## the opening seconds, fire on its own
const FIRE_BED_DB := -10.0   ## tucked under the music
const FIRE_PEAK_DB := -4.0   ## top of a swell
const CUTOFF_CALM := 3600.0  ## fire low-pass while calm (soft, distant)
const CUTOFF_PEAK := 12000.0 ## opens up as it flares: crisper crackles

const SWELL_RISE := 3.2
const SWELL_HOLD := 1.4
const SWELL_FALL := 5.0
const SWELL_GAP := Vector2(16.0, 30.0)  ## random seconds between swells

var swell_level := 0.0
var _music: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _tense := false
var _fire: AudioStreamPlayer
var _fire_layer: AudioStreamPlayer  ## same loop, other offset: thickens swells
var _crickets: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _fire_base_db := SILENT_DB
var _swells_on := false
var _swell_timer := Timer.new()
var _swell_tween: Tween
var _tweens := {}
var _sfx := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0

const SFX_NAMES := ["dice_roll", "place", "bolt", "flare", "pop", "hurt", "tap", "chime", "wave", "button"]
const SFX_VOICES := 12


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The Fire bus (with its low-pass) lives in default_bus_layout.tres. Adding
	# a bus at runtime silences ALL audio in Godot 4.3's web build.
	var bus := AudioServer.get_bus_index("Fire")
	_lowpass = AudioServer.get_bus_effect(bus, 0)

	_music = _make_player(MUSIC, "Music")
	_tension = _make_player(TENSION, "Music")
	_crickets = _make_player(CRICKETS, "Effects")
	_fire = _make_player(FIRE, "Fire")
	_fire_layer = _make_player(FIRE, "Fire")

	for n in SFX_NAMES:
		_sfx[n] = load("res://assets/audio/sfx/%s.ogg" % n)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_sfx_pool.append(p)
	_load_volumes()

	_swell_timer.one_shot = true
	_swell_timer.timeout.connect(swell)
	add_child(_swell_timer)


func _make_player(stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	return p


# ------------------------------------------------------------ title sequence
func start_fire(fade := 0.35) -> void:
	if _fire.playing:
		return
	_fire.play()
	_fire_layer.play(16.0)
	_fire_base_db = FIRE_SOLO_DB
	_fade(_fire, FIRE_SOLO_DB, fade)


func start_crickets(fade := 2.5) -> void:
	if _crickets.playing:
		return
	_crickets.play(randf() * 20.0)
	_fade(_crickets, CRICKETS_DB, fade)


func start_music(fade := 1.0) -> void:
	if _music.playing:
		return
	_music.play()
	_tension.play()   # silent until set_tension(true); started together to stay in step
	_fade(_music, MUSIC_DB, fade)
	# The fire steps back so the music can lead.
	_fire_base_db = FIRE_BED_DB
	_fade(_fire, FIRE_BED_DB, 3.0)


func is_music_playing() -> bool:
	return _music.playing


## Crossfades to the suspenseful version of the music (waves) and back.
func set_tension(on: bool, seconds := 2.5) -> void:
	if on == _tense or not _music.playing:
		return
	_tense = on
	_fade(_tension, MUSIC_DB if on else SILENT_DB, seconds)
	_fade(_music, SILENT_DB if on else MUSIC_DB, seconds * (1.4 if on else 0.8))


# ------------------------------------------------------------ menu swells
## Turns the occasional fire swell on (main menu) or off.
func set_swells_enabled(on: bool, first_delay := 7.0) -> void:
	_swells_on = on
	if on:
		_swell_timer.start(first_delay)
	else:
		_swell_timer.stop()


## One swell: the fire breathes up, crackles brighten, then settles back.
func swell() -> void:
	if _swell_tween and _swell_tween.is_running():
		return
	_swell_tween = create_tween()
	_swell_tween.tween_method(_set_swell, 0.0, 1.0, SWELL_RISE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_swell_tween.tween_interval(SWELL_HOLD)
	_swell_tween.tween_method(_set_swell, 1.0, 0.0, SWELL_FALL) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_swell_tween.finished.connect(func():
		if _swells_on:
			_swell_timer.start(randf_range(SWELL_GAP.x, SWELL_GAP.y)))


func _set_swell(v: float) -> void:
	swell_level = v
	_kill_fade(_fire)
	_fire.volume_db = lerpf(_fire_base_db, FIRE_PEAK_DB, v)
	# The second layer only joins near the top, adding extra pops.
	_fire_layer.volume_db = linear_to_db(maxf(v * v, 0.0001)) + FIRE_PEAK_DB - 3.0
	# Perceptually even sweep of the filter.
	_lowpass.cutoff_hz = CUTOFF_CALM * pow(CUTOFF_PEAK / CUTOFF_CALM, v)
	swell_changed.emit(v)


# ------------------------------------------------------------ sound effects
## Plays a short effect with a little pitch variety so repeats don't grate.
func play_sfx(sfx_name: String, db := 0.0, pitch_jitter := 0.06) -> void:
	if not _sfx.has(sfx_name) or _sfx[sfx_name] == null:
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


# ------------------------------------------------------------ volume settings
## Player-facing volume sliders, 0..1 per bus. Saved to user://settings.cfg.
const VOLUME_BUSES := ["Master", "Music", "Effects"]
const SETTINGS_PATH := "user://settings.cfg"
var _volumes := {"Master": 1.0, "Music": 1.0, "Effects": 1.0}


func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: String, v: float, save := true) -> void:
	v = clampf(v, 0.0, 1.0)
	_volumes[bus] = v
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	# Squared curve so the slider feels even to the ear; 0 is true silence.
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		for b in VOLUME_BUSES:
			cfg.set_value("audio", b, _volumes[b])
		cfg.save(SETTINGS_PATH)


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SETTINGS_PATH) == OK
	for b in VOLUME_BUSES:
		var v: float = cfg.get_value("audio", b, _volumes[b]) if ok else _volumes[b]
		set_volume(b, v, false)


# ------------------------------------------------------------ helpers
func _fade(p: AudioStreamPlayer, to_db: float, seconds: float) -> void:
	_kill_fade(p)
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tweens[p] = t


func _kill_fade(p: AudioStreamPlayer) -> void:
	if _tweens.has(p) and _tweens[p].is_valid():
		_tweens[p].kill()
	_tweens.erase(p)
