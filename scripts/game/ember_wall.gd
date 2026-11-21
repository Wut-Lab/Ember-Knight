class_name EmberWall
extends Node2D

const Defs := preload("res://scripts/game/defs.gd")
## Ember Wall: a low wall of glowing stones built across a trail. Spirits
## that reach it stop and burn through it (it loses hp while they press on
## it), and its embers scorch them meanwhile. Broken walls crumble away.

var battle
var board
var world := Vector2.ZERO
var tangent := Vector2.RIGHT   ## trail direction at the wall (world)
var level := 1
var hp := 1.0
var max_hp := 1.0
var _t := 0.0
var _hit := 0.0                ## flash when chewed
var _crumble := -1.0           ## >=0 while crumbling away
var broken := false


func setup(b, bd, at: Vector2, tan: Vector2) -> void:
	battle = b
	board = bd
	world = at
	tangent = tan.normalized()
	_set_level(1)
	position = board.proj(world)
	z_index = 0


func _set_level(l: int) -> void:
	level = clampi(l, 1, 3)
	max_hp = Defs.WALL[level - 1]["hp"] * (Defs.STURDY_WALL if Run.has_oath("sturdy_stones") else 1.0)
	hp = max_hp


func level_up() -> void:
	if level < 3:
		_set_level(level + 1)
	hp = max_hp   # a fresh die patches it up


func blocks(sp_world: Vector2) -> bool:
	return not broken and sp_world.distance_to(world) < Defs.WALL_BLOCK


## A spirit pressing on the wall: the wall loses hp.
func chew(amount: float) -> void:
	if broken:
		return
	hp -= amount
	_hit = 0.1
	if hp <= 0.0:
		broken = true
		_crumble = 0.0
		AudioDirector.play_sfx("pop", -8.0)


func _process(delta: float) -> void:
	_t += delta
	_hit = maxf(0.0, _hit - delta)
	position = board.proj(world)
	if broken:
		_crumble += delta
		if _crumble > 0.6:
			queue_free()
		queue_redraw()
		return
	if battle.fighting:   # embers scorch spirits held at the wall
		var dps: float = Defs.WALL[level - 1]["burn"]
		for sp in battle.spirits:
			if is_instance_valid(sp) and not sp.dead and sp.world.distance_to(world) < Defs.WALL_BLOCK + 8.0:
				sp.hit(dps * delta)
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - (clampf(_crumble / 0.6, 0.0, 1.0) if broken else 0.0)
	var half := 20.0 + 5.0 * level
	var vs: float = board.view_scale
	var glow := 0.6 + 0.3 * sin(_t * 3.0)
	# Faces the camera so it reads as a barricade on any trail.
	var pl := Vector2(-half * vs, 0.0)
	var pr := Vector2(half * vs, 0.0)
	var h := (14.0 + 5.0 * level) * vs
	var sink := Vector2(0, 18.0 * (1.0 - a))
	var up := Vector2(0, -h) * a
	# warm glow on the ground
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, (pr.x - pl.x) * 0.75, Color(1.0, 0.45, 0.15, 0.18 * a * glow))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var stone := Color("#4a3a33").lerp(Color("#ffb070"), _hit * 4.0)
	var face := PackedVector2Array([pl + sink, pr + sink, pr + up + sink, pl + up + sink])
	draw_colored_polygon(face, Color(stone, a))
	# top, catching the firelight
	var depth := Vector2(0, -4.0 * vs)
	draw_colored_polygon(PackedVector2Array([pl + up + sink, pr + up + sink, pr + up + depth + sink, pl + up + depth + sink]), Color(Color("#7a5a48"), a))
	# brick courses: 2 rows, offset joints
	var ink := Color("#1c1310", a * 0.9)
	var mid := up * 0.5
	draw_line(pl + mid + sink, pr + mid + sink, ink, 1.5)
	var n := 2 + level
	for row in 2:
		var y0 := mid * row
		var y1 := mid * (row + 1)
		for k in range(1, n + (row % 2)):
			var f := (float(k) - 0.5 * (row % 2)) / n
			if f <= 0.0 or f >= 1.0:
				continue
			var x := pl.lerp(pr, f)
			draw_line(x + y0 + sink, x + y1 + sink, ink, 1.5)
	# glowing cracks and a hot top edge
	var hot := Color(1.0, 0.55, 0.2, a * glow)
	for k in n:
		var x := pl.lerp(pr, (k + 0.35) / n) + sink
		draw_line(x + up * 0.85, x + up * 0.55 + Vector2(4, 0), hot, 1.6)
		draw_line(x + up * 0.55 + Vector2(4, 0), x + up * 0.3, Color(hot, hot.a * 0.7), 1.2)
	draw_line(pl + up + sink, pr + up + sink, Color(1.0, 0.7, 0.3, a * glow * 0.9), 2.0)
	draw_polyline(PackedVector2Array([pl + sink, pl + up + sink, pr + up + sink, pr + sink]), Color("#140d0a", a), 1.5)
	# hp bar once damaged
	if not broken and hp < max_hp:
		var top := Vector2(-18, up.y - 12.0)
		draw_rect(Rect2(top, Vector2(36, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(36 * hp / max_hp, 4)), Color("#ff8a3c"))
