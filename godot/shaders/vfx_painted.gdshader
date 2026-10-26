shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform vec4 uv_rect = vec4(0.0,0.0,1.0,1.0);
uniform float progress = 0.0;
uniform float scan = 1.0;
uniform float dissolve = 0.0;
uniform float flow = 0.0;
uniform float wave = 0.0;
uniform bool ground_masked = false;
uniform float allowed_cells[50];
varying vec3 world_point;
void vertex() {
 world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 float radius = length(UV-vec2(0.67,0.45));
 VERTEX.z -= exp(-radius*8.0)*sin(radius*20.0-progress*9.0)*wave*0.06;
}
void fragment() {
 vec2 at = UV;
 at.x += sin(UV.y*10.0-progress*5.0)*flow*0.014;
 vec4 paint = texture(art,uv_rect.xy+at*uv_rect.zw);
 float rising = scan>=0.999 ? 1.0 : smoothstep(-0.1,0.08,scan-(1.0-UV.y));
 float grain = fract(sin(dot(floor(UV*90.0),vec2(12.9898,78.233)))*43758.5453);
 float worn = dissolve<0.001 ? 1.0 : 1.0-smoothstep(grain-0.12,grain+0.12,dissolve);
 float coverage = 1.0;
 if (ground_masked) {
  int col=int(floor(world_point.x/1.35+5.0));
  int row=int(floor(world_point.z/1.35+2.5));
  if(col<0 || col>9 || row<0 || row>4) coverage=0.0;
  else coverage=allowed_cells[row*10+col];
 }
 ALBEDO=paint.rgb*tint.rgb;
 ALPHA=paint.a*tint.a*opacity*rising*worn*coverage;
}
