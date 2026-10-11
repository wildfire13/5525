extends "res://engine_bridge.gd"
var hold=false
var waiting=false
var deliver=false
var held_reply={}
var calls=[]
func request(payload: Dictionary) -> Dictionary:
	calls.append(payload.duplicate(true))
	var reply=await super.request(payload)
	if payload.get("op")=="hover_preview" and hold:
		hold=false;waiting=true;held_reply=reply.duplicate(true)
		while not deliver and not closing:await get_tree().process_frame
		deliver=false;waiting=false
	return reply
