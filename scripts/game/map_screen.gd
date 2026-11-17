extends Control
## The caravan's route: one column per night, the camps to choose from in
## each. Past choices stay marked; future columns are visible but locked.

signal stop_chosen(stop_id: String)

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")

var _cards := []      ## per night: one Button per camp
var _lines: Control
var _root := VBoxContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	_lines = DrawProxy.new()
	_lines.draw_fn = _draw_lines
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 18)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var h := Label.new()
	h.text = "Choose tonight's camp"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 52)
	h.add_theme_color_override("font_color", Style.ACCENT)
	_root.add_child(h)

	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", 34)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cols)
	var first_open: Button = null
	for n in Defs.NIGHTS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.text = "Night %d" % (n + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Style.MUTE if n != Run.night else Style.FG)
		lbl.add_theme_font_size_override("font_size", 20)
		col.add_child(lbl)
		var pair := []
		for id in Run.stop_options[n]:
			var info: Dictionary = Defs.STOPS[id]
			var card := ChoiceCard.make(info["name"], info["desc"], 200.0)
			if n < Run.night:
				card.disabled = true
				card.modulate.a = 1.0 if Run.chosen_stops[n] == id else 0.3
			elif n > Run.night:
				card.disabled = true
				card.modulate.a = 0.45
			else:
				card.pressed.connect(func(): stop_chosen.emit(id))
				if first_open == null:
					first_open = card
			col.add_child(card)
			pair.append(card)
		_cards.append(pair)
		cols.add_child(col)

	var status := Label.new()
	status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Style.MUTE)
	status.add_theme_font_size_override("font_size", 20)
	_root.add_child(status)
	if first_open:
		first_open.grab_focus.call_deferred()
		if Run.autoplay:
			get_tree().create_timer(1.6).timeout.connect(first_open.emit_signal.bind("pressed"))


func _process(_d: float) -> void:
	_lines.queue_redraw()


## Dotted trail joining the chosen camps and the options ahead.
func _draw_lines(ci: CanvasItem) -> void:
	for n in range(1, _cards.size()):
		var from_cards: Array = _cards[n - 1]
		if n - 1 < Run.chosen_stops.size():
			from_cards = [from_cards[Run.stop_options[n - 1].find(Run.chosen_stops[n - 1])]]
		for a in from_cards:
			for b in _cards[n]:
				var p0: Vector2 = a.global_position + Vector2(a.size.x, a.size.y / 2) - ci.global_position
				var p1: Vector2 = b.global_position + Vector2(0, b.size.y / 2) - ci.global_position
				var col := Color(1.0, 0.7, 0.3, 0.45 if n <= Run.night else 0.15)
				var steps := 10
				for k in steps:
					if k % 2 == 0:
						ci.draw_line(p0.lerp(p1, float(k) / steps), p0.lerp(p1, float(k + 1) / steps), col, 3.0, true)
