extends Control
## A root overlay, including when the source is in an embedded window.
const Grid=preload("res://screen_grid.gd")
const SURFACE=Color("#20242b")
const INK=Color("#f3f6fb")
const PADDING=10
const WIDTH_CELLS=3
var source: Control
var content: Control
var title: Label
var body: Label
var panel: Panel
var measured_width := 0.0

func _ready():
	name="CompactHover";add_to_group("equipment_full_hover");hide()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=Panel.new();panel.name="EquipmentTooltipPanel";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	if source.has_method("configure_skill"):panel.set_meta("ui_region","CompactSkillHover")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style=StyleBoxFlat.new();style.bg_color=SURFACE;style.border_color=Color("#a8c9ed")
	style.set_border_width_all(1);style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	content=Control.new();content.name="EquipmentTooltip";content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.set_meta("hover_owner",weakref(self));add_child(content);content.position=Vector2(PADDING,PADDING)
	title=make_label("EquipmentTooltipName",20)
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	body=make_label("EquipmentTooltipDetails",18)
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
	place()
	show()

func place():
	var view=get_tree().root.get_visible_rect().size
	var cell=view/Grid.DIVISIONS
	var width=Grid.cell_rect(view,0,0,WIDTH_CELLS,1).size.x
	if width!=measured_width:
		measured_width=width
		title.size=Vector2(width-2*PADDING,0);body.size=Vector2(width-2*PADDING,0)
		body.position.y=title.get_line_height()+3
		var body_height=body.get_line_height()*body.get_line_count() if body.visible else 0
		content.size=Vector2(width-2*PADDING,body.position.y+body_height)
		title.size.y=body.position.y-3;body.size.y=body_height
	var height=content.size.y+2*PADDING
	var span=clampi(ceili(height/cell.y),1,Grid.DIVISIONS)
	var to_game=get_tree().root.get_screen_transform().affine_inverse()*source.get_window().get_screen_transform()
	var anchor=to_game*source.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,source.size)
	# Start beyond the source so the hover does not cover its own icon.
	var right=ceili(anchor.end.x/cell.x)
	var left=floori(anchor.position.x/cell.x)-WIDTH_CELLS
	var x=right if right+WIDTH_CELLS<=Grid.DIVISIONS else left
	var y=clampi(floori(anchor.position.y/cell.y),0,Grid.DIVISIONS-span)
	if x<0:
		x=clampi(floori(anchor.position.x/cell.x),0,Grid.DIVISIONS-WIDTH_CELLS)
		var below=ceili(anchor.end.y/cell.y)
		y=below if below+span<=Grid.DIVISIONS else maxi(0,floori(anchor.position.y/cell.y)-span)
	Grid.place(self,Grid.cell_rect(view,x,y,WIDTH_CELLS,span))

func _process(_delta):
	if not visible:return
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.get_viewport().gui_is_dragging():
		hide()
		return
	place()
