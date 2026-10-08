extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	var ok=not game.data.is_empty() and not game.engine.disconnected and game.campaign().location=="astaris"
	var pid=int(game.engine.handles.get("pid",-1))
	print(JSON.stringify({"suite":"launcher_smoke","passed":ok,"node_pid":pid,"headless":true,"python":OS.get_environment("NATIVE5525_PYTHON"),"node":OS.get_environment("NATIVE5525_NODE")}))
	if not ok:
		game.engine.close_engine();quit(1);return
	var saved=await game.engine.request({"op":"campaign_save"})
	if not saved.get("ok",false):
		game.engine.close_engine();quit(1);return
	await game.close_game()
