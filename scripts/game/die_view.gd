extends Control
## One die in the tray. Tap/click to hold it (held dice are kept when you
## reroll, and a held die can then be placed by tapping a glowing tile);
## or drag it straight onto a tile. Works the same with touch and mouse.

signal tapped(die)
signal drag_started(die)
signal drag_moved(die, screen_pos)
signal drag_ended(die, screen_pos)

const Defs := preload("res://scripts/game/defs.gd")
const Icons := preload("res://scripts/game/icons.gd")
const SIZE := 92.0
const DRAG_THRESHOLD := 14.0

var face := "kindle"
var held := false
var selected := false
var placed := false
var index := 0

var _rolling := 0.0
var _shown_face := "kindle"
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _t := 0.0
var _lift := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 18)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func roll(new_face: String, duration: float) -> void:
	face = new_face
	_rolling = duration


func is_rolling() -> bool:
	return _rolling > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _rolling > 0.0:
		_rolling -= delta
		if int(_t * 18.0) % 2 == 0:
			_shown_face = Defs.DIE_FACES[randi() % Defs.DIE_FACES.size()]
		if _rolling <= 0.0:
			_shown_face = face
	else:
		_shown_face = face
	var want := 1.0 if (held or selected) else 0.0
	_lift = move_toward(_lift, want, delta * 6.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if placed or _rolling > 0.0:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
		else:
			if _dragging:
				drag_ended.emit(self, event.global_position)
			elif _pressing:
				tapped.emit(self)
			_pressing = false
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit(self)
		if _dragging:
			drag_moved.emit(self, event.global_position)
		accept_event()


func _draw() -> void:
	if placed:
		# An empty socket where the die was.
		var r := Rect2(Vector2(4, 18), Vector2(SIZE - 8, SIZE - 8))
		draw_rect(r, Color(1, 1, 1, 0.05))
		draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
		return
	if _dragging:
		return
	draw_die(self, Vector2(SIZE / 2, SIZE / 2 + 18 - _lift * 14.0), SIZE - 8, _shown_face, held or selected, _rolling > 0.0, _t)
	if held:
		_draw_lock(Vector2(SIZE - 14, 14 - _lift * 14.0 + 10))
	# Key hint for keyboard players.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(6, SIZE + 14), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.35))


## Shared die drawing (also used for the drag ghost).
static func draw_die(ci: CanvasItem, c: Vector2, s: float, f: String, lit: bool, rolling: bool, t: float) -> void:
	var col: Color = Defs.FACE_INFO[f]["color"]
	var wob := sin(t * 40.0) * 0.08 if rolling else 0.0
	ci.draw_set_transform(c, wob, Vector2.ONE)
	var h := s / 2
	# Shadow, side (depth) and top face: a chunky bone-white die.
	ci.draw_rect(Rect2(-h + 3, -h + 10, s, s), Color(0, 0, 0, 0.35))
	_round_rect(ci, Rect2(-h, -h + 6, s, s), 14, Color("#b9ab98"))
	_round_rect(ci, Rect2(-h, -h, s, s - 4), 14, Color("#f3e9dc"))
	_round_rect(ci, Rect2(-h + 5, -h + 4, s - 10, s * 0.3), 10, Color(1, 1, 1, 0.35))
	if lit:
		_round_outline(ci, Rect2(-h - 3, -h - 3, s + 6, s + 8), 16, Color("#ffb238"), 4.0)
	# Face badge.
	var badge := col.darkened(0.55) if f != "kindle" else Color("#8a5a10")
	ci.draw_circle(Vector2(0, -2), s * 0.3, badge)
	Icons.draw(ci, f, Vector2(0, -2), s * 0.5, col if f != "kindle" else Color("#ffe27a"))
	ci.draw_set_transform(Vector2.ZERO)


static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


static func _round_outline(ci: CanvasItem, r: Rect2, rad: float, col: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(w))
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


func _draw_lock(c: Vector2) -> void:
	draw_circle(c, 13, Color("#1e1b25"))
	draw_circle(c, 13, Color("#ffb238"), false, 2.0)
	draw_rect(Rect2(c.x - 6, c.y - 2, 12, 9), Color("#ffb238"))
	draw_arc(c + Vector2(0, -2), 4.5, PI, TAU, 10, Color("#ffb238"), 2.2)
