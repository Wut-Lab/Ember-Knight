extends Control
## Road event: Fog Cloud. Rolls after the player picks a stop, from night 2 on.
## Press On risks a pothole; Make Camp Early heals but may draw a Mist Wisp
## ambush. `done(ambush)` tells the run screen whether to fight the ambush first.

signal done(ambush: bool)

const Defs := preload("res://scripts/game/defs.gd")
const Style := preload("res://scripts/ui/ui_style.gd")
const ChoiceCard := preload("res://scripts/ui/choice_card.gd")

var _root: VBoxContainer
var _sub: Label
var _row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.make_theme()
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 16)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var h := Label.new()
	h.text = "Fog Cloud"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_override("font", Style.display_font())
	h.add_theme_font_size_override("font_size", 64)
	h.add_theme_color_override("font_color", Color("#bcd2ff"))
	_root.add_child(h)
	_sub = Label.new()
	_sub.text = "A thick fog rolls over the road. Something drifts inside it."
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_font_size_override("font_size", 22)
	_root.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)
	var press := ChoiceCard.make("Press On", "Drive through blind. The stagecoach may hit a pothole (%d%%: −%d flame)."
		% [roundi(Defs.POTHOLE_CHANCE * 100), roundi(Defs.POTHOLE_DAMAGE)], 300.0)
	var camp := ChoiceCard.make("Make Camp Early", "Rest until it clears (+%d flame). Mist Wisps may find you first (%d%%)."
		% [roundi(Defs.CAMP_HEAL), roundi(Defs.AMBUSH_CHANCE * 100)], 300.0)
	for c in [press, camp]:
		c.custom_minimum_size.y = 150
		_row.add_child(c)
	press.pressed.connect(_press_on)
	camp.pressed.connect(_make_camp)
	press.grab_focus.call_deferred()
	if Run.autoplay:
		var pick: Button = camp if Run.rng.randf() < 0.5 else press
		get_tree().create_timer(1.2).timeout.connect(pick.emit_signal.bind("pressed"))


func _press_on() -> void:
	if Run.rng.randf() < Defs.POTHOLE_CHANCE:
		Run.flame = maxf(1.0, Run.flame - Defs.POTHOLE_DAMAGE)
		AudioDirector.play_sfx("hurt", -2.0)
		_result("Thunk! The stagecoach hits a pothole (−%d flame)." % roundi(Defs.POTHOLE_DAMAGE), false)
	else:
		_result("The wheels find the road. You come through the fog unharmed.", false)


func _make_camp() -> void:
	if Run.rng.randf() < Defs.AMBUSH_CHANCE:
		_result("Mist Wisps drift out of the fog toward your camp!", true)
	else:
		Run.flame = minf(Run.max_flame, Run.flame + Defs.CAMP_HEAL)
		_result("A quiet rest. The fog lifts by nightfall (+%d flame)." % roundi(Defs.CAMP_HEAL), false)


func _result(text: String, ambush: bool) -> void:
	_sub.text = text
	if Run.autoplay:
		print("  fog cloud: %s" % text)
	for c in _row.get_children():
		c.queue_free()
	var status := Label.new()
	status.text = "Flame %d / %d" % [roundi(Run.flame), roundi(Run.max_flame)]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Style.MUTE)
	status.add_theme_font_size_override("font_size", 20)
	_root.add_child(status)
	var go := ChoiceCard.make("Defend the Camp" if ambush else "Onward",
		"One wave, Mist Wisps only." if ambush else "The road goes on.", 300.0)
	go.pressed.connect(func():
		AudioDirector.play_sfx("chime", -4.0)
		done.emit(ambush))
	_row.add_child(go)
	go.grab_focus.call_deferred()
	if Run.autoplay:
		get_tree().create_timer(1.2).timeout.connect(go.emit_signal.bind("pressed"))
