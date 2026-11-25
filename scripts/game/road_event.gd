extends Control
## Base for road events: a title, a line of story, choice cards, then the
## outcome and a card to go on. Subclasses call _build() and _result().
## `done(ambush)` tells the run screen whether to fight an ambush first.

signal done(ambush: bool)

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")
const DrawProxy := preload("res://scripts/ui/draw_proxy.gd")
const ART_SIZE := Vector2(480, 150)

var _root: VBoxContainer
var _sub: Label
var _row: HBoxContainer
var _status := Label.new()
var _ambient: Control   ## full-screen mood layer behind everything
var _art: Control       ## the event's picture above its title
var _t := 0.0


## options: Array of [title, desc, Callable]
func _build(title: String, color: Color, intro: String, options: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	_ambient = DrawProxy.new()
	_ambient.draw_fn = func(ci): _draw_ambient(ci, ci.size, _t)
	_ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ambient)
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 16)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_art = DrawProxy.new()
	_art.custom_minimum_size = ART_SIZE
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw_fn = func(ci): _draw_art(ci, ART_SIZE, _t)
	_root.add_child(_art)
	var h := Label.new()
	h.text = title
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", color)
	_root.add_child(h)
	_sub = Label.new()
	_sub.text = intro
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_size_override("font_size", 22)
	_root.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)
	var cards := []
	var w := 300.0 if options.size() <= 2 else 260.0
	for o in options:
		var c := ChoiceCard.make(o[0], o[1], w)
		c.custom_minimum_size.y = 160
		c.pressed.connect(o[2])
		_row.add_child(c)
		cards.append(c)
	cards[0].grab_focus.call_deferred()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Style.MUTE)
	_status.add_theme_font_size_override("font_size", 20)
	_root.add_child(_status)
	_update_status()
	if Run.autoplay:
		var pick: Button = cards[Run.rng.randi() % cards.size()]
		get_tree().create_timer(1.2).timeout.connect(pick.emit_signal.bind("pressed"))


func _update_status() -> void:
	_status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]


## Swaps the choice cards for a new set (a second step), with new story text.
func _reoffer(text: String, options: Array) -> void:
	_sub.text = text
	for c in _row.get_children():
		c.queue_free()
	var cards := []
	for o in options:
		var c := ChoiceCard.make(o[0], o[1], 300.0)
		c.custom_minimum_size.y = 160
		c.pressed.connect(o[2])
		_row.add_child(c)
		cards.append(c)
	cards[0].grab_focus.call_deferred()
	_update_status()
	if Run.autoplay:
		var pick: Button = cards[Run.rng.randi() % cards.size()]
		get_tree().create_timer(1.2).timeout.connect(pick.emit_signal.bind("pressed"))


## Shows the outcome, then a card to go on.
func _result(text: String, ambush := false, go_title := "Onward", go_desc := "The road goes on.") -> void:
	_sub.text = text
	if Run.autoplay:
		print("  %s: %s" % [get_script().resource_path.get_file().get_basename(), text])
	for c in _row.get_children():
		c.queue_free()
	_update_status()
	var go := ChoiceCard.make(go_title, go_desc, 300.0)
	go.pressed.connect(func():
		AudioDirector.play_sfx("chime", -4.0)
		done.emit(ambush))
	_row.add_child(go)
	go.grab_focus.call_deferred()
	if Run.autoplay:
		get_tree().create_timer(1.2).timeout.connect(go.emit_signal.bind("pressed"))


func _process(delta: float) -> void:
	_t += delta
	if _ambient:
		_ambient.queue_redraw()
		_art.queue_redraw()


## Each event paints its own scene: override these.
func _draw_ambient(_ci: CanvasItem, _sz: Vector2, _time: float) -> void:
	pass


func _draw_art(_ci: CanvasItem, _sz: Vector2, _time: float) -> void:
	pass


## A filled ellipse (Godot has no draw_ellipse).
static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)
