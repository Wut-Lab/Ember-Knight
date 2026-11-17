// Soft additive glow from a texture's alpha (used behind the title text).
shader_type canvas_item;
render_mode blend_add;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.18, 1.0);
uniform float strength = 1.0;
uniform float radius_px = 14.0;

varying vec4 fade; // node modulate only (not the texture), so fades apply

void vertex() {
	fade = COLOR;
}

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * radius_px / 4.0;
	float acc = 0.0;
	float wsum = 0.0;
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			float w = exp(-float(x * x + y * y) / 9.0);
			acc += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a * w;
			wsum += w;
		}
	}
	float a = acc / wsum;
	COLOR = vec4(tint.rgb, a * strength * tint.a) * fade;
}
