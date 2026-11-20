extends Control
## The boss's health in the HUD: a wide iron-framed bar under the night counter,
## with the boss's name in blood-red display type, horned spikes at both ends,
## a fill in the boss's own colour over a dark red "chip" that drains after it,
## notches at each quarter, and a slow menacing pulse. Slides down when the boss
## arrives, shudders when hit, and cracks apart when the boss is banished.

const Style := preload("res://scripts/ui/ui_style.gd")

const W := 560.0
const H := 28.0

var boss                    ## the Spirit, or null
var _name := ""
var _col := Color.WHITE
var _shown := 1.0           ## the fill, eased
var _chip := 1.0            ## the dark red trail, drains slowly after a hit
var _chip_wait := 0.0
var _last := 1.0
var _hit := 0.0
var _in := 0.0              ## 0..1 slide-in
var _dying := -1.0          ## >=0: breaking apart after the boss falls
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W + 100, 84)
	size = custom_minimum_size
	visible = false


func show_boss(sp, title: String, col: Color) -> void:
	boss = sp
	_name = title
	_col = col
	_shown = 1.0
	_chip = 1.0
	_last = 1.0
	_in = 0.0
	_dying = -1.0
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_in = minf(1.0, _in + delta / 0.6)
	_hit = maxf(0.0, _hit - delta)
	var f := 0.0
	if is_instance_valid(boss) and not boss.dead:
		f = clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	elif _dying < 0.0:
		_dying = 0.0
	if f < _last - 0.0001:
		_hit = 0.25
		_chip_wait = 0.5
	_last = f
	_shown = move_toward(_shown, f, delta * 1.5)
	_chip_wait -= delta
	if _chip_wait <= 0.0:
		_chip = move_toward(_chip, _shown, delta * 0.35)
	_chip = maxf(_chip, _shown)
	if _dying >= 0.0:
		_dying += delta
		if _dying > 1.2:
			visible = false
			boss = null
	queue_redraw()


func _draw() -> void:
	var ease := 1.0 - pow(1.0 - _in, 3.0)
	var fade := 1.0 if _dying < 0.0 else clampf(1.0 - (_dying - 0.4) / 0.8, 0.0, 1.0)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 3.0 * (_hit / 0.25)
	var o := Vector2((size.x - W) / 2.0, 44.0 - (1.0 - ease) * 50.0) + shake
	var a := ease * fade
	var pulse := 0.5 + 0.5 * sin(_t * 2.6)
	var blood := Color("#e0303a")

	# A dark red haze behind, breathing slowly.
	var haze := StyleBoxFlat.new()
	haze.bg_color = Color(0.5, 0.0, 0.05, (0.18 + 0.12 * pulse) * a)
	haze.set_corner_radius_all(18)
	haze.shadow_color = Color(0.8, 0.05, 0.08, (0.25 + 0.2 * pulse) * a)
	haze.shadow_size = 14
	draw_style_box(haze, Rect2(o + Vector2(-6, -6), Vector2(W + 12, H + 12)))

	# Horned iron spikes at both ends.
	var iron := Color(0.22, 0.15, 0.16, a)
	var rim := Color(0.62, 0.42, 0.36, a)
	var lit := Color(blood.lightened(0.1), (0.45 + 0.35 * pulse) * a)
	for side in [-1.0, 1.0]:
		var x: float = o.x + (W if side > 0 else 0.0)
		var cy := o.y + H / 2.0
		var horn := PackedVector2Array([Vector2(x - side * 6, cy - H * 0.8), Vector2(x + side * 46, cy - H * 1.5),
			Vector2(x + side * 24, cy - H * 0.25), Vector2(x + side * 50, cy + H * 0.05),
			Vector2(x + side * 22, cy + H * 0.4), Vector2(x + side * 34, cy + H * 1.25), Vector2(x - side * 6, cy + H * 0.8)])
		var glow := PackedVector2Array(horn)
		glow.append(glow[0])
		draw_polyline(glow, Color(lit, lit.a * 0.4), 8.0, true)
		draw_colored_polygon(horn, iron)
		draw_polyline(glow, rim, 2.0, true)
		draw_line(horn[1], horn[2], lit, 2.0, true)
		draw_line(horn[3], horn[4], lit, 2.0, true)

	# Frame.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.03, 0.05, 0.9 * a)
	frame.border_color = rim
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(4)
	draw_style_box(frame, Rect2(o, Vector2(W, H)))
	var inner := Rect2(o + Vector2(4, 4), Vector2(W - 8, H - 8))

	# Shattering: the bar splits into falling shards.
	if _dying >= 0.0:
		var n := 10
		for i in n:
			var k := _dying
			var x0 := inner.position.x + inner.size.x * i / n
			var drop := Vector2((i - n / 2.0) * 6.0 * k, 80.0 * k * k + sin(i * 1.7) * 10.0 * k)
			var c := _col.lerp(Color.WHITE, clampf(1.0 - k * 3.0, 0.0, 1.0))
			draw_set_transform(Vector2(x0 + inner.size.x / n / 2.0, inner.get_center().y) + drop, sin(i * 2.3) * k * 2.0)
			draw_rect(Rect2(-inner.size.x / n / 2.0, -inner.size.y / 2.0, inner.size.x / n - 2.0, inner.size.y), Color(c, a))
			draw_set_transform(Vector2.ZERO)
	else:
		# Chip trail, then the fill in the boss's colour with a hot top edge.
		if _chip > _shown:
			draw_rect(Rect2(inner.position, Vector2(inner.size.x * _chip, inner.size.y)), Color(0.55, 0.05, 0.08, a))
		if _shown > 0.0:
			var fill := Rect2(inner.position, Vector2(inner.size.x * _shown, inner.size.y))
			var base := _col.lerp(Color.WHITE, _hit * 2.0)
			draw_rect(fill, Color(base.darkened(0.25), a))
			draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.45)), Color(base.lightened(0.15), a))
			# A slow glint sweeping across.
			var gx := fmod(_t * 0.35, 1.4) - 0.2
			if gx > 0.0 and gx < _shown:
				draw_rect(Rect2(inner.position + Vector2(inner.size.x * gx, 0), Vector2(10, inner.size.y)), Color(1, 1, 1, 0.25 * a))
			# The leading edge burns.
			draw_rect(Rect2(fill.end.x - 3, fill.position.y, 3, fill.size.y), Color(blood.lightened(0.3), (0.6 + 0.4 * pulse) * a))
		# Notches at each quarter.
		for q in [0.25, 0.5, 0.75]:
			var x: float = inner.position.x + inner.size.x * q
			draw_line(Vector2(x, o.y + 2), Vector2(x, o.y + H - 2), Color(0, 0, 0, 0.75 * a), 2.0)

	# Name above, in display type: dark outline, blood-red glow.
	var font := Style.display_font()
	var fs := 34
	var tw := font.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(o.x + (W - tw) / 2.0, o.y - 7)
	draw_string_outline(font, tp, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(blood, (0.25 + 0.2 * pulse) * a))
	draw_string_outline(font, tp, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.08, 0.0, 0.02, a))
	draw_string(font, tp, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#ffd9c9").lerp(blood, 0.25 + 0.15 * pulse) * Color(1, 1, 1, a))
