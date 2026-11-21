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
var face := "kindle"   ## faces[side], without any "+"
var plus := false      ## the rolled face is a "+" face (places two levels)
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
	face = Defs.base_face(faces[side])
	plus = Defs.face_levels(faces[side]) > 1
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


## Shared die drawing (also used for the drag ghost): a 2.5D bone cube in the
## camp art style (dark outline, soft shading, warm firelight from the top
## left). The rolled face (faces[top]) is on top; two neighbouring faces show,
## squashed, on the front and right sides.
const OUTLINE := Color("#2a1a12")
const BONE_HI := Color("#fbf3e6")
const BONE := Color("#efe2cd")
const BONE_FRONT := Color("#d7c4a6")
const BONE_SIDE := Color("#b9a383")


static func draw_die(ci: CanvasItem, c: Vector2, s: float, faces: Array, top: int, lit: bool, rolling: bool, t: float) -> void:
	var wob := sin(t * 40.0) * 0.08 if rolling else 0.0
	var base := Transform2D(wob, c)
	ci.draw_set_transform_matrix(base)
	var h := s / 2
	var d := s * 0.2             # depth of the side faces
	var e := s - d               # edge of the top face
	var o := Vector2(-h, -h)     # top-left of the top face
	var r := e * 0.22            # corner rounding
	var near := neighbours(top)
	var sil := _silhouette(o, e, d, r, 2.0)
	# Soft ground shadow, then the outline (silhouette grown by a couple px).
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(1.0, 1.0), 0.0, Vector2(5, 8)))
	ci.draw_colored_polygon(sil, Color(0, 0, 0, 0.3))
	ci.draw_set_transform_matrix(base)
	if lit:
		ci.draw_polyline(_closed(sil), Color("#ffb238"), 6.0, true)
	ci.draw_colored_polygon(sil, OUTLINE)
	# The body is one solid rounded block: fill it with the right side's shade,
	# then lay the front side and the top face over it so they join cleanly.
	var body := _silhouette(o, e, d, r, 0.0)
	ci.draw_polygon(body, _shade(body, o.x + e, o.x + e + d, BONE_SIDE, BONE_SIDE.darkened(0.15), true))
	var front := _front_face(o, e, d, r)
	ci.draw_polygon(front, _shade(front, o.y + e, o.y + e + d, BONE_FRONT, BONE_FRONT.darkened(0.12), false))
	_side_icon(ci, base, faces[near[0]], o + Vector2(e * 0.5 + d * 0.5, e + d * 0.5), e * 0.42, Vector2(1.0, 0.36), BONE_FRONT)
	_side_icon(ci, base, faces[near[1]], o + Vector2(e + d * 0.5, e * 0.5 + d * 0.5), e * 0.42, Vector2(0.36, 1.0), BONE_SIDE)
	# Top face: gradient from a warm highlight (top left) to bone.
	# Its near corner, where all three faces meet, is only lightly rounded.
	var top_pts := _top_face(o, e, r, r * 0.3)
	var cols := PackedColorArray()
	for p in top_pts:
		var k := clampf(((p.x - o.x) + (p.y - o.y)) / (2.0 * e), 0.0, 1.0)
		cols.append(BONE_HI.lerp(BONE, k))
	ci.draw_polygon(top_pts, cols)
	# Soft bevel where the top meets the sides.
	ci.draw_polyline(top_pts.slice(11, 19), Color(BONE_HI, 0.7), 1.5, true)
	# Firelight sheen along the top-left edge.
	ci.draw_polyline(_rrect(Rect2(o + Vector2(4, 4), Vector2(e - 8, e - 8)), r * 0.8).slice(0, 12), Color(1, 0.93, 0.78, 0.6), 2.0, true)
	_face_icon(ci, faces[top], o + Vector2(e, e) * 0.5, e * 0.62, BONE)
	ci.draw_set_transform_matrix(Transform2D())


## A face icon pressed into the bone: a soft recessed dimple with the icon
## engraved in its colour, a dark lip below and a light lip above.
static func _face_icon(ci: CanvasItem, f: String, at: Vector2, s: float, bone: Color) -> void:
	var up := f.ends_with("+")
	f = Defs.base_face(f)
	var col: Color = Defs.FACE_INFO[f]["color"]
	var ink := col.darkened(0.15) if f != "kindle" else Color("#e0a020")
	ci.draw_circle(at, s * 0.5, bone.darkened(0.06))
	ci.draw_arc(at, s * 0.5, PI * 1.1, PI * 1.9, 16, Color(OUTLINE, 0.18), 1.5, true)
	ci.draw_arc(at, s * 0.5, PI * 0.1, PI * 0.9, 16, Color(1, 1, 1, 0.45), 1.2, true)
	Icons.draw(ci, f, at + Vector2(0, 1.2), s * 0.78, OUTLINE.lerp(bone, 0.35))
	Icons.draw(ci, f, at, s * 0.78, ink)
	if up:   # a small raised "+" at the top right
		var p := at + Vector2(s * 0.36, -s * 0.36)
		var w := s * 0.13
		ci.draw_circle(p, w * 1.6, ink)
		ci.draw_line(p - Vector2(w, 0), p + Vector2(w, 0), bone, w * 0.6)
		ci.draw_line(p - Vector2(0, w), p + Vector2(0, w), bone, w * 0.6)


## A face icon drawn squashed onto a side of the cube.
static func _side_icon(ci: CanvasItem, base: Transform2D, f: String, at: Vector2, s: float, squash: Vector2, bone: Color) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(0.0, squash, 0.0, at))
	_face_icon(ci, f, Vector2.ZERO, s, bone)
	ci.draw_set_transform_matrix(base)


## Two sides next to `top` (not top itself and not its opposite, 5 - top).
static func neighbours(top: int) -> Array:
	var out := []
	for i in 6:
		if i != top and i != 5 - top:
			out.append(i)
	return [out[0], out[1]]


## Outline of the whole cube (top face plus the two sides), rounded corners,
## grown by `g` (the outline's thickness when drawn behind the body).
static func _silhouette(o: Vector2, e: float, d: float, r: float, g: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	o -= Vector2(g, g)
	e += g * 2.0
	r += g
	pts.append_array(_arc(o + Vector2(r, r), r, PI, PI * 1.5))                      # top-left
	pts.append_array(_arc(o + Vector2(e - r, r), r, PI * 1.5, PI * 1.75))            # top-right
	pts.append_array(_arc(o + Vector2(e + d - r, d + r), r, PI * 1.75, TAU))        # back-right
	pts.append_array(_arc(o + Vector2(e + d - r, e + d - r), r, 0.0, PI * 0.5))     # bottom-right
	pts.append_array(_arc(o + Vector2(d + r, e + d - r), r, PI * 0.5, PI * 0.75))   # bottom-front-left
	pts.append_array(_arc(o + Vector2(r, e - r), r, PI * 0.75, PI))                 # left
	return pts


## The front side: from under the top face's bottom edge, down the diagonal to
## the near corner, then back along the block's rounded bottom and left edge.
static func _front_face(o: Vector2, e: float, d: float, r: float) -> PackedVector2Array:
	var out := PackedVector2Array([o + Vector2(0, e - r), o + Vector2(e, e - r), o + Vector2(e, e)])
	out.append_array(_arc(o + Vector2(e + d - r, e + d - r), r, PI * 0.25, PI * 0.5))  # bottom-right half
	out.append_array(_arc(o + Vector2(d + r, e + d - r), r, PI * 0.5, PI * 0.75))      # bottom-left
	out.append_array(_arc(o + Vector2(r, e - r), r, PI * 0.75, PI))                    # left edge
	return out


## The top face: rounded like the block, but the near (bottom-right) corner,
## where it meets both sides, uses the smaller radius `rn`. Points 11..18 run
## down its right edge, round the near corner and along its bottom edge.
static func _top_face(o: Vector2, e: float, r: float, rn: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append_array(_arc(o + Vector2(r, r), r, PI, PI * 1.5))                # top-left
	pts.append_array(_arc(o + Vector2(e - r, r), r, PI * 1.5, TAU))           # top-right
	pts.append_array(_arc(o + Vector2(e - rn, e - rn), rn, 0.0, PI * 0.5))    # near corner
	pts.append_array(_arc(o + Vector2(r, e - r), r, PI * 0.5, PI))            # bottom-left
	return pts


## Per-vertex colours shading from a to b along y (or x when `horiz`).
static func _shade(pts: PackedVector2Array, from: float, to: float, a: Color, b: Color, horiz: bool) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		var v := p.x if horiz else p.y
		cols.append(a.lerp(b, clampf((v - from) / (to - from), 0.0, 1.0)))
	return cols


static func _rrect(rc: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := rc.position
	var z := rc.size
	pts.append_array(_arc(p + Vector2(r, r), r, PI, PI * 1.5))
	pts.append_array(_arc(p + Vector2(z.x - r, r), r, PI * 1.5, TAU))
	pts.append_array(_arc(p + Vector2(z.x - r, z.y - r), r, 0.0, PI * 0.5))
	pts.append_array(_arc(p + Vector2(r, z.y - r), r, PI * 0.5, PI))
	return pts


static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, i / 5.0)) * r)
	return pts


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _draw_lock(c: Vector2) -> void:
	draw_circle(c, 13, Color("#1e1b25"))
	draw_circle(c, 13, Color("#ffb238"), false, 2.0)
	draw_rect(Rect2(c.x - 6, c.y - 2, 12, 9), Color("#ffb238"))
	draw_arc(c + Vector2(0, -2), 4.5, PI, TAU, 10, Color("#ffb238"), 2.2)
