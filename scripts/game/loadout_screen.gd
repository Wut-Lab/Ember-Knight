extends Control
## Before each night: fill the dice slots from the dice owned this run.
## Tap a die in the bag to put it in the first empty slot; tap a slot to
## empty it. The Faces dropdown narrows the bag to dice carrying any of the
## faces ticked in it.

signal confirmed
signal oaths_requested

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DieView := preload("res://scripts/game/die_view.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const FILTERS := [["torch", "Torch"], ["vent", "Steam Vent"], ["mortar", "Mortar"], ["guide", "Guide Light"], ["bellows", "Bellows"], ["brazier", "Ember Brazier"], ["kindle", "Kindle"], ["pine", "Pine Log"], ["wall", "Ember Wall"], ["mire", "Mire"], ["lure", "Wisp Lantern"], ["votive", "Votive Candles"], ["ward", "Ash Ward"], ["reliquary", "Reliquary"]]

var _slots: Array = []        ## die id per slot, "" when empty
var _filters: Array = []     ## face ids ticked in the Faces dropdown
var _slot_row: HBoxContainer
var _filter_btn: Button
var _filter_pop: PopupPanel
var _grid: GridContainer
var _go: Button


const GATE_KIT := "_gates"   ## a slot traded for gates
const Board := preload("res://scripts/game/board.gd")

var _forks := 0   ## forks on tonight's map, shown on the gate card


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	_forks = Board.fork_count(Run.current_stop(), Run.layout_seed)
	_slots = _start_slots()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var h := Label.new()
	h.text = "Choose tonight's dice"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 48)
	h.add_theme_color_override("font_color", Style.ACCENT)
	root.add_child(h)

	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 18)
	root.add_child(_slot_row)

	var bag := Label.new()
	bag.text = "YOUR DICE"
	bag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag.add_theme_color_override("font_color", Style.MUTE)
	bag.add_theme_font_size_override("font_size", 15)
	root.add_child(bag)

	var frow := HBoxContainer.new()
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(frow)
	frow.add_child(_build_filter())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_grid)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	root.add_child(bottom)
	var oaths := Button.new()
	oaths.text = "Oaths"
	oaths.custom_minimum_size = Vector2(180, 58)
	oaths.pressed.connect(func(): oaths_requested.emit())
	bottom.add_child(oaths)
	_go = Button.new()
	_go.text = "Begin Night"
	_go.custom_minimum_size = Vector2(260, 58)
	_go.pressed.connect(_confirm)
	bottom.add_child(_go)

	_refresh()
	_go.grab_focus.call_deferred()
	if Run.autoplay:
		get_tree().create_timer(1.2).timeout.connect(_confirm)


## Last night's dice if still owned, topped up from the bag.
func _start_slots() -> Array:
	var out := []
	if Run.gates > Defs.GATES_FREE and _forks > Defs.GATES_FREE:   # kept the gate kit last night
		out.append(GATE_KIT)
	for id in Run.loadout:
		if out.count(id) < Run.owned(id) and out.size() < Defs.dice_slots(Run.night):
			out.append(id)
	for id in Run.pool:
		if out.size() < Defs.dice_slots(Run.night) and out.count(id) < Run.owned(id):
			out.append(id)
	while out.size() < Defs.dice_slots(Run.night):
		out.append("")
	return out


func _confirm() -> void:
	if Run.autoplay and not GATE_KIT in _slots and _forks > Defs.GATES_FREE and Run.rng.randf() < 0.5:
		_slots[_slots.size() - 1] = GATE_KIT   # autoplay trades half the time when forks outnumber gates
	if "" in _slots:
		return
	Run.gates = Defs.GATES_FREE + _slots.count(GATE_KIT) * Defs.GATES_PER_SLOT
	Run.loadout = _slots.filter(func(id): return id != GATE_KIT)
	Run.apply_loadout()
	AudioDirector.play_sfx("dice_roll", -6.0)
	confirmed.emit()


func _refresh() -> void:
	for c in _slot_row.get_children() + _grid.get_children():
		c.queue_free()
	for i in _slots.size():
		_slot_row.add_child(_slot_button(i))
	_filter_btn.queue_redraw()
	if _filters.is_empty() and Defs.has_forks(Run.current_stop()):
		_grid.add_child(_gate_card())
	for id in _bag_ids():
		_grid.add_child(_bag_card(id))
	_go.disabled = "" in _slots
	_go.text = "Begin Night" if not _go.disabled else "Fill every slot"


## Owned die kinds carrying any ticked face, those with the most of them first.
func _bag_ids() -> Array:
	var ids := []
	for id in Defs.DICE:
		if Run.owned(id) > 0 and (_filters.is_empty() or _hits(id) > 0):
			ids.append(id)
	if not _filters.is_empty():
		ids.sort_custom(func(a, b): return _hits(a) > _hits(b))
	return ids


func _hits(id: String) -> int:
	var n := 0
	for f in _filters:
		n += Defs.face_count(Defs.DICE[id]["faces"], f)
	return n


## Faces found on the dice owned this run, in FILTERS order.
func _owned_faces() -> Array:
	var out := []
	for f in FILTERS:
		for id in Defs.DICE:
			if Run.owned(id) > 0 and Defs.face_count(Defs.DICE[id]["faces"], f[0]) > 0:
				out.append(f)
				break
	return out


## The Faces dropdown: a button showing what is ticked, opening a panel of
## face toggles (icon, name, tick) that stays open while choosing several.
func _build_filter() -> Button:
	_filter_btn = Button.new()
	_filter_btn.custom_minimum_size = Vector2(340, 46)
	var lab := DrawProxy.new()
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.draw_fn = func(ci: CanvasItem):
		var w := _filter_btn.size.x
		var txt := "Faces:  All"
		if _filters.size() == 1:
			txt = "Faces:  " + _face_name(_filters[0])
		elif _filters.size() > 1:
			txt = "Faces:  %d chosen" % _filters.size()
		var x := 16.0
		for f in _filters.slice(0, 4):
			Icons.draw(ci, f, Vector2(x + 9, 23), 18.0, Color(Defs.FACE_INFO[f]["color"]))
			x += 22.0
		_text(ci, txt, Vector2(x + 4, 30), w - x - 44, 18, Style.FG if _filters.is_empty() else Style.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
		var a := Vector2(w - 24, 23)   # the drop arrow
		ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-7, -3), a + Vector2(7, -3), a + Vector2(0, 5)]), Style.MUTE)
	_filter_btn.add_child(lab)
	_filter_btn.draw.connect(lab.queue_redraw)

	_filter_pop = PopupPanel.new()
	_filter_pop.theme = Style.make_theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.CARD
	sb.border_color = Style.ACCENT.darkened(0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	_filter_pop.add_theme_stylebox_override("panel", sb)
	add_child(_filter_pop)
	_filter_btn.pressed.connect(_open_filter)
	return _filter_btn


func _open_filter() -> void:
	for c in _filter_pop.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_filter_pop.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for f in _owned_faces():
		grid.add_child(_face_toggle(f[0], f[1]))
	var clear := Button.new()
	clear.text = "Show all dice"
	clear.custom_minimum_size = Vector2(0, 40)
	clear.add_theme_font_size_override("font_size", 17)
	clear.pressed.connect(func():
		_filters.clear()
		_filter_pop.hide()
		_refresh())
	box.add_child(clear)
	_filter_pop.reset_size()
	var r := _filter_btn.get_global_rect()
	_filter_pop.popup(Rect2i(Vector2i(r.position.x + r.size.x / 2 - 220, r.end.y + 6), Vector2i(440, 0)))


func _face_toggle(f: String, label: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = f in _filters
	b.custom_minimum_size = Vector2(208, 42)
	var art := DrawProxy.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw_fn = func(ci: CanvasItem):
		var on := f in _filters
		var bx := Rect2(12, 12, 18, 18)   # tick box
		ci.draw_rect(bx, Style.ACCENT if on else Style.MUTE, false, 2.0)
		if on:
			ci.draw_polyline(PackedVector2Array([Vector2(15, 21), Vector2(20, 26), Vector2(28, 15)]), Style.ACCENT, 3.0, true)
		Icons.draw(ci, f, Vector2(50, 21), 22.0, Color(Defs.FACE_INFO[f]["color"]))
		_text(ci, label, Vector2(68, 28), 136, 18, Style.FG if on else Style.MUTE, HORIZONTAL_ALIGNMENT_LEFT)
	b.add_child(art)
	b.toggled.connect(func(on: bool):
		if on and not f in _filters:
			_filters.append(f)
		elif not on:
			_filters.erase(f)
		art.queue_redraw()
		AudioDirector.play_sfx("tap", -8.0)
		_refresh())
	return b


func _face_name(f: String) -> String:
	for e in FILTERS:
		if e[0] == f:
			return e[1]
	return f


func _slot_button(i: int) -> Button:
	var id: String = _slots[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 150)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func():
		if _slots[i] != "":
			_slots[i] = ""
			AudioDirector.play_sfx("tap", -8.0)
			_refresh())
	var art := DrawProxy.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw_fn = func(ci: CanvasItem):
		var c := Vector2(85, 62)
		if id == GATE_KIT:
			_draw_gate(ci, c, 1.6)
			_text(ci, "+%d Gate" % Defs.GATES_PER_SLOT, Vector2(0, 132), 170, 18, Style.FG)
		elif id == "":
			for k in 16:  # dashed outline of an empty slot
				var a0 := TAU * k / 16.0
				ci.draw_arc(c, 40, a0, a0 + TAU / 32.0, 4, Color(1, 1, 1, 0.3), 3.0, true)
			_text(ci, "Slot %d" % (i + 1), Vector2(0, 132), 170, 18, Style.MUTE)
		else:
			DieView.draw_die(ci, c, 76.0, Defs.DICE[id]["faces"], 0, true, false, 0.0)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
			_text(ci, Defs.DICE[id]["name"], Vector2(0, 132), 170, 18, Style.FG)
	b.add_child(art)
	return b


## Trade one die slot for gates Char cobbles at the forks.
func _gate_card() -> Button:
	var used := GATE_KIT in _slots
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 112)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func():
		var empty := _slots.find("")
		if used:
			_slots[_slots.find(GATE_KIT)] = ""
		elif empty != -1:
			_slots[empty] = GATE_KIT
		AudioDirector.play_sfx("tap", -8.0)
		_refresh())
	var art := DrawProxy.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw_fn = func(ci: CanvasItem):
		_draw_gate(ci, Vector2(44, 58), 1.0)
		_text(ci, "Cobble Gates", Vector2(82, 30), 116, 17, Style.FG, HORIZONTAL_ALIGNMENT_LEFT)
		ci.draw_multiline_string(Style.BODY_MEDIUM, Vector2(82, 50), "%d fork%s tonight. Trade a slot for +%d gate." % [_forks, "" if _forks == 1 else "s", Defs.GATES_PER_SLOT],
			HORIZONTAL_ALIGNMENT_LEFT, 112, 13, 3, Style.MUTE)
		_text(ci, "In use" if used else "%d gate free" % Defs.GATES_FREE, Vector2(82, 98), 116, 15,
			Style.ACCENT if used else Style.MUTE, HORIZONTAL_ALIGNMENT_LEFT)
	b.add_child(art)
	return b


static func _draw_gate(ci: CanvasItem, c: Vector2, k: float) -> void:
	var wood := Color("#c88a50")
	for x in [-22.0, 22.0]:
		ci.draw_line(c + Vector2(x, 26) * k, c + Vector2(x, -26) * k, wood.darkened(0.3), 7 * k, true)
	for y in [-14.0, 8.0]:
		ci.draw_line(c + Vector2(-30, y) * k, c + Vector2(30, y) * k, wood, 7 * k, true)
	ci.draw_line(c + Vector2(-20, 8) * k, c + Vector2(20, -14) * k, wood.darkened(0.15), 5 * k, true)


func _bag_card(id: String) -> Button:
	var used := _slots.count(id)
	var have := Run.owned(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 112)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func():
		var empty := _slots.find("")
		if empty != -1 and _slots.count(id) < Run.owned(id):
			_slots[empty] = id
		elif _slots.count(id) > 0:   # every copy in use: tap takes one back out
			_slots[_slots.rfind(id)] = ""
		AudioDirector.play_sfx("tap", -8.0)
		_refresh())
	var art := DrawProxy.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw_fn = func(ci: CanvasItem):
		DieView.draw_die(ci, Vector2(44, 56), 54.0, Defs.DICE[id]["faces"], 0, false, false, 0.0)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_text(ci, Defs.DICE[id]["name"], Vector2(82, 30), 116, 17, Style.FG, HORIZONTAL_ALIGNMENT_LEFT)
		# Face tally: one small icon per face kind with its count.
		var x := 84.0
		for f in Defs.DIE_FACES:
			var n: int = Defs.face_count(Defs.DICE[id]["faces"], f)
			if n == 0:
				continue
			Icons.draw(ci, f, Vector2(x + 9, 54), 20.0, Color(Defs.FACE_INFO[f]["color"]))
			_text(ci, "%d" % n, Vector2(x + 19, 61), 16, 16, Style.FG, HORIZONTAL_ALIGNMENT_LEFT)
			x += 36.0
		_text(ci, "In use %d  ·  %d left" % [used, have - used], Vector2(82, 86), 116, 15,
			Style.ACCENT if used > 0 else Style.MUTE, HORIZONTAL_ALIGNMENT_LEFT)
		# Copies owned against the cap: a die leaves the Dawn Offerings at MAX_DIE_COPIES.
		var capped := have >= Defs.MAX_DIE_COPIES
		_text(ci, ("Owned %d / %d" % [have, Defs.MAX_DIE_COPIES]) if have <= Defs.MAX_DIE_COPIES else "Owned %d" % have,
			Vector2(82, 104), 116, 15, Style.MUTE.lerp(Style.ACCENT, 0.5) if capped else Style.MUTE, HORIZONTAL_ALIGNMENT_LEFT)
	b.add_child(art)
	return b


static func _text(ci: CanvasItem, s: String, at: Vector2, w: float, px: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	ci.draw_string(Style.BODY_MEDIUM, at, s, align, w, px, col)
