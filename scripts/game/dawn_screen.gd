extends Control
## Dawn after a night survived: the flame recovers, then pick 1 passive.

signal passive_chosen(id: String)

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
	sub.text = "The spirits fade with the sunrise. Char's flame recovers (+%d).\nChoose a blessing for the road:" % roundi(Defs.DAWN_HEAL)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	root.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	var first: Button = null
	for id in Run.passive_offer():
		var p: Dictionary = Defs.PASSIVES[id]
		var c := ChoiceCard.make(p["name"], p["desc"], 280.0)
		c.custom_minimum_size.y = 150
		c.pressed.connect(func():
			AudioDirector.play_sfx("chime", -4.0)
			passive_chosen.emit(id))
		row.add_child(c)
		if first == null:
			first = c
	if first:
		first.grab_focus.call_deferred()
		if Run.autoplay:
			get_tree().create_timer(1.6).timeout.connect(first.emit_signal.bind("pressed"))
