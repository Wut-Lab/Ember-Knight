extends Control
## Store/social banner: the title-screen campfire and glow title, Char, and the
## mine event's forest. Render with:
##   godot --path . --resolution 3000x1000 tools/banner/banner.tscn -- --out=banner.png
## Saves a PNG after the fire settles, then quits.

const Campfire := preload("res://scripts/title/campfire.gd")
const GlowTitle := preload("res://scripts/title/glow_title.gd")
const Woods := preload("res://scripts/game/woods_event.gd")
const Mine := preload("res://scripts/game/mine_event.gd")
const BODY_FONT := preload("res://assets/fonts/AlegreyaSans-Medium.ttf")
const SZ := Vector2(1500, 500)
const HB := 270.0   ## far edge of the clearing
const FIRE := Vector2(1080, 430)

var _t := 0.0


func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size = Vector2i(SZ * 2.0)
	get_viewport().canvas_transform = Transform2D().scaled(Vector2(2, 2))
	size = SZ
	var fire := Campfire.new()
	fire.position = FIRE
	fire.scale = Vector2(0.62, 0.62)
	add_child(fire)
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://assets/char/char_determined.svg"), 1.35)
	var ch := Sprite2D.new()
	ch.texture = ImageTexture.create_from_image(img)
	ch.centered = false
	ch.offset = Vector2(-img.get_width() * 0.5, -img.get_height())
	ch.position = Vector2(1290, 462)
	add_child(ch)
	var title := GlowTitle.new()
	title.font_size = 150
	title.glow = 1.0
	add_child(title)
	title.position = Vector2(40, 70)
	var tag := Label.new()
	tag.text = "Don't Let them Snuff the Flame"
	tag.add_theme_font_override("font", BODY_FONT)
	tag.add_theme_font_size_override("font_size", 40)
	tag.add_theme_color_override("font_color", Color("#f3e9dc"))
	tag.add_theme_constant_override("outline_size", 8)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	tag.position = Vector2(108, 300)
	add_child(tag)
	await get_tree().create_timer(2.5).timeout
	_t = 0.0
	await RenderingServer.frame_post_draw
	var out := "banner.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func _draw() -> void:
	# Night sky
	for k in 40:
		var f := k / 40.0
		draw_rect(Rect2(0, HB * f, SZ.x, HB / 40.0 + 1), Color("#06050c").lerp(Color("#1b1630"), f))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 90:
		draw_circle(Vector2(r.randf() * SZ.x, r.randf() * HB * 0.85), r.randf_range(0.6, 1.6), Color(1, 1, 1, r.randf_range(0.15, 0.6)))
	# Far forest, two hazed rows (as in the mine event), scaled to the banner
	Woods._silhouettes(self, SZ, HB + 2.0, 1.5, Color("#1c2532"), 5.0, 0.0)
	Mine._haze(self, Vector2(SZ.x * 0.5, HB), Vector2(SZ.x * 0.6, 30.0), Color("#8fa6c8"), 0.06)
	Woods._silhouettes(self, SZ, HB + 14.0, 2.0, Color("#141b21"), 29.0, 0.0)
	# Clearing floor, lighter toward us, warm around the fire
	draw_rect(Rect2(0, HB + 10, SZ.x, SZ.y), Color("#120e10"))
	for k in 14:
		var f := 1.0 - k * 0.05
		Mine._ellipse(self, Vector2(SZ.x * 0.6, SZ.y + 30.0), Vector2(SZ.x * 0.7 * f, (SZ.y - HB) * 1.1 * f), Color("#2a231c", 0.09))
	for k in 16:
		Mine._ellipse(self, FIRE + Vector2(0, -6), Vector2(440.0 - k * 25.0, 95.0 - k * 5.4), Color(1.0, 0.55, 0.22, 0.02))
	# Trees on the clearing, smaller with distance, lit on the fire side
	for tr in [[640.0, 0.18, 0], [820.0, 0.22, 1], [1440.0, 0.25, 0], [1500.0, 0.6, 1], [700.0, 0.35, 0]]:
		var f: float = tr[1]
		var side := -1.0 if tr[0] > FIRE.x else 1.0
		Mine._tree(self, Vector2(tr[0], lerpf(HB, SZ.y + 16.0, f)), lerpf(0.6, 2.2, f), tr[2], side, 1.0, 0.0)
	Woods._fog(self, SZ, HB + 24.0, 3.0, 0.05)
