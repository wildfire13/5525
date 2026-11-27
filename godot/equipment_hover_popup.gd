extends Control
## A root overlay, including when the source is in an embedded window.
const Grid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
const UiMotion=preload("res://ui_motion.gd")
const SURFACE=Tokens.SURFACE
const INK=Tokens.INK
const PADDING=Tokens.SPACE_MD
const WIDTH_CELLS=3
var source: Control
var content: Control
var title: Label
var body: Label
var panel: Panel
var measured_width := 0.0
var _placed_sig: Array=[]

func _ready():
	name="CompactHover";add_to_group("equipment_full_hover");hide();set_process(false)
	visibility_changed.connect(func():set_process(visible))
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=Panel.new();panel.name="EquipmentTooltipPanel";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.clip_contents=true;add_child(panel)
	if source.has_method("configure_skill"):panel.set_meta("ui_region","CompactSkillHover")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style=Tokens.elevate(Tokens.box(Tokens.SURFACE,Tokens.BORDER_ACCENT,Tokens.RADIUS_SM,0,Tokens.BORDER_WIDTH),10,4.0,Tokens.SHADOW_ELEVATED)
	panel.add_theme_stylebox_override("panel",style)
	content=Control.new();content.name="EquipmentTooltip";content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.set_meta("hover_owner",weakref(self));panel.add_child(content);content.position=Vector2(PADDING,PADDING)
	title=make_label("EquipmentTooltipName",Tokens.FONT_BODY)
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	body=make_label("EquipmentTooltipDetails",Tokens.FONT_SM)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func make_label(label_name: String,font_size: int) -> Label:
	var label=Label.new();label.name=label_name;content.add_child(label)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",source.get_theme_font("font"))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",INK)
	return label

func present():
	title.text=source.heading;body.text=source.brief();body.visible=not body.text.is_empty()
	measured_width=0
	_placed_sig=[]
	place()
	show()
	UiMotion.reveal(self,source,UiMotion.FAST,0.975)

func measure_body_height() -> float:
	if not body.visible:return 0.0
	var lines=body.get_line_count()
	var spacing=body.get_theme_constant("line_spacing")
	var by_lines=float(body.get_line_height()*lines+maxi(0,lines-1)*spacing)
	return maxf(by_lines,body.get_minimum_size().y)

func place():
	var view=get_tree().root.get_visible_rect().size
	var src_win=source.get_window()
	var sig=[view,measured_width,source.global_position,source.size,src_win.position if src_win!=null else Vector2i.ZERO]
	if _placed_sig==sig:return
	var cell=view/Grid.DIVISIONS
	var width_cells=4 if body.visible and (body.text.count("\n")>=6 or body.text.length()>180) else WIDTH_CELLS
	var width=Grid.cell_rect(view,0,0,width_cells,1).size.x
	if width!=measured_width:
		measured_width=width
		var inner_w=width-2*PADDING
		body.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		title.size=Vector2(inner_w,0);body.size=Vector2(inner_w,0)
		body.position.y=title.get_line_height()+Tokens.SPACE_XS
		var body_height=measure_body_height()
		if body.position.y+body_height+2*PADDING>view.y:
			body.add_theme_font_size_override("font_size",Tokens.FONT_XS)
			body.size=Vector2(inner_w,0)
			body_height=measure_body_height()
		var max_body=maxf(0.0,view.y-2*PADDING-body.position.y)
		body_height=minf(body_height,max_body)
		content.size=Vector2(inner_w,body.position.y+body_height)
		title.size.y=body.position.y-Tokens.SPACE_XS;body.size.y=body_height
	var height=content.size.y+2*PADDING
	var span=clampi(ceili(height/cell.y),1,Grid.DIVISIONS)
	var to_game=get_tree().root.get_screen_transform().affine_inverse()*src_win.get_screen_transform()
	var anchor=to_game*source.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,source.size)
	# Start beyond the source so the hover does not cover its own icon.
	var right=ceili(anchor.end.x/cell.x)
	var left=floori(anchor.position.x/cell.x)-width_cells
	var x=right if right+width_cells<=Grid.DIVISIONS else left
	var y=clampi(floori(anchor.position.y/cell.y),0,Grid.DIVISIONS-span)
	if x<0:
		x=clampi(floori(anchor.position.x/cell.x),0,Grid.DIVISIONS-width_cells)
		var below=ceili(anchor.end.y/cell.y)
		y=below if below+span<=Grid.DIVISIONS else maxi(0,floori(anchor.position.y/cell.y)-span)
	Grid.place(self,Grid.cell_rect(view,x,y,width_cells,span))
	_placed_sig=[view,measured_width,source.global_position,source.size,src_win.position if src_win!=null else Vector2i.ZERO]

func _process(_delta):
	if not visible:set_process(false);return
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.get_viewport().gui_is_dragging():
		hide()
		return
	place()
