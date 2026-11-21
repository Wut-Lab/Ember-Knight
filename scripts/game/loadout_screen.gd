extends Control
## Before each night: fill the dice slots from the dice owned this run.
## Tap a die in the bag to put it in the first empty slot; tap a slot to
## empty it. Filters narrow the bag to dice carrying a given face.

signal confirmed
signal oaths_requested

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DieView := preload("res://scripts/game/die_view.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const FILTERS := [["torch", "Torch"], ["vent", "Steam Vent"], ["mortar", "Mortar"], ["guide", "Guide Light"], ["kindle", "Kindle"], ["pine", "Pine Log"]]

var _slots: Array = []        ## die id per slot, "" when empty
var _filter := ""
var _slot_row: HBoxContainer
var _filter_row: HBoxContainer
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

	_filter_row = HBoxContainer.new()
	_filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_filter_row.add_theme_constant_override("separation", 8)
	root.add_child(_filter_row)

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
	for c in _slot_row.get_children() + _filter_row.get_children() + _grid.get_children():
		c.queue_free()
	for i in _slots.size():
		_slot_row.add_child(_slot_button(i))
	for f in FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_pressed = _filter == f[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			_filter = "" if _filter == f[0] else f[0]   # tap an active filter again to clear it
			_refresh())
		_filter_row.add_child(b)
	var reset := Button.new()
	reset.text = "Reset"
	reset.disabled = _filter == ""
	reset.custom_minimum_size = Vector2(0, 44)
	reset.add_theme_font_size_override("font_size", 18)
	reset.pressed.connect(func():
		_filter = ""
		_refresh())
	_filter_row.add_child(reset)
	if _filter == "" and Defs.has_forks(Run.current_stop()):
		_grid.add_child(_gate_card())
	for id in _bag_ids():
		_grid.add_child(_bag_card(id))
	_go.disabled = "" in _slots
	_go.text = "Begin Night" if not _go.disabled else "Fill every slot"


## Owned die kinds, filtered, those with the most of the filter face first.
func _bag_ids() -> Array:
	var ids := []
	for id in Defs.DICE:
		if Run.owned(id) > 0 and (_filter == "" or Defs.face_count(Defs.DICE[id]["faces"], _filter) > 0):
			ids.append(id)
	if _filter != "":
		ids.sort_custom(func(a, b): return Defs.face_count(Defs.DICE[a]["faces"], _filter) > Defs.face_count(Defs.DICE[b]["faces"], _filter))
	return ids


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
