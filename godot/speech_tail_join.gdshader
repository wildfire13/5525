shader_type canvas_item;
// Original tail paper opens the body's lower ink edge. Suppress only the
// tail's old root ink inside the body; its exposed contour remains untouched.
uniform float body_edge_y = 0.0;
varying float canvas_y;
void vertex() {
 canvas_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}
void fragment() {
 vec4 paper = texture(TEXTURE, UV);
 if (canvas_y < body_edge_y && min(paper.r, min(paper.g, paper.b)) < 0.75) {
  paper.a = 0.0;
 }
 COLOR = paper;
}
