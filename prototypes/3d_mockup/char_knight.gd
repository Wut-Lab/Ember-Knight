## Char, the Ember Knight: procedural mock-up, about 0.6 m tall.
## Armor pieces are lathed (spun) profiles so they read as hammered plate,
## not stacked primitives. Swap for authored models later; keep node names.
extends Node3D

const IRON := Color("4b4650")
const IRON_HI := Color("6a6470")
const COPPER := Color("b5652b")
const EMBER := Color("ffb238")
const CHECK_RED := Color("c8262b")
const CHECK_WHITE := Color("f4efe6")

var flame_shader: Shader = preload("res://prototypes/3d_mockup/flame.gdshader")
var _t := 0.0
var _head := Node3D.new()
var _body := Node3D.new()

func _ready() -> void:
	add_child(_body)
	_build()

func _process(delta: float) -> void:
	_t += delta
	_body.position.y = sin(_t * 2.0) * 0.004          # breathing bob
	_head.rotation.z = sin(_t * 1.3) * 0.05
	_head.rotation.x = sin(_t * 0.9) * 0.03

# ---------------- materials ----------------
func _mat(c: Color, metal := 0.35, rough := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _glow(c: Color, e := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _checker_mat() -> StandardMaterial3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, CHECK_RED); img.set_pixel(1, 1, CHECK_RED)
	img.set_pixel(1, 0, CHECK_WHITE); img.set_pixel(0, 1, CHECK_WHITE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ---------------- mesh builders ----------------
## Spin a profile (Vector2(radius, y), bottom to top) around Y.
## front_lift raises the profile's upper points toward +Z (the front).
func _lathe(profile: Array, segs := 40, sz := 1.0, front_lift := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var n := profile.size()
	var grid := []
	for i in segs + 1:
		var a := TAU * i / segs
		var front := pow(max(cos(a), 0.0), 2.0)
		var ring := []
		for j in n:
			var p: Vector2 = profile[j]
			var k := float(j) / (n - 1)
			ring.append(Vector3(p.x * sin(a), p.y + front_lift * front * k * k, p.x * cos(a) * sz))
		grid.append(ring)
	for i in segs:
		for j in n - 1:
			var a: Vector3 = grid[i][j]; var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i + 1][j + 1]; var d: Vector3 = grid[i][j + 1]
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	return st.commit()

## Curved hanging cloth panel; wider at the hem, bowed around the body.
func _cloth(top_w: float, bot_w: float, h: float, bow: float, checks_x: int, checks_y: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 8; var rows := 12
	var pts := []
	for r in rows + 1:
		var v := float(r) / rows
		var w := lerpf(top_w, bot_w, v)
		var row := []
		for c in cols + 1:
			var u := float(c) / cols
			var x := (u - 0.5) * w
			var z := -bow * pow(x / (w * 0.5), 2.0) + 0.012 * v * v + 0.004 * sin(u * 9.0 + v * 4.0) * v
			row.append([Vector3(x, -v * h, z), Vector2(u * checks_x * 0.5, v * checks_y * 0.5)])
		pts.append(row)
	for r in rows:
		for c in cols:
			var q = [pts[r][c], pts[r][c + 1], pts[r + 1][c + 1], pts[r + 1][c]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(q[idx][1]); st.add_vertex(q[idx][0])
	st.generate_normals()
	return st.commit()

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = h
	return c

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z)
	return b

func _ring(r: float, thick: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = r - thick; t.outer_radius = r + thick
	return t

func _add(mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat
	mi.position = pos; mi.scale = scl; mi.rotation = rot
	(parent if parent else _body).add_child(mi)
	return mi

# ---------------- build ----------------
func _build() -> void:
	var iron := _mat(IRON)
	var iron_hi := _mat(IRON_HI, 0.45, 0.45)
	var copper := _mat(COPPER, 0.7, 0.35)
	var ember := _glow(EMBER, 4.0)

	# --- legs: tapered greaves, glowing knee seam, round sabatons ---
	var greave := _lathe([Vector2(0.034, 0.035), Vector2(0.04, 0.06), Vector2(0.043, 0.095), Vector2(0.04, 0.14)], 24)
	for sx in [-1.0, 1.0]:
		_add(greave, iron, Vector3(0.048 * sx, 0, 0))
		_add(_ring(0.041, 0.004), ember, Vector3(0.048 * sx, 0.1, 0))
		_add(_sphere(0.022), iron_hi, Vector3(0.048 * sx, 0.104, 0.03), Vector3(1, 0.8, 0.6))   # knee cop
		_add(_sphere(0.05), iron_hi, Vector3(0.05 * sx, 0.024, 0.016), Vector3(0.9, 0.5, 1.3))  # sabaton
		_add(_ring(0.036, 0.004), copper, Vector3(0.048 * sx, 0.04, 0.004))

	# --- torso: barrel breastplate with a waist and faulds below ---
	var torso := _lathe([
		Vector2(0.08, 0.15), Vector2(0.092, 0.17), Vector2(0.104, 0.205),
		Vector2(0.108, 0.24), Vector2(0.1, 0.275), Vector2(0.082, 0.3), Vector2(0.06, 0.31)], 40, 0.82)
	_add(torso, iron, Vector3.ZERO)
	var fauld := _lathe([Vector2(0.098, 0.12), Vector2(0.092, 0.15)], 40, 0.86)
	_add(fauld, iron_hi, Vector3.ZERO)
	_add(fauld, iron_hi, Vector3(0, 0.02, 0), Vector3(0.95, 1, 0.95))
	_add(_ring(0.09, 0.006), copper, Vector3(0, 0.16, 0), Vector3(1, 1, 0.84))          # belt
	_add(_box(0.022, 0.02, 0.008), copper, Vector3(0, 0.16, 0.077))                    # buckle


	# hearth-door chest grate, set into the plate
	_add(_box(0.064, 0.058, 0.02), copper, Vector3(0, 0.215, 0.081), Vector3.ONE, null, Vector3(-0.12, 0, 0))
	_add(_box(0.048, 0.042, 0.012), ember, Vector3(0, 0.215, 0.089), Vector3.ONE, null, Vector3(-0.12, 0, 0))
	for gx in [-0.009, 0.009]:
		_add(_box(0.005, 0.044, 0.014), iron, Vector3(gx, 0.215, 0.091), Vector3.ONE, null, Vector3(-0.12, 0, 0))

	# --- checkered cloth, front and back, hanging from the belt ---
	var cloth := _cloth(0.075, 0.1, 0.13, 0.012, 4, 6)
	var cm := _checker_mat()
	_add(cloth, cm, Vector3(0, 0.152, 0.092), Vector3.ONE, null, Vector3(-0.1, 0, 0))
	_add(cloth, cm, Vector3(0, 0.152, -0.092), Vector3.ONE, null, Vector3(0.1, PI, 0))

	# --- arms: domed pauldrons, elbow cops, big mitten gauntlets ---
	var dome := _lathe([Vector2(0.062, 0.0), Vector2(0.058, 0.02), Vector2(0.045, 0.04), Vector2(0.022, 0.054), Vector2(0.0, 0.058)], 32)
	var lame := _lathe([Vector2(0.066, -0.012), Vector2(0.062, 0.006)], 32)
	for sx in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.105 * sx, 0.27, 0)
		sh.rotation = Vector3(0, 0, -0.45 * sx)
		_body.add_child(sh)
		_add(dome, iron_hi, Vector3.ZERO, Vector3(1, 1, 0.95), sh)
		_add(lame, iron, Vector3(0, -0.004, 0), Vector3(1, 1, 0.95), sh)
		_add(_ring(0.063, 0.004), copper, Vector3(0, -0.012, 0), Vector3(1, 1, 0.95), sh)

		_add(_capsule(0.028, 0.08), iron, Vector3(0.122 * sx, 0.225, 0), Vector3.ONE, null, Vector3(0, 0, 0.18 * sx))
		_add(_sphere(0.026), iron_hi, Vector3(0.13 * sx, 0.188, -0.004))                     # elbow
		_add(_ring(0.027, 0.004), ember, Vector3(0.13 * sx, 0.188, 0), Vector3.ONE, null, Vector3(0, 0, 0.2 * sx))
		_add(_capsule(0.03, 0.07), iron, Vector3(0.135 * sx, 0.155, 0.01), Vector3.ONE, null, Vector3(0.15, 0, 0.08 * sx))
		_add(_lathe([Vector2(0.03, 0.0), Vector2(0.038, 0.022)], 24), copper, Vector3(0.137 * sx, 0.128, 0.014), Vector3.ONE, null, Vector3(PI, 0, 0))  # cuff
		_add(_sphere(0.036), iron_hi, Vector3(0.138 * sx, 0.1, 0.016), Vector3(1, 0.9, 1.05))  # mitten
		_add(_sphere(0.014), iron_hi, Vector3(0.122 * sx, 0.106, 0.042))                      # thumb

	# --- gorget: flared collar, rising higher at the front over the "mouth" ---
	var gorget := _lathe([Vector2(0.07, 0.295), Vector2(0.074, 0.32), Vector2(0.084, 0.34), Vector2(0.098, 0.352)], 48, 0.9, 0.022)
	_add(gorget, iron_hi, Vector3.ZERO)
	var rim := _lathe([Vector2(0.097, 0.349), Vector2(0.103, 0.356)], 48, 0.9, 0.024)
	_add(rim, copper, Vector3.ZERO)
	var seam := _lathe([Vector2(0.09, 0.35), Vector2(0.093, 0.356)], 48, 0.9, 0.024)
	_add(seam, ember, Vector3(0, 0, 0), Vector3(0.96, 1, 0.96))
	# lower gorget lame with a glowing gap above the breastplate
	_add(_ring(0.068, 0.004), ember, Vector3(0, 0.298, 0), Vector3(1, 1, 0.88))

	# --- head flame, rooted inside the gorget ---
	_head.position = Vector3(0, 0.33, 0)
	_body.add_child(_head)
	var fs := _sphere(0.5); fs.radial_segments = 48; fs.rings = 32
	# [scale, offset, tip color, height, seed, energy]
	var layers := [
		[Vector3(0.2, 0.15, 0.17), Vector3(0, 0.1, -0.004), Color("ff5a14"), 1.6, 0.0, 1.2],
		[Vector3(0.16, 0.125, 0.14), Vector3(0, 0.095, 0.004), Color("ff9a2a"), 1.45, 3.1, 1.25],
		[Vector3(0.09, 0.08, 0.08), Vector3(0, 0.07, 0.02), Color("ffd27a"), 1.3, 6.7, 1.3],
	]
	for L in layers:
		_add(fs, _flame_mat(L[2], L[3], L[4], L[5]), L[1], L[0], _head)
	# small tongues licking off the back
	for side in [-1.0, 1.0]:
		_add(fs, _flame_mat(Color("ff5a14"), 1.8, 9.0 + side, 1.2), Vector3(0.045 * side, 0.1, -0.045),
			Vector3(0.05, 0.05, 0.045), _head, Vector3(-0.5, 0, -0.5 * side))

	# --- the one big eye ---
	_add(_sphere(0.05), _glow(Color("fffbe8"), 1.0), Vector3(0, 0.1, 0.066), Vector3(0.8, 1.0, 0.3), _head)
	_add(_sphere(0.024), _mat(Color("3b1a10"), 0.0, 0.3), Vector3(0.003, 0.094, 0.079), Vector3(0.85, 1.1, 0.3), _head)
	_add(_sphere(0.008), _glow(Color.WHITE, 2.0), Vector3(0.014, 0.11, 0.086), Vector3(1, 1, 0.4), _head)
	_add(_sphere(0.004), _glow(Color.WHITE, 2.0), Vector3(-0.006, 0.084, 0.084), Vector3(1, 1, 0.4), _head)

	# --- light + sparks ---
	var light := OmniLight3D.new()
	light.light_color = Color("ff9a3c")
	light.light_energy = 2.5
	light.omni_range = 3.0
	light.shadow_enabled = true
	light.position = Vector3(0, 0.5, 0.12)
	_body.add_child(light)

	var sparks := GPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 1.6
	sparks.position = Vector3(0, 0.5, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, 0.05, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.scale_min = 0.5
	sparks.process_material = pm
	var sq := QuadMesh.new(); sq.size = Vector2(0.008, 0.008)
	var smat := _glow(EMBER, 6.0)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sq.material = smat
	sparks.draw_pass_1 = sq
	_body.add_child(sparks)

func _flame_mat(tip: Color, height: float, seed: float, energy: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = flame_shader
	sm.set_shader_parameter("tip_color", tip)
	sm.set_shader_parameter("height", height)
	sm.set_shader_parameter("seed", seed)
	sm.set_shader_parameter("energy", energy)
	return sm
