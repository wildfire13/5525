// Adapted from GDQuest clouds2D.gdshader. See GDQuest-MIT.txt.
shader_type canvas_item;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;
void fragment() {
	vec2 drift = vec2(-0.023, 0.008) * TIME;
	float detail = texture(cloud_noise, UV * 2.2 - drift * 0.38).r;
	float cloud = texture(cloud_noise, UV * vec2(1.5, 1.1) + drift + detail * 0.075).r;
	float shade = smoothstep(0.37, 0.65, cloud) * smoothstep(0.32, 0.68, UV.y);
	COLOR.rgb *= mix(vec3(1.0), vec3(0.72, 0.77, 0.84), shade);
}
