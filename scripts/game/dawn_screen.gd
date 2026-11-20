extends Control
## Dawn after a night survived: the flame recovers, then the player picks one
## of three Dawn Offerings (a new die or an Oath) and the road goes on.

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
	sub.text = "The spirits fade with the sunrise. Char's flame recovers (+%d)." % roundi(Run.dawn_heal())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	root.add_child(sub)
	if Defs.ends_leg(Run.night):
		var leg := Label.new()
		leg.text = "Leg %d of the road complete!  +1 dice slot, and an %s joins your bag." % [Defs.leg_of(Run.night) + 1, Defs.DICE[Defs.LEG_REWARD_DIE]["name"]]
		leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leg.add_theme_font_size_override("font_size", 22)
		leg.add_theme_color_override("font_color", Style.ACCENT)
		root.add_child(leg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	var pick := Label.new()
	pick.text = "DAWN OFFERINGS  ·  CHOOSE ONE"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_color_override("font_color", Style.MUTE)
	pick.add_theme_font_size_override("font_size", 16)
	root.add_child(pick)
	root.move_child(pick, row.get_index())
	var first: Button = null
	for o in Defs.dawn_offerings(Run.rng, Run.pool, Run.oaths):
		var card: Button
		if o["type"] == "die":
			card = ChoiceCard.make(Defs.DICE[o["id"]]["name"], "New die:  " + _tally(Defs.DICE[o["id"]]["faces"]), 280.0)
		else:
			card = ChoiceCard.make(Defs.OATHS[o["id"]]["name"], "Oath:  " + Defs.OATHS[o["id"]]["short"], 280.0)
		card.custom_minimum_size.y = 150
		card.pressed.connect(_take.bind(o))
		row.add_child(card)
		if first == null:
			first = card
	var status := Label.new()
	status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Style.MUTE)
	status.add_theme_font_size_override("font_size", 20)
	root.add_child(status)
	if first == null:   # nothing left to offer
		pick.text = "NO OFFERINGS LEFT"
		first = ChoiceCard.make("Onward", "The road goes on.", 280.0)
		first.pressed.connect(func():
			AudioDirector.play_sfx("chime", -4.0)
			continued.emit())
		row.add_child(first)
	first.grab_focus.call_deferred()
	if Run.autoplay:
		get_tree().create_timer(1.6).timeout.connect(first.emit_signal.bind("pressed"))


func _take(o: Dictionary) -> void:
	if o["type"] == "die":
		Run.pool.append(o["id"])
	else:
		Run.oaths.append(o["id"])
	AudioDirector.play_sfx("chime", -4.0)
	continued.emit()


static func _tally(faces: Array) -> String:
	var parts := []
	for f in Defs.DIE_FACES:
		var n := faces.count(f)
		if n > 0:
			parts.append("%d %s" % [n, Defs.FACE_INFO[f]["name"]])
	return ", ".join(parts)
