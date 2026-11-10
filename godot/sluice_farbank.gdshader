shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D painting : source_color, filter_linear_mipmap;
varying float elevation;
void vertex() { elevation = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
 ALBEDO = texture(painting, UV).rgb;
 ALPHA = smoothstep(-0.64, 0.65, elevation);
}
