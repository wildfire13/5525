// Adapted from GDQuest water_2D.gdshader. See GDQuest-MIT.txt.
shader_type canvas_item;
uniform sampler2D river_mask : filter_linear, repeat_disable;
varying vec4 canvas_tint;
void vertex() {
	canvas_tint = COLOR;
}
void fragment() {
	float mask = texture(river_mask, UV).r;
	float depth = smoothstep(0.34, 0.86, UV.y);
	float phase = UV.y * mix(560.0, 300.0, depth) + UV.x * 28.0;
	float ripple = sin(phase - TIME * 2.6 + sin(UV.x * 23.0 + TIME * 0.6));
	float cross_wave = cos(phase * 0.73 + UV.x * 16.0 + TIME * 1.8);
	vec2 offset = vec2(ripple * 3.4, cross_wave * 1.45) * TEXTURE_PIXEL_SIZE * mask * depth;
	vec4 water = texture(TEXTURE, UV + offset) * canvas_tint;
	water.rgb += vec3(0.034, 0.045, 0.052) * smoothstep(0.74, 1.0, ripple * cross_wave) * mask * depth;
	COLOR = water;
}
