extends RefCounted
## Shared look for menus, matching the blueprint palette (dark firelit night).

const BG := Color("#14121a")
const CARD := Color("#1e1b25")
const FG := Color("#f3e9dc")
const MUTE := Color("#b0a69b")
const ACCENT := Color("#ffb238")
const ACCENT2 := Color("#ff8a4c")
const LINE := Color("#3a3442")

const DISPLAY_FONT := preload("res://assets/fonts/GrenzeGotisch.ttf")
const BODY_FONT := preload("res://assets/fonts/AlegreyaSans-Regular.ttf")
const BODY_MEDIUM := preload("res://assets/fonts/AlegreyaSans-Medium.ttf")


static func display_font(weight := 700) -> Font:
	var f := FontVariation.new()
	f.base_font = DISPLAY_FONT
	f.variation_opentype = {"wght": weight}
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 24

	# Every button carries a faint white glow so it lifts off the dark scenery;
	# the selected (hovered / focused / pressed) one swaps it for ember orange.
	var normal := _box(Color(CARD, 0.62), Color(LINE.lightened(0.25)), 1)
	normal.shadow_color = Color(1, 1, 1, 0.10)
	normal.shadow_size = 10
	var hover := _box(Color("#2b2128", 0.85), ACCENT, 2)
	hover.shadow_color = Color(ACCENT2, 0.32)
	hover.shadow_size = 14
	var pressed := _box(Color("#3a2420", 0.92), ACCENT2, 2)
	pressed.shadow_color = Color(ACCENT2, 0.4)
	pressed.shadow_size = 14
	var disabled := _box(Color(CARD, 0.45), LINE, 1)
	disabled.shadow_color = Color(1, 1, 1, 0.05)
	disabled.shadow_size = 8
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_disabled_color", "Button", Color(MUTE, 0.6))
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_font("font", "Button", BODY_MEDIUM)
	t.set_font_size("font_size", "Button", 27)
	t.set_color("font_color", "Button", FG)
	t.set_color("font_hover_color", "Button", Color("#ffd58f"))
	t.set_color("font_focus_color", "Button", Color("#ffd58f"))
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)

	var panel := _box(Color(BG, 0.88), LINE, 1)
	panel.set_content_margin_all(36)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 24
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", FG)

	# Volume sliders: thin dark track, ember fill, round glowing grabber.
	var track := _box(Color(LINE, 0.9), LINE, 0)
	track.set_content_margin_all(3)
	track.set_corner_radius_all(4)
	var fill := _box(ACCENT2, ACCENT2, 0)
	fill.set_content_margin_all(3)
	fill.set_corner_radius_all(4)
	var fill_hi := _box(ACCENT, ACCENT, 0)
	fill_hi.set_content_margin_all(3)
	fill_hi.set_corner_radius_all(4)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", _dot(22, FG))
	t.set_icon("grabber_highlight", "HSlider", _dot(24, Color("#ffd58f")))
	t.set_icon("grabber_disabled", "HSlider", _dot(22, MUTE))
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(ACCENT, 0.7)
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(10)
	ring.set_expand_margin_all(6)
	t.set_stylebox("focus", "HSlider", ring)
	return t


## A soft-edged filled circle, for slider grabbers.
static func _dot(d: int, col: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - 1.0 - dist + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(8)
	b.content_margin_left = 24
	b.content_margin_right = 24
	b.content_margin_top = 10
	b.content_margin_bottom = 12
	b.anti_aliasing = true
	return b


## "Something New!" under a dawn or game-over screen when a (non-hidden)
## unlock was earned since the last one shown. Clears Profile.fresh.
static func add_something_new(root: Control) -> void:
	if Profile.fresh.is_empty():
		return
	Profile.fresh.clear()
	var l := Label.new()
	l.text = "Something New!"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", ACCENT)
	root.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "modulate:a", 0.55, 0.8)
	tw.tween_property(l, "modulate:a", 1.0, 0.8)
