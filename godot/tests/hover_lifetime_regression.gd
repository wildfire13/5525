extends SceneTree
# Retains the independent aae0d204 review's eight controlled Q06 conditions:
# real success/error/EOF/timeout responses, released after town/new-board teardown.
# Assertions alone previously passed despite eight runtime errors. check.py also
# gates SCRIPT ERROR / ERROR output; both conditions are required for acceptance.
var game
var probe
var fixtures
var checks=[]
var owned=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func process_running(pid: int) -> bool:
	# Godot4.6 Linux emits an error when querying an already reaped child PID.
	if OS.get_name()=="Linux":return DirAccess.dir_exists_absolute("/proc/"+str(pid))
	return OS.is_process_running(pid)
func frames(n=12):
	for i in range(n):await process_frame
func settle():
	await frames()
	var deadline=Time.get_ticks_msec()+18000
	while (game.locked or game.presenting or game.engine.busy or game.preview_pending) and Time.get_ticks_msec()<deadline:await process_frame
	await frames()
func check(id,ok,detail=""):
	checks.append({"id":id,"passed":bool(ok),"detail":detail});print(("PASS " if ok else "FAIL ")+id)
	var f=FileAccess.open(evidence.path_join("hover-lifetime-regression.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"owned":owned,"scope":"Adapted independent Q06 controls plus current-response and freed-callback checks; real Node transport; no OS input."},"  "));f.close()
func mode(value):
	var f=FileAccess.open(evidence.path_join("hover-fault-mode.txt"),FileAccess.WRITE);f.store_string(value);f.close()
func saved():return (await probe.request({"op":"campaign_save"})).data
func prepare():
	await game.update({"op":"campaign_load","data":fixtures.battle});await settle();game.board.set_hover("");await game.choose_command("attack");await settle()
func trigger():
	probe.hold=true;game.board.set_hover(str(game.data.choices.attack[0]))
	var deadline=Time.get_ticks_msec()+5000
	while not probe.waiting and Time.get_ticks_msec()<deadline:await process_frame
	return probe.waiting
func delayed(fault,new_battle):
	await prepare();var old=game.board;var old_pid=int(probe.handles.pid);var connection=probe.connection_generation
	mode(fault);probe.timeout_ms=250
	var label=("success" if fault=="" else fault)+("-new-board" if new_battle else "-town")
	check(label+"-held",await trigger(),"Real hover response withheld only after transport completion")
	if not probe.waiting:return
	mode("")
	var loss=fault in ["eof","timeout"]
	check(label+"-transport",probe.held_reply.get("connection_lost",false)==loss and probe.disconnected==loss and probe.held_reply.get("ok",false)==(fault==""),probe.held_reply.duplicate(true))
	if loss:
		check(label+"-old-node-exited",not process_running(old_pid));await game.reconnect_engine();await settle();owned.append(int(probe.handles.pid));check(label+"-new-connection",probe.connection_generation>connection)
	else:await game.new_game();await settle()
	probe.timeout_ms=15000
	check(label+"-old-board-freed",not is_instance_valid(old))
	if new_battle:await prepare();game.board.set_hover("guard");await settle()
	var before=await saved();var generation=game.generation;var pending=game.pending;var pid=int(probe.handles.pid)
	game.notice="fresh session";game.render();await frames()
	var current=game.board;var person=game.hud.inspected_uid;var caption=current.hover_caption if current else "";var call_count=probe.calls.size()
	probe.deliver=true;await settle()
	check(label+"-released",not probe.waiting)
	check(label+"-no-replay",probe.calls.size()==call_count)
	check(label+"-state-preserved",await saved()==before and game.generation==generation and game.pending==pending)
	check(label+"-new-view-preserved",game.notice=="fresh session" and game.board==current and game.hud.inspected_uid==person and (current==null or current.hover_caption==caption))
	check(label+"-connection-preserved",not probe.disconnected and int(probe.handles.pid)==pid and process_running(pid))
func null_and_foreign():
	await prepare();var old=game.board;var person=game.hud.inspected_uid
	game.hud.selected_cell=24;old.set_hover("guard");var shown=game.hud.inspected_uid;game.board=null;old.set_hover("");game.hud.render_person();game.hud.refresh_hover();await frames()
	check("null-board-no-inspection-mutation",game.hud.inspected_uid==shown)
	game.board=old;var foreign=Node.new();root.add_child(foreign);game.hud.inspect_hover("mage",foreign);check("foreign-board-rejected",game.hud.inspected_uid==shown);foreign.free()
	game.hud.inspect_hover("mage",foreign);check("freed-board-callback-rejected",game.hud.inspected_uid==shown)
	await game.new_game();await settle();check("teardown-town",game.board==null and game.campaign().phase=="town")
func current_response(fault):
	await prepare();var before=await saved();mode(fault);check("current-"+fault+"-held",await trigger())
	mode("");var calls=probe.calls.size();probe.deliver=true;await settle()
	var caption=game.board.hover_caption
	check("current-"+fault+"-applied",caption=="予測：未取得" if fault=="error" else caption.begins_with("予測：") and caption.contains("が受ける −") and caption.contains("命中：100%"),caption)
	check("current-"+fault+"-no-replay",calls==probe.calls.size())
	check("current-"+fault+"-state-preserved",await saved()==before)
func busy_teardown():
	await prepare();var old=game.board;var source_id=old.get_instance_id();var inspected=game.hud.inspected_uid;var calls=probe.calls.size()
	probe.busy=true;game.hud.request_hover("guard",game.hud.hover_generation,game.generation,probe.connection_generation,source_id)
	# Keep the token intact to exercise source lifetime validation in the busy wait.
	game.board=null;old.queue_free();await frames();probe.busy=false;await frames()
	check("busy-wait-old-board-freed",not is_instance_valid(old))
	check("busy-wait-no-dispatch",probe.calls.size()==calls)
	check("busy-wait-no-inspection-mutation",game.hud.inspected_uid==inspected)
	await game.new_game();await settle()
func run():
	create_timer(160).timeout.connect(func():print("WATCHDOG TIMEOUT");quit(2))
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://hover-lifetime")
	DirAccess.make_dir_recursive_absolute(evidence)
	OS.set_environment("NATIVE5525_HOVER_FAULT_FILE",evidence.path_join("hover-fault-mode.txt"))
	var output=[];var executable=OS.get_environment("NATIVE5525_NODE");if executable.is_empty():executable="node"
	var code=OS.execute(executable,PackedStringArray([ProjectSettings.globalize_path("res://tests/hover_fixtures.cjs")]),output,false,false);fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary:print(output);quit(2);return
	mode("");root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();game.engine.close_engine();game.engine.queue_free()
	probe=load("res://tests/hover_lifetime_probe.gd").new();game.add_child(probe);game.engine=probe;probe.node_script=ProjectSettings.globalize_path("res://tests/hover_lifetime_fault.cjs");probe.start_engine();owned.append(int(probe.handles.pid));await game.new_game();await settle()
	for fault in ["","error","eof","timeout"]:
		for new_battle in [false,true]:await delayed(fault,new_battle)
	await current_response("");await current_response("error");await busy_teardown();await null_and_foreign();game.closing=true;game.invalidate_preview();await game.audio.finish_audio();probe.close_engine();game.queue_free();await frames()
	check("owned-nodes-exited",owned.all(func(pid):return not process_running(pid)))
	var failed=checks.filter(func(c):return not c.passed).size();print("HOVER LIFETIME REGRESSION ",checks.size()," FAILED ",failed);quit(0 if failed==0 else 1)
