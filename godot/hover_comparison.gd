extends Window
## A compact comparison beside the status window; it never takes keyboard focus.
const FONT_SIZE := 18
const PADDING := 10
const MIN_WIDTH := 200.0
const MAX_WIDTH := 420.0
var ui
var source: Control
var content: RichTextLabel
var idle := 0.0
var keyboard_focus := false
func _ready():
	name="EquipmentHover";visible=false;borderless=true;unresizable=true;transient=true;unfocusable=true
	var panel=PanelContainer.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style=StyleBoxFlat.new();style.bg_color=Color("#18212a");style.border_color=Color("#a8c9ed");style.set_border_width_all(1);style.set_content_margin_all(PADDING);panel.add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	content=RichTextLabel.new();content.name="OwnedEquipmentComparison";content.bbcode_enabled=true;content.fit_content=true;content.scroll_active=false;content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for font_size in ["normal_font_size","bold_font_size","italics_font_size","bold_italics_font_size","mono_font_size"]:content.add_theme_font_size_override(font_size,FONT_SIZE)
	scroll.add_child(content)
func show_for(control: Control,keyboard:=false):
	source=control;keyboard_focus=keyboard;idle=0;place();show()
func place():
	if not is_instance_valid(source):hide();return
	var status=source.get_window();var bounds=ui.size
	var font=content.get_theme_font("normal_font")
	var plain=content.get_parsed_text();var natural=0.0
	for line in plain.split("\n"):natural=maxf(natural,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x)
	# Reserve scrollbar width even for short content so wrapping never oscillates.
	var width=clampf(natural+PADDING*2+16,MIN_WIDTH,MAX_WIDTH)
	var anchor=Vector2(status.position)+source.get_global_rect().position
	var x=anchor.x+source.size.x+8
	if x+width>bounds.x-8:x=anchor.x-width-8
	width=minf(width,maxf(120,bounds.x-16))
	var height=font.get_multiline_string_size(plain,HORIZONTAL_ALIGNMENT_LEFT,width-PADDING*2-16,FONT_SIZE).y+PADDING*2+4
	# Use the final RichText layout after a width change has settled as well.
	if absf(float(size.x)-width)<1:height=maxf(height,float(content.get_content_height())+PADDING*2+4)
	size=Vector2i(ceili(width),ceili(clampf(height,48,minf(360,bounds.y-72))))
	var y=anchor.y
	# A left-side fallback must not cover the same item's name/drag source.
	# Keep the comparison scrollable, but move it above or below that row.
	if str(source.name).begins_with("OwnedEquipmentActions_"):
		var item=source.get_parent().get_node_or_null("OwnedEquipment_"+str(source.name).trim_prefix("OwnedEquipmentActions_"))
		if item is Control:
			var row=Rect2(Vector2(status.position)+item.get_global_rect().position,item.size).merge(Rect2(anchor,source.size))
			if Rect2(Vector2(x,y),Vector2(size)).intersects(row):
				var above=maxf(0,row.position.y-44);var below=maxf(0,bounds.y-row.end.y-16)
				var use_below=below>=size.y or below>=above
				size.y=mini(size.y,int(below if use_below else above))
				y=row.end.y+8 if use_below else row.position.y-size.y-8
	position=Vector2i(Vector2(x,y).clamp(Vector2(8,36),(bounds-Vector2(size)-Vector2(8,8)).max(Vector2(8,36))))
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
