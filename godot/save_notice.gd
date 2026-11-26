extends PanelContainer
## Transient presentation only: no input capture and no changes to save handling.
const Tokens=preload("res://ui_tokens.gd")
const Grid=preload("res://screen_grid.gd")
const UiMotion=preload("res://ui_motion.gd")
var caption: Label
var fade: Tween
var _placed_size := Vector2.ZERO
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=100
	var style=Tokens.elevate(Tokens.box(Tokens.NOTICE_BG,Tokens.NOTICE_BORDER,Tokens.RADIUS_SM,Tokens.SPACE_MD,Tokens.BORDER_WIDTH),10,4.0,Tokens.SHADOW_ELEVATED)
	add_theme_stylebox_override("panel",style)
	caption=Label.new();caption.add_theme_color_override("font_color",Tokens.INK_INVERSE);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(caption);hide();set_process(false)
func display(message: String,path: String=""):
	if is_instance_valid(fade):fade.kill()
	caption.text=message;tooltip_text=path;show();_placed_size=Vector2.ZERO;place();set_process(true)
	if UiMotion.is_reduced(self):
		modulate.a=1.0;scale=Vector2.ONE
		fade=create_tween();fade.tween_interval(5.0);fade.tween_callback(_hide_notice)
		return
	pivot_offset=size*0.5;modulate.a=0.0;scale=Vector2(0.975,0.975)
	fade=create_tween()
	fade.set_parallel(true)
	fade.tween_property(self,"modulate:a",1.0,UiMotion.BASE).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	fade.tween_property(self,"scale",Vector2.ONE,UiMotion.BASE).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	fade.chain().tween_interval(5.0)
	fade.tween_property(self,"modulate:a",0.0,UiMotion.EMPHASIS).set_trans(UiMotion.TRANS).set_ease(UiMotion.EASE)
	fade.tween_callback(_hide_notice)
func _hide_notice():
	hide();set_process(false)
func dismiss():
	if is_instance_valid(fade):fade.kill()
	fade=null;caption.text="";tooltip_text="";modulate.a=1;hide();set_process(false)
func place():
	var parent_size: Vector2=get_parent().size
	if parent_size==_placed_size:return
	_placed_size=parent_size
	Grid.place(self,Grid.cell_rect(parent_size,3,1,4,1))
func _process(_delta):
	if not visible:set_process(false);return
	place()
