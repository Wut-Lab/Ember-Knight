extends Node2D
## Camp scenery that Char defends: the covered wagon and the resting horse.
## Drawn 2.5D in the same shaded-SVG style as Char and the campfire: warm
## firelight on the side facing the fire, a cool moonlit rim on the far side.
## Purely visual; it doesn't block spirits or tiles.
## The node's origin is where the prop meets the ground.

const ART_SCALE := 2.0   ## SVGs rasterized at 2x for crisp edges

## kind -> [svg, ground anchor inside the SVG, base scale]
const ART := {
	"wagon": ["WAGON_SVG", Vector2(165, 222), 0.5],
	"horse": ["HORSE_SVG", Vector2(150, 184), 0.4],
}

var kind := "wagon"
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
	var err := img.load_svg_from_string(get(ART[kind][0]), ART_SCALE)
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


# ------------------------------------------------------------ art (SVG)
const WAGON_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="320" height="240" viewBox="0 0 320 240">
<defs>
 <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b07a4e"/><stop offset=".45" stop-color="#6a4229"/><stop offset="1" stop-color="#2e1c11"/></linearGradient>
 <linearGradient id="woodFar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a3020"/><stop offset="1" stop-color="#1a110b"/></linearGradient>
 <linearGradient id="canvas" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8e92ad"/><stop offset=".3" stop-color="#cfc5ae"/><stop offset=".75" stop-color="#ebc08e"/><stop offset="1" stop-color="#c98a52"/></linearGradient>
 <linearGradient id="canvasEnd" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#e2b07a"/><stop offset="1" stop-color="#a98a6c"/></linearGradient>
 <radialGradient id="inside" cx=".6" cy=".7" r=".8"><stop offset="0" stop-color="#6b3a1c"/><stop offset=".6" stop-color="#2a1610"/><stop offset="1" stop-color="#140c09"/></radialGradient>
 <radialGradient id="warm" cx=".5" cy="1.05" r=".75"><stop offset="0" stop-color="#ff9a3c" stop-opacity=".45"/><stop offset="1" stop-color="#ff7a2a" stop-opacity="0"/></radialGradient>
 <radialGradient id="hub" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#f2d68a"/><stop offset=".6" stop-color="#9a7430"/><stop offset="1" stop-color="#4a3410"/></radialGradient>
 <linearGradient id="barrel" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#c88a58"/><stop offset=".5" stop-color="#8a5634"/><stop offset="1" stop-color="#3e2616"/></linearGradient>
</defs>
<ellipse cx="160" cy="222" rx="150" ry="13" fill="#000" opacity=".45"/>
<!-- far wheels -->
<g fill="none" stroke-linecap="round">
 <circle cx="116" cy="188" r="26" stroke="#120b08" stroke-width="7"/>
 <circle cx="116" cy="188" r="21" stroke="url(#woodFar)" stroke-width="4"/>
 <circle cx="258" cy="182" r="32" stroke="#120b08" stroke-width="7"/>
 <circle cx="258" cy="182" r="27" stroke="url(#woodFar)" stroke-width="4"/>
</g>
<!-- tongue -->
<path d="M58 182 L8 214" stroke="#1a110b" stroke-width="10" stroke-linecap="round"/>
<path d="M58 182 L8 214" stroke="url(#wood)" stroke-width="6" stroke-linecap="round"/>
<path d="M18 200 L34 216" stroke="#1a110b" stroke-width="6" stroke-linecap="round"/>
<!-- bed -->
<path d="M46 138 H276 L272 188 H52 Z" fill="url(#wood)" stroke="#1a110b" stroke-width="3" stroke-linejoin="round"/>
<path d="M50 154 H274 M51 171 H273" stroke="#2e1c11" stroke-width="2" opacity=".7"/>
<path d="M48 141 H274" stroke="#ffbf7a" stroke-width="2.5" opacity=".55"/>
<path d="M54 186 H270" stroke="#ff9a55" stroke-width="2.5" opacity=".5"/>
<!-- water barrel on the side -->
<rect x="150" y="150" width="34" height="34" rx="6" fill="url(#barrel)" stroke="#1a110b" stroke-width="2.5"/>
<path d="M151 158 H183 M151 176 H183" stroke="#3a3540" stroke-width="3"/>
<!-- bonnet -->
<path d="M44 140 C34 100 40 62 66 42 Q160 26 254 42 C280 62 286 100 276 140 Z" fill="url(#canvas)" stroke="#1a110b" stroke-width="3" stroke-linejoin="round"/>
<g fill="none" stroke="#7a6a52" stroke-width="2.2" opacity=".55">
 <path d="M104 138 Q100 86 106 36"/><path d="M160 138 Q158 84 160 32"/><path d="M216 138 Q220 86 214 36"/>
</g>
<path d="M66 44 Q160 28 254 44" fill="none" stroke="#9fb2ff" stroke-width="3" opacity=".55" stroke-linecap="round"/>
<path d="M48 134 Q160 128 272 134" fill="none" stroke="#ffb070" stroke-width="3" opacity=".5" stroke-linecap="round"/>
<!-- open front end with a warm glow inside -->
<ellipse cx="58" cy="94" rx="20" ry="46" fill="url(#canvasEnd)" stroke="#1a110b" stroke-width="2.5"/>
<ellipse cx="60" cy="98" rx="12" ry="32" fill="url(#inside)"/>
<path d="M46 66 q8 -6 16 0 M44 120 q10 8 24 0" fill="none" stroke="#7a5a3a" stroke-width="2" opacity=".7"/>
<!-- near wheels -->
<g stroke-linecap="round">
 <circle cx="94" cy="192" r="30" fill="none" stroke="#1a110b" stroke-width="9"/>
 <circle cx="94" cy="192" r="30" fill="none" stroke="#4a4752" stroke-width="5"/>
 <circle cx="94" cy="192" r="24" fill="none" stroke="url(#wood)" stroke-width="5"/>
 <path d="M94 168 V216 M70 192 H118 M77 175 L111 209 M111 175 L77 209" stroke="#5a3820" stroke-width="3.5"/>
 <circle cx="94" cy="192" r="7" fill="url(#hub)" stroke="#1a110b" stroke-width="2"/>
 <path d="M68 180 A28 28 0 0 1 82 166" fill="none" stroke="#ffb070" stroke-width="2.5" opacity=".7"/>
 <circle cx="232" cy="186" r="36" fill="none" stroke="#1a110b" stroke-width="9"/>
 <circle cx="232" cy="186" r="36" fill="none" stroke="#4a4752" stroke-width="5"/>
 <circle cx="232" cy="186" r="30" fill="none" stroke="url(#wood)" stroke-width="5"/>
 <path d="M232 156 V216 M202 186 H262 M211 165 L253 207 M253 165 L211 207" stroke="#5a3820" stroke-width="4"/>
 <circle cx="232" cy="186" r="8" fill="url(#hub)" stroke="#1a110b" stroke-width="2"/>
 <path d="M200 174 A34 34 0 0 1 216 156" fill="none" stroke="#ffb070" stroke-width="2.5" opacity=".7"/>
</g>
</svg>"""

const HORSE_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200">
<defs>
 <radialGradient id="coat" cx=".3" cy=".35" r=".85"><stop offset="0" stop-color="#c9814a"/><stop offset=".5" stop-color="#8a4c28"/><stop offset="1" stop-color="#3a1c0e"/></radialGradient>
 <radialGradient id="coatHead" cx=".35" cy=".3" r=".9"><stop offset="0" stop-color="#d08a52"/><stop offset=".6" stop-color="#8a4c28"/><stop offset="1" stop-color="#40200f"/></radialGradient>
 <linearGradient id="mane" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a2a18"/><stop offset="1" stop-color="#160c08"/></linearGradient>
 <linearGradient id="warm" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff9a3c" stop-opacity=".45"/><stop offset=".55" stop-color="#ff9a3c" stop-opacity="0"/></linearGradient>
 <linearGradient id="shade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".45"/></linearGradient>
</defs>
<ellipse cx="160" cy="184" rx="135" ry="12" fill="#000" opacity=".45"/>
<!-- tail lying on the ground -->
<path d="M236 136 C262 140 276 160 288 182 C270 184 252 176 240 160 Z" fill="url(#mane)" stroke="#120a06" stroke-width="2.5" stroke-linejoin="round"/>
<!-- hind leg, tucked -->
<path d="M206 160 C230 160 244 172 236 182 L178 184 C176 174 186 162 206 160 Z" fill="url(#coat)" stroke="#1a0e08" stroke-width="2.5"/>
<path d="M172 176 L186 176 L188 185 L170 185 Z" fill="#241510" stroke="#120a06" stroke-width="2"/>
<!-- body and haunch -->
<ellipse cx="160" cy="142" rx="78" ry="38" fill="url(#coat)" stroke="#1a0e08" stroke-width="3"/>
<ellipse cx="206" cy="136" rx="40" ry="35" fill="url(#coat)" stroke="#1a0e08" stroke-width="3"/>
<path d="M184 116 C200 104 226 104 240 122" fill="none" stroke="#9fb2ff" stroke-width="3" opacity=".5" stroke-linecap="round"/>
<!-- saddle blanket -->
<path d="M132 108 Q160 100 188 106 L184 148 Q158 154 134 148 Z" fill="#c8262b" stroke="#1a0e08" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M146 106 V150 M160 104 V151 M174 105 V150 M135 120 H186 M135 135 H185" stroke="#f4efe6" stroke-width="4" opacity=".75"/>
<path d="M132 108 Q160 100 188 106 L184 148 Q158 154 134 148 Z" fill="url(#shade)"/>
<!-- front legs, folded under the chest -->
<path d="M92 160 C104 172 130 176 146 178 L146 186 C120 186 96 182 86 172 Z" fill="url(#coat)" stroke="#1a0e08" stroke-width="2.5"/>
<path d="M144 177 L158 178 L158 187 L144 186 Z" fill="#241510" stroke="#120a06" stroke-width="2"/>
<!-- neck, lowered toward the fire -->
<path d="M128 114 C112 98 90 96 74 110 L60 140 C78 148 96 156 110 162 C118 146 124 130 128 114 Z" fill="url(#coat)" stroke="#1a0e08" stroke-width="3" stroke-linejoin="round"/>
<!-- mane -->
<path d="M132 112 C118 92 96 88 78 100 L70 114 C84 104 100 102 112 112 L120 106 L124 118 Z" fill="url(#mane)" stroke="#120a06" stroke-width="2" stroke-linejoin="round"/>
<!-- head, resting low, eyes closed -->
<path d="M84 118 C66 112 44 122 30 144 C24 156 30 166 42 166 C58 166 76 156 88 144 C94 134 92 122 84 118 Z" fill="url(#coatHead)" stroke="#1a0e08" stroke-width="3" stroke-linejoin="round"/>
<path d="M30 146 C26 156 32 164 42 164 C46 158 42 148 36 144 Z" fill="#3a2016" opacity=".85"/>
<ellipse cx="36" cy="155" rx="2.5" ry="1.8" fill="#120a06"/>
<path d="M78 112 L84 94 L92 114 Z" fill="url(#coatHead)" stroke="#1a0e08" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M82 116 C74 112 70 118 72 124 C76 120 80 120 84 122 Z" fill="url(#mane)"/>
<path d="M58 132 Q64 136 70 132" fill="none" stroke="#120a06" stroke-width="2.5" stroke-linecap="round"/>
<path d="M60 135 l-1 3 M64 136 l0 3 M68 135 l1 3" stroke="#120a06" stroke-width="1.5" stroke-linecap="round"/>
<path d="M48 124 Q60 116 74 118" fill="none" stroke="#ffb070" stroke-width="2.5" opacity=".6" stroke-linecap="round"/>
</svg>"""
