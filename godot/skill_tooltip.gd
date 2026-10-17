extends Button
func _make_custom_tooltip(for_text: String) -> Object:
	var label=Label.new();label.name="SkillDescriptionTooltip"
	label.custom_minimum_size.x=520;label.size.x=520;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.text=for_text;label.add_theme_font_size_override("font_size",20);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label
