extends Node2D
## Char beside the campfire. Shoots small flame bolts at the spirit nearest
## the fire; grows hotter with each Kindle (★) die; flinches when hurt.
## Uses the 2.5D art from the concept sheet (assets/char/*.svg).

const Defs := preload("res://scripts/game/defs.gd")
const OutfitArt := preload("res://scripts/game/outfit_art.gd")
const FACES := ["open", "determined", "hurt", "happy"]
const ART_SCALE := 2.0   ## SVGs rasterized at 2x

var world := Vector2(-78, 42)
var kindle := 0          ## 0..3 this night
var battle
var board

var _tex := {}
var _rig := Node2D.new()          ## holds the body sprite (and wings), in art pixels
var _sprite := Sprite2D.new()
var _wings: Array = []            ## [shoulder, wrist] Node2D pairs, left then mirrored right
var _fold := 1.0                  ## 0 spread (fighting) .. 1 folded (between waves)
const FOLD_SHOULDER := 0.08       ## radians the forearm swings up and in when folded
const FOLD_WRIST := -1.25         ## radians the hand swings down along the body
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
		img.load_svg_from_string(Defs.outfit_svg(FileAccess.get_file_as_string("res://assets/char/char_%s.svg" % f), Profile.outfit, true), ART_SCALE)
		_tex[f] = ImageTexture.create_from_image(img)
	add_child(_rig)
	if Profile.outfit == "angel":
		_build_wings()
	_sprite.texture = _tex["open"]
	_sprite.centered = false
	_rig.add_child(_sprite)


## The Seraph Knight's wings: per side a forearm piece turning at the shoulder
## and a hand piece turning at the wrist (behind the forearm), so they fold.
func _build_wings() -> void:
	var tex := {}
	for part in ["inner", "outer"]:
		var img := Image.new()
		img.load_svg_from_string(OutfitArt.wing_piece(OutfitArt.WING_INNER if part == "inner" else OutfitArt.WING_OUTER), ART_SCALE)
		tex[part] = ImageTexture.create_from_image(img)
	var px := func(v: Vector2) -> Vector2: return (v + Vector2(40, 0)) * ART_SCALE   # wide canvas starts at x = -40
	for side in [1.0, -1.0]:
		var holder := Node2D.new()
		holder.position = Vector2(px.call(Vector2(100, 0)).x, 0)
		holder.scale.x = side
		_rig.add_child(holder)
		var shoulder := Node2D.new()
		shoulder.position = px.call(OutfitArt.WING_SHOULDER) - holder.position
		holder.add_child(shoulder)
		var wrist := Node2D.new()
		wrist.position = px.call(OutfitArt.WING_WRIST) - px.call(OutfitArt.WING_SHOULDER)
		shoulder.add_child(wrist)
		var outer := Sprite2D.new()
		outer.texture = tex["outer"]
		outer.centered = false
		outer.position = -px.call(OutfitArt.WING_WRIST)
		wrist.add_child(outer)
		var inner := Sprite2D.new()
		inner.texture = tex["inner"]
		inner.centered = false
		inner.position = -px.call(OutfitArt.WING_SHOULDER)
		shoulder.add_child(inner)
		_wings.append([shoulder, wrist])


func stats() -> Dictionary:
	var s: Dictionary = Defs.CHAR_STATS[kindle].duplicate()
	if Run.has_oath("simplicity"):
		s["rate"] *= Defs.SIMPLICITY_RATE
	if Run.has_oath("roaring_forge"):
		var n := 0
		for d in battle.defenses:
			if is_instance_valid(d) and d.kind == "bellows":
				n += 1
		s["rate"] *= 1.0 + Defs.FORGE_CHAR_RATE * mini(n, Defs.FORGE_MAX_BELLOWS)
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
	_rig.scale = Vector2.ONE * size_k / ART_SCALE * Vector2(1.0 + 0.02 * sin(_t * 2.4), 1.0)
	var half_w: float = _sprite.texture.get_width() / ART_SCALE * 0.5   # 80, or 140 with wings
	_rig.position = Vector2(-half_w * size_k, -246.0 * size_k + bob)
	if not _wings.is_empty():
		_fold = move_toward(_fold, 0.0 if battle.fighting else 1.0, delta * 1.6)
		var f := smoothstep(0.0, 1.0, _fold)
		var flap := sin(_t * 2.4) * 0.04 * (1.0 - f)
		for w in _wings:
			w[0].rotation = FOLD_SHOULDER * f + flap
			w[1].rotation = FOLD_WRIST * f - flap
			w[1].scale.x = lerpf(1.0, 0.8, f)
	var hue := Color(1, 1, 1)
	if chill > 0.0:
		hue = hue.lerp(Color(0.7, 0.85, 1.25), 0.6)
	if _hurt > 0.0:
		hue = hue.lerp(Color(1.4, 0.6, 0.6), _hurt)
	_rig.modulate = hue
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
