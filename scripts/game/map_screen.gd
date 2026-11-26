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
const Vignette := preload("res://scripts/game/camp_vignette.gd")

const PIP_GAP := 54.0      ## distance between night pips
const LEG_GAP := 34.0      ## extra space between legs
const PIP_R := 9.0
const OPTION_W := 460.0
const VIG := Vector2(124, 86)          ## camp picture on each option card
const CLEARED_SIZE := Vector2(320, 230)

var _root := VBoxContainer.new()
var _lines: Control
var _tracker: Control
var _cleared: PanelContainer
var _options: Array = []   ## tonight's camp buttons
var _journey_btn: Button
var _journey: PanelContainer
var _dim: ColorRect
var _leaders: Control      ## dotted lines from each Journey camp to its flame count
var _leader_pairs: Array = []
var _t := 0.0
var _vigs: Array = []      ## camp pictures, redrawn every frame
var _coach_u := 0.0        ## 0..1: the coach's way down the hovered trail
var _coach_on := -1        ## which option's trail it is on


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
	opts.add_theme_constant_override("separation", 12)
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(opts)
	for id in Run.stop_options[Run.night]:
		var card := _camp_card(id)
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
	for v in _vigs:
		v.queue_redraw()
	# The coach rolls down whichever trail is hovered, then waits and goes again.
	var hot := -1
	for i in _options.size():
		if _options[i].has_focus() or _options[i].is_hovered():
			hot = i
	if hot != _coach_on:
		_coach_on = hot
		_coach_u = 0.0
	elif hot != -1:
		_coach_u = fmod(_coach_u + delta * 0.55, 1.6)
	_tracker.queue_redraw()
	if _leaders:
		_leaders.queue_redraw()


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
	lit.set_content_margin_all(28)
	lit.anti_aliasing = true
	lit.shadow_color = Color(1.0, 0.94, 0.72, 0.2)
	lit.shadow_size = 26
	card.add_theme_stylebox_override("panel", lit)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var last: String = "road" if Run.night == 0 or Run.chosen_stops.is_empty() else Run.chosen_stops[Run.night - 1]
	box.add_child(_vignette(last, Vector2(CLEARED_SIZE.x - 72, 92), true))

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


## A camp on tonight's route: its picture, then its name and what it holds.
## The card grows to fit the description.
func _camp_card(id: String) -> Button:
	var info: Dictionary = Defs.STOPS[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(OPTION_W, VIG.y + 20)
	b.mouse_entered.connect(b.grab_focus)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var v := _vignette(id, VIG)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := Label.new()
	t.text = info["name"]
	t.add_theme_font_override("font", Style.display_font(600))
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Style.ACCENT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var d := Label.new()
	d.text = info["desc"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = OPTION_W - VIG.x - 38
	d.add_theme_font_size_override("font_size", 16)
	d.add_theme_color_override("font_color", Style.FG)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	row.minimum_size_changed.connect(func():
		b.custom_minimum_size.y = maxf(VIG.y + 20, row.get_combined_minimum_size().y + 20))
	return b


func _vignette(id: String, sz: Vector2, dawn := false) -> Control:
	var v := DrawProxy.new()
	v.custom_minimum_size = sz
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.clip_contents = true
	v.draw_fn = func(ci): Vignette.draw(ci, id, sz, _t, dawn)
	_vigs.append(v)
	return v


## Wagon trails from the cleared card to each of tonight's camps: packed
## dirt with two ruts and grass along the verges, embers drifting down it
## toward the camp. The hovered trail lights up and the coach rolls down it.
func _draw_trails(ci: CanvasItem) -> void:
	if _options.is_empty():
		return
	var p0: Vector2 = _cleared.global_position + Vector2(_cleared.size.x, _cleared.size.y / 2) - ci.global_position
	var hot_pts := []
	for i in _options.size():
		var b: Button = _options[i]
		var p1: Vector2 = b.global_position + Vector2(0, b.size.y / 2) - ci.global_position
		var hot := i == _coach_on
		var c1: Vector2 = p0 + Vector2((p1.x - p0.x) * 0.5, 0)
		var c2: Vector2 = p1 - Vector2((p1.x - p0.x) * 0.5, 0)
		var pts := PackedVector2Array()
		var steps := 40
		for k in steps + 1:
			pts.append(_bezier(p0, c1, c2, p1, float(k) / steps))
		var lit := 1.0 if hot else 0.55
		if hot:
			ci.draw_polyline(pts, Color(Style.ACCENT2, 0.10), 34.0, true)   # warm glow under it
			hot_pts = pts
		ci.draw_polyline(pts, Color(DIRT_EDGE, lit), 18.0, true)
		ci.draw_polyline(pts, Color(DIRT, lit), 14.0, true)
		for side in [-1.0, 1.0]:   # ruts
			var rut := PackedVector2Array()
			for k in pts.size():
				rut.append(pts[k] + _normal(pts, k) * 3.5 * side)
			ci.draw_polyline(rut, Color(RUT, lit), 1.6, true)
		for k in range(3, steps - 2, 3):   # grass on the verges
			var side := 1.0 if (k + i) % 2 else -1.0
			var base: Vector2 = pts[k] + _normal(pts, k) * (10.0 + 4.0 * Vignette._r(k + i * 7, 2)) * side
			_tuft(ci, base, 5.0 + 6.0 * Vignette._r(k + i * 7, 3), k + i * 13, lit)
		# embers drifting toward the camp
		var n := 5 if hot else 3
		for e in n:
			var u := fmod(_t * (0.22 if hot else 0.12) + float(e) / n + i * 0.13, 1.0)
			var p := _bezier(p0, c1, c2, p1, u)
			var a := sin(u * PI) * (0.95 if hot else 0.45)
			ci.draw_circle(p, 5.0, Color(Style.ACCENT2, 0.18 * a))
			ci.draw_circle(p, 1.8, Color(Style.ACCENT, a))
	# you are here: a lantern post at the end of last night's road
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	ci.draw_circle(p0, 12.0 + 3.0 * pulse, Color(Style.ACCENT2, 0.12 + 0.08 * pulse))
	ci.draw_circle(p0, 6.0, Style.ACCENT)
	ci.draw_circle(p0, 2.6, Color("#fff0b8"))
	if not hot_pts.is_empty():
		_draw_coach(ci, hot_pts, clampf(_coach_u, 0.0, 1.0))


const DIRT := Color("#4a3e2e")
const DIRT_EDGE := Color("#2b241c")
const RUT := Color("#241e18")


static func _normal(pts: PackedVector2Array, k: int) -> Vector2:
	var a := pts[maxi(k - 1, 0)]
	var b := pts[mini(k + 1, pts.size() - 1)]
	return (b - a).normalized().orthogonal()


static func _tuft(ci: CanvasItem, p: Vector2, h: float, i: int, lit: float) -> void:
	for k in 5:
		var lean := (Vignette._r(i, 10 + k) - 0.5) * 7.0
		var hh := h * (0.55 + 0.6 * Vignette._r(i, 20 + k))
		var x := p.x + (k - 2) * 1.8
		var col := Color("#5f6d4f").lerp(Color("#8e9a6c"), Vignette._r(i, 30 + k) * 0.7)
		ci.draw_line(Vector2(x, p.y), Vector2(x + lean, p.y - hh), Color(col, lit), 1.4, true)


## The little stagecoach, rolling along the trail (u 0..1), wheels turning.
func _draw_coach(ci: CanvasItem, pts: PackedVector2Array, u: float) -> void:
	var f := u * (pts.size() - 1)
	var k := mini(int(f), pts.size() - 2)
	var p := pts[k].lerp(pts[k + 1], f - k)
	var dir := (pts[k + 1] - pts[k]).normalized()
	var ang := clampf(dir.angle(), -0.5, 0.5)
	var bob := sin(_t * 14.0) * 0.6 if u < 1.0 else 0.0
	ci.draw_set_transform(p + Vector2(0, -9 + bob), ang, Vector2.ONE)
	ci.draw_circle(Vector2(0, 8), 14.0, Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(-12, -9, 22, 13), Color("#5b3f2a"))           # body
	ci.draw_rect(Rect2(-12, -9, 22, 13), Color("#2a1c12"), false, 1.2)
	ci.draw_rect(Rect2(-8, -6, 6, 5), Color("#ffcf7a"))               # lit window
	ci.draw_rect(Rect2(-14, -12, 26, 3), Color("#3a2a1d"))           # roof
	ci.draw_line(Vector2(10, 0), Vector2(17, 0), Color("#3a2a1d"), 1.5)   # shaft
	ci.draw_circle(Vector2(14, -10), 2.2, Color(Style.ACCENT, 0.9))    # lantern
	ci.draw_circle(Vector2(14, -10), 5.0, Color(Style.ACCENT2, 0.2))
	var spin := _t * 9.0 if u < 1.0 else 0.0
	for wx in [-7.0, 6.0]:
		var c := Vector2(wx, 5)
		ci.draw_circle(c, 4.5, Color("#2a1c12"))
		ci.draw_arc(c, 4.5, 0, TAU, 16, Color("#8a6a48"), 1.2, true)
		for sp in 3:
			var a := spin + sp * PI / 3.0
			ci.draw_line(c - Vector2(cos(a), sin(a)) * 4.0, c + Vector2(cos(a), sin(a)) * 4.0, Color("#8a6a48"), 0.8)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


# ------------------------------------------------------------ night tracker
func _place_top(top: Control) -> void:
	var w := _pip_x(Defs.NIGHTS - 1) + 20.0
	_tracker.size = Vector2(w, 64)
	_tracker.position = Vector2((top.size.x - w) / 2, 0)
	_journey_btn.reset_size()
	_journey_btn.position = Vector2(_tracker.position.x + w + 36, 10)


## x of a night's pip: evenly spaced, with a gap between legs.
func _pip_x(n: int) -> float:
	return 20.0 + PIP_GAP * n + LEG_GAP * Defs.leg_of(n)


func _draw_tracker(ci: CanvasItem) -> void:
	var y := 20.0
	var x0 := 20.0
	var font := Style.BODY_MEDIUM
	ci.draw_line(Vector2(x0, y), Vector2(_pip_x(Defs.NIGHTS - 1), y), Color(Style.LINE, 1.0), 2.0, true)
	if Run.night > 0:
		ci.draw_line(Vector2(x0, y), Vector2(_pip_x(Run.night), y), Color(Style.ACCENT2, 0.8), 3.0, true)
	for n in Defs.NIGHTS:
		var c := Vector2(_pip_x(n), y)
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
## Faint glowing orange dots leading from each camp name to its flame count.
func _draw_leaders(ci: CanvasItem) -> void:
	for pair in _leader_pairs:
		var name_l: Label = pair[0]
		var num_l: Label = pair[1]
		if not is_instance_valid(name_l) or not is_instance_valid(num_l):
			continue
		var font := name_l.get_theme_font("font")
		var fs := name_l.get_theme_font_size("font_size")
		var text_w := font.get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var origin: Vector2 = (ci as Control).global_position
		var y: float = name_l.global_position.y + name_l.size.y * 0.62 - origin.y
		var x0: float = name_l.global_position.x + text_w + 12.0 - origin.x
		var x1: float = num_l.global_position.x - 10.0 - origin.x
		var x: float = x0
		while x <= x1:
			ci.draw_circle(Vector2(x, y), 4.0, Color(Style.ACCENT2, 0.12))   # glow
			ci.draw_circle(Vector2(x, y), 1.6, Color(Style.ACCENT, 0.6))
			x += 9.0


## Lists the nights already cleared and where Char camped.
func _open_journey() -> void:
	if _journey:
		return
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_journey = PanelContainer.new()
	_leader_pairs.clear()
	_journey.custom_minimum_size = Vector2(600, 0)
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
		_leader_pairs.append([b, num])
		stat.add_child(num)
		stat.add_child(sit)
		grid.add_child(stat)
	# Widen the name column so even the longest name gets a run of dots.
	var widest := 0.0
	for pair in _leader_pairs:
		var l: Label = pair[0]
		widest = maxf(widest, Style.BODY_FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x)
	if not _leader_pairs.is_empty():
		(_leader_pairs[0][0] as Label).custom_minimum_size.x = widest + 64.0
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
	_leaders = DrawProxy.new()
	_leaders.draw_fn = _draw_leaders
	_leaders.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_leaders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leaders)
	_journey.reset_size()
	_journey.position = (size - _journey.size) / 2
	for n in [_dim, _journey, _leaders]:
		if n:
			n.modulate.a = 0.0
			create_tween().tween_property(n, "modulate:a", 1.0, 0.18)
	back.grab_focus()


func _close_journey() -> void:
	if not _journey:
		return
	_journey.queue_free()
	_dim.queue_free()
	_leaders.queue_free()
	_journey = null
	_leaders = null
	_journey_btn.grab_focus()
