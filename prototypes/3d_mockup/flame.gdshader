// Head flame: a sphere reshaped into a teardrop that tapers into the gorget,
// with scrolling noise for flicker. Unshaded + emissive so glow picks it up.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.77, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.70, 0.22, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 0.42, 0.12, 1.0);
uniform float energy = 1.25;
uniform float height = 1.9;     // how far the tip stretches up
uniform float speed = 1.0;
uniform float seed = 0.0;

varying float h;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), u.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x), u.y);
}

void vertex(){
	// sphere radius 0.5 -> h in 0..1 bottom to top
	h = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float t = TIME * speed + seed;
	// taper at base (into collar), full in lower-middle, pinch to a tip
	float width = smoothstep(0.0, 0.32, h) * 0.55 + 0.45;
	width *= mix(1.0, 0.25, smoothstep(0.45, 1.0, h));
	float ang = atan(VERTEX.z, VERTEX.x);
	float n = noise(vec2(ang * 1.6 + seed, h * 3.0 - t * 2.2));
	width *= 0.85 + 0.3 * n;
	VERTEX.xz *= width;
	VERTEX.y = (h - 0.5) + h * h * (height - 1.0) * (0.8 + 0.4 * n);
	// sway the top
	VERTEX.x += sin(t * 2.3 + h * 3.0) * 0.06 * h * h;
	VERTEX.z += cos(t * 1.7 + h * 2.0) * 0.04 * h * h;
}

void fragment(){
	float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	vec3 c = mix(tip_color.rgb, mid_color.rgb, f);
	c = mix(c, core_color.rgb, f * f * (1.0 - h) * 0.6);
	ALBEDO = c * energy;
	ALPHA = clamp(0.6 + f, 0.0, 1.0);
}
