extends ConfirmationDialog

const Layout=preload("res://window_grid.gd")

func content(message_region: String="") -> VBoxContainer:
	var layout=Layout.new()
	layout.top_level=true
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading=Layout.title_label(title)
	heading.name="ModalHeading";layout.add_child(heading)
	title_changed.connect(func():heading.text=title;heading.tooltip_text=title)
	var scroll=ScrollContainer.new()
	scroll.name="ConfirmationTextScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var message_area=Control.new()
	message_area.mouse_filter=Control.MOUSE_FILTER_IGNORE
	message_area.name="ConfirmationMessage" if message_region.is_empty() else message_region
	layout.add_child(message_area)
	message_area.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.set_regions(heading,message_area,null)
	var contents=VBoxContainer.new()
	contents.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation",8)
	scroll.add_child(contents)
	if not dialog_text.is_empty():
		var message=Label.new()
		message.name="ConfirmationText"
		message.text=dialog_text
		message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		message.add_theme_font_size_override("font_size",18)
		contents.add_child(message)
	return contents

func _ready():
	# AcceptDialog includes even its hidden label in the minimum size.
	get_label().top_level=true
	var style=get_theme_stylebox("panel").duplicate()
	style.set_content_margin_all(0);add_theme_stylebox_override("panel",style)
	add_theme_constant_override("buttons_separation",0)
	get_tree().root.size_changed.connect(fit_actions)
	fit_actions()
func fit_actions():
	var view=Vector2(get_tree().root.size)
	var area=Layout.local_rect(view,2,9,7,1)
	var style=get_theme_stylebox("panel")
	style.set_content_margin(SIDE_LEFT,area.position.x)
	style.set_content_margin(SIDE_RIGHT,Layout.frame_rect(view).size.x-area.end.x)
	add_theme_constant_override("buttons_min_height",int(area.size.y))
