// Stylized campfire flames to match Char's vector look: crisp colour bands
// (red rim, orange, yellow, cream core) on noise-licked teardrop tongues.
shader_type canvas_item;
render_mode blend_add;

uniform float swell : hint_range(0.0, 1.0) = 0.0; // menu fire swell
uniform float flicker = 0.0;                      // small random flicker from script

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

// Signed "inside-ness" of one flame tongue. uv.y: 0 bottom .. 1 top.
float tongue(vec2 uv, float cx, float h, float w, float seed, float t) {
	float y = uv.y / h;
	float sway = (fbm(vec2(seed * 3.1, uv.y * 1.8 - t * 1.1)) - 0.5) * 0.30 * y * y;
	float x = uv.x - cx - sway;
	float n = fbm(vec2(uv.x * 4.0 + seed * 7.3, uv.y * 3.2 - t * 2.3));
	float prof = w * pow(max(0.0, 1.0 - y), 0.7) * smoothstep(-0.25, 0.2, y);
	return prof - abs(x) + (n - 0.5) * 0.09 * (0.25 + y);
}

float band(float d, float edge) {
	float aa = fwidth(d) * 1.2;
	return smoothstep(edge - aa, edge + aa, d);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME;
	float hs = (1.0 + 0.22 * swell) * (1.0 + 0.04 * flicker);
	float d = tongue(uv, 0.50, 0.62 * hs, 0.22, 1.3, t);
	d = max(d, tongue(uv, 0.37, 0.42 * hs, 0.14, 4.7, t * 1.13));
	d = max(d, tongue(uv, 0.63, 0.46 * hs, 0.14, 8.1, t * 0.93));
	d = max(d, tongue(uv, 0.47, 0.76 * hs, 0.075, 2.9, t * 1.27));

	vec3 red    = vec3(0.86, 0.20, 0.05);
	vec3 orange = vec3(1.00, 0.47, 0.10);
	vec3 yellow = vec3(1.00, 0.76, 0.26);
	vec3 cream  = vec3(1.00, 0.95, 0.78);

	float b0 = band(d, 0.0);
	float b1 = band(d, 0.028);
	float b2 = band(d, 0.065);
	float b3 = band(d - uv.y * 0.12, 0.10);
	vec3 col = mix(red, orange, b1);
	col = mix(col, yellow, b2);
	col = mix(col, cream, b3);

	float tip_fade = 1.0 - smoothstep(0.55, 0.93, uv.y);
	float a = b0 * mix(0.0, 0.95, tip_fade) * (0.92 + 0.08 * swell);
	float haze = smoothstep(-0.08, 0.0, d) * (1.0 - b0) * 0.22;
	// Multiply by the incoming COLOR so node fades (modulate) apply.
	COLOR = vec4(col, (a + haze) * tip_fade) * COLOR;
}
