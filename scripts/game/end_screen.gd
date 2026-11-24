extends Control
## End of a run: victory after every night, or the flame went out.

signal play_again
signal main_menu

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")

var won := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var h := Label.new()
	h.text = "The Caravan Is Safe" if won else "The Flame Went Out"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", Style.ACCENT if won else Color("#c9b8b0"))
	root.add_child(h)
	var sub := Label.new()
	sub.text = ("Char kept the dark at bay for %d nights." % Defs.NIGHTS) if won \
		else "Char held on for %d of %d nights." % [Run.nights_survived, Defs.NIGHTS]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	root.add_child(sub)
	var stats := Label.new()
	stats.text = "Spirits banished: %d" % Run.spirits_banished
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Style.MUTE)
	stats.add_theme_font_size_override("font_size", 20)
	root.add_child(stats)
	Style.add_something_new(root)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	root.add_child(gap)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(300, 60)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func(): play_again.emit())
	root.add_child(again)
	var menu := Button.new()
	menu.text = "Main Menu"
	menu.custom_minimum_size = Vector2(300, 60)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func(): main_menu.emit())
	root.add_child(menu)
	again.grab_focus.call_deferred()
