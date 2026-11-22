extends ConfirmationDialog
func _ready():
	# AcceptDialog includes even its hidden label in the minimum size.
	get_label().top_level=true
	var style=get_theme_stylebox("panel").duplicate()
	style.set_content_margin_all(0);add_theme_stylebox_override("panel",style)
	add_theme_constant_override("buttons_separation",0)
	get_tree().root.size_changed.connect(fit_actions)
	fit_actions()
	var message=get_node_or_null("ConfirmationTextScroll/ConfirmationMessage")
	if message:message.size_flags_vertical=Control.SIZE_EXPAND_FILL
func fit_actions():
	add_theme_constant_override("buttons_min_height",roundi(get_tree().root.size.y/10.0))
