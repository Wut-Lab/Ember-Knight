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

	var normal := _box(Color(CARD, 0.62), LINE, 1)
	var hover := _box(Color("#2b2128", 0.85), ACCENT, 2)
	hover.shadow_color = Color(ACCENT2, 0.28)
	hover.shadow_size = 14
	var pressed := _box(Color("#3a2420", 0.92), ACCENT2, 2)
	t.set_stylebox("normal", "Button", normal)
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
	return t


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
