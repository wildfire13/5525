extends Button
## A short horizontal swipe scrolls the strip; a deployment drag leaves it vertically.
var strip_ref: WeakRef
var uid := ""
var pointer_start := Vector2.ZERO
var scroll_start := 0
var tracking := false
var suppress_click := false
var swiping := false
func configure(strip,id: String):
	strip_ref=weakref(strip);uid=id
	pressed.connect(activate)
	focus_entered.connect(func():
		var owner_=owner_strip()
		if owner_!=null and owner_.scroll!=null:owner_.scroll.ensure_control_visible(self))
func owner_strip():return strip_ref.get_ref() if strip_ref!=null else null
func activate():
	var owner_=owner_strip()
	if owner_!=null and not suppress_click and not get_viewport().gui_is_dragging():owner_.activate(uid)
func _gui_input(event):
	var owner_=owner_strip()
	if owner_==null:return
	if event is InputEventKey and event.pressed:suppress_click=false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_start=get_global_mouse_position();scroll_start=owner_.scroll.scroll_horizontal;tracking=true;swiping=false;suppress_click=false
		else:tracking=false
	elif event is InputEventMouseMotion and tracking:
		var delta_=get_global_mouse_position()-pointer_start
		if delta_.length()>10:suppress_click=true
		if not owner_.guild_drag() and absf(delta_.x)>12 and absf(delta_.x)>absf(delta_.y)*1.25:swiping=true
		if swiping:owner_.scroll.scroll_horizontal=scroll_start-int(delta_.x);accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:pointer_start=get_global_transform_with_canvas()*event.position;scroll_start=owner_.scroll.scroll_horizontal;tracking=true;swiping=false;suppress_click=false
		else:tracking=false
	elif event is InputEventScreenDrag and tracking:
		var delta_=get_global_transform_with_canvas()*event.position-pointer_start
		if delta_.length()>10:suppress_click=true
		if absf(delta_.x)>12 and absf(delta_.x)>absf(delta_.y)*1.25:swiping=true
		if swiping:owner_.scroll.scroll_horizontal=scroll_start-int(delta_.x);accept_event()
func _get_drag_data(at: Vector2):
	var owner_=owner_strip()
	if owner_==null or disabled:return null
	var delta_=get_global_mouse_position()-pointer_start if tracking else get_global_mouse_position()-(global_position+at)
	if swiping or (not owner_.guild_drag() and absf(delta_.x)>absf(delta_.y)*1.25):
		suppress_click=true;return null
	var data=owner_.drag_payload(uid)
	if data!=null:suppress_click=true;tracking=false;set_drag_preview(preload("res://deployment_drag.gd").preview(owner_.ui,uid))
	return data
func _can_drop_data(_at: Vector2,data) -> bool:
	var owner_=owner_strip();return owner_!=null and owner_.can_drop(data,uid)
func _drop_data(_at: Vector2,data):
	var owner_=owner_strip()
	if owner_!=null:suppress_click=true;owner_.drop(data,uid)
func _notification(what):
	if what==NOTIFICATION_DRAG_BEGIN:suppress_click=true
	elif what==NOTIFICATION_DRAG_END:tracking=false;suppress_click=true
