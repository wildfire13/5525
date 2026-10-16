extends PanelContainer
## A bounded scrollable inspection surface; the right-side equip action stays exposed.
var source: Control
var content: RichTextLabel
var idle := 0.0
var keyboard_focus := false
func _ready():
	name="EquipmentHover";visible=false;z_index=100
	var style=StyleBoxFlat.new();style.bg_color=Color("#18212afa");style.border_color=Color("#a8c9ed");style.set_border_width_all(1);style.set_content_margin_all(12);add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	content=RichTextLabel.new();content.name="OwnedEquipmentComparison";content.bbcode_enabled=true;content.fit_content=true;content.scroll_active=false;content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
func show_for(control: Control,keyboard:=false):
	source=control;keyboard_focus=keyboard;idle=0;show();place()
func place():
	if not is_instance_valid(source):hide();return
	var bounds=get_viewport_rect().size
	var width=minf(520,maxf(220,bounds.x-180))
	size=Vector2(width,minf(480,maxf(180,bounds.y-110)))
	var rect=source.get_global_rect()
	position=Vector2(clampf(rect.position.x,8,maxf(8,bounds.x-width-150)),clampf(rect.end.y+8,8,maxf(8,bounds.y-size.y-8)))
	if position.y<rect.end.y and rect.position.y>size.y+8:position.y=rect.position.y-size.y-8
	position=position.clamp(Vector2(8,8),(bounds-size-Vector2(8,8)).max(Vector2(8,8)))
func _process(delta):
	if not visible:return
	if not is_instance_valid(source) or not source.is_visible_in_tree():hide();return
	place()
	var point=get_global_mouse_position()
	if get_global_rect().has_point(point) or source.get_global_rect().has_point(point) or keyboard_focus and source.has_focus():idle=0
	else:
		idle+=delta
		if idle>.25:hide()
