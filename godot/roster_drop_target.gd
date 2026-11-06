extends Button
var member_id=""
func _notification(what):
	if what==NOTIFICATION_DRAG_BEGIN:
		var payload=get_viewport().gui_get_drag_data()
		if payload is Dictionary and payload.get("kind")=="character_transfer":
			modulate.a=1.0 if payload.get("allowed",[]).has(member_id) else .35
	elif what==NOTIFICATION_DRAG_END:modulate.a=1.0
