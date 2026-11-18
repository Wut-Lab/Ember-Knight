extends Control
## Main menu: Play, Unlocks, Options, Credits in one centred column,
## with Continue on top when a saved run exists.
## Play starts a run; Unlocks and Options open an "Under Construction" card;
## Credits lists who made the game. Every card has
## a Back button, and Esc / gamepad B also goes back.

const Style := preload("res://scripts/ui/ui_style.gd")
const EssenceTracker := preload("res://scripts/ui/essence_tracker.gd")

signal play_requested

const ITEMS := ["Play", "Unlocks", "Options", "Credits"]
const BUTTON_SIZE := Vector2(320, 60)

## Title of the card + one line under "Under Construction".
const PLACEHOLDERS := {
	"Unlocks": ["Unlocks", "Caravan unlockables will live here."],
	"Options": ["Options", "Sound, controls and display settings will live here."],
}

const CREDITS := [
	["Game design & direction", "[Your name]"],
	["Char the Ember Knight", "[Your name], drawn with Claude"],
	["Music, sound & code", "Made with Claude"],
	["Fonts", "Grenze Gotisch by Omnibus-Type,\nAlegreya Sans by Huerta Tipográfica (SIL OFL)"],
	["Engine", "Godot Engine (MIT License)"],
]

var _items: Array = ITEMS.duplicate()
var _column: VBoxContainer
var _buttons := {}
var _card: PanelContainer
var _card_back: Button
var _last_pick := "Play"
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 16)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	if Run.has_save():
		_items.push_front("Continue")
		_last_pick = "Continue"
	for item in _items:
		var b := Button.new()
		b.text = item
		b.custom_minimum_size = BUTTON_SIZE
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_pick.bind(item))
		b.mouse_entered.connect(b.grab_focus)
		_column.add_child(b)
		_buttons[item] = b
	add_child(_column)
	var essence := EssenceTracker.new()
	essence.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	essence.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	essence.offset_right = -20
	essence.offset_top = 16
	add_child(essence)
	_column.modulate.a = 0.0
	visible = false
	resized.connect(_layout)


func _layout() -> void:
	_column.reset_size()
	_column.position = Vector2((size.x - _column.size.x) / 2, size.y * 0.53 - _column.size.y / 2)
	if _card:
		_card.reset_size()
		# Centred under the title, never above it.
		var top := maxf(size.y * 0.27, size.y * 0.6 - _card.size.y / 2)
		_card.position = Vector2((size.x - _card.size.x) / 2, top)


## Fades the buttons in one after another.
func appear(delay := 0.0) -> void:
	visible = true
	_layout()
	_column.modulate.a = 1.0
	var i := 0
	for item in _items:
		var b: Button = _buttons[item]
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(delay + i * 0.09)
		t.tween_property(b, "modulate:a", 1.0, 0.45)
		i += 1
	get_tree().create_timer(delay + 0.1).timeout.connect(func(): _buttons[_items[0]].grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if visible and _card and event.is_action_pressed("ui_cancel"):
		_close_card()
		get_viewport().set_input_as_handled()


func _on_pick(item: String) -> void:
	if _busy or _card:
		return
	_last_pick = item
	if item == "Play" or item == "Continue":
		_busy = true
		Run.resume = item == "Continue"
		play_requested.emit()
	elif item == "Credits":
		_open_card(_credits_card())
	else:
		_open_card(_placeholder_card(PLACEHOLDERS[item][0], PLACEHOLDERS[item][1]))


# ------------------------------------------------------------ cards
func _open_card(card: PanelContainer) -> void:
	_busy = true
	_card = card
	add_child(card)
	_layout()
	_layout.call_deferred()  # again once wrapped text knows its width
	card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_column, "modulate:a", 0.0, 0.2)
	t.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.12)
	t.chain().tween_callback(func():
		_column.visible = false
		_card_back.grab_focus()
		_busy = false)


func _close_card() -> void:
	if _busy or not _card:
		return
	_busy = true
	var card := _card
	_column.visible = true
	var t := create_tween().set_parallel()
	t.tween_property(card, "modulate:a", 0.0, 0.2)
	t.tween_property(_column, "modulate:a", 1.0, 0.3).set_delay(0.12)
	t.chain().tween_callback(func():
		card.queue_free()
		_card = null
		_buttons[_last_pick].grab_focus()
		_busy = false)


func _base_card(heading: String) -> Array:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var h := Label.new()
	h.text = heading
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 52)
	h.add_theme_color_override("font_color", Style.ACCENT)
	box.add_child(h)
	return [card, box]


func _add_back(box: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	_card_back = Button.new()
	_card_back.text = "Back"
	_card_back.custom_minimum_size = Vector2(200, 54)
	_card_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_back.pressed.connect(_close_card)
	box.add_child(_card_back)


func _placeholder_card(heading: String, line: String) -> PanelContainer:
	var parts := _base_card(heading)
	var box: VBoxContainer = parts[1]
	var sign := Label.new()
	sign.text = "Under Construction"
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_theme_font_override("font", Style.BODY_MEDIUM)
	sign.add_theme_font_size_override("font_size", 30)
	box.add_child(sign)
	var sub := Label.new()
	sub.text = line
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(440, 0)
	sub.add_theme_color_override("font_color", Style.MUTE)
	sub.add_theme_font_size_override("font_size", 22)
	box.add_child(sub)
	_add_back(box)
	return parts[0]


func _credits_card() -> PanelContainer:
	var parts := _base_card("Credits")
	var box: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in CREDITS:
		var role := Label.new()
		role.text = row[0].to_upper()
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		role.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		role.size_flags_vertical = Control.SIZE_FILL
		role.add_theme_color_override("font_color", Style.MUTE)
		role.add_theme_font_size_override("font_size", 15)
		role.add_theme_constant_override("line_spacing", 0)
		var holder := MarginContainer.new()  # nudge small caps onto the name's baseline
		holder.add_theme_constant_override("margin_top", 5)
		holder.add_child(role)
		grid.add_child(holder)
		var who := Label.new()
		who.text = row[1]
		who.add_theme_font_size_override("font_size", 21)
		who.add_theme_constant_override("line_spacing", -2)
		grid.add_child(who)
	box.add_child(grid)
	_add_back(box)
	return parts[0]
