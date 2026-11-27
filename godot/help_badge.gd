extends RefCounted
## Reusable help mark icon (5525_help_icon_blue_v2.png) with hover & click popover.

const Tokens = preload("res://ui_tokens.gd")
const UiMotion = preload("res://ui_motion.gd")
const HELP_ICON_PATH := "res://assets/interface_icons/5525_help_icon_blue_v2.png"

static var _icon_cache: Texture2D
static var _active_popover: PanelContainer
static var _active_owner: WeakRef
static var _pinned := false


static func _icon_texture() -> Texture2D:
	if _icon_cache == null and ResourceLoader.exists(HELP_ICON_PATH):
		_icon_cache = load(HELP_ICON_PATH)
	return _icon_cache


static func dismiss() -> void:
	_pinned = false
	_active_owner = null
	if is_instance_valid(_active_popover):
		_active_popover.queue_free()
	_active_popover = null


static func attach(parent: Node, title: String, body: String, badge_name: String = "", icon_size: int = 28) -> Button:
	var sz := maxi(24, icon_size)
	var btn := Button.new()
	if not badge_name.is_empty():
		btn.name = badge_name
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_HELP
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.custom_minimum_size = Vector2(sz, sz)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.icon = _icon_texture()
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", sz)
	btn.tooltip_text = title + "\n" + body
	btn.set_meta(&"help_title", title)
	btn.set_meta(&"help_body", body)
	parent.add_child(btn)

	btn.mouse_entered.connect(func():
		if not _pinned:
			_show_popover(btn, title, body, false)
	)
	btn.mouse_exited.connect(func():
		if not _pinned and _active_owner != null and _active_owner.get_ref() == btn:
			dismiss()
	)
	btn.pressed.connect(func():
		if _pinned and _active_owner != null and _active_owner.get_ref() == btn:
			dismiss()
		else:
			_show_popover(btn, title, body, true)
	)
	btn.tree_exiting.connect(func():
		if _active_owner != null and _active_owner.get_ref() == btn:
			dismiss()
	)
	return btn


static func _show_popover(anchor: Control, title: String, body: String, pin: bool) -> void:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	dismiss()
	var tree := anchor.get_tree()
	if tree == null or tree.root == null:
		return
	var host := tree.root.get_node_or_null("HelpPopoverLayer")
	if host == null:
		host = CanvasLayer.new()
		host.name = "HelpPopoverLayer"
		host.layer = 2100
		tree.root.add_child(host)

	var panel := PanelContainer.new()
	panel.name = "HelpBadgePopover"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if pin else Control.MOUSE_FILTER_IGNORE
	var style := Tokens.elevate(
		Tokens.box(Tokens.SURFACE, Tokens.BORDER_ACCENT, Tokens.RADIUS_SM, Tokens.SPACE_MD, Tokens.BORDER_WIDTH_EMPHASIS),
		12,
		4.0,
		Tokens.SHADOW_ELEVATED
	)
	panel.add_theme_stylebox_override("panel", style)
	host.add_child(panel)

	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 340
	col.add_theme_constant_override("separation", Tokens.SPACE_XS)
	panel.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", Tokens.SPACE_SM)
	col.add_child(header)

	var title_lbl := Label.new()
	title_lbl.name = "HelpPopoverTitle"
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", Tokens.FONT_SM)
	title_lbl.add_theme_color_override("font_color", Tokens.ACCENT)
	header.add_child(title_lbl)

	if pin:
		var close_btn := Button.new()
		close_btn.name = "HelpPopoverClose"
		close_btn.text = "×"
		close_btn.flat = true
		close_btn.focus_mode = Control.FOCUS_NONE
		close_btn.custom_minimum_size = Vector2(24, 24)
		close_btn.add_theme_font_size_override("font_size", Tokens.FONT_SM)
		close_btn.add_theme_color_override("font_color", Tokens.MUTED_INK)
		close_btn.pressed.connect(dismiss)
		header.add_child(close_btn)

	var body_lbl := Label.new()
	body_lbl.name = "HelpPopoverBody"
	body_lbl.text = body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size.x = 340
	body_lbl.add_theme_font_size_override("font_size", Tokens.FONT_XS)
	body_lbl.add_theme_color_override("font_color", Tokens.INK)
	col.add_child(body_lbl)

	_active_popover = panel
	_active_owner = weakref(anchor)
	_pinned = pin

	panel.reset_size()
	var view := Vector2(tree.root.size)
	var rect := anchor.get_global_rect()
	var win := anchor.get_window()
	if win != null and win != tree.root and win.is_embedded():
		rect.position += Vector2(win.position)
	var pop_size := panel.get_combined_minimum_size()
	var x := rect.end.x + 8.0
	if x + pop_size.x > view.x - 16.0:
		x = rect.position.x - pop_size.x - 8.0
	x = clampf(x, 16.0, maxf(16.0, view.x - pop_size.x - 16.0))
	var y := rect.position.y - 4.0
	if y + pop_size.y > view.y - 16.0:
		y = view.y - pop_size.y - 16.0
	y = clampf(y, 16.0, maxf(16.0, view.y - pop_size.y - 16.0))
	panel.position = Vector2(x, y)
	UiMotion.reveal(panel, anchor, UiMotion.FAST, 0.975)
