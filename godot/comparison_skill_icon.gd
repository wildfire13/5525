extends Button
## Hover exposes the same full skill document as the keyboard/click detail view.
func _make_custom_tooltip(for_text: String) -> Object:
 var label=Label.new();label.name="ComparisonSkillTooltip"
 var width=minf(520,get_viewport_rect().size.x-32)
 label.custom_minimum_size.x=width;label.size.x=width
 label.add_theme_font_size_override("font_size",18);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.text=for_text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return label
