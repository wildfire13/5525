extends "res://engine_bridge.gd"
## Isolated fault injection only. Production transport and game calculations are reused.
var calls=[]
var hold_action := ""
var holding := false
var release := false
var drop_buy_reply := false
func request(payload: Dictionary) -> Dictionary:
	calls.append(payload.duplicate(true))
	if not hold_action.is_empty() and (payload.get("action")==hold_action or payload.get("op")==hold_action):
		hold_action="";holding=true;busy=true
		while not release and not closing:await get_tree().process_frame
		busy=false;holding=false;release=false
	var reply=await super.request(payload)
	if drop_buy_reply and payload.get("action")=="buyGear":
		drop_buy_reply=false;return _disconnect("injected_lost_purchase_response")
	return reply
