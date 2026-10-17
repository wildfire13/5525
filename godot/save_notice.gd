extends PanelContainer
## Transient presentation only: no input capture and no changes to save handling.
var caption: Label
var fade: Tween
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=100
	var style=StyleBoxFlat.new();style.bg_color=Color("#203c3bf2");style.border_color=Color("#94c9b8");style.set_border_width_all(1);style.set_corner_radius_all(6);style.set_content_margin_all(10);add_theme_stylebox_override("panel",style)
	caption=Label.new();caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption);hide()
func display(message: String,path: String=""):
	if is_instance_valid(fade):fade.kill()
	caption.text=message;tooltip_text=path;modulate.a=1;show();place()
	fade=create_tween();fade.tween_interval(5.0);fade.tween_property(self,"modulate:a",0.0,.5);fade.tween_callback(hide)
func place():
	var ui=get_parent();var width=minf(680,maxf(160,ui.size.x*.45))
	size=Vector2(width,50);position=Vector2((ui.size.x-width)/2,ui.top.get_global_rect().end.y+8)
func _process(_delta):
	if visible:place()
