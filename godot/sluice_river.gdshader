shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep : source_color = vec4(0.25,0.43,0.47,1.0);
uniform vec4 shallows : source_color = vec4(0.43,0.61,0.61,1.0);
uniform vec4 glint : source_color = vec4(0.83,0.78,0.62,1.0);
varying vec2 river_uv;
void vertex() { river_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = river_uv;
	float current = p.x - 0.55 * TIME;
	float bend = sin(current * 1.5 + p.y * 0.8) + 0.5 * sin(current * 2.1 - p.y * 1.7);
	float glass = 0.5 + 0.5 * sin(p.y * 3.3 + bend + current * 0.23);
	float wave = sin(p.y * 14.0 + bend * 2.0 + current * 0.8);
	float flecks = smoothstep(0.77, 1.0, wave) * smoothstep(0.48, 1.1, bend);
	ALBEDO = mix(mix(deep.rgb, shallows.rgb, 0.25 + glass * 0.45), glint.rgb, flecks * 0.65);
}
