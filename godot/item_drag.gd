extends RefCounted
## Payloads are quotes of current UI state; mutations remain in consent flows.
static func source(control: Control,payload: Callable,caption: String,icon: Texture2D=null,allowed: Callable=Callable(),accept: Callable=Callable()):
	control.set_drag_forwarding(func(_position):
		var data=payload.call()
		if data==null:return null
		var preview=Button.new();preview.set_meta("ui_region","ItemDragPreview");preview.add_to_group("ui_drag_preview");preview.text=caption;preview.icon=icon
		preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.alignment=HORIZONTAL_ALIGNMENT_LEFT
		preview.custom_minimum_size=control.size;preview.size=control.size
		for state in ["normal","hover","pressed"]:preview.add_theme_stylebox_override(state,control.get_theme_stylebox("normal").duplicate())
		control.set_drag_preview(preview)
		return data,func(_position,data):return data is Dictionary and allowed.is_valid() and allowed.call(data),
		func(_position,data):
			if data is Dictionary and allowed.is_valid() and allowed.call(data) and accept.is_valid():accept.call(data))

static func target(control: Control,allowed: Callable,accept: Callable):
	control.set_drag_forwarding(func(_position):return null,
		func(_position,data):return data is Dictionary and allowed.call(data),
		func(_position,data):
			if data is Dictionary and allowed.call(data):accept.call(data))
