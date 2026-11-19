extends RefCounted
## Builds the Master / Music / Effects volume rows used by both Options cards
## (main menu and battle pause). Changes apply live and save immediately.

const Style := preload("res://scripts/ui/ui_style.gd")

const ROWS := [["Master", "Master"], ["Music", "Music"], ["Effects", "Effects"]]
const STEP := 0.05


## Returns a grid of label + slider + percent rows. First slider is at index 1.
static func build() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in ROWS:
		var bus: String = row[1]
		var name := Label.new()
		name.text = row[0]
		name.custom_minimum_size = Vector2(100, 0)
		name.add_theme_font_override("font", Style.BODY_MEDIUM)
		grid.add_child(name)

		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = STEP
		s.value = AudioDirector.get_volume(bus)
		s.custom_minimum_size = Vector2(240, 32)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_ALL
		s.mouse_entered.connect(s.grab_focus)
		grid.add_child(s)

		var pct := Label.new()
		pct.custom_minimum_size = Vector2(64, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_color_override("font_color", Style.MUTE)
		pct.text = "%d%%" % roundi(s.value * 100)
		grid.add_child(pct)

		s.value_changed.connect(func(v: float):
			AudioDirector.set_volume(bus, v)
			pct.text = "%d%%" % roundi(v * 100)
			if bus != "Music":   # a little tick so you can hear the new level
				AudioDirector.play_sfx("tap", -8.0, 0.02))
	return grid
