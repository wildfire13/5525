extends Window
## A non-focus-taking comparison beside the status window, in root coordinates.
var ui
var source: Control
var content: RichTextLabel
var idle := 0.0
var keyboard_focus := false
func _ready():
	name="EquipmentHover";visible=false;borderless=true;unresizable=true;transient=true;unfocusable=true
	var panel=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style=StyleBoxFlat.new();style.bg_color=Color("#18212a");style.border_color=Color("#a8c9ed");style.set_border_width_all(1);style.set_content_margin_all(12);panel.add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	content=RichTextLabel.new();content.name="OwnedEquipmentComparison";content.bbcode_enabled=true;content.fit_content=true;content.scroll_active=false;content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
func show_for(control: Control,keyboard:=false):
	source=control;keyboard_focus=keyboard;idle=0;place();show()
func place():
	if not is_instance_valid(source):hide();return
	var status=source.get_window();var bounds=ui.size
	var width=minf(520,maxf(220,bounds.x-16));size=Vector2i(width,minf(480,maxf(180,bounds.y-72)))
	var right=float(status.position.x+status.size.x)+8
	var left=float(status.position.x)-width-8
	var x=right if right+width<=bounds.x-8 else left if left>=8 else bounds.x-width-8
	position=Vector2i(Vector2(x,float(status.position.y)+180).clamp(Vector2(8,36),(bounds-Vector2(size)-Vector2(8,8)).max(Vector2(8,36))))
func _process(delta):
	if not visible:return
	if not is_instance_valid(source) or not source.is_visible_in_tree():hide();return
	place()
	var over_source=source.get_global_rect().has_point(source.get_global_mouse_position())
	var over_hover=Rect2(Vector2.ZERO,Vector2(size)).has_point(get_mouse_position())
	if over_hover or over_source or keyboard_focus and source.has_focus():idle=0
	else:
		idle+=delta
		if idle>.25:hide()
