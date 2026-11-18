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
	# A raised 2.5D chip: faint blue-white glow, a darker lip below for depth,
	# then the face with a dark outline and a soft highlight along its top.
	var face := Rect2(Vector2(2, h * 0.5 - 21), Vector2(size.x - 4, 38))
	var glow := _box(Color(0, 0, 0, 0), 21)
	glow.shadow_color = Color(0.62, 0.82, 1.0, 0.16 + 0.12 * sin(_pulse * PI))
	glow.shadow_size = 14
	draw_style_box(glow, face.grow_individual(0, 0, 0, 4))
	var lip := _box(Color("#0f0d14"), 21)
	draw_style_box(lip, Rect2(face.position + Vector2(0, 5), face.size))
	var top := _box(Color("#2a2533"), 20)
	top.border_color = Color("#120f17")
	top.set_border_width_all(2)
	draw_style_box(top, face)
	var shine := _box(Color(1, 1, 1, 0.06), 16)
	draw_style_box(shine, Rect2(face.position + Vector2(5, 3), Vector2(face.size.x - 10, face.size.y * 0.42)))
	var icon_c := Vector2(22, h * 0.5 + 2)
	Icons.draw(self, "essence", icon_c, 36.0 * (1.0 + 0.15 * sin(_pulse * PI)), Color.WHITE, _t)
	var font := Style.display_font()
	draw_string(font, Vector2(44, h * 0.5 + 9), str(_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e6f2ff"))
	if _gain_t > 0.0:
		var a := clampf(_gain_t / 0.6, 0.0, 1.0)
		var rise := (1.6 - _gain_t) * 14.0
		draw_string(font, Vector2(42, h * 0.5 + 52 - rise), "+%d" % _gain, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.85, 1.0, a))


static func _box(col: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb
