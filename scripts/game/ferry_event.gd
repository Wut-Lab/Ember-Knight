extends "res://scripts/game/road_event.gd"
## Road event: The Ferryman's Toll (repeatable). Every way across costs
## something: flame, a die traded blind for one the river took, or fording
## the river and soaking your dice. Now and then he blesses the night anyway.

var _blessed := false
var _paid := 0.0          ## 0..1: lantern swells when he's paid
var _paid_to := 0.0
var _splash := -10.0      ## time of the ford splash
var _bless := 0.0         ## 0..1: gold blessing glow
var _picker: GridContainer


func _ready() -> void:
	_blessed = Run.rng.randf() < Defs.FERRY_BLESS_CHANCE
	_build("The Ferryman's Toll", TEAL, "The road ends at a black river. A hooded ferryman waits on his raft, lantern raised. \"Everyone pays.\"", [
		["Pay in Flame", "−%d flame now." % roundi(Defs.FERRY_FLAME), _pay_flame],
		["Pay with a Die", "Give him one of your dice. He fishes another out of the river for you: what the river took.", _pick_die],
		["Ford the River", "Free, but your dice get soaked: no rerolls in wave 1, at most %d in wave 2. Dry by wave 3." % Defs.FERRY_SOAKED_W2, _ford],
	])


func _pay_flame() -> void:
	Run.flame = maxf(1.0, Run.flame - Defs.FERRY_FLAME)
	_paid_to = 1.0
	_finish("He takes the warmth from your hand without a word and poles you across. (−%d flame)" % roundi(Defs.FERRY_FLAME))


## A card per die kind you own; pick one to hand over.
func _pick_die() -> void:
	_sub.text = "Which die do you give him?"
	for c in _row.get_children():
		c.queue_free()
	_picker = GridContainer.new()
	_picker.columns = 4
	_picker.add_theme_constant_override("h_separation", 14)
	_picker.add_theme_constant_override("v_separation", 14)
	_row.add_child(_picker)
	var kinds := []
	for id in Run.pool:
		if Defs.DICE.has(id) and not id in kinds:
			kinds.append(id)
	var cards := []
	for id in kinds:
		var c := ChoiceCard.make(Defs.DICE[id]["name"], "Owned %d" % Run.pool.count(id), 210.0)
		c.custom_minimum_size.y = 90
		c.pressed.connect(_give.bind(id))
		_picker.add_child(c)
		cards.append(c)
	cards[0].grab_focus.call_deferred()
	if Run.autoplay:
		var pick: Button = cards[Run.rng.randi() % cards.size()]
		get_tree().create_timer(1.2).timeout.connect(pick.emit_signal.bind("pressed"))


func _give(id: String) -> void:
	var back := ""
	for d in Defs.dawn_dice(Run.rng, Run.pool):
		if d != id:
			back = d
			break
	Run.pool.erase(id)   # one copy
	_paid_to = 1.0
	if back == "":   # nothing left in the river: he keeps it and lets you pass
		_finish("He weighs your %s, drops it into the river, and poles you across." % Defs.DICE[id]["name"])
		return
	Run.pool.append(back)
	AudioDirector.play_sfx("dice_roll", -4.0)
	_finish("He drops your %s into the river and fishes out another, dripping: a %s.\n%s" % [Defs.DICE[id]["name"], Defs.DICE[back]["name"], _tally(Defs.DICE[back]["faces"])])


func _ford() -> void:
	Run.ferry_soaked = true
	_splash = _t
	_finish("You wade across, the cold water up to your chest. Your dice will take a while to dry.")


## Shows the outcome; now and then the ferryman blesses the night anyway.
func _finish(text: String) -> void:
	if _blessed:
		Run.ferry_blessed = true
		_bless = 0.01
		text += "\nAs you go, he lifts his lantern toward you. Its light follows you to camp: Char starts tonight at Kindle level 1."
	_result(text)


static func _tally(faces: Array) -> String:
	var parts := []
	for f in Defs.DIE_FACES:
		for up in ["++", "+", ""]:
			var n := faces.count(f + up)
			if n > 0:
				parts.append("%d %s%s" % [n, Defs.FACE_INFO[f]["name"], up])
	return ", ".join(parts)


const TEAL := Color("#9fd8c8")
const LAMP := Color("#d8ffe8")
const GOLD := Color("#ffd27a")
const WATER := Color("#0b1a1e")


func _process(delta: float) -> void:
	_paid = lerpf(_paid, _paid_to, minf(1.0, delta * 2.0))
	if _bless > 0.0:
		_bless = minf(1.0, _bless + delta * 0.6)
	super(delta)


## Slow dark water filling the lower screen, mist drifting over it, and a
## faint green lantern-glow; gold if he blesses the night.
func _draw_ambient(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var top := sz.y * 0.62
	ci.draw_rect(Rect2(0, top, sz.x, sz.y - top), Color(WATER, 0.55))
	for k in 14:   # long slow ripples
		var y := top + 12.0 + k * (sz.y - top) / 14.0
		var x := fposmod(k * 157.0 + time * (14.0 + k), sz.x + 300.0) - 150.0
		ci.draw_line(Vector2(x, y), Vector2(x + 120.0 + (k % 4) * 40.0, y), Color(TEAL, 0.05 + 0.02 * (k % 3)), 2.0, true)
	for k in 8:    # mist over the water
		var x := fposmod(k * 240.0 - time * (8.0 + k), sz.x + 400.0) - 200.0
		for j in 3:
			_ellipse(ci, Vector2(x, top - 10.0 + (k % 3) * 26.0), Vector2(240.0 - j * 60.0, 28.0 - j * 7.0), Color(TEAL, 0.014))
	var glow := LAMP.lerp(GOLD, _bless)
	for k in 10:
		_ellipse(ci, Vector2(sz.x * 0.5, sz.y * 0.32), Vector2(90.0 + k * 50.0, 60.0 + k * 34.0), Color(glow, 0.006 + 0.006 * _paid + 0.008 * _bless))


## The ferryman on his raft: a tall hooded figure with a pole, his lantern
## held out on a crook, a rope line across the river, and the far bank.
func _draw_art(ci: CanvasItem, sz: Vector2, time: float) -> void:
	var water_y := sz.y - 34.0
	# Far bank and reeds.
	ci.draw_rect(Rect2(0, water_y - 6, sz.x, 6), Color("#141a18"))
	for k in 9:   # reed clumps on the far bank
		var x := 20.0 + k * 52.0 + fposmod(k * 17.0, 23.0)
		for b in 4:
			var lean := (b - 1.5) * 2.5 + sin(time * 0.8 + k) * 1.5
			ci.draw_line(Vector2(x + b * 2.5, water_y - 4), Vector2(x + b * 2.5 + lean, water_y - 10 - fposmod(k * 5.0 + b * 3.0, 9.0)), Color("#25332a"), 1.5, true)
	# The river.
	ci.draw_rect(Rect2(0, water_y, sz.x, sz.y - water_y), WATER)
	for k in 6:
		var x := fposmod(k * 90.0 + time * 12.0, sz.x + 60.0) - 30.0
		var y := water_y + 6.0 + (k % 3) * 8.0
		ci.draw_line(Vector2(x, y), Vector2(x + 30.0, y), Color(TEAL, 0.25), 1.5, true)
	# Rope line strung across.
	var rope := PackedVector2Array()
	for k in 25:
		var x := sz.x * k / 24.0
		var f := float(k) / 24.0
		rope.append(Vector2(x, water_y - 128.0 + 22.0 * sin(f * PI)))
	ci.draw_polyline(rope, Color("#4a3a2a", 0.8), 1.5, true)
	# The raft, bobbing.
	var bob := sin(time * 1.3) * 2.0
	var raft := Vector2(sz.x * 0.5, water_y + 4.0 + bob)
	ci.draw_rect(Rect2(raft + Vector2(-70, -6), Vector2(140, 10)), Color("#3a2a1c"))
	for k in 7:
		ci.draw_line(raft + Vector2(-70 + k * 20, -6), raft + Vector2(-70 + k * 20, 4), Color("#22180f"), 1.5)
	_ellipse(ci, raft + Vector2(0, 8), Vector2(80, 5), Color(TEAL, 0.12))
	# The ferryman: tall robe, deep hood, two faint eyes.
	var feet := raft + Vector2(-10, -6)
	var robe := PackedVector2Array([feet + Vector2(-20, 0), feet + Vector2(20, 0), feet + Vector2(9, -70), feet + Vector2(-9, -70)])
	ci.draw_colored_polygon(robe, Color("#1d2427"))
	var rim := Color("#5e7a76").lerp(GOLD, _bless * 0.6)
	ci.draw_line(robe[1], robe[2], Color(rim, 0.8), 2.0, true)   # lantern-lit side
	ci.draw_line(robe[0], robe[3], Color("#3a4a4c", 0.6), 1.5, true)
	var hood := feet + Vector2(0, -78)
	_ellipse(ci, hood, Vector2(15, 16), Color(rim, 0.7))
	_ellipse(ci, hood + Vector2(-1, 0), Vector2(14, 15), Color("#1d2427"))
	_ellipse(ci, hood + Vector2(2, 3), Vector2(8, 9), Color("#050607"))
	var eye := LAMP.lerp(GOLD, _bless)
	ci.draw_circle(hood + Vector2(-1, 2), 1.6, Color(eye, 0.8))
	ci.draw_circle(hood + Vector2(5, 2), 1.6, Color(eye, 0.8))
	# His pole, slanting into the water.
	ci.draw_line(feet + Vector2(-14, -52), raft + Vector2(-60, 22), Color("#2c2218"), 3.0, true)
	# Lantern held out on a crook.
	var crook := feet + Vector2(16, -60)
	var lamp := crook + Vector2(34, -8) + Vector2(sin(time * 1.1) * 3.0, 0)
	ci.draw_line(feet + Vector2(8, -50), crook, Color("#1d2427"), 5.0, true)
	ci.draw_line(feet + Vector2(8, -52), crook - Vector2(0, 2), Color(rim, 0.6), 1.5, true)
	ci.draw_line(crook, crook + Vector2(30, -14), Color("#2c2218"), 2.5, true)
	ci.draw_line(crook + Vector2(30, -14), lamp, Color("#1a1410"), 1.5, true)
	var col := LAMP.lerp(GOLD, _bless)
	var flick := 0.8 + 0.2 * sin(time * 7.0) * sin(time * 4.1)
	var bright := 1.0 + 0.8 * _paid + 1.0 * _bless
	for k in 9:
		ci.draw_circle(lamp, 8.0 + k * 6.0 * (0.8 + 0.3 * bright), Color(col, 0.02 * flick * bright))
	ci.draw_rect(Rect2(lamp - Vector2(5, 7), Vector2(10, 14)), Color("#1a1410"))
	ci.draw_rect(Rect2(lamp - Vector2(3, 5), Vector2(6, 10)), Color(col, 0.9 * flick))
	# Splashes where you forded.
	var since := _t - _splash
	if since >= 0.0 and since < 2.5:
		for k in 8:
			var p := Vector2(sz.x * 0.22 + (k - 4) * 9.0, water_y + 2.0)
			var h := sin(since * 5.0 + k) * 10.0 * (1.0 - since / 2.5)
			ci.draw_circle(p + Vector2(0, -absf(h)), 2.0, Color(TEAL, 0.6 * (1.0 - since / 2.5)))
		_ring_at(ci, Vector2(sz.x * 0.22, water_y + 4.0), 10.0 + since * 30.0, Color(TEAL, 0.4 * (1.0 - since / 2.5)))


static func _ring_at(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.3))
	ci.draw_polyline(pts, col, 1.5, true)
