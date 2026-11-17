extends Node2D
## Camp scenery that Char defends: the stagecoach and the resting horse.
## The art is generated in 2.5D by tools/gen_camp_art.py (into camp_art.gd):
## modelled in 3D, seen from the board's camera and lit by the campfire.
## Purely visual; it doesn't block spirits or tiles.
## The node's origin is where the prop meets the ground.

const CampArt := preload("res://scripts/game/camp_art.gd")
const ART_SCALE := 2.0   ## SVGs rasterized at 2x for crisp edges

## kind -> [svg, ground anchor inside the SVG, base scale]
const ART := {
	"stagecoach": [CampArt.STAGECOACH_SVG, CampArt.STAGECOACH_ANCHOR, 0.5],
	"horse": [CampArt.HORSE_SVG, CampArt.HORSE_ANCHOR, 0.42],
}

var kind := "stagecoach"
var world := Vector2.ZERO
var board

var _sprite := Sprite2D.new()
var _t := 0.0


func setup(k: String, w: Vector2, bd) -> void:
	kind = k
	world = w
	board = bd


func _ready() -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(ART[kind][0], ART_SCALE)
	assert(err == OK, "Camp prop SVG failed to load")
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.centered = false
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var a: Vector2 = ART[kind][1]
	var k: float = ART[kind][2] * board.view_scale
	var sy := 1.0
	if kind == "horse":
		sy += 0.012 * sin(_t * 1.3)   # slow sleepy breathing
	_sprite.scale = Vector2(k, k * sy) / ART_SCALE
	_sprite.position = Vector2(-a.x * k, -a.y * k * sy)
