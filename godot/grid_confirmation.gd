extends ConfirmationDialog

const Layout=preload("res://window_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
var grid_box := Rect2i(3,3,4,3)

func content(message_region: String="",box: Rect2i=Rect2i()) -> VBoxContainer:
	if box.has_area():
		grid_box=box
	else:
		grid_box=Layout.confirm_grid(dialog_text.length()>120 or dialog_text.count("\n")>=2)
	var layout=Layout.new()
	layout.grid_box=grid_box
	layout.top_level=true
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading=Layout.title_label(title)
	heading.name="ModalHeading"
	heading.set_meta("ui_region","ConfirmationHeading")
	layout.add_child(heading)
	title_changed.connect(func():Layout.set_heading_text(heading,title))
	var scroll=ScrollContainer.new()
	scroll.name="ConfirmationTextScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_pad=StyleBoxEmpty.new()
	scroll_pad.content_margin_left=Tokens.SPACE_XL;scroll_pad.content_margin_right=Tokens.SPACE_XL
	scroll_pad.content_margin_top=Tokens.SPACE_MD;scroll_pad.content_margin_bottom=Tokens.SPACE_MD
	scroll.add_theme_stylebox_override("panel",scroll_pad)
	var message_area=Control.new()
	message_area.mouse_filter=Control.MOUSE_FILTER_IGNORE
	message_area.name="ConfirmationMessage" if message_region.is_empty() else message_region
	layout.add_child(message_area)
	message_area.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.set_regions(heading,message_area,null)
	var contents=VBoxContainer.new()
	contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	contents.size_flags_vertical=Control.SIZE_EXPAND_FILL
	contents.alignment=BoxContainer.ALIGNMENT_CENTER
	contents.add_theme_constant_override("separation",Tokens.SPACE_SM)
	scroll.add_child(contents)
	if not dialog_text.is_empty():
		var message=Label.new()
		message.name="ConfirmationText"
		message.text=dialog_text
		message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(message)
	return contents

func _ready():
	if is_embedded():close_requested.connect(func():canceled.emit())
	if theme==null:
		var theme_owner: Node=get_parent()
		while theme_owner!=null:
			if (theme_owner is Control or theme_owner is Window) and theme_owner.theme!=null:
				theme=theme_owner.theme;break
			theme_owner=theme_owner.get_parent()
	# AcceptDialog includes even its hidden label in the minimum size.
	get_label().top_level=true
	var style=get_theme_stylebox("panel").duplicate()
	style.set_content_margin_all(0);add_theme_stylebox_override("panel",style)
	add_theme_constant_override("buttons_separation",Tokens.SPACE_MD)
	add_theme_constant_override("buttons_min_width",Tokens.BUTTON_W_MD)
	add_theme_constant_override("buttons_min_height",Tokens.BUTTON_MD)
	get_tree().root.size_changed.connect(fit_actions)
	fit_actions()
func fit_actions():
	var view=Vector2(get_tree().root.size)
	var frame=Layout.grid_frame_rect(view,grid_box)
	var action_y := grid_box.position.y+grid_box.size.y-1
	var area=Layout.modal_local_rect(view,grid_box.position.x,action_y,grid_box.size.x,1,frame)
	var style=get_theme_stylebox("panel")
	style.set_content_margin(SIDE_LEFT,0)
	style.set_content_margin(SIDE_RIGHT,0)
	var bar=get_ok_button().get_parent() as Control
	var widths={}
	for child in bar.get_children():
		if child is Button:widths[child]=child.custom_minimum_size.x
	add_theme_constant_override("buttons_min_width",Tokens.BUTTON_W_MD)
	add_theme_constant_override("buttons_min_height",Tokens.BUTTON_MD)
	bar.add_theme_constant_override("separation",Tokens.SPACE_MD)
	bar.custom_minimum_size.y=area.size.y
	var count := bar.get_child_count()
	for i in range(count):
		var child := bar.get_child(i)
		if child is Button:
			var min_w := maxi(int(ceilf(maxf(float(widths.get(child,0.0)),child.custom_minimum_size.x))),Tokens.BUTTON_W_MD)
			Tokens.apply_button_size(child,Tokens.BUTTON_MD,true,min_w)
		elif child is Control and i>0 and i<count-1:
			child.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			child.custom_minimum_size.x=0
