extends RefCounted
## Shared inventory controls. Each screen supplies its own selection and actions.
static func add_filter(ui, parent, member, selected_filter: String, changed: Callable) -> OptionButton:
	var filter=OptionButton.new()
	parent.add_child(filter)
	var choices=[["all","すべて"],["items","消耗品・荷物"]]
	for slot in member.get("equipmentSlots",[]):
		choices.append([slot.slot,slot.label])
	for choice in choices:
		filter.add_item(choice[1])
		filter.set_item_metadata(filter.item_count-1,choice[0])
		if choice[0]==selected_filter:filter.select(filter.item_count-1)
	filter.item_selected.connect(func(index):changed.call(str(filter.get_item_metadata(index))))
	return filter

static func matches(entry: Dictionary, selected_filter: String) -> bool:
	if selected_filter=="all":return true
	if selected_filter=="items":return entry.kind!="equipment"
	return entry.get("equipSlots",[]).any(func(option):return option.slot==selected_filter)

static func add_row(ui, parent, entry: Dictionary, on_pressed: Callable, selected: bool, disabled: bool) -> Button:
	var button=ui.button(parent,str(entry.name)+"  ×"+str(int(entry.count)),on_pressed,disabled)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=60
	button.clip_text=true
	button.tooltip_text=str(entry.name)
	var icon=ui.icons.equipment(entry) if entry.kind=="equipment" else "items" if entry.kind=="quest" else str(entry.id)
	button.icon=ui.icons.texture(icon)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",40)
	ui.mark_selected(button,selected)
	return button
