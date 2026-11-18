extends Control
## One die in the tray. Tap/click to hold it (held dice are kept when you
## reroll, and a held die can then be placed by tapping a glowing tile);
## or drag it straight onto a tile. Works the same with touch and mouse.
## Each die is a D6 (a list of 6 faces), drawn as a cube: the rolled face on
## top and two neighbouring faces on the sides.

signal tapped(die)
signal drag_started(die)
signal drag_moved(die, screen_pos)
signal drag_ended(die, screen_pos)

const Defs := preload("res://scripts/game/defs.gd")
const Icons := preload("res://scripts/game/icons.gd")
const SIZE := 92.0
const DRAG_THRESHOLD := 14.0

var faces: Array = Defs.STARTER_DIE
var side := 0          ## index into faces of the rolled (top) face
var face := "kindle"   ## faces[side]
var held := false
var selected := false
var placed := false
var index := 0

var _rolling := 0.0
var _shown := 0        ## side shown while tumbling
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _t := 0.0
var _lift := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE + 18)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func roll(new_side: int, duration: float) -> void:
	side = new_side
	face = faces[side]
	_rolling = duration


func is_rolling() -> bool:
	return _rolling > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _rolling > 0.0:
		_rolling -= delta
		if int(_t * 18.0) % 2 == 0:
			_shown = randi() % faces.size()
		if _rolling <= 0.0:
			_shown = side
	else:
		_shown = side
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
	draw_die(self, Vector2(SIZE / 2, SIZE / 2 + 18 - _lift * 14.0), SIZE - 8, faces, _shown, held or selected, _rolling > 0.0, _t)
	if held:
		_draw_lock(Vector2(SIZE - 14, 14 - _lift * 14.0 + 10))
	# Key hint for keyboard players.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(6, SIZE + 14), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.35))


## Shared die drawing (also used for the drag ghost): a 2.5D cube with the
## top face (faces[top]) big, and two neighbouring faces on the front and
## right sides, squashed for depth.
static func draw_die(ci: CanvasItem, c: Vector2, s: float, faces: Array, top: int, lit: bool, rolling: bool, t: float) -> void:
	var wob := sin(t * 40.0) * 0.08 if rolling else 0.0
	var base := Transform2D(wob, c)
	ci.draw_set_transform_matrix(base)
	var h := s / 2
	var d := s * 0.24            # depth of the side faces
	var e := s - d               # edge of the top face
	var o := Vector2(-h, -h)     # top-left of the top face
	var near := neighbours(top)
	# Shadow.
	ci.draw_colored_polygon(_quad(o + Vector2(6, 10), e, d), Color(0, 0, 0, 0.35))
	# Front side (below the top face) and right side, slightly shaded.
	var front := PackedVector2Array([o + Vector2(0, e), o + Vector2(e, e), o + Vector2(e + d, e + d), o + Vector2(d, e + d)])
	var right := PackedVector2Array([o + Vector2(e, 0), o + Vector2(e + d, d), o + Vector2(e + d, e + d), o + Vector2(e, e)])
	ci.draw_colored_polygon(front, Color("#cbbca8"))
	ci.draw_colored_polygon(right, Color("#a89a87"))
	_side_icon(ci, base, faces[near[0]], o + Vector2(e * 0.5 + d * 0.5, e + d * 0.5), s * 0.34, Vector2(1.0, 0.42))
	_side_icon(ci, base, faces[near[1]], o + Vector2(e + d * 0.5, e * 0.5 + d * 0.5), s * 0.34, Vector2(0.42, 1.0))
	ci.draw_polyline(front + PackedVector2Array([front[0]]), Color(0, 0, 0, 0.25), 1.5, true)
	ci.draw_polyline(right + PackedVector2Array([right[0]]), Color(0, 0, 0, 0.25), 1.5, true)
	# Top face.
	_round_rect(ci, Rect2(o, Vector2(e, e)), 10, Color("#f3e9dc"))
	_round_rect(ci, Rect2(o + Vector2(4, 3), Vector2(e - 8, e * 0.28)), 8, Color(1, 1, 1, 0.35))
	if lit:
		_round_outline(ci, Rect2(o - Vector2(3, 3), Vector2(e + d + 6, e + d + 6)), 12, Color("#ffb238"), 4.0)
	var f: String = faces[top]
	var col: Color = Defs.FACE_INFO[f]["color"]
	var mid := o + Vector2(e, e) * 0.5
	ci.draw_circle(mid, e * 0.36, col.darkened(0.55) if f != "kindle" else Color("#8a5a10"))
	Icons.draw(ci, f, mid, e * 0.6, col if f != "kindle" else Color("#ffe27a"))
	ci.draw_set_transform(Vector2.ZERO)


## Two sides next to `top` (not top itself and not its opposite, 5 - top).
static func neighbours(top: int) -> Array:
	var out := []
	for i in 6:
		if i != top and i != 5 - top:
			out.append(i)
	return [out[0], out[1]]


static func _quad(o: Vector2, e: float, d: float) -> PackedVector2Array:
	return PackedVector2Array([o, o + Vector2(e, 0), o + Vector2(e + d, d), o + Vector2(e + d, e + d), o + Vector2(d, e + d), o + Vector2(0, e)])


## A face icon drawn squashed onto a side of the cube.
static func _side_icon(ci: CanvasItem, base: Transform2D, f: String, at: Vector2, s: float, squash: Vector2) -> void:
	var col: Color = Defs.FACE_INFO[f]["color"]
	ci.draw_set_transform_matrix(base * Transform2D(0.0, squash, 0.0, at))
	ci.draw_circle(Vector2.ZERO, s * 0.5, col.darkened(0.6) if f != "kindle" else Color("#7a5010"))
	Icons.draw(ci, f, Vector2.ZERO, s * 0.8, (col if f != "kindle" else Color("#ffe27a")).darkened(0.15))
	ci.draw_set_transform_matrix(base)


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
