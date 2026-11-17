extends Control
## Char's flame (his health): a flame icon and a warm bar that cools toward
## red as it drops, and flashes when a spirit reaches the fire.

const Icons := preload("res://scripts/game/icons.gd")
const Style := preload("res://scripts/ui/ui_style.gd")

var _value := 100.0
var _max := 100.0
var _shown := 100.0
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(300, 46)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, m: float) -> void:
	_value = v
	_max = m


func flash() -> void:
	_flash = 0.5


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_shown = move_toward(_shown, _value, delta * 60.0)
	queue_redraw()


func _draw() -> void:
	var f := clampf(_shown / maxf(_max, 1.0), 0.0, 1.0)
	var hot := Color("#ffb238").lerp(Color("#ff4a1c"), 1.0 - f)
	var shake := Vector2(sin(_t * 60.0), 0) * 3.0 * _flash
	Icons.draw(self, "flare", Vector2(22, 22) + shake, 44.0 * (0.9 + 0.1 * f), hot)
	var r := Rect2(Vector2(48, 12) + shake, Vector2(240, 20))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = Style.LINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, r)
	if f > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = hot.lerp(Color.WHITE, _flash)
		fill.set_corner_radius_all(8)
		draw_style_box(fill, Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * f, r.size.y - 6)))
	var font := Style.BODY_MEDIUM
	draw_string(font, Vector2(54, 47) + shake, "Flame  %d / %d" % [roundi(_value), roundi(_max)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.FG)
