// Warm vertical gradient fill for the title glyphs (cream top -> ember gold).
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.91, 0.70, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.62, 0.16, 1.0);
uniform float top_y = 20.0;
uniform float bottom_y = 150.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float g = clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec4 c = mix(top_color, bottom_color, g);
	COLOR = vec4(c.rgb, COLOR.a);
}
