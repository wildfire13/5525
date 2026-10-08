extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
	var args=OS.get_cmdline_user_args();var mode=args[0];var marker=args[1]
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	if mode=="file":
		game.engine.io_script=ProjectSettings.globalize_path("res://tests/fault_file_helper.py")
		game.engine.io_timeout_ms=600
		var saved=await game.engine.request({"op":"campaign_save"})
		game.call_deferred("write_snapshot",marker+".save.json",saved.data,"進行")
		while not game.engine.busy:await process_frame
	else:
		game.engine.close_engine();game.engine.node_script=ProjectSettings.globalize_path("res://tests/fault_rules.cjs")
		OS.set_environment("AUDIT_RULE_MODE","ack");game.engine.start_engine();await game.new_game()
		await game.act("depart",["north","convoy"]);await game.act("travel",["safe"]);await game.act("begin",[])
		game.call_deferred("update",{"op":"act","kind":"guard","target":null,"presentation":true})
		while not game.presenting or not game.engine.busy:await process_frame
	var file=FileAccess.open(marker,FileAccess.WRITE)
	file.store_string(JSON.stringify({"node":game.engine.handles.pid,"helpers":game.engine.owned_io_pids,"busy":game.engine.busy,"presenting":game.presenting,"mode":mode}));file.close()
	await game.close_game()
