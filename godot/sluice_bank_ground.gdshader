shader_type spatial;
render_mode cull_disabled;
varying vec2 ground;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.55); }
float noise2(vec2 p) {
 vec2 cell = floor(p), f = smoothstep(vec2(0.0),vec2(1.0),fract(p));
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x), f.y);
}
void vertex() {
 ground = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
 float shoreline = -4.55 + 0.35*sin(ground.x*.68) + 0.18*sin(ground.x*1.31);
 float meadow = smoothstep(3.45,8.0,ground.y);
 VERTEX.y = .123 - .98*(1.0-smoothstep(shoreline-1.2,shoreline+.68,ground.y)) + meadow*(.15*sin(ground.x*.47)+.14*sin(ground.y*.75)-.10);
}
void fragment() {
 float broad = noise2(ground*.67), grain = noise2(ground*23.0);
 float edge = 2.83 + .62*sin(ground.x*.6) + .35*sin(ground.x*1.34) + .3*broad;
 float bankroad = 1.0-smoothstep(-.3,.52, abs(ground.y+.12)-edge);
 float turn = -.7 - 1.35*(ground.y-3.0) + .63*sin(ground.y*.85);
 float across = abs(ground.x-turn)*.72;
 float spur = (1.0-smoothstep(1.02,1.53,across + .28*broad)) * smoothstep(1.4,2.75,ground.y);
 vec3 grass = mix(vec3(.31,.40,.19),vec3(.56,.60,.30),broad*.84+grain*.16);
 vec3 soil = mix(vec3(.49,.39,.26),vec3(.67,.57,.39),broad*.56+grain*.44);
 vec3 color = mix(grass,soil,max(bankroad,spur));
 float wheel = 1.0-smoothstep(.045,.16,abs(across-.60)+.035*grain);
 color *= 1.0 - .32*spur*wheel;
 ALBEDO = color; ROUGHNESS = .96;
}
