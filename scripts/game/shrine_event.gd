extends "res://scripts/game/road_event.gd"
## Road event: Ember Shrine (once per run). Pay flame now for an extra reroll
## every wave for the rest of the run, or grab flame now and face tougher
## spirits tonight, or walk on.


func _ready() -> void:
	_build("Ember Shrine", Color("#ffb36b"), "A roadside shrine smoulders in the dusk. Old embers glow in its bowl.", [
		["Kneel and Offer", "Give −%d flame. For the rest of the run: +%d reroll every wave."
			% [roundi(Defs.SHRINE_OFFER_COST), Defs.SHRINE_REROLLS], _offer],
		["Take the Embers", "+%d flame now. The shrine's keepers follow: tonight's spirits have +%d%% HP."
			% [roundi(Defs.SHRINE_TAKE_HEAL), roundi((Defs.SHRINE_CURSE_HP - 1.0) * 100)], _take],
		["Walk On", "Leave the shrine be. Nothing gained, nothing lost.", _walk_on],
	])


var _glow := 1.0       ## ember brightness: flares on an offering, dies if taken
var _glow_to := 1.0


func _offer() -> void:
	_glow = 2.2
	Run.flame = maxf(1.0, Run.flame - Defs.SHRINE_OFFER_COST)
	Run.bonus_rerolls += Defs.SHRINE_REROLLS
	AudioDirector.play_sfx("chime", -2.0)
	_result("The embers flare and settle into your dice. (+%d reroll every wave)" % Defs.SHRINE_REROLLS)


func _take() -> void:
	Run.flame = minf(Run.max_flame, Run.flame + Defs.SHRINE_TAKE_HEAL)
	Run.shrine_curse = true
	_glow_to = 0.08
	_result("Char swallows the embers (+%d flame). Behind you, the shrine goes dark... and something stirs." % roundi(Defs.SHRINE_TAKE_HEAL))


func _walk_on() -> void:
	_result("You bow your head and walk on. The shrine keeps its embers.")


const EMBER := Color("#ffb36b")


func _process(delta: float) -> void:
	_glow = lerpf(_glow, _glow_to, minf(1.0, delta * 1.6))
	super(delta)


## A warm glow from below and sparks drifting up the whole screen.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var g := clampf(_glow, 0.0, 1.5)
	for k in 6:
		_ellipse(ci, Vector2(sz.x * 0.5, sz.y + 40.0), Vector2(sz.x * (0.25 + 0.1 * k), 220.0 + 70.0 * k), Color(EMBER, 0.022 * g))
	for k in 22:
		var life := fposmod(time * (0.08 + 0.02 * (k % 5)) + k * 0.137, 1.0)
		var x := fposmod(k * 233.0, sz.x) + sin(time * 0.9 + k) * 24.0
		var y := sz.y * (1.0 - life)
		ci.draw_circle(Vector2(x, y), 1.5 + (k % 3) * 0.6, Color(EMBER, 0.5 * (1.0 - life) * g))


## A stone shrine with a bowl of embers on top.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var c := Vector2(sz.x * 0.5, sz.y)
	var stone := Color("#4a4250")
	var edge := Color("#6d6274")
	var g := _glow
	# glow behind the bowl
	var bowl := c + Vector2(0, -98)
	for k in 4:
		ci.draw_circle(bowl, 34.0 + 16.0 * k, Color(EMBER, 0.07 * g))
	# steps, pillar, capital
	ci.draw_rect(Rect2(c + Vector2(-70, -14), Vector2(140, 14)), stone)
	ci.draw_rect(Rect2(c + Vector2(-52, -24), Vector2(104, 10)), edge)
	ci.draw_rect(Rect2(c + Vector2(-20, -78), Vector2(40, 54)), stone)
	ci.draw_line(c + Vector2(-8, -72), c + Vector2(-8, -30), Color(edge, 0.6), 2.0)
	ci.draw_rect(Rect2(c + Vector2(-32, -86), Vector2(64, 8)), edge)
	# the bowl
	var pts := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16.0
		pts.append(bowl + Vector2(cos(a) * 44.0, sin(a) * 14.0 + 2.0))
	ci.draw_colored_polygon(pts, stone)
	ci.draw_line(bowl + Vector2(-46, 2), bowl + Vector2(46, 2), edge, 3.0, true)
	# embers heaped in the bowl, breathing
	for k in 7:
		var x := (k - 3) * 11.0
		var pulse := 0.6 + 0.4 * sin(time * 2.2 + k * 1.7)
		var col := EMBER.lerp(Color("#ff5a2a"), float(k % 2) * 0.6)
		ci.draw_circle(bowl + Vector2(x, -2.0 - (3 - absi(k - 3)) * 2.5), 6.0, Color(col, clampf(pulse * g, 0.0, 1.0)))
	# sparks lifting off the bowl
	for k in 8:
		var life := fposmod(time * 0.45 + k * 0.125, 1.0)
		var p := bowl + Vector2(sin(k * 2.3 + life * 4.0) * 16.0, -8.0 - life * 90.0)
		ci.draw_circle(p, 2.0 * (1.0 - life) + 0.5, Color(Color("#ffe1a8"), (1.0 - life) * clampf(g, 0.0, 1.0)))
