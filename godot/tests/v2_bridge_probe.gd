extends "res://engine_bridge.gd"
## Isolated fault injection only. Production transport and game calculations are reused.
var calls=[]
var hold_action := ""
var holding := false
var release := false
var drop_buy_reply := false
var hold_reply_action := ""
var fail_held_reply := false
var disconnect_held_reply := false
var held_reply: Dictionary={}
func request(payload: Dictionary) -> Dictionary:
	calls.append(payload.duplicate(true))
	if not hold_action.is_empty() and (payload.get("action")==hold_action or payload.get("op")==hold_action):
		hold_action="";holding=true;busy=true
		while not release and not closing:await get_tree().process_frame
		busy=false;holding=false;release=false
	var reply=await super.request(payload)
	if not hold_reply_action.is_empty() and (payload.get("action")==hold_reply_action or payload.get("op")==hold_reply_action):
		hold_reply_action="";holding=true;busy=true;held_reply=reply.duplicate(true)
		while not release and not closing:await get_tree().process_frame
		busy=false;holding=false;release=false
		if disconnect_held_reply:
			disconnect_held_reply=false;return _disconnect("injected_delayed_reply_disconnect")
		if fail_held_reply:
			fail_held_reply=false;return {"ok":false,"error":"injected_delayed_quote_failure"}
	if drop_buy_reply and payload.get("action")=="buyGear":
		drop_buy_reply=false;return _disconnect("injected_lost_purchase_response")
	return reply
