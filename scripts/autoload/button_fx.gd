extends Node
## The game's standard button feel, applied automatically to every button
## (anything extending BaseButton) the moment it enters the scene tree:
##   press   - the button squashes to 93% and brightens a little
##   release - it springs back with a small overshoot
##   use     - the "button" tap sound plays when the button actually fires
##   hover   - a hovered or focused button lifts to 104% and brightens a touch
## Works the same for mouse, touch, keyboard and gamepad. Nothing to call by hand.
##
## To leave a button out (e.g. one that plays its own sound), before adding it:
##     ButtonFx.skip(button)            # no animation, no sound
##     ButtonFx.skip(button, false)     # keep the animation, no sound

const PRESS_SCALE := 0.93
const PRESS_TIME := 0.06
const RELEASE_TIME := 0.24
const PRESS_TINT := Color(1.18, 1.12, 1.04)
const HOVER_SCALE := 1.04
const HOVER_TINT := Color(1.08, 1.06, 1.02)
const HOVER_TIME := 0.12
const SOUND := "button"
const SOUND_DB := -5.0

const _META := &"button_fx"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


## Opt a button out of the standard feel. Call before it enters the tree.
func skip(b: BaseButton, animation := true) -> void:
	b.set_meta(_META, "no_anim_no_sound" if animation else "no_sound")


func _on_node_added(n: Node) -> void:
	if not n is BaseButton:
		return
	var b := n as BaseButton
	var mode = b.get_meta(_META, "")
	if mode == "attached" or mode == "no_anim_no_sound":
		return
	if mode != "no_sound":
		b.pressed.connect(_on_pressed)
	b.set_meta(_META, "attached")
	b.button_down.connect(_on_down.bind(b))
	b.button_up.connect(_on_up.bind(b))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
		sig.connect(_on_hover.bind(b), CONNECT_DEFERRED)   # after is_hovered() updates


func _on_pressed() -> void:
	AudioDirector.play_sfx(SOUND, SOUND_DB, 0.04)


func _on_down(b: BaseButton) -> void:
	b.pivot_offset = b.size / 2.0
	b.set_meta(&"button_fx_down_at", Time.get_ticks_msec())
	var t := _new_tween(b)
	t.tween_property(b, "scale", Vector2.ONE * PRESS_SCALE, PRESS_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "self_modulate", PRESS_TINT, PRESS_TIME)


func _on_up(b: BaseButton) -> void:
	# A quick tap (or a key press) can release before the squash has shown:
	# let it finish first so every press is visible.
	var held := (Time.get_ticks_msec() - int(b.get_meta(&"button_fx_down_at", 0))) / 1000.0
	var wait := maxf(0.0, PRESS_TIME - held)
	var t := _new_tween(b)
	var lift := _lifted(b)
	t.tween_property(b, "scale", Vector2.ONE * (HOVER_SCALE if lift else 1.0), RELEASE_TIME).set_delay(wait) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "self_modulate", HOVER_TINT if lift else Color.WHITE, RELEASE_TIME * 0.8).set_delay(wait)


## Hover and focus share one look, so mouse and gamepad read the same.
func _on_hover(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree() or (b.is_pressed() and not b.toggle_mode):
		return   # gone, or mid-press: _on_up settles it
	b.pivot_offset = b.size / 2.0
	var lift := _lifted(b)
	var t := _new_tween(b)
	t.tween_property(b, "scale", Vector2.ONE * (HOVER_SCALE if lift else 1.0), HOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "self_modulate", HOVER_TINT if lift else Color.WHITE, HOVER_TIME)


func _lifted(b: BaseButton) -> bool:
	return not b.disabled and b.is_visible_in_tree() and (b.is_hovered() or b.has_focus())


func _new_tween(b: BaseButton) -> Tween:
	if b.has_meta(&"button_fx_tween"):
		var old = b.get_meta(&"button_fx_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var t := b.create_tween().set_parallel()
	b.set_meta(&"button_fx_tween", t)
	return t
