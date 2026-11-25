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
		if absf(x - sz.x * 0.5) < 95.0:
			continue   # leave the raft clear
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
	# The raft, bobbing: a plank deck seen from above at an angle, with its
	# front edge showing and a wet shine along the waterline.
	var bob := sin(time * 1.3) * 2.0
	var R := Vector2(sz.x * 0.5, water_y + 2.0 + bob)
	var lit := LAMP.lerp(GOLD, _bless)
	var deck := PackedVector2Array([R + Vector2(-68, -12), R + Vector2(66, -12), R + Vector2(76, 2), R + Vector2(-78, 2)])
	var front := PackedVector2Array([R + Vector2(-78, 2), R + Vector2(76, 2), R + Vector2(76, 9), R + Vector2(-78, 9)])
	_ellipse(ci, R + Vector2(0, 10), Vector2(88, 6), Color(0, 0, 0, 0.35))
	ci.draw_colored_polygon(front, Color("#24180f"))
	ci.draw_colored_polygon(deck, Color("#4a3624"))
	for k in 9:   # planks, converging slightly toward the back
		var f := k / 8.0
		ci.draw_line(R + Vector2(lerpf(-68, 66, f), -12), R + Vector2(lerpf(-78, 76, f), 2), Color("#2e2016"), 1.2, true)
	ci.draw_line(R + Vector2(-78, 2), R + Vector2(76, 2), Color("#6a5038"), 1.5, true)   # lit front lip
	ci.draw_line(R + Vector2(-78, 9), R + Vector2(76, 9), Color(TEAL, 0.25), 1.0, true)  # wet line
	# The ferryman stands on it, the lantern to his right.
	var F := R + Vector2(-8, -6)
	_ellipse(ci, F + Vector2(-10, 0), Vector2(26, 5), Color(0, 0, 0, 0.45))   # his shadow, cast left
	var rim := Color("#6f8c86").lerp(GOLD, _bless * 0.7)
	# Pole, held in his left hand, slanting down into the river behind the raft.
	ci.draw_line(F + Vector2(-12, -92), R + Vector2(-66, 18), Color("#1e150d"), 4.0, true)
	ci.draw_line(F + Vector2(-11, -92), R + Vector2(-65, 18), Color("#4a3624"), 1.2, true)
	# Robe: a bell, darkest on the left, lantern-lit on the right, round at the hem.
	var shade := [Color("#101416"), Color("#1a2124"), Color("#232c30"), Color("#2e3a3e")]
	for band in 4:
		var x0 := lerpf(-22.0, 22.0, band / 4.0)
		var x1 := lerpf(-22.0, 22.0, (band + 1) / 4.0)
		var t0 := lerpf(-12.0, 12.0, band / 4.0)
		var t1 := lerpf(-12.0, 12.0, (band + 1) / 4.0)
		ci.draw_colored_polygon(PackedVector2Array([F + Vector2(x0, 0), F + Vector2(x1, 0), F + Vector2(t1, -60), F + Vector2(t0, -60)]), shade[band])
	ci.draw_colored_polygon(PackedVector2Array([F + Vector2(17, 0), F + Vector2(22, 0), F + Vector2(12, -60), F + Vector2(9, -60)]), Color(rim, 0.55))
	var hem := PackedVector2Array()
	for k in 13:
		var ang := PI * k / 12.0
		hem.append(F + Vector2(cos(ang) * 22.0, sin(ang) * 4.0))
	ci.draw_colored_polygon(hem, Color("#0c0f10"))
	# Left sleeve to the pole.
	ci.draw_line(F + Vector2(-9, -54), F + Vector2(-13, -64), Color("#161c1e"), 7.0, true)
	ci.draw_circle(F + Vector2(-13, -66), 3.0, Color("#8c7a68"))
	# Hood: deep and pointed, rim-lit on the lantern side.
	var H := F + Vector2(0, -72)
	var hood := PackedVector2Array([H + Vector2(-15, 10), H + Vector2(-16, -4), H + Vector2(-8, -16), H + Vector2(2, -21), H + Vector2(12, -12), H + Vector2(16, 2), H + Vector2(14, 10)])
	ci.draw_colored_polygon(hood, Color("#1d2528"))
	ci.draw_polyline(PackedVector2Array([hood[3], hood[4], hood[5], hood[6]]), Color(rim, 0.85), 2.0, true)
	_ellipse(ci, H + Vector2(1, 1), Vector2(9, 10), Color("#050607"))   # the dark inside
	var eye := LAMP.lerp(GOLD, _bless)
	ci.draw_circle(H + Vector2(-2, -2), 1.5, Color(eye, 0.85))
	ci.draw_circle(H + Vector2(4, -2), 1.5, Color(eye, 0.85))
	# A long beard spilling out of the hood, down past his chest, swaying a little.
	var sway := sin(time * 0.9) * 1.5
	var beard := PackedVector2Array([H + Vector2(-7, 2), H + Vector2(8, 2), H + Vector2(7, 22), H + Vector2(3 + sway, 44), H + Vector2(sway, 52), H + Vector2(-3 + sway, 44), H + Vector2(-7, 22)])
	ci.draw_colored_polygon(beard, Color("#6e7672"))
	ci.draw_colored_polygon(PackedVector2Array([H + Vector2(1, 2), H + Vector2(8, 2), H + Vector2(7, 22), H + Vector2(3 + sway, 44), H + Vector2(sway, 52)]), Color("#a9b2ad").lerp(GOLD, _bless * 0.35))
	for k in 5:   # strands
		var x := -5.0 + k * 2.6
		ci.draw_line(H + Vector2(x, 5), H + Vector2(x * 0.4 + sway, 40 + (k % 2) * 6), Color("#4e5552", 0.7), 1.0, true)
	ci.draw_line(H + Vector2(-6, 3), H + Vector2(7, 3), Color("#c8d0cb", 0.6), 1.5, true)   # moustache
	# Right sleeve and hand on the crook.
	var hand := F + Vector2(24, -50)
	ci.draw_line(F + Vector2(10, -54), hand + Vector2(-3, 1), Color("#2a3438"), 7.0, true)
	ci.draw_line(F + Vector2(11, -57), hand + Vector2(-3, -2), Color(rim, 0.5), 1.5, true)
	ci.draw_circle(hand, 3.0, Color("#b09a84").lerp(GOLD, _bless * 0.3))
	# The crook: up from his hand, curling over, the lantern hanging from it.
	var top := hand + Vector2(6, -44)
	ci.draw_line(hand + Vector2(-2, 14), top, Color("#2c2218"), 3.0, true)
	var hook := PackedVector2Array()
	for k in 9:
		var ang := PI + PI * k / 8.0
		hook.append(top + Vector2(10, 0) + Vector2(cos(ang) * 10.0, sin(ang) * 8.0))
	ci.draw_polyline(hook, Color("#2c2218"), 3.0, true)
	var hang := top + Vector2(20, 0)
	var lamp := hang + Vector2(sin(time * 1.1) * 3.0, 14)
	ci.draw_line(hang, lamp + Vector2(0, -8), Color("#1a1410"), 1.2, true)
	var flick := 0.8 + 0.2 * sin(time * 7.0) * sin(time * 4.1)
	var bright := 1.0 + 0.8 * _paid + 1.0 * _bless
	for k in 9:
		ci.draw_circle(lamp, 8.0 + k * 6.0 * (0.8 + 0.3 * bright), Color(lit, 0.02 * flick * bright))
	# Lantern: cap, glass and base, the glass lit from inside.
	ci.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-6, -7), lamp + Vector2(6, -7), lamp + Vector2(3, -11), lamp + Vector2(-3, -11)]), Color("#2a2018"))
	ci.draw_rect(Rect2(lamp - Vector2(5, 7), Vector2(10, 13)), Color("#1a1410"))
	ci.draw_rect(Rect2(lamp - Vector2(3.5, 5.5), Vector2(7, 10)), Color(lit, 0.9 * flick))
	ci.draw_rect(Rect2(lamp - Vector2(1, 5.5), Vector2(1.5, 10)), Color(1, 1, 1, 0.35 * flick))
	ci.draw_rect(Rect2(lamp + Vector2(-6, 6), Vector2(12, 2.5)), Color("#2a2018"))
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
