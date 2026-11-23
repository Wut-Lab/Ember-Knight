extends Control
## "Who rides along?": before night 1 of a new run, pick up to
## Defs.CARAVAN_SEATS hired caravan members to ride on the stagecoach.
## Last run's riders are picked to start with. Emits `done` once set out;
## the picks go to Run.riders (and Profile.riders for next time).

signal done

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const Icons := preload("res://scripts/game/icons.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

const CARD := Vector2(220, 250)

var _picked: Array = []
var _cards := {}
var _seats: Label
var _go: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	for id in Profile.riders:
		if id in Profile.members and _picked.size() < Defs.CARAVAN_SEATS:
			_picked.append(id)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	var h := Label.new()
	h.text = "Who rides along?"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", Style.ACCENT)
	root.add_child(h)
	_seats = Label.new()
	_seats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seats.add_theme_font_size_override("font_size", 22)
	_seats.add_theme_color_override("font_color", Style.MUTE)
	root.add_child(_seats)
	# Cards wrap onto a second row past 4 members.
	var grid := GridContainer.new()
	grid.columns = mini(Profile.members.size(), 4)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(grid)
	for id in Defs.CARAVAN:
		if id in Profile.members:
			var c := _card(id)
			grid.add_child(c)
			_cards[id] = c
	_go = Button.new()
	_go.custom_minimum_size = Vector2(260, 60)
	_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_go.pressed.connect(_set_out)
	root.add_child(_go)
	_refresh()
	_go.grab_focus.call_deferred()


func _card(id: String) -> Button:
	var m: Dictionary = Defs.CARAVAN[id]
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.toggle_mode = true
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(_toggle.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 12
	box.offset_bottom = -12
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var px := 80.0
	var ic := DrawProxy.new()
	ic.custom_minimum_size = Vector2(px, px)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw_fn = func(ci: CanvasItem):
		var on: bool = id in _picked
		ci.draw_circle(Vector2(px, px) / 2, px * 0.48, Color(1, 0.6, 0.2, 0.16) if on else Color(0, 0, 0, 0.3))
		Icons.draw(ci, m["icon"], Vector2(px, px) / 2, px * 0.85, Style.ACCENT if on else Color("#b0a69b"))
	box.add_child(ic)
	var name := Label.new()
	name.text = m["name"]
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", Style.display_font(600))
	name.add_theme_font_size_override("font_size", 26)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(CARD.x - 24, 0)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var desc := Label.new()
	desc.text = m["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD.x - 24, 0)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Style.MUTE)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc)
	return b


## Picking past the last seat bumps the earliest pick off.
func _toggle(id: String) -> void:
	if id in _picked:
		_picked.erase(id)
	else:
		_picked.append(id)
		if _picked.size() > Defs.CARAVAN_SEATS:
			_picked.pop_front()
	AudioDirector.play_sfx("tap")
	_refresh()


func _refresh() -> void:
	for id in _cards:
		var b: Button = _cards[id]
		b.set_pressed_no_signal(id in _picked)
		b.modulate = Color.WHITE if id in _picked or _picked.size() < Defs.CARAVAN_SEATS else Color(1, 1, 1, 0.6)
		b.get_child(0).get_child(0).queue_redraw()
	var names := []
	for id in _picked:
		names.append(Defs.CARAVAN[id]["name"])
	_seats.text = "Seats on the stagecoach: %d of %d%s" % [_picked.size(), Defs.CARAVAN_SEATS,
		("  ·  " + ", ".join(names)) if names else ""]
	_go.text = "Set out" if _picked else "Set out alone"


func _set_out() -> void:
	Run.riders = _picked.duplicate()
	Run.riders_picked = true
	Profile.set_riders(_picked)
	Run.apply_loadout()   # Simon, the Smith forges now
	done.emit()
