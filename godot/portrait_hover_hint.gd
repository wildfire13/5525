extends TextureRect
## Keep the portrait hint inside its status Window, above the scrolling content.
## This avoids depending on a separate native tooltip popup for an embedded Window.
var hint: PanelContainer
func configure_hint():
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_entered.connect(show_hint)
	mouse_exited.connect(hide_hint)
	visibility_changed.connect(func():
		if not is_visible_in_tree():hide_hint())
func _get_tooltip(_at: Vector2) -> String:
	return "" # The same text is presented by the window-local hover hint.
func show_hint():
	if not is_visible_in_tree():return
	if not is_instance_valid(hint):
		hint=PanelContainer.new();hint.name="StatusPortraitHoverHint";hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.z_index=100
		var style=StyleBoxFlat.new();style.bg_color=Color("#20262e");style.border_color=Color("#aab6c3");style.set_border_width_all(1);style.set_content_margin_all(8);hint.add_theme_stylebox_override("panel",style)
		var caption=Label.new();caption.text=tooltip_text;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.add_theme_font_size_override("font_size",20);hint.add_child(caption)
		get_window().add_child(hint)
	var extent=hint.get_combined_minimum_size();var available=Vector2(get_window().size)
	hint.position=Vector2(global_position.x,global_position.y+size.y+6).clamp(Vector2.ZERO,(available-extent).max(Vector2.ZERO))
	hint.show()
func hide_hint():
	if is_instance_valid(hint):hint.hide()
func _exit_tree():
	if is_instance_valid(hint):hint.queue_free()
