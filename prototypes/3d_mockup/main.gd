## Night camp test scene: Char beside the caravan's campfire ring.
## Drag with the left mouse button to orbit, scroll to zoom.
## Run with `-- --shot=res://shot.png` to save one screenshot and quit.
extends Node3D

const KnightScript := preload("res://prototypes/3d_mockup/char_knight.gd")

var cam := Camera3D.new()
var yaw := 0.35
var pitch := -0.12
var dist := 1.15
var target := Vector3(0, 0.3, 0)

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	RenderingServer.set_default_clear_color(Color("0e0c14"))
	env.background_color = Color("14121a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a4560")
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.fog_light_color = Color("1c1826")
	env.fog_density = 0.05
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color("8090c0"); moon.light_energy = 0.25
	moon.rotation = Vector3(-0.9, 0.6, 0)
	add_child(moon)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color("2a2420"); gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# campfire stone ring behind Char
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color("55505a")
	for i in 9:
		var a := TAU * i / 9.0
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.06; sm.height = 0.08
		s.mesh = sm; s.material_override = stone
		s.position = Vector3(cos(a) * 0.28 - 0.55, 0.03, sin(a) * 0.28 - 0.6)
		add_child(s)

	var knight := Node3D.new()
	knight.set_script(KnightScript)
	knight.name = "Char"
	add_child(knight)

	add_child(cam)
	cam.fov = 40
	_update_cam()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot(a.substr(7))
		elif a.begins_with("--yaw="):
			yaw = float(a.substr(6)); _update_cam()

func _shot(path: String) -> void:
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _update_cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= e.relative.x * 0.01
		pitch = clamp(pitch - e.relative.y * 0.01, -1.2, 0.3)
		_update_cam()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = max(0.4, dist * 0.9)
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = min(5.0, dist * 1.1)
		_update_cam()
