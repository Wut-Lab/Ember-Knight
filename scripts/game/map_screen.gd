extends Control
## The caravan's route for tonight. A night tracker runs across the top (with
## a quiet Journey button beside it that lists the camps already cleared).
## Below it, the camp just cleared sits large on the left, and glowing dotted
## trails lead from it to tonight's 2-3 camps on the right.

signal stop_chosen(stop_id: String)
signal save_and_quit
signal oaths_requested

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const PIP_GAP := 74.0      ## distance between night pips
const PIP_R := 9.0
const OPTION_W := 300.0
const CLEARED_SIZE := Vector2(360, 230)

var _root := VBoxContainer.new()
var _lines: Control
var _tracker: Control
var _cleared: PanelContainer
var _options: Array = []   ## tonight's camp buttons
var _journey_btn: Button
var _journey: PanelContainer
var _dim: ColorRect
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()

	_lines = DrawProxy.new()
	_lines.draw_fn = _draw_trails
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 22)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- night tracker (centred) with the Journey button to its right
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 64)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_tracker = DrawProxy.new()
	_tracker.draw_fn = _draw_tracker
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_tracker)
	_journey_btn = Button.new()
	_journey_btn.text = "Journey"
	_journey_btn.add_theme_font_size_override("font_size", 19)
	_journey_btn.custom_minimum_size = Vector2(118, 40)
	_journey_btn.modulate.a = 0.75
	_journey_btn.disabled = Run.chosen_stops.is_empty() or Run.night == 0
	_journey_btn.pressed.connect(_open_journey)
	top.add_child(_journey_btn)
	top.resized.connect(func(): _place_top(top))

	var h := Label.new()
	h.text = "Choose tonight's camp"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 50)
	h.add_theme_color_override("font_color", Style.ACCENT)
	_root.add_child(h)

	# --- the camp just cleared (left) and tonight's options (right)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 170)   # room for the trails
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)
	_cleared = _cleared_card()
	_cleared.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cleared)

	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 16)
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(opts)
	for id in Run.stop_options[Run.night]:
		var info: Dictionary = Defs.STOPS[id]
		var card := ChoiceCard.make(info["name"], info["desc"], OPTION_W)
		card.custom_minimum_size.y = 104
		card.pressed.connect(func(): stop_chosen.emit(id))
		opts.add_child(card)
		_options.append(card)

	# --- flame and buttons
	var status := Label.new()
	status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Style.MUTE)
	status.add_theme_font_size_override("font_size", 20)
	_root.add_child(status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	_root.add_child(buttons)
	var oaths := Button.new()
	oaths.text = "Oaths"
	oaths.custom_minimum_size = Vector2(180, 58)
	oaths.pressed.connect(func(): oaths_requested.emit())
	buttons.add_child(oaths)
	var save := Button.new()
	save.text = "Save and Quit"
	save.custom_minimum_size = Vector2(280, 58)
	save.pressed.connect(func(): save_and_quit.emit())
	buttons.add_child(save)

	if not _options.is_empty():
		var first: Button = _options[0]
		if Run.autoplay:
			first = _options[Run.rng.randi() % _options.size()]
			get_tree().create_timer(1.6).timeout.connect(first.emit_signal.bind("pressed"))
		first.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	_lines.queue_redraw()
	_tracker.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _journey and event.is_action_pressed("ui_cancel"):
		_close_journey()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ cleared camp
## Large card for the camp Char just held (or the start of the trip).
func _cleared_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CLEARED_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lit by the dawn: a faint white-to-yellow glow and a warm border.
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color("#1d1a1f", 0.92)
	lit.border_color = Color(1.0, 0.9, 0.62, 0.55)
	lit.set_border_width_all(2)
	lit.set_corner_radius_all(8)
	lit.set_content_margin_all(36)
	lit.anti_aliasing = true
	lit.shadow_color = Color(1.0, 0.94, 0.72, 0.2)
	lit.shadow_size = 26
	card.add_theme_stylebox_override("panel", lit)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color", Style.MUTE)
	tag.add_theme_font_size_override("font_size", 17)
	var name := Label.new()
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", Style.display_font(700))
	name.add_theme_font_size_override("font_size", 42)
	name.add_theme_color_override("font_color", Style.ACCENT)
	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CLEARED_SIZE.x - 80, 0)
	desc.add_theme_font_size_override("font_size", 19)

	if Run.night == 0 or Run.chosen_stops.is_empty():
		tag.text = "DUSK · DAY 1"
		name.text = "Setting Out"
		desc.text = "The caravan rolls out at dusk. Seven nights on the road lie ahead."
	else:
		var id: String = Run.chosen_stops[Run.night - 1]
		tag.text = "NIGHT %d CLEARED" % Run.night
		name.text = Defs.STOPS.get(id, {}).get("name", id)
		desc.text = "Char kept the fire burning till dawn."
	box.add_child(tag)
	box.add_child(name)
	box.add_child(desc)
	return card


## Dotted trails from the cleared card to each of tonight's camps, glowing orange.
func _draw_trails(ci: CanvasItem) -> void:
	if _options.is_empty():
		return
	var p0: Vector2 = _cleared.global_position + Vector2(_cleared.size.x, _cleared.size.y / 2) - ci.global_position
	for i in _options.size():
		var b: Button = _options[i]
		var p1: Vector2 = b.global_position + Vector2(0, b.size.y / 2) - ci.global_position
		var hot := b.has_focus() or b.is_hovered()
		var c1: Vector2 = p0 + Vector2((p1.x - p0.x) * 0.5, 0)
		var c2: Vector2 = p1 - Vector2((p1.x - p0.x) * 0.5, 0)
		var pts := []
		var steps := 48
		for k in steps + 1:
			pts.append(_bezier(p0, c1, c2, p1, float(k) / steps))
		# march the dashes toward the camps
		var shift := fmod(_t * 0.6, 1.0)
		for k in steps:
			if (k + int(shift * 4.0)) % 4 >= 2:
				continue
			var a: Vector2 = pts[k]
			var e: Vector2 = pts[k + 1]
			ci.draw_line(a, e, Color(Style.ACCENT2, 0.16 if not hot else 0.3), 11.0, true)   # glow
			ci.draw_line(a, e, Color(Style.ACCENT, 0.55 if not hot else 0.95), 3.5, true)
	ci.draw_circle(p0, 6.0, Style.ACCENT)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


# ------------------------------------------------------------ night tracker
func _place_top(top: Control) -> void:
	var w := PIP_GAP * (Defs.NIGHTS - 1) + 40.0
	_tracker.size = Vector2(w, 64)
	_tracker.position = Vector2((top.size.x - w) / 2, 0)
	_journey_btn.reset_size()
	_journey_btn.position = Vector2(_tracker.position.x + w + 36, 10)


func _draw_tracker(ci: CanvasItem) -> void:
	var y := 20.0
	var x0 := 20.0
	var font := Style.BODY_MEDIUM
	ci.draw_line(Vector2(x0, y), Vector2(x0 + PIP_GAP * (Defs.NIGHTS - 1), y), Color(Style.LINE, 1.0), 2.0, true)
	if Run.night > 0:
		ci.draw_line(Vector2(x0, y), Vector2(x0 + PIP_GAP * Run.night, y), Color(Style.ACCENT2, 0.8), 3.0, true)
	for n in Defs.NIGHTS:
		var c := Vector2(x0 + PIP_GAP * n, y)
		var label_col := Style.MUTE
		if n < Run.night:
			ci.draw_circle(c, PIP_R, Style.ACCENT2)
		elif n == Run.night:
			var pulse := 0.5 + 0.5 * sin(_t * 2.6)
			ci.draw_circle(c, PIP_R + 7 + 2 * pulse, Color(Style.ACCENT2, 0.12 + 0.1 * pulse))
			ci.draw_circle(c, PIP_R + 1, Style.BG)
			ci.draw_arc(c, PIP_R + 1, 0, TAU, 32, Style.ACCENT, 3.0, true)
			ci.draw_circle(c, PIP_R - 4, Style.ACCENT)
			label_col = Style.FG
		else:
			ci.draw_circle(c, PIP_R, Style.BG)
			ci.draw_arc(c, PIP_R, 0, TAU, 32, Color(Style.MUTE, 0.5), 2.0, true)
		var txt := str(n + 1)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		ci.draw_string(font, Vector2(c.x - tw / 2, y + 36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, label_col)


# ------------------------------------------------------------ journey window
## Lists the nights already cleared and where Char camped.
func _open_journey() -> void:
	if _journey:
		return
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_journey = PanelContainer.new()
	_journey.custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_journey.add_child(box)
	var h := Label.new()
	h.text = "Journey"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 48)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for n in mini(Run.night, Run.chosen_stops.size()):
		var a := Label.new()
		a.text = "NIGHT %d" % (n + 1)
		a.add_theme_color_override("font_color", Style.MUTE)
		a.add_theme_font_size_override("font_size", 17)
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(a)
		var b := Label.new()
		b.text = Defs.STOPS.get(Run.chosen_stops[n], {}).get("name", Run.chosen_stops[n])
		b.add_theme_font_size_override("font_size", 24)
		grid.add_child(b)
		# Flame left that dawn: the number in ember orange, the words muted.
		var stat := HBoxContainer.new()
		stat.add_theme_constant_override("separation", 6)
		stat.alignment = BoxContainer.ALIGNMENT_END
		var num := Label.new()
		num.text = str(Run.night_flames[n]) if n < Run.night_flames.size() else "–"
		num.add_theme_font_override("font", Style.BODY_MEDIUM)
		num.add_theme_font_size_override("font_size", 24)
		num.add_theme_color_override("font_color", Style.ACCENT)
		var words := Label.new()
		words.text = "flame left"
		words.add_theme_font_size_override("font_size", 17)
		words.add_theme_color_override("font_color", Style.MUTE)
		var sit := MarginContainer.new()   # sit the small words on the number's baseline
		sit.add_theme_constant_override("margin_bottom", 4)
		sit.size_flags_vertical = Control.SIZE_SHRINK_END
		sit.add_child(words)
		stat.add_child(num)
		stat.add_child(sit)
		grid.add_child(stat)
	box.add_child(grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_journey)
	box.add_child(back)
	add_child(_journey)
	_journey.reset_size()
	_journey.position = (size - _journey.size) / 2
	back.grab_focus()


func _close_journey() -> void:
	if not _journey:
		return
	_journey.queue_free()
	_dim.queue_free()
	_journey = null
	_journey_btn.grab_focus()
