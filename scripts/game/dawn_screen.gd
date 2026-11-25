extends Control
## Dawn after a night survived: the flame recovers, then the player takes one
## of two dice and swears one of two Oaths (or skips either for a little flame),
## and the road goes on.

signal continued

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")
const Icons := preload("res://scripts/game/icons.gd")
const RECAP_SIZE := Vector2(780, 104)
const DAWN := Color("#ffd58f")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var h := Label.new()
	h.text = "Dawn"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", Color("#ffd58f"))
	root.add_child(h)
	if not Run.recap.is_empty() and not Run.night_flames.is_empty():
		root.add_child(_recap_strip())
	var sub := Label.new()
	var healed := Run.dawn_heal() + (Defs.BOSS_DAWN_HEAL if Defs.ends_leg(Run.night) else 0.0)
	sub.text = "The spirits fade with the sunrise. Char's flame recovers (+%d)." % roundi(healed)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	root.add_child(sub)
	Style.add_something_new(root)
	if Run.has_rider("cook"):
		var cook := Label.new()
		var who: String = Defs.CARAVAN["cook"]["name"]
		cook.text = ("%s, ladles out a hot broth:  +%d flame." % [who, roundi(Run.cook_healed)]) if Run.cook_healed >= 0.5 \
			else "%s, ladles out a hot broth, but Char's flame is already full." % who
		cook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cook.add_theme_font_size_override("font_size", 22)
		cook.add_theme_color_override("font_color", Color("#ffd58f"))
		root.add_child(cook)
	if Defs.ends_leg(Run.night):
		var leg := Label.new()
		leg.text = "%s is banished!  Leg %d of the road complete:  +1 dice slot, and an %s joins your bag." % [Defs.SPIRITS[Run.boss_for(Run.night)]["name"], Defs.leg_of(Run.night) + 1, Defs.DICE[Defs.LEG_REWARD_DIE]["name"]]
		leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leg.add_theme_font_size_override("font_size", 22)
		leg.add_theme_color_override("font_color", Style.ACCENT)
		root.add_child(leg)
	_root = root
	if Run.current_stop() == "swamp":
		var sw := Label.new()
		sw.text = "Something stirs in the bog:  one die from the swamp is on offer."
		sw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sw.add_theme_font_size_override("font_size", 20)
		sw.add_theme_color_override("font_color", Color("#9fc9a0"))
		root.add_child(sw)
		_row("A NEW DIE  ·  TAKE ONE", "die", Defs.swamp_dawn_dice(Run.rng, Run.pool))
	elif Run.current_stop() == "chapel":
		var ch := Label.new()
		ch.text = "Candlelight lingers in the chapel:  one of its dice is on offer."
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ch.add_theme_font_size_override("font_size", 20)
		ch.add_theme_color_override("font_color", Color("#ffd98a"))
		root.add_child(ch)
		_row("A NEW DIE  ·  TAKE ONE", "die", Defs.swamp_dawn_dice(Run.rng, Run.pool, Defs.CHAPEL_DICE))
	else:
		_row("A NEW DIE  ·  TAKE ONE", "die", Defs.dawn_dice(Run.rng, Run.pool))
	_row("AN OATH  ·  SWEAR ONE", "oath", Defs.dawn_oaths(Run.rng, Run.oaths, Run.night))
	if Run.has_oath("dawn_offerings") and not _rows.is_empty():
		_add_reroll()
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Style.MUTE)
	_status.add_theme_font_size_override("font_size", 20)
	root.add_child(_status)
	_update_status()
	if not _rows.is_empty():
		_rows[0]["cards"][0].grab_focus.call_deferred()
	_check_done()
	if Run.autoplay:
		get_tree().create_timer(1.2).timeout.connect(_auto_pick.bind("die"))
		get_tree().create_timer(2.0).timeout.connect(_auto_pick.bind("oath"))


var _root: VBoxContainer
var _status: Label
var _rows := []        ## [{kind, cards: [Button], done}]
var _left := 0         ## rows still to choose in
var _reroll: Button
var _rerolled := false


## One row of offerings (2 cards) plus a Skip card worth SKIP_FLAME flame.
func _row(title: String, kind: String, ids: Array) -> void:
	var lab := Label.new()
	lab.text = title if not ids.is_empty() else ("NO DICE LEFT TO OFFER" if kind == "die" else "NO OATHS LEFT TO SWEAR")
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Style.MUTE)
	lab.add_theme_font_size_override("font_size", 16)
	_root.add_child(lab)
	if ids.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)
	var r := {"kind": kind, "cards": [], "ids": ids, "done": false, "box": row}
	_fill(r)
	_rows.append(r)
	_left += 1


## (Re)builds a row's cards from r["ids"], plus the Skip card.
func _fill(r: Dictionary) -> void:
	for c in r["cards"]:
		c.queue_free()
	r["cards"] = []
	for id in r["ids"]:
		var card: Button
		if r["kind"] == "die":
			card = ChoiceCard.make(Defs.DICE[id]["name"], "New die:  " + _tally(Defs.DICE[id]["faces"]), 300.0)
		else:
			var o: Dictionary = Defs.OATHS[id]
			var rar: Dictionary = Defs.RARITY[o.get("rarity", "common")]
			card = ChoiceCard.make(o["name"], "%s Oath:  %s" % [rar["name"], o["short"]], 300.0)
			_tint(card, rar["color"])
		card.custom_minimum_size.y = 118
		card.pressed.connect(_choose.bind(r, card, id))
		r["box"].add_child(card)
		r["cards"].append(card)
	var skip := ChoiceCard.make("Skip", "+%d flame" % roundi(Defs.SKIP_FLAME), 170.0)
	skip.custom_minimum_size.y = 118
	skip.pressed.connect(_choose.bind(r, skip, ""))
	r["box"].add_child(skip)
	r["cards"].append(skip)


## Oath of Dawn Offerings: once a dawn, pay flame and Essence to reroll
## every row not yet chosen in.
func _add_reroll() -> void:
	_reroll = Button.new()
	_reroll.text = "Reroll offerings  (%d flame, %d Essence)" % [roundi(Defs.DAWN_REROLL_FLAME), Defs.DAWN_REROLL_ESSENCE]
	_reroll.custom_minimum_size = Vector2(380, 50)
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.pressed.connect(_do_reroll)
	_root.add_child(_reroll)
	_update_reroll()


func _update_reroll() -> void:
	if _reroll:
		_reroll.disabled = _rerolled or _left <= 0 or Run.flame <= Defs.DAWN_REROLL_FLAME \
			or Profile.essence < Defs.DAWN_REROLL_ESSENCE


func _do_reroll() -> void:
	if _reroll.disabled or not Profile.spend_essence(Defs.DAWN_REROLL_ESSENCE):
		return
	_rerolled = true
	Run.flame -= Defs.DAWN_REROLL_FLAME
	for r in _rows:
		if r["done"]:
			continue
		r["ids"] = Defs.dawn_dice(Run.rng, Run.pool) if r["kind"] == "die" else Defs.dawn_oaths(Run.rng, Run.oaths, Run.night)
		_fill(r)
	AudioDirector.play_sfx("chime", -4.0)
	_update_status()
	_update_reroll()
	for r in _rows:
		if not r["done"]:
			r["cards"][0].grab_focus.call_deferred()
			break


## Colour an Oath card's title by its rarity.
func _tint(card: Button, col: Color) -> void:
	var t: Label = card.get_child(0).get_child(0)
	t.add_theme_color_override("font_color", col)


func _choose(r: Dictionary, card: Button, id: String) -> void:
	if r["done"]:
		return
	r["done"] = true
	_left -= 1
	if id == "":
		Profile.add_stat("dawn_skips")
		Run.flame = minf(Run.max_flame, Run.flame + Defs.SKIP_FLAME)
	elif r["kind"] == "die":
		Run.pool.append(id)
	else:
		Run.oaths.append(id)
	for c in r["cards"]:   # the taken card stays lit; the rest fade
		c.disabled = true
		c.modulate = Color(1, 1, 1, 1.0 if c == card else 0.35)
	AudioDirector.play_sfx("chime", -4.0)
	_update_status()
	_update_reroll()
	for o in _rows:   # move focus to the next open row
		if not o["done"]:
			o["cards"][0].grab_focus()
			break
	_check_done()


func _check_done() -> void:
	if _left > 0:
		return
	_left = -1
	get_tree().create_timer(0.7 if not _rows.is_empty() else 1.4).timeout.connect(func(): continued.emit())


func _update_status() -> void:
	_status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]


## Autoplay: skip when flame is low; otherwise build on dice already owned and
## take the rarest Oath.
func _auto_pick(kind: String) -> void:
	for r in _rows:
		if r["kind"] != kind or r["done"]:
			continue
		var ids: Array = r["ids"]
		var best := 0
		if Run.flame < Run.max_flame * 0.3:
			best = ids.size()   # the Skip card
		elif kind == "die":
			for i in ids.size():
				if Run.owned(ids[i]) > Run.owned(ids[best]):
					best = i
		else:
			for i in ids.size():
				if Defs.RARITY_ORDER.find(Defs.OATHS[ids[i]].get("rarity", "common")) > Defs.RARITY_ORDER.find(Defs.OATHS[ids[best]].get("rarity", "common")):
					best = i
		r["cards"][best].emit_signal("pressed")


static func _tally(faces: Array) -> String:
	var parts := []
	for f in Defs.DIE_FACES:
		for up in ["++", "+", ""]:
			var n := faces.count(f + up)
			if n > 0:
				parts.append("%d %s%s" % [n, Defs.FACE_INFO[f]["name"], up])
	return ", ".join(parts)


# ------------------------------------------------------------ night recap
var _recap: Array = []   ## [{icon, value, prefix, label, note}]
var _recap_t := 0.0
var _recap_head := ""


## A strip summing up the night just survived, cells revealed one by one.
func _recap_strip() -> Control:
	var r: Dictionary = Run.recap
	var end_flame: float = Run.night_flames.back()
	var lost := roundi(r["flame"] - end_flame)
	_recap_head = "NIGHT %d  ·  %s" % [Run.night + 1, Defs.STOPS.get(Run.current_stop(), {}).get("name", "").to_upper()]
	_recap = [
		{"icon": "flame", "value": absi(lost), "prefix": "−" if lost >= 0 else "+", "label": "flame lost" if lost >= 0 else "flame gained",
			"note": "struck %d×" % r["hits"] if r["hits"] > 0 else "untouched!"},
		{"icon": "wisp", "value": Run.spirits_banished - int(r["banished"]), "prefix": "", "label": "spirits banished", "note": ""},
		{"icon": "gem", "value": Profile.essence - int(r["essence"]), "prefix": "+", "label": "Essence earned", "note": ""},
		{"icon": "hourglass", "value": roundi(r["low"]), "prefix": "", "label": "closest call", "note": "lowest flame"},
	]
	var p := DrawProxy.new()
	p.custom_minimum_size = RECAP_SIZE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw_fn = _draw_recap
	var tw := p.create_tween()
	tw.tween_method(func(v: float):
		_recap_t = v
		p.queue_redraw(), 0.0, 1.6, 1.6)
	return p


func _draw_recap(ci: CanvasItem) -> void:
	var sz := RECAP_SIZE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(Style.CARD, 0.82)
	bg.border_color = Color(DAWN, 0.4)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	bg.anti_aliasing = true
	ci.draw_style_box(bg, Rect2(Vector2.ZERO, sz))
	var body: Font = Style.BODY_MEDIUM
	ci.draw_string(body, Vector2(0, 22), _recap_head, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 14, Style.MUTE)
	var cw := sz.x / _recap.size()
	for k in _recap.size():
		var cell: Dictionary = _recap[k]
		var a := clampf((_recap_t - k * 0.18) / 0.35, 0.0, 1.0)
		if a <= 0.0:
			continue
		var x0 := k * cw
		if k > 0:
			ci.draw_line(Vector2(x0, 34), Vector2(x0, sz.y - 14), Color(Style.LINE, 0.8), 1.0)
		var ic := Vector2(x0 + 34, 62 - (1.0 - a) * 8.0)
		_recap_icon(ci, cell["icon"], ic, Color(DAWN, a))
		var shown := roundi(cell["value"] * clampf((_recap_t - k * 0.18) / 0.7, 0.0, 1.0))
		var num: String = cell["prefix"] + str(shown) if shown != 0 or cell["prefix"] == "" else "0"
		ci.draw_string(Style.display_font(), Vector2(x0 + 62, 65), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(Style.ACCENT, a))
		ci.draw_string(body, Vector2(x0 + 62, 82), cell["label"], HORIZONTAL_ALIGNMENT_LEFT, cw - 66, 15, Color(Style.FG, a))
		if cell["note"] != "":
			ci.draw_string(body, Vector2(x0 + 62, 96), cell["note"], HORIZONTAL_ALIGNMENT_LEFT, cw - 66, 13, Color(Style.MUTE, a))


func _recap_icon(ci: CanvasItem, kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"flame":
			Icons.draw(ci, "torch", c, 40.0, Color(Style.ACCENT2, col.a))
		"wisp":   # a little spirit with a trailing tail, faded out
			var pts := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				pts.append(c + Vector2(-t * 16.0 + 4.0, 6.0 + t * 10.0 + sin(t * 5.0) * 3.0))
			ci.draw_polyline(pts, Color(col, col.a * 0.5), 4.0, true)
			ci.draw_circle(c + Vector2(4, -2), 11.0, Color(col, col.a * 0.25))
			ci.draw_circle(c + Vector2(4, -2), 7.5, col)
			ci.draw_circle(c + Vector2(1.5, -3), 1.4, Color(Style.CARD, col.a))
			ci.draw_circle(c + Vector2(6.5, -3), 1.4, Color(Style.CARD, col.a))
		"gem":   # an Essence shard
			var g := PackedVector2Array([c + Vector2(0, -14), c + Vector2(11, -3), c + Vector2(0, 14), c + Vector2(-11, -3)])
			ci.draw_colored_polygon(g, Color("#c9a8ff", col.a))
			ci.draw_line(c + Vector2(-11, -3), c + Vector2(11, -3), Color(1, 1, 1, col.a * 0.5), 1.5, true)
			ci.draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color(1, 1, 1, col.a * 0.3), 1.5, true)
		_:
			Icons.draw(ci, kind, c, 38.0, col)
