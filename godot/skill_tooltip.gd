extends Button
func _make_custom_tooltip(for_text: String) -> Object:
 var label=Label.new();label.name="SkillDescriptionTooltip"
 var width=mini(520,maxi(200,int(get_viewport_rect().size.x)-32))
 label.add_theme_font_size_override("font_size",20)
 label.custom_minimum_size.x=width;label.size.x=width;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.max_lines_visible=mini(10,maxi(3,int((get_viewport_rect().size.y-80)/28)));label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.text="全文は「説明」から\n"+for_text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.custom_minimum_size.y=minf(label.get_minimum_size().y,label.max_lines_visible*28)
 return label
