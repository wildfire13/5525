shader_type spatial;
render_mode cull_disabled;
varying vec2 river_uv;
void vertex() {
 river_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
 vec2 p = river_uv;
 float glide = p.x * 1.4 - TIME * 1.25;
 float swell = sin(p.y * 4.4 + sin(glide * 0.32)) + 0.38 * sin(p.y * 10.0 - glide * 0.7);
 float crest = smoothstep(0.93, 1.28, swell) * (0.35 + 0.65 * smoothstep(-0.3, 0.9, sin(glide * 1.8 + p.y)));
 float reflection = 0.5 + 0.5 * sin(p.x * 0.55 + swell * 1.3 + TIME * 0.22);
 ALBEDO = mix(vec3(0.16,0.23,0.24), vec3(0.34,0.39,0.37), reflection) + crest * vec3(0.22,0.19,0.12);
 ROUGHNESS = 0.38;
}
