extends Control
## The Oaths menu: a small card listing the Oaths sworn this run, each with
## its symbol on the left and its name on the right. Tapping one opens a card
## that explains it. Each card has a Back button (Esc / gamepad B too).
## Pauses the game while open.

signal closed

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const OATH_COL := Color("#ffb238")

var _card: PanelContainer
var _was_paused := false
var _detail := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	_was_paused = get_tree().paused
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	resized.connect(_layout)
	_show_list()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _back() -> void:
	if _detail:
		_show_list()
	else:
		get_tree().paused = _was_paused
		closed.emit()
		queue_free()


func _layout() -> void:
	if _card:
		_card.reset_size()
		_card.position = (size - _card.size) / 2


func _new_card(heading: String) -> VBoxContainer:
	if _card:
		_card.queue_free()
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(460, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_card.add_child(box)
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 46)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	add_child(_card)
	_layout.call_deferred()
	return box


func _icon(kind: String, px: float) -> Control:
	var ic := DrawProxy.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw_fn = func(ci: CanvasItem):
		ci.draw_circle(Vector2(px, px) / 2, px * 0.48, Color(0, 0, 0, 0.3))
		Icons.draw(ci, kind, Vector2(px, px) / 2, px * 0.85, OATH_COL)
	return ic


func _back_button(box: VBoxContainer) -> void:
	var b := Button.new()
	b.text = "Back"
	b.custom_minimum_size = Vector2(200, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_back)
	box.add_child(b)
	b.grab_focus.call_deferred()


func _show_list() -> void:
	_detail = false
	var box := _new_card("Oaths")
	if Run.oaths.is_empty():
		var none := Label.new()
		none.text = "No Oaths sworn yet.\nThey can be found among the Dawn Offerings."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", Style.MUTE)
		none.add_theme_font_size_override("font_size", 20)
		box.add_child(none)
	for id in Run.oaths:
		var info: Dictionary = Defs.OATHS[id]
		var row := Button.new()
		row.custom_minimum_size = Vector2(400, 64)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.mouse_entered.connect(row.grab_focus)
		row.pressed.connect(_show_detail.bind(id))
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_icon(info["icon"], 52))
		var name := Label.new()
		name.text = info["name"]
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name.add_theme_font_size_override("font_size", 22)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(name)
		row.add_child(h)
		box.add_child(row)
	_back_button(box)


func _show_detail(id: String) -> void:
	_detail = true
	var info: Dictionary = Defs.OATHS[id]
	var box := _new_card(info["name"])
	var ic := _icon(info["icon"], 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var d := Label.new()
	d.text = info["desc"]
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(420, 0)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 20)
	box.add_child(d)
	_back_button(box)
