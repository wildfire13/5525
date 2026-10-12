extends "res://engine_bridge.gd"
var calls=[]
var hold_loss := false
var loss_held := false
var release_loss := false
func request(payload: Dictionary) -> Dictionary:
	calls.append(payload.duplicate(true))
	var reply=await super.request(payload)
	if hold_loss and reply.get("connection_lost",false):
		hold_loss=false;loss_held=true
		while not release_loss and not closing:await get_tree().process_frame
		loss_held=false;release_loss=false
	return reply
