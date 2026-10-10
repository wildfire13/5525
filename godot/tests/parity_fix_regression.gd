extends SceneTree
var game
var checks=[]
var failures=[]
var phases=[]
var captures=[]
var visual=false
var folder=OS.get_temp_dir().path_join("5525-parity-"+str(Time.get_ticks_usec()))
var output=ProjectSettings.globalize_path("res://qa/visual/parity-fix")
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"name":label,"passed":ok})
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(5):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func capture(name: String):
	if not visual:return
	await RenderingServer.frame_post_draw
	var path=output.path_join(name+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name);captures.append(path)
func snapshot():return (await game.engine.request({"op":"campaign_save"})).data
func restore(save: Dictionary):
	await game.update({"op":"campaign_load","data":save});await settle()
func dialog():return game.find_child("OverwriteConfirmation",false,false)
func respond(yes: bool):
	var d=dialog();check(d!=null,"overwrite confirmation exists")
	if d!=null:
		if yes:d.confirmed.emit()
		else:d.canceled.emit()
	await settle()
func labels_starting(text: String) -> Array:
	return game.find_children("*","Label",true,false).filter(func(l):return l.text.begins_with(text))
func observe(label: String,kind: String,target):
	game.checks_fast=false
	var observed=[]
	await capture(label+"-before")
	game.update({"op":"act","kind":kind,"target":target,"presentation":true})
	var deadline=Time.get_ticks_msec()+30000
	while (game.locked or game.presenting) and Time.get_ticks_msec()<deadline:
		var p=game.data.get("presentation")
		if p is Dictionary:
			var key=str(p.id)+":"+str(p.index)
			if observed.is_empty() or observed[-1].key!=key:
				observed.append({"key":key,"phase":p.phase,"actor":p.actor_id,"unit":p.unit_id,"action":p.action_id,"from":p.get("from"),"to":p.get("to"),"moved":[]})
			for id in game.board.actors:
				if game.board.actors[id].sprite.position.distance_to(Vector3(0,.75,0))>.002:
					if not observed[-1].moved.has(id):observed[-1].moved.append(id)
			if visual and not observed[-1].has("captured") and game.board.actors[p.unit_id].sprite.position.distance_to(Vector3(0,.75,0))>.06 and observed.size()<=(3 if label=="split" else 2):
				observed[-1].captured=true;await capture(label+"-"+str(observed.size())+"-"+str(p.phase))
		await process_frame
	check(not game.locked and not game.presenting,label+" finishes acknowledged sequence")
	check(observed.size()>=3 and observed[0].phase=="action",label+" begins with acting portrait")
	for p in observed:
		if p.phase in ["action","hurt"]:
			check(p.moved==[p.unit],label+" "+p.key+" shakes only "+str(p.unit))
			if p.phase=="hurt":check(p.from>p.to,label+" hurt is actual HP loss")
		else:check(p.moved.is_empty(),label+" "+p.phase+" has no damage shake")
	var actions=observed.filter(func(p):return p.phase=="action")
	check(actions.size()>=2 and actions[0].actor!=actions[1].actor,label+" next actor follows prior impacts")
	var first=observed.filter(func(p):return p.action==actions[0].action)
	if label=="split":check(first.filter(func(p):return p.phase=="hurt").size()==2,"split skill shakes two actual recipients sequentially")
	if label=="heal":check(first.any(func(p):return p.phase=="heal") and not first.any(func(p):return p.phase=="hurt"),"healing target never receives damage shake")
	check(game.board.actors.values().all(func(n):return n.sprite.position==Vector3(0,.75,0)),label+" portraits reset after last phase")
	phases.append({"case":label,"frames":observed})
	game.checks_fast=true
func run():
	visual=OS.get_cmdline_user_args().has("--visual")
	DirAccess.make_dir_recursive_absolute(folder);DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800);root.title="5525 parity repair QA (isolated)"
	var result=[];var node=OS.get_environment("NATIVE5525_NODE")
	if node.is_empty():node="node"
	var code=OS.execute(node,PackedStringArray([ProjectSettings.globalize_path("res://tests/parity_fix_fixtures.cjs")]),result,false,false)
	var fixture=JSON.parse_string("".join(result))
	if code!=0 or not fixture is Dictionary:check(false,"fixture creation");quit(1);return
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	await restore(fixture.low)
	var low=game.board.actors.guard.label;var boundary=game.board.actors.archer.label
	check(low.font is FontVariation and low.font.variation_embolden>0 and low.modulate==Color("#ff9494"),"44/180 board portrait HP is red bold")
	check(not boundary.font is FontVariation and boundary.modulate!=Color("#ff9494"),"25/100 board HP stays normal")
	var current=game.header
	check(current.has_theme_font_override("font") and current.get_theme_color("font_color")==Color("#ff9494"),"current actor low HP is red bold")
	game.hud.toggle_details();await settle()
	var detail=labels_starting("ガロ: HP")[0]
	check(detail.has_theme_font_override("font") and detail.get_theme_color("font_color")==Color("#ff9494"),"sidebar low HP is red bold")
	check(not labels_starting("リノ: HP")[0].has_theme_font_override("font"),"sidebar exact 25 percent remains normal")
	await capture("low-hp-red-bold")
	game.dialog.body.get_parent().ensure_control_visible(detail);await settle();await capture("low-hp-sidebar")
	game.dialog.close();await settle()
	var exact=fixture.low.duplicate(true);exact.state.battle.units.filter(func(u):return u.id=="guard")[0].hp=45
	await restore(exact)
	check(not game.board.actors.guard.label.font is FontVariation,"45/180 restores normal board weight")
	current=game.header
	check(not current.has_theme_font_override("font"),"45/180 restores normal actor weight")
	for camera in range(3):
		game.board.set_camera(camera);await settle()
		check(game.board.cell_at(game.board.project_cell(24))==24,"font change retains camera "+str(camera)+" projection")
	for case in ["attack","split","heal"]:
		await restore(fixture[case])
		var target=game.data.choices.skill[0] if case=="split" else "guard" if case=="heal" else game.state().units.filter(func(u):return u.side=="enemy")[0].id
		await observe(case,"attack" if case=="attack" else "skill",target)
	# Exercise the actual save-dialog callback for first creation and repeat saves.
	await game.new_game();var original=await snapshot()
	var path=folder.path_join("progress.json")
	await game.save_game();await settle()
	var chooser=game.get_children().filter(func(n):return n is FileDialog)[0]
	check(not chooser.overwrite_warning_enabled,"single application overwrite confirmation")
	chooser.file_selected.emit(path);await settle()
	check(FileAccess.file_exists(path),"save dialog creates new test save")
	var saved_bytes=FileAccess.get_file_as_bytes(path)
	var changed=original.duplicate(true);changed.state.gold=99
	await restore(changed)
	await game.save_game();await settle()
	chooser=game.get_children().filter(func(n):return n is FileDialog)[0];chooser.file_selected.emit(path);await settle()
	check(dialog()!=null and FileAccess.get_file_as_bytes(path)==saved_bytes,"second save asks before replacing any bytes")
	check(dialog()!=null and dialog().get_cancel_button().has_focus(),"overwrite defaults focus to cancellation")
	await capture("overwrite-confirmation")
	await respond(false)
	check(FileAccess.get_file_as_bytes(path)==saved_bytes,"cancel retains original save bytes")
	await game.save_game();await settle()
	chooser=game.get_children().filter(func(n):return n is FileDialog)[0];chooser.file_selected.emit(path);await settle()
	await respond(true)
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).state.gold==99,"confirmed same-name save atomically replaces snapshot")
	await game.new_game();await game.load_game(path)
	check(game.campaign().gold==99,"replaced save reloads through product adapter")
	await game.write_snapshot(path,original,"進行");await settle()
	var external=FileAccess.open(path,FileAccess.WRITE);external.store_string('{"external":true}');external.close()
	var external_bytes=FileAccess.get_file_as_bytes(path)
	await respond(true)
	check(FileAccess.get_file_as_bytes(path)==external_bytes and game.notice.contains("確認後"),"changed-during-confirmation file is retained")
	var log_path=folder.path_join("log.json")
	await game.write_snapshot(log_path,{"log":["old"]},"プレイログ")
	await game.write_snapshot(log_path,{"log":["new"]},"プレイログ");await settle();await respond(true)
	check(JSON.parse_string(FileAccess.get_file_as_string(log_path)).log==["new"],"confirmed log overwrite restored")
	# Kill a delayed helper before/after replacement; rule process and old data survive.
	var before=await snapshot();var node_pid=int(game.engine.handles.pid)
	game.engine.io_script=ProjectSettings.globalize_path("res://tests/fault_file_helper.py");game.engine.io_timeout_ms=600
	for mode in ["before_publish","after_publish"]:
		var old_bytes=FileAccess.get_file_as_bytes(log_path)
		var r=await game.engine.request({"op":"godot_io","action":"write","path":log_path,"data":{"mode":mode},"overwrite":true,"expected_sha256":FileAccess.get_sha256(log_path),"fault_mode":mode})
		if mode=="before_publish":check(not r.ok and FileAccess.get_file_as_bytes(log_path)==old_bytes,"overwrite timeout before replace retains old bytes")
		else:check(r.ok and r.data.get("recovered",false) and JSON.parse_string(FileAccess.get_file_as_string(log_path)).mode==mode,"lost reply after replace reconciles completed overwrite")
		check(OS.is_process_running(node_pid) and await snapshot()==before,"overwrite timeout preserves exact game state")
	check(Array(DirAccess.get_files_at(folder)).filter(func(n):return n.begins_with(".5525-save-")).is_empty(),"overwrite failure cleanup leaves no owned temp")
	check(game.engine.owned_io_pids.all(func(pid):return not OS.is_process_running(pid)),"overwrite helpers are reaped")
	game.engine.io_script="";await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(5):await process_frame
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"phases":phases,"captures":captures,"test_files":folder,"visual":visual,"input":"Godot callbacks and viewport rendering; no personal saves"}
	var f=FileAccess.open(output.path_join("visual-report.json" if visual else "headless-report.json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("PARITY FIX CHECKS "+str(checks.size())+" FAILURES "+str(failures.size()))
	quit(0 if failures.is_empty() else 1)
