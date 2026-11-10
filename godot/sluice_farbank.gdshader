shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D painting : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float along_bank = world_position.x / 22.0 + 0.5;
	float u = 1.0 - abs(mod(along_bank, 2.0) - 1.0);
	float v = 1.0 - (world_position.y + 2.5) / 7.33;
	vec3 picture = texture(painting, vec2(u, clamp(v, 0.001, 0.999))).rgb;
	ALBEDO = mix(picture, vec3(0.52, 0.65, 0.75), smoothstep(0.0, 0.5, -v));
	ALPHA = smoothstep(-0.64, 0.65, world_position.y);
}
