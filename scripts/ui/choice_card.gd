extends RefCounted
## A big tappable card (title + description) used for map stops and the dawn screen.

const Style := preload("res://scripts/ui/ui_style.gd")


static func make(title: String, desc: String, width := 260.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 118)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 12
	box.offset_bottom = -12
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Style.display_font(600))
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Style.ACCENT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	var d := Label.new()
	d.text = desc
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(width - 32, 0)
	d.add_theme_font_size_override("font_size", 18)
	d.add_theme_color_override("font_color", Style.FG)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(d)
	b.add_child(box)
	b.mouse_entered.connect(b.grab_focus)
	return b
