extends Button
## The Faces dropdown, shared by every screen that lists your dice. The
## button shows what is ticked; pressing it opens `panel`, a side panel of
## face toggles the caller places beside its dice so the list stays in view
## and changes as faces are ticked. `changed` fires on every tick,
## `opened(open)` when the panel shows or hides (callers narrow their grid).

signal changed
signal opened(open: bool)

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const FILTERS := [["torch", "Torch"], ["vent", "Steam Vent"], ["mortar", "Mortar"], ["guide", "Guide Light"], ["bellows", "Bellows"], ["brazier", "Ember Brazier"], ["kindle", "Kindle"], ["pine", "Pine Log"], ["wall", "Ember Wall"], ["mire", "Mire"], ["lure", "Wisp Lantern"], ["votive", "Votive Candles"], ["ward", "Ash Ward"], ["reliquary", "Reliquary"]]
const PANEL_W := 440.0

var filters: Array = []    ## face ids ticked
var source: Callable       ## () -> Array of die ids the screen can show
var panel: PanelContainer
var _list: GridContainer
var _scroll: ScrollContainer
var _height := 250.0


func _init(height := 250.0) -> void:
	custom_minimum_size = Vector2(340, 46)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lab := DrawProxy.new()
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.draw_fn = _draw_label
	add_child(lab)
	draw.connect(lab.queue_redraw)
	pressed.connect(func(): set_open(not panel.visible))
	_height = height

	panel = PanelContainer.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CARD
	sb.border_color = Style.ACCENT.darkened(0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var scroll := _scroll
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 6)
	_list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for e in [["Show all dice", func():
			filters.clear()
			_fill()
			_changed()], ["Done", func(): set_open(false)]]:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(e[1])
		row.add_child(b)


func set_open(open: bool) -> void:
	if open == panel.visible:
		return
	if open:
		_fill()
	panel.visible = open
	AudioDirector.play_sfx("tap", -8.0)
	opened.emit(open)
	queue_redraw()


## Die ids carrying any ticked face, those with the most of them first.
func apply(ids: Array) -> Array:
	if filters.is_empty():
		return ids
	var out := ids.filter(func(id): return hits(id, filters) > 0)
	out.sort_custom(func(a, b): return hits(a, filters) > hits(b, filters))
	return out


static func hits(id: String, fs: Array) -> int:
	var n := 0
	for f in fs:
		n += Defs.face_count(Defs.DICE[id]["faces"], f)
	return n


static func face_name(f: String) -> String:
	for e in FILTERS:
		if e[0] == f:
			return e[1]
	return f


## Faces found on the source dice, in FILTERS order.
func _faces() -> Array:
	var ids: Array = source.call()
	var out := []
	for f in FILTERS:
		for id in ids:
			if Defs.face_count(Defs.DICE[id]["faces"], f[0]) > 0:
				out.append(f)
				break
	return out


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var fs := _faces()
	for f in fs:
		_list.add_child(_toggle(f[0], f[1]))
	# Grow to fit the faces, scrolling past the screen's height budget.
	_scroll.custom_minimum_size.y = minf(ceili(fs.size() / 2.0) * 48 - 6, _height - 64)


func _changed() -> void:
	queue_redraw()
	changed.emit()


func _draw_label(ci: CanvasItem) -> void:
	var w := size.x
	var txt := "Faces:  All"
	if filters.size() == 1:
		txt = "Faces:  " + face_name(filters[0])
	elif filters.size() > 1:
		txt = "Faces:  %d chosen" % filters.size()
	var x := 16.0
	for f in filters.slice(0, 4):
		Icons.draw(ci, f, Vector2(x + 9, 23), 18.0, Color(Defs.FACE_INFO[f]["color"]))
		x += 22.0
	ci.draw_string(Style.BODY_MEDIUM, Vector2(x + 4, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, w - x - 44, 18,
		Style.FG if filters.is_empty() else Style.ACCENT)
	var a := Vector2(w - 24, 23)   # the arrow points at the open panel
	var pts := [a + Vector2(-3, -7), a + Vector2(-3, 7), a + Vector2(5, 0)] if panel and panel.visible \
		else [a + Vector2(-7, -3), a + Vector2(7, -3), a + Vector2(0, 5)]
	ci.draw_colored_polygon(PackedVector2Array(pts), Style.ACCENT if panel and panel.visible else Style.MUTE)


func _toggle(f: String, label: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = f in filters
	b.custom_minimum_size = Vector2(200, 42)
	var art := DrawProxy.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw_fn = func(ci: CanvasItem):
		var on := f in filters
		var bx := Rect2(12, 12, 18, 18)   # tick box
		ci.draw_rect(bx, Style.ACCENT if on else Style.MUTE, false, 2.0)
		if on:
			ci.draw_polyline(PackedVector2Array([Vector2(15, 21), Vector2(20, 26), Vector2(28, 15)]), Style.ACCENT, 3.0, true)
		Icons.draw(ci, f, Vector2(50, 21), 22.0, Color(Defs.FACE_INFO[f]["color"]))
		ci.draw_string(Style.BODY_MEDIUM, Vector2(68, 28), label, HORIZONTAL_ALIGNMENT_LEFT, 128, 18, Style.FG if on else Style.MUTE)
	b.add_child(art)
	b.toggled.connect(func(on: bool):
		if on and not f in filters:
			filters.append(f)
		elif not on:
			filters.erase(f)
		art.queue_redraw()
		AudioDirector.play_sfx("tap", -8.0)
		_changed())
	return b
