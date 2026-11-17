extends Node2D
## A glowing campfire on a dirt patch, drawn 2.5D to match Char's art:
## shaded SVG layers (dirt, stones, crossed logs, coals) around a stylized
## flame shader, rising embers and an additive glow that flickers.
## The node's origin is the centre of the fire's base.
## Set `swell` (0..1) to make the fire flare up; flicker runs on its own.

const FLAME_SHADER := preload("res://shaders/campfire_flame.gdshader")
const RASTER_SCALE := 2.0          ## SVGs are rasterized at 2x for crisp edges
const SVG_ORIGIN := Vector2(300, 170)  ## fire base inside the 600x260 SVGs
const FLAME_SIZE := Vector2(250, 300)

var swell := 0.0

var _t := 0.0
var _noise := FastNoiseLite.new()
var _flame: ColorRect
var _glow: Sprite2D
var _ground_glow: Sprite2D
var _embers: CPUParticles2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1207
	_noise.frequency = 2.2
	_noise.seed = 3

	_ground_glow = _radial_sprite(Color(1.0, 0.55, 0.22, 0.55), Vector2(760, 210))
	_ground_glow.position = Vector2(0, 6)
	add_child(_ground_glow)

	add_child(_svg_sprite(_back_svg()))

	_flame = ColorRect.new()
	_flame.size = FLAME_SIZE
	_flame.position = Vector2(-FLAME_SIZE.x / 2, -FLAME_SIZE.y + 8)
	_flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	_flame.material = mat
	add_child(_flame)

	add_child(_svg_sprite(_front_svg()))

	_embers = _make_embers()
	add_child(_embers)

	_glow = _radial_sprite(Color(1.0, 0.6, 0.25, 0.42), Vector2(1100, 820))
	_glow.position = Vector2(0, -90)
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	var f := _noise.get_noise_1d(_t)            # -1..1, smooth
	var fast := _noise.get_noise_1d(_t * 4.0 + 50.0)
	var flick := f * 0.7 + fast * 0.3
	(_flame.material as ShaderMaterial).set_shader_parameter("swell", swell)
	(_flame.material as ShaderMaterial).set_shader_parameter("flicker", flick)
	var bright := 1.0 + 0.10 * flick + 0.45 * swell
	_glow.modulate.a = clampf(0.85 * bright, 0.0, 1.6)
	_glow.scale = _glow.get_meta("base_scale") * (1.0 + 0.12 * swell + 0.02 * flick)
	_ground_glow.modulate.a = clampf(0.9 * bright, 0.0, 1.6)
	_embers.modulate.a = clampf(0.7 + 0.3 * swell + 0.1 * flick, 0.0, 1.0)
	_embers.speed_scale = 1.0 + 0.4 * swell
	_embers.initial_velocity_max = 95.0 + 60.0 * swell


# ------------------------------------------------------------ builders
func _svg_sprite(svg: String) -> Sprite2D:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, RASTER_SCALE)
	assert(err == OK, "Campfire SVG failed to load")
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.scale = Vector2.ONE / RASTER_SCALE
	s.position = -SVG_ORIGIN
	return s


func _radial_sprite(color: Color, px_size: Vector2) -> Sprite2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([
		color, Color(color, color.a * 0.45), Color(color, color.a * 0.12), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var s := Sprite2D.new()
	s.texture = tex
	var sc := px_size / 256.0
	s.scale = sc
	s.set_meta("base_scale", sc)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	return s


func _make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -40)
	p.amount = 46
	p.lifetime = 2.8
	p.preprocess = 3.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(46, 10)
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2(8, -18)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.damping_min = 4.0
	p.damping_max = 12.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.3
	p.orbit_velocity_min = -0.02
	p.orbit_velocity_max = 0.02
	var dot := GradientTexture2D.new()
	var dg := Gradient.new()
	dg.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	p.texture = dot
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 0.92, 0.6, 0.0), Color(1.0, 0.8, 0.4, 1.0),
		Color(1.0, 0.45, 0.12, 0.8), Color(0.9, 0.2, 0.05, 0.0)])
	p.color_ramp = ramp
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	return p


# ------------------------------------------------------------ art (SVG)
const DEFS := """
<defs>
 <radialGradient id="dirt">
  <stop offset="0" stop-color="#8a5532"/>
  <stop offset=".3" stop-color="#5c3822"/>
  <stop offset=".62" stop-color="#33211a" stop-opacity=".95"/>
  <stop offset=".85" stop-color="#1c1411" stop-opacity=".6"/>
  <stop offset="1" stop-color="#140f0e" stop-opacity="0"/>
 </radialGradient>
 <radialGradient id="coals" cy=".55">
  <stop offset="0" stop-color="#fff2c2"/>
  <stop offset=".28" stop-color="#ffbf47"/>
  <stop offset=".58" stop-color="#ff6a1c"/>
  <stop offset=".85" stop-color="#8f2509"/>
  <stop offset="1" stop-color="#3d1006" stop-opacity="0"/>
 </radialGradient>
 <linearGradient id="stoneLit" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#d9946a"/>
  <stop offset=".45" stop-color="#8e5f4a"/>
  <stop offset="1" stop-color="#3f2e2b"/>
 </linearGradient>
 <linearGradient id="stoneDark" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#6b5550"/>
  <stop offset=".35" stop-color="#3b3033"/>
  <stop offset="1" stop-color="#191416"/>
 </linearGradient>
 <linearGradient id="bark" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#a06a42"/>
  <stop offset=".4" stop-color="#6a4229"/>
  <stop offset="1" stop-color="#2a1910"/>
 </linearGradient>
 <linearGradient id="char" x1="0" y1="0" x2="1" y2="0">
  <stop offset="0" stop-color="#140b07" stop-opacity="0"/>
  <stop offset=".3" stop-color="#140b07" stop-opacity=".85"/>
  <stop offset=".7" stop-color="#140b07" stop-opacity=".85"/>
  <stop offset="1" stop-color="#140b07" stop-opacity="0"/>
 </linearGradient>
 <radialGradient id="endcap">
  <stop offset="0" stop-color="#e8bd88"/>
  <stop offset=".6" stop-color="#b07c4e"/>
  <stop offset="1" stop-color="#6b4428"/>
 </radialGradient>
</defs>
"""


func _f(v: float) -> String:
	return "%.1f" % v


func _svg(body: String) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="260" viewBox="0 0 600 260">' \
		+ DEFS + body + "</svg>"


## Stones ring the coals; `back` picks the ones behind the logs.
func _stones(back: bool) -> String:
	var out := ""
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var count := 10
	for i in count:
		var a := TAU * i / count + 0.15
		var sx := r.randf_range(0.9, 1.15)
		var sy := r.randf_range(0.85, 1.1)
		var rot := r.randf_range(-12.0, 12.0)
		var is_back := sin(a) < -0.05
		if is_back != back:
			continue
		var depth := (sin(a) + 1.0) / 2.0          # 0 far .. 1 near
		var cx := 300.0 + 132.0 * cos(a)
		var cy := 168.0 + 40.0 * sin(a)
		var rx := (21.0 + 7.0 * depth) * sx
		var ry := (13.0 + 5.0 * depth) * sy
		var g := '<g transform="rotate(%s %s %s)">' % [_f(rot), _f(cx), _f(cy)]
		g += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#000" opacity=".4"/>' % [
			_f(cx), _f(cy + ry * 0.55), _f(rx * 1.05), _f(ry * 0.6)]
		if back:
			# Faces the fire: warm lit front, bright top.
			g += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#stoneLit)"/>' % [
				_f(cx), _f(cy), _f(rx), _f(ry)]
			g += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#ffd2a0" opacity=".35"/>' % [
				_f(cx - rx * 0.1), _f(cy - ry * 0.4), _f(rx * 0.55), _f(ry * 0.32)]
		else:
			# Faces us, away from the fire: dark, with a warm rim on top.
			g += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="url(#stoneDark)"/>' % [
				_f(cx), _f(cy), _f(rx), _f(ry)]
			g += '<path d="M%s %s Q%s %s %s %s" fill="none" stroke="#ff9a55" stroke-width="2.6" stroke-linecap="round" opacity=".6"/>' % [
				_f(cx - rx * 0.78), _f(cy - ry * 0.5), _f(cx), _f(cy - ry * 1.25),
				_f(cx + rx * 0.78), _f(cy - ry * 0.5)]
		out += g + "</g>"
	return out


## One log lying across the fire, glowing where it burns in the middle.
func _log(cx: float, cy: float, rot: float, length: float, flip: bool) -> String:
	var h := 26.0
	var hl := length / 2.0
	var s := '<g transform="translate(%s %s) rotate(%s)">' % [_f(cx), _f(cy), _f(rot)]
	s += '<ellipse cx="0" cy="%s" rx="%s" ry="7" fill="#000" opacity=".35"/>' % [_f(h * 0.55), _f(hl)]
	s += '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="url(#bark)"/>' % [
		_f(-hl), _f(-h / 2), _f(length), _f(h), _f(h / 2)]
	# Bark grain.
	for k in 5:
		var x0 := -hl + 18.0 + k * (length - 36.0) / 4.0
		s += '<path d="M%s %s q14 2 28 0" fill="none" stroke="#2a1910" stroke-width="1.4" opacity=".55"/>' % [
			_f(x0 - 14.0), _f(-h * 0.18 + (k % 2) * 6.0)]
	# Charred middle with ember cracks.
	s += '<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="url(#char)"/>' % [
		_f(-hl * 0.55), _f(-h / 2), _f(length * 0.55), _f(h), _f(h / 2)]
	for k in 4:
		var x := -hl * 0.35 + k * hl * 0.23
		s += '<path d="M%s %s l6 4 l-3 5 l7 4" fill="none" stroke="#ff8a3a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity=".9"/>' % [
			_f(x), _f(-h * 0.35)]
	# Top light from the fire.
	s += '<path d="M%s %s H%s" stroke="#ffb070" stroke-width="2.5" stroke-linecap="round" opacity=".45"/>' % [
		_f(-hl + 10.0), _f(-h / 2 + 3.0), _f(hl - 10.0)]
	# Cut end facing us, with growth rings.
	var ex := -hl if flip else hl
	s += '<ellipse cx="%s" cy="0" rx="8" ry="%s" fill="url(#endcap)" stroke="#3a2416" stroke-width="1.2"/>' % [
		_f(ex), _f(h / 2)]
	s += '<ellipse cx="%s" cy="0" rx="4.5" ry="7.5" fill="none" stroke="#8a5a36" stroke-width="1"/>' % _f(ex)
	s += '<ellipse cx="%s" cy="0" rx="1.6" ry="3" fill="#8a5a36"/>' % _f(ex)
	return s + "</g>"


func _back_svg() -> String:
	var body := '<ellipse cx="300" cy="176" rx="296" ry="82" fill="url(#dirt)"/>'
	# Pebbles and scuffs in the lit dirt.
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 26:
		var a := r.randf() * TAU
		var d := r.randf_range(0.55, 0.95)
		var px := 300.0 + cos(a) * 250.0 * d
		var py := 176.0 + sin(a) * 66.0 * d
		var c := "#a0704c" if r.randf() < 0.4 else "#22160f"
		body += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s" opacity=".55"/>' % [
			_f(px), _f(py), _f(r.randf_range(1.5, 4.0)), _f(r.randf_range(1.0, 2.2)), c]
	body += _stones(true)
	body += '<ellipse cx="300" cy="168" rx="92" ry="26" fill="url(#coals)"/>'
	body += _log(300, 160, -11.0, 210.0, true)
	# Glowing coal lumps on the bed.
	for i in 9:
		var cx := 300.0 + r.randf_range(-60.0, 60.0)
		var cy := 170.0 + r.randf_range(-8.0, 10.0)
		body += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/>' % [
			_f(cx), _f(cy), _f(r.randf_range(5.0, 9.0)), _f(r.randf_range(3.0, 5.0)),
			["#ff7a2a", "#ffb347", "#d8461a"][i % 3]]
	return _svg(body)


func _front_svg() -> String:
	var body := _log(302, 182, 13.0, 220.0, false)
	body += _stones(false)
	return _svg(body)
