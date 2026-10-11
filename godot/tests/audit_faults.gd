extends SceneTree
var failures: Array[String]=[]
var count:=0
var game
var sounds=[]
var folder=OS.get_temp_dir().path_join("5525-audit-"+str(Time.get_ticks_usec()))
func check(ok: bool,label: String):
	count+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func bridge():
	var b=load("res://engine_bridge.gd").new();root.add_child(b);return b
func snapshot(b):return (await b.request({"op":"campaign_save"})).data
func settle():
	await process_frame;await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func esc():
	var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;root.push_input(e,true);await process_frame
func until_busy():
	var deadline=Time.get_ticks_msec()+3000
	while not game.engine.busy and Time.get_ticks_msec()<deadline:await process_frame
	check(game.engine.busy,"request held before cancellation")
func run():
	DirAccess.make_dir_recursive_absolute(folder)
	var b=bridge();check(b.start_engine(),"real rule engine starts")
	await b.request({"op":"campaign_start"})
	var pid=int(b.handles.pid);var saved=await snapshot(b)
	b.io_script=ProjectSettings.globalize_path("res://tests/fault_file_helper.py");b.io_timeout_ms=600
	var path=folder.path_join("save.json")
	var reply=await b.request({"op":"godot_io","action":"write","path":path,"data":saved,"fault_mode":"before_publish"})
	check(not reply.get("ok",true) and reply.get("outcome")=="not_saved","timeout before publication reports not saved")
	check(not FileAccess.file_exists(path) and DirAccess.get_files_at(folder).is_empty(),"timed-out unpublished file leaves no temporary")
	check(OS.is_process_running(pid) and await snapshot(b)==saved,"file timeout preserves rule PID and exact campaign")
	check(b.owned_io_pids.all(func(p):return not OS.is_process_running(p)),"timed-out helper and recovery helper terminated")
	reply=await b.request({"op":"godot_io","action":"write","path":path,"data":saved,"fault_mode":"after_publish"})
	check(reply.get("ok",false) and reply.data.get("recovered",false) and reply.data.get("outcome")=="saved","lost response after publication reconciles saved result")
	check(JSON.parse_string(FileAccess.get_file_as_string(path))==saved,"reconciled file contains full requested snapshot")
	reply=await b.request({"op":"godot_io","action":"read","path":path,"allowed":[]})
	check(not reply.get("ok",true) and OS.is_process_running(pid) and await snapshot(b)==saved,"slow read cannot kill or mutate game")
	for mode in ["invalid_reply","eof"]:
		reply=await b.request({"op":"godot_io","action":"read","path":path,"allowed":[],"fault_mode":mode})
		check(not reply.get("ok",true) and not b.disconnected and await snapshot(b)==saved,"file "+mode+" leaves rules available")
	b.python_program=folder.path_join("missing-python.exe")
	reply=await b.request({"op":"godot_io","action":"read","path":path,"allowed":[]})
	check(not reply.get("ok",true) and await snapshot(b)==saved,"missing Python is a recoverable file error")
	b.python_program="";b.io_script=""
	reply=await b.request({"op":"godot_io","action":"read","path":path,"allowed":[]})
	check(reply.get("ok",false),"normal file operation works after file failures")
	var all_helpers=b.owned_io_pids.duplicate();b.close_engine();await process_frame
	check(not OS.is_process_running(pid) and all_helpers.all(func(p):return not OS.is_process_running(p)),"owned Node and all Python processes reaped")
	b.queue_free();await process_frame
	for mode in ["eof","invalid","hang"]:
		b=bridge();b.node_script=ProjectSettings.globalize_path("res://tests/fault_rules.cjs");b.timeout_ms=600
		OS.set_environment("AUDIT_RULE_MODE",mode);b.start_engine();OS.set_environment("AUDIT_RULE_MODE","preview")
		var failed_pid=int(b.handles.pid)
		reply=await b.request({"op":"campaign_start"})
		check(reply.get("connection_lost",false) and b.disconnected and b.handles.is_empty(),"rule "+mode+" transitions to disconnected once")
		check(not OS.is_process_running(failed_pid),"rule "+mode+" process reaped")
		var again=await b.request({"op":"campaign_start"})
		check(again.get("error")==reply.get("error"),"rule "+mode+" subsequent request has consistent recovery message")
		b.node_script="";check(b.start_engine(),"explicit reconnect after "+mode)
		reply=await b.request({"op":"campaign_start"})
		check(reply.get("ok",false) and reply.campaign.location=="astaris","reconnected engine accepts saved-file workflow")
		b.close_engine();b.queue_free();await process_frame
	b=bridge();b.node_program=folder.path_join("missing-node.exe")
	check(not b.start_engine() and b.disconnected,"missing Node has explicit disconnected state")
	b.node_program="";b.start_engine();var external_pid=int(b.handles.pid)
	await b.request({"op":"campaign_start"});OS.kill(external_pid);await create_timer(.05).timeout
	reply=await b.request({"op":"view"})
	check(reply.get("connection_lost",false) and b.handles.is_empty(),"externally terminated Node invalidates handles")
	b.close_engine();b.queue_free();await process_frame
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	game.engine.close_engine();game.engine.node_script=ProjectSettings.globalize_path("res://tests/fault_rules.cjs")
	OS.set_environment("AUDIT_RULE_MODE","preview");game.engine.start_engine();await game.new_game()
	var initial=await snapshot(game.engine);initial.state.location="west"
	await game.update({"op":"campaign_load","data":initial})
	await game.act("trial",["guard","swift-boots","feet"])
	var before=JSON.stringify(game.state(),"",true,true)
	game.choose_command("move")
	game.call_deferred("on_cell",int(game.data.choices.move[0]));await until_busy()
	await esc();await esc();await esc();await settle()
	check(game.pending==null and game.preview.is_empty() and not game.board.ghost.visible,"Esc during delayed preview never revives ghost or range")
	check(JSON.stringify(game.state(),"",true,true)==before,"delayed cancelled preview consumes no action or resources")
	game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]))
	game.call_deferred("inspect_movement","skill");await until_busy();await esc();await settle()
	check(game.pending==null and game.preview.is_empty() and not game.board.ghost.visible,"Esc cancels delayed alternate range preview")
	game.choose_command("move");game.call_deferred("on_cell",int(game.data.choices.move[0]));await until_busy()
	game.choose_command("guard");await settle()
	check(game.command=="guard" and game.preview.is_empty() and game.pending==null,"command change invalidates previous request token")
	await game.act("endTrial",[])
	# R09: accessory trials now belong to North; armor trial above stays in West.
	initial=await snapshot(game.engine);initial.state.location="north";await game.update({"op":"campaign_load","data":initial})
	game.audio.ui_sound_started.connect(func(id):if id in ["victory","failure"]:sounds.append(id))
	for trial in range(2):
		await game.act("trial",["guard","victory-earring-1","accessory1"])
		check(game.data.get("trial")!=null,"real victory-breath trial starts")
		for turn in range(30):
			if game.state().get("result")!=null:break
			if not game.data.choices.attack.is_empty():await game.update({"op":"act","kind":"attack","target":game.data.choices.attack[0],"presentation":true})
			else:
				var cells: Array=game.data.choices.move.duplicate()
				var enemies=game.state().units.filter(func(u):return u.side=="enemy" and u.hp>0)
				cells.sort_custom(func(a,z):
					var da=100;var dz=100
					for e in enemies:
						da=mini(da,absi(int(a)%10-int(e.pos)%10)+absi(int(a)/10-int(e.pos)/10))
						dz=mini(dz,absi(int(z)%10-int(e.pos)%10)+absi(int(z)/10-int(e.pos)/10))
					return da<dz)
				if cells.is_empty():break
				await game.update({"op":"act","kind":"move","target":cells[0],"presentation":true})
		check(game.state().get("result")!=null,"independent trial reaches actual victory")
		var previous=sounds.size();game.render();game.render();game.render()
		check(sounds.size()==previous and previous==trial+1,"result redraw once, distinct trial victory plays again")
		await game.act("endTrial",[])
	check(sounds==["victory","victory"],"two real trial victories emit two victory sound events")
	var lost_pid=int(game.engine.handles.pid);OS.kill(lost_pid);await create_timer(.05).timeout
	await game.update({"op":"view"})
	check(game.retry_button.visible and not game.retry_button.disabled and game.engine.disconnected,"UI exposes reconnect after connection loss")
	await game.reconnect_engine()
	check(not game.engine.disconnected and game.campaign().phase=="town" and not game.retry_button.visible,"UI reconnect returns to load-capable town")
	check(await game.audio.finish_audio(),"stopped audio resources drain before exit")
	game.engine.close_engine();await process_frame
	game.queue_free();await process_frame
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(folder)
	print(JSON.stringify({"suite":"audit_faults","checks":count,"failures":failures,"gui":false,"subjective_listening":false}))
	quit(0 if failures.is_empty() else 1)
