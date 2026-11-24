extends Node2D
## Char beside the campfire. Shoots small flame bolts at the spirit nearest
## the fire; grows hotter with each Kindle (★) die; flinches when hurt.
## Uses the 2.5D art from the concept sheet (assets/char/*.svg).

const Defs := preload("res://scripts/game/defs.gd")
const FACES := ["open", "determined", "hurt", "happy"]
const ART_SCALE := 2.0   ## SVGs rasterized at 2x

var world := Vector2(-78, 42)
var kindle := 0          ## 0..3 this night
var battle
var board

var _tex := {}
var _sprite := Sprite2D.new()
var _t := 0.0
var _cool := 0.6
var chill := 0.0          ## 0..1, attack slow from nearby Mist Wisps
var _hurt := 0.0
var _kick := 0.0
var _mood := "open"


func setup(b, bd) -> void:
	battle = b
	board = bd
	position = board.proj(world)


func _ready() -> void:
	for f in FACES:
		var img := Image.new()
		img.load_svg_from_string(Defs.outfit_svg(FileAccess.get_file_as_string("res://assets/char/char_%s.svg" % f), Profile.outfit), ART_SCALE)
		_tex[f] = ImageTexture.create_from_image(img)
	_sprite.texture = _tex["open"]
	_sprite.centered = false
	add_child(_sprite)


func stats() -> Dictionary:
	var s: Dictionary = Defs.CHAR_STATS[kindle].duplicate()
	if Run.has_oath("simplicity"):
		s["rate"] *= Defs.SIMPLICITY_RATE
	if Run.has_oath("roaring_forge"):
		var n := 0
		for d in battle.defenses:
			if is_instance_valid(d) and d.kind == "bellows":
				n += 1
		s["rate"] *= 1.0 + Defs.FORGE_CHAR_RATE * n
	if Run.has_oath("urgency"):
		s["rate"] *= Defs.URGENCY_RATE
		s["damage"] *= Defs.URGENCY_DAMAGE
	if Run.flame < Run.max_flame * Defs.COMEBACK_AT:   # cornered, Char fights harder
		s["rate"] *= Defs.COMEBACK_RATE
	if battle.heavy:   # lull reward: Heavy Support Fire
		s["damage"] *= Defs.HEAVY_DAMAGE
		s["rate"] *= Defs.HEAVY_RATE
		s["range"] *= Defs.HEAVY_RANGE
	return s


func set_mood(m: String) -> void:
	_mood = m


func hurt() -> void:
	_hurt = 0.6


func kindle_up() -> void:
	kindle = mini(kindle + 1, 3)
	_kick = 1.0


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta)
	_kick = maxf(0.0, _kick - delta * 2.0)
	var face := "hurt" if _hurt > 0.0 else _mood
	_sprite.texture = _tex[face]
	# Art is 160x252 (viewBox), feet at y≈246, centre x=100 (viewBox x 20..180 -> 80).
	var size_k: float = 0.42 * board.view_scale * (1.0 + 0.06 * kindle + 0.15 * sin(_kick * PI))
	var bob: float = sin(_t * 2.4) * 2.5 * board.view_scale
	_sprite.scale = Vector2.ONE * size_k / ART_SCALE * Vector2(1.0 + 0.02 * sin(_t * 2.4), 1.0)
	_sprite.position = Vector2(-80.0 * size_k, -246.0 * size_k + bob)
	var hue := Color(1, 1, 1)
	if chill > 0.0:
		hue = hue.lerp(Color(0.7, 0.85, 1.25), 0.6)
	if _hurt > 0.0:
		hue = hue.lerp(Color(1.4, 0.6, 0.6), _hurt)
	_sprite.modulate = hue
	queue_redraw()
	if not battle.fighting:
		return
	_cool -= delta
	if _cool <= 0.0:
		var st := stats()
		var target = battle.pick_target(world, st["range"])
		if target:
			var muzzle := Vector2(0, -150.0 * size_k)
			if battle.heavy:
				battle.shoot(world, muzzle, target, st["damage"] * (1.0 + battle.banked), "mortar", Defs.HEAVY_SPLASH)
			else:
				battle.shoot(world, muzzle, target, st["damage"] * (1.0 + battle.banked), "char")
			_cool = 1.0 / (st["rate"] * (1.0 - chill))


func _draw() -> void:
	var v: float = board.view_scale
	draw_set_transform(Vector2(0, 2 * v), 0.0, Vector2(1, board.K))
	draw_circle(Vector2.ZERO, 26 * v, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
