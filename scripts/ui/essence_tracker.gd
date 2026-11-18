extends Control
## Small Essence counter for the HUD: the orb icon and the total. When
## Essence is earned it gives a gentle pulse and floats "+N" above itself.

const Icons := preload("res://scripts/game/icons.gd")
const Style := preload("res://scripts/ui/ui_style.gd")

var _shown := 0
var _pulse := 0.0
var _gain := 0
var _gain_t := 0.0
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(96, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown = Profile.essence
	Profile.essence_changed.connect(_on_changed)
	tooltip_text = "Essence: kept between runs."


func _on_changed(total: int, gained: int) -> void:
	_shown = total
	_gain = gained
	_gain_t = 1.6
	_pulse = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	_gain_t = maxf(0.0, _gain_t - delta)
	queue_redraw()


func _draw() -> void:
	var h := size.y
	# Quiet pill behind it, like the other HUD chips.
	var pill := Rect2(Vector2(0, h * 0.5 - 20), Vector2(size.x, 40))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e1b25", 0.7)
	sb.set_corner_radius_all(20)
	sb.anti_aliasing = true
	draw_style_box(sb, pill)
	var icon_c := Vector2(22, h * 0.5 + 2)
	Icons.draw(self, "essence", icon_c, 36.0 * (1.0 + 0.15 * sin(_pulse * PI)), Color.WHITE, _t)
	var font := Style.display_font()
	draw_string(font, Vector2(44, h * 0.5 + 9), str(_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e6f2ff"))
	if _gain_t > 0.0:
		var a := clampf(_gain_t / 0.6, 0.0, 1.0)
		var rise := (1.6 - _gain_t) * 14.0
		draw_string(font, Vector2(42, h * 0.5 + 52 - rise), "+%d" % _gain, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.85, 1.0, a))
