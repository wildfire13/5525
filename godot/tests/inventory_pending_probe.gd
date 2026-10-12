extends "res://engine_bridge.gd"
## Test-only response hold after real Node transport, without desktop input.
var hold_action=""
var waiting=false
var deliver=false
func request(payload: Dictionary) -> Dictionary:
	var reply=await super.request(payload)
	if payload.get("op")=="campaign" and payload.get("action")==hold_action:
		hold_action="";waiting=true
		while not deliver and not closing:await get_tree().process_frame
		deliver=false;waiting=false
	return reply
