extends MarginContainer
var owner_ref: WeakRef
func _unhandled_key_input(event):
	if not event is InputEventKey:return
	var controller=owner_ref.get_ref() if owner_ref!=null else null
	if controller==null:return
	if event.pressed and event.keycode==KEY_ESCAPE:
		accept_event();get_viewport().set_input_as_handled();controller.ui.get_viewport().set_input_as_handled();controller.ui.modal_escape_frame=Engine.get_process_frames();controller.close()
	elif event.pressed and event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:accept_event()
