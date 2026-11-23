extends Node2D
## Leopold, the Lamplighter's Lit Lamp: an iron lamp on a post beside Char.
## During a wave it fires a ring of Defs.LAMP_SHOTS unaimed white shots every
## Defs.LAMP_EVERY seconds; the ring turns a little each volley so no trail
## sits in a blind spot forever.

const Defs := preload("res://scripts/game/defs.gd")
const LampShot := preload("res://scripts/game/lamp_shot.gd")

var world := Vector2(-122, 24)
var battle
var board
var _cool := 1.5
var _turn := 0.0
var _flash := 0.0   # 1 just after a volley, fading
var _t := 0.0


func setup(b, bd) -> void:
	battle = b
	board = bd
	position = board.proj(world)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()
	if not battle.fighting:
		_cool = minf(_cool, 1.5)
		return
	_cool -= delta
	if _cool <= 0.0:
		_cool = Defs.LAMP_EVERY
		_volley()


func _volley() -> void:
	var reach := 0.0
	for i in board.lane_count:
		reach = maxf(reach, board.path_point(i, 0.0).length())
	reach *= Defs.LAMP_RANGE
	var dmg: float = battle.char_unit.stats()["damage"] * Defs.LAMP_DAMAGE
	for i in Defs.LAMP_SHOTS:
		var s := LampShot.new()
		battle.add_lamp_shot(s)
		s.setup(battle, board, world, Vector2.from_angle(_turn + TAU * i / Defs.LAMP_SHOTS), reach, dmg)
	_turn += Defs.LAMP_TURN
	_flash = 1.0
	AudioDirector.play_sfx("chime", -14.0)


## Glows brighter as the next volley nears.
func charge() -> float:
	if not battle.fighting:
		return 0.0
	return clampf(1.0 - _cool / 1.0, 0.0, 1.0)


func _draw() -> void:
	var v: float = board.view_scale * 1.35
	var dark := Color("#2a2622")
	var iron := Color("#4a443d")
	# Post and foot.
	draw_rect(Rect2(Vector2(-6, -6) * v, Vector2(12, 6) * v), dark)
	draw_rect(Rect2(Vector2(-2.5, -70) * v, Vector2(5, 66) * v), iron)
	draw_rect(Rect2(Vector2(-2.5, -70) * v, Vector2(14, 3) * v), iron)   # arm
	var c := Vector2(10, -56) * v   # lamp hangs from the arm
	var glow := 0.55 + 0.1 * sin(_t * 3.0) + 0.35 * maxf(charge(), _flash)
	draw_circle(c, 34.0 * v * (0.8 + 0.3 * glow), Color(1, 1, 1, 0.06 + 0.10 * glow))
	draw_circle(c, 18.0 * v, Color(1, 1, 1, 0.10 + 0.15 * glow))
	# Cage: cap, glass and base.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -9) * v, c + Vector2(8, -9) * v, c + Vector2(0, -15) * v]), dark)
	draw_rect(Rect2(c + Vector2(-6, -9) * v, Vector2(12, 17) * v), Color(1, 0.98, 0.92, 0.75 + 0.25 * glow))
	draw_rect(Rect2(c + Vector2(-6, -9) * v, Vector2(12, 17) * v), dark, false, 1.5 * v)
	draw_line(c + Vector2(0, -9) * v, c + Vector2(0, 8) * v, dark, 1.2 * v)
	draw_rect(Rect2(c + Vector2(-8, 8) * v, Vector2(16, 3) * v), dark)
