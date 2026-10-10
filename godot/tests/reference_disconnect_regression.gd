extends SceneTree
## Real transport failures after Node calculates a canonical preview; no desktop input.
class LossProbe:
	extends "res://engine_bridge.gd"
	var hold_next := false
	var holding := false
	var release := false
	var hold_loss := false
	var loss_held := false
	var release_loss := false
	var calls=[]
	func request(payload: Dictionary)->Dictionary:
		calls.append(payload.duplicate(true))
		if hold_next and payload.get("op")=="preview":
			hold_next=false;holding=true;busy=true
			while not release and not closing:await get_tree().process_frame
			busy=false;holding=false;release=false
		var reply=await super.request(payload)
		if hold_loss and reply.get("connection_lost",false):
			hold_loss=false;loss_held=true
			while not release_loss and not closing:await get_tree().process_frame
			loss_held=false;release_loss=false
		return reply
var game
var probe
var fixture={}
var checks=[]
var owned=[]
var evidence=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(ok: bool,detail: String):
	checks.append({"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+"D03 "+detail)
func settle():
	for i in range(8):await process_frame
	var deadline=Time.get_ticks_msec()+12000
	while (game.locked or game.engine.busy or game.presenting) and Time.get_ticks_msec()<deadline:await process_frame
func held(loss:=false):
	var deadline=Time.get_ticks_msec()+5000
	while not (probe.loss_held if loss else probe.holding) and Time.get_ticks_msec()<deadline:await process_frame
	check(probe.loss_held if loss else probe.holding,"owned request reached the requested hold point")
func mode(value: String):
	var f=FileAccess.open(evidence.path_join("fault-mode.txt"),FileAccess.WRITE);f.store_string(value);f.close()
func visible_notice(node: Node)->bool:
	if node is Label and node.is_visible_in_tree() and node.text.contains("ゲーム接続が終了しました"):return true
	for child in node.get_children():
		if visible_notice(child):return true
	return false
func snapshot():return (await probe.request({"op":"campaign_save"})).data
func prepare(reference:=true):
	await game.update({"op":"campaign_load","data":fixture});await settle()
	game.choose_command("move" if reference else "attack")
	if reference:
		await game.on_cell(int(game.data.choices.move[0]));await settle();game.hud.open_range_reference();await settle()
func start_request(reference: bool,which: String):
	if reference:game.hud.request_reference(which)
	else:
		var target=game.data.choices.attack[0];game.on_cell(int(game.hud.unit(target).pos))
func wire_case(reference: bool,which: String,exit_mode: String,fault: String):
	await prepare(reference);var epoch=game.pages.epoch;var connection=probe.connection_generation
	probe.hold_next=true;probe.timeout_ms=400;start_request(reference,which);await held()
	match exit_mode:
		"close":game.hud.close_reference() if reference else game.cancel()
		"reopen":
			if reference:game.hud.close_reference();game.hud.open_range_reference()
			else:game.cancel();game.choose_command("move")
	var count=probe.calls.size();mode(fault);var pid=int(probe.handles.pid);probe.release=true;await settle();mode("")
	var label=("reference/"+which if reference else "normal-preview")+"/"+exit_mode+"/"+fault
	check(probe.disconnected and not OS.is_process_running(pid),label+" actual EOF/timeout closes only its owned Node")
	check(game.retry_button.visible and not game.retry_button.disabled and not game.notice.is_empty() and visible_notice(game),label+" exposes a visible explanation and enabled reconnect button")
	check(game.pending==null and game.preview.is_empty() and not game.preview_pending and not game.hud.range_reference and game.pages.epoch>epoch and not game.can_commit(),label+" invalidates abandoned/current decision context and prevents execution")
	check(probe.calls.size()==count,label+" never resends preview or any action automatically")
	# A failed baseline may not expose the button; reconnect directly only to finish all cases.
	if game.retry_button.visible and not game.retry_button.disabled:
		game.retry_button.pressed.emit()
		for i in range(2):await process_frame
		for child in game.get_children():
			if child is ConfirmationDialog and child.visible:child.confirmed.emit();break
	else:game.reconnect_engine()
	await settle();if not probe.handles.is_empty():owned.append(int(probe.handles.pid))
	probe.timeout_ms=15000
	check(not probe.disconnected and probe.connection_generation>connection and not game.retry_button.visible and game.notice.is_empty(),label+" reconnect establishes a new usable connection")
func stale_connection_case(reference: bool,fault: String):
	await prepare(reference);var old_generation=probe.connection_generation;var old_pid=int(probe.handles.pid)
	probe.hold_loss=true;probe.timeout_ms=400;mode(fault);start_request(reference,"skill");await held(true);mode("")
	check(probe.disconnected and not OS.is_process_running(old_pid),"late old-connection case has already lost its real Node")
	await game.reconnect_engine();await settle();if not probe.handles.is_empty():owned.append(int(probe.handles.pid))
	probe.timeout_ms=15000
	await prepare(true);var pending=game.pending;var preview=game.preview.duplicate(true);var epoch=game.pages.epoch;var before=await snapshot()
	probe.release_loss=true;await settle()
	check(probe.connection_generation>old_generation and not probe.disconnected and game.notice.is_empty() and not game.retry_button.visible and game.pending==pending and game.preview==preview and game.hud.range_reference and game.pages.epoch==epoch,"late "+fault+" from old "+("reference" if reference else "normal preview")+" cannot invalidate a new connection or its decision")
	check(await snapshot()==before,"discarding the old connection notification leaves the new canonical campaign unchanged")
	game.hud.close_reference();await settle()
func run():
	if evidence.is_empty():evidence=ProjectSettings.globalize_path("user://reference-disconnect")
	DirAccess.make_dir_recursive_absolute(evidence.path_join("reports"));OS.set_environment("REFERENCE_WIRE_EVIDENCE",evidence);mode("");root.size=Vector2i(800,600)
	var output=[];var node=OS.get_environment("NATIVE5525_NODE");if node.is_empty():node="node"
	var code=OS.execute(node,PackedStringArray([ProjectSettings.globalize_path("res://tests/parity_fix_fixtures.cjs")]),output,false,false);var fixtures=JSON.parse_string("".join(output))
	if code!=0 or not fixtures is Dictionary:quit(2);return
	fixture=fixtures.attack;game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();game.engine.close_engine();game.engine.queue_free()
	probe=LossProbe.new();game.add_child(probe);game.engine=probe;probe.node_script=ProjectSettings.globalize_path("res://tests/reference_disconnect_rules.cjs");probe.start_engine();owned.append(int(probe.handles.pid));await game.new_game();await settle()
	for which in ["attack","skill"]:
		for exit_mode in ["open","close","reopen"]:
			for fault in ["eof","timeout"]:await wire_case(true,which,exit_mode,fault)
	for exit_mode in ["open","close","reopen"]:
		for fault in ["eof","timeout"]:await wire_case(false,"attack",exit_mode,fault)
	for reference in [true,false]:
		for fault in ["eof","timeout"]:await stale_connection_case(reference,fault)
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(8):await process_frame
	check(owned.all(func(pid):return not OS.is_process_running(pid)),"all owned test Node processes exited")
	var failures=checks.filter(func(c):return not c.passed);var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"gui":false,"transport":"Real Node canonical preview then EOF or timeout; old connection responses held across actual reconnect","reference_cases":12,"normal_preview_cases":6,"obsolete_connection_cases":4}
	var f=FileAccess.open(evidence.path_join("reports/reference-disconnect.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ",true,true));f.close();print("REFERENCE DISCONNECT ",checks.size()," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
