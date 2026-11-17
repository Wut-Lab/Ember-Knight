extends Control
## "Ember Knight" in Grenze Gotisch (the blueprint's display font) with a warm
## gradient fill and a soft ember glow behind it. `glow` sets glow strength.

const FONT := preload("res://assets/fonts/GrenzeGotisch.ttf")
const BLUR := preload("res://shaders/glow_blur.gdshader")
const GRADIENT := preload("res://shaders/title_gradient.gdshader")
const PAD := 60

@export var text := "Ember Knight"
@export var font_size := 132

var glow := 0.8: set = _set_glow

var _label: Label
var _glow_rect: TextureRect
var _vp: SubViewport


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {"wght": 700}

	_label = _make_label(font)
	add_child(_label)  # measure once it's in the tree, with its font overrides
	var label_size := _label.get_minimum_size()
	size = label_size
	pivot_offset = size / 2

	# The glow: the same text rendered offscreen, blurred and added on top of the scene.
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.size = Vector2i(label_size) + Vector2i(PAD * 2, PAD * 2)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var shadow_label := _make_label(font)
	shadow_label.position = Vector2(PAD, PAD)
	_vp.add_child(shadow_label)
	add_child(_vp)

	_glow_rect = TextureRect.new()
	_glow_rect.texture = _vp.get_texture()
	_glow_rect.position = Vector2(-PAD, -PAD)
	_glow_rect.size = Vector2(_vp.size)
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = BLUR
	_glow_rect.material = gm
	add_child(_glow_rect)

	var lm := ShaderMaterial.new()
	lm.shader = GRADIENT
	lm.set_shader_parameter("top_y", label_size.y * 0.22)
	lm.set_shader_parameter("bottom_y", label_size.y * 0.85)
	_label.material = lm
	move_child(_label, -1)  # crisp text on top of the glow
	_set_glow(glow)


func _make_label(font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _set_glow(v: float) -> void:
	glow = v
	if _glow_rect:
		(_glow_rect.material as ShaderMaterial).set_shader_parameter("strength", v)
