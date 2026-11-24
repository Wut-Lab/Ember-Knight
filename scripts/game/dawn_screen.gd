extends Control
## Dawn after a night survived: the flame recovers, then the player takes one
## of two dice and swears one of two Oaths (or skips either for a little flame),
## and the road goes on.

signal continued

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")


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
	var sub := Label.new()
	var healed := Run.dawn_heal() + (Defs.BOSS_DAWN_HEAL if Defs.ends_leg(Run.night) else 0.0)
	sub.text = "The spirits fade with the sunrise. Char's flame recovers (+%d)." % roundi(healed)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	root.add_child(sub)
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
