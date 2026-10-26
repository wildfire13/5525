extends "res://tests/deployment_drag_regression.gd"
## Actual X11/XTest drag/drop, not signal simulation. Canonical seven-member fixture.
var request_id=0
var legacy_dispatches=[]
var observed_native_drag := false
func assignment_requests() -> int:
	var path=OS.get_environment("DEPLOYMENT_REQUEST_LOG")
	if path.is_empty() or not FileAccess.file_exists(path):return 0
	return FileAccess.get_file_as_string(path).strip_edges().split("\n").size()
func request(payload: Dictionary):
	request_id+=1;payload.id=request_id
	var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE);f.store_string(JSON.stringify(payload));f.close()
	var until=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<until:
		if FileAccess.file_exists(evidence.path_join("response.json")):
			var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
			if response is Dictionary and response.get("id")==request_id:break
		await process_frame
	check(Time.get_ticks_msec()<until,"real OS request "+str(payload.action));await settle()
func drag_os(from: Vector2,to: Vector2,cancelled:=false):
	observed_native_drag=false
	await request({"action":"drag_cancel" if cancelled else "drag","x":from.x,"y":from.y,"end_x":to.x,"end_y":to.y})
	check(observed_native_drag,"mouse movement engaged Godot native drag state")
func member_point(uid: String) -> Vector2:return game.board.global_position+game.board.project_cell(int(ally(uid).pos))
func cell_point(cell: int) -> Vector2:return game.board.global_position+game.board.project_cell(cell)
func screen(control: Control) -> Vector2:return control.get_global_rect().get_center()+Vector2(control.get_window().position)
func shot(label: String):
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(evidence.path_join(label+".png"));check(true,"captured rendered "+label)
func neutral_free() -> Vector2:
	var blockers=[game.hud.left_panel,game.hud.right_panel,game.hud.deployment_bar,game.hud.deployment_actions,game.deployment_party_strip,node("CommonMenuButton")]
	for y in range(80,int(root.size.y)-120,20):
		for x in range(int(root.size.x*.35),int(root.size.x*.65),20):
			var at=Vector2(x,y)
			if game.board.cell_at(at)<0 and not blockers.any(func(c):return is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(at)):return at
	return Vector2(-1,-1)
func native_resize(dims: Vector2i):
	await request({"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y});check(root.size==dims,"OS parent resize "+str(dims));await frames(10)
func unchanged_drag(from: Vector2,to: Vector2,label: String,cancelled:=false):
	var before=await saved();var count=drops.size();await drag_os(from,to,cancelled)
	check(await saved()==before and drops.size()==count,label+" leaves full save and dispatch count unchanged")
func run():
	create_timer(240).timeout.connect(func():print("FAIL deployment GUI watchdog");quit(2))
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	check(DisplayServer.get_name()!="headless","real X11 display")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	check((await game.update({"op":"campaign_load","data":fixtures()})).get("ok",false),"canonical fixture restored")
	await settle();var original=await saved()
	game.board.deployment_assigned.connect(func(uid,pos):drops.append([uid,pos]));game.board.deploy_drag.connect(func(uid,pos):legacy_dispatches.append([uid,pos]))
	process_frame.connect(func():if root.gui_is_dragging():observed_native_drag=true)
	layout("FHD actual");await shot("deployment-FHD-before")
	var count=drops.size();await drag_os(member_point("guard"),cell_point(2))
	check(ally("guard").pos==2 and drops.size()==count+1,"OS board drag moves one member exactly once")
	var archer_pos=int(ally("archer").pos);count=drops.size();await drag_os(member_point("guard"),cell_point(archer_pos))
	check(ally("guard").pos==archer_pos and ally("archer").pos==2 and drops.size()==count+1,"OS occupied-ally drag swaps exactly once")
	await unchanged_drag(member_point("guard"),cell_point(1),"ESC native cancel",true)
	await unchanged_drag(member_point("guard"),cell_point(25),"enemy side rejected")
	await native_resize(Vector2i(1180,812));layout("1180 actual");await shot("deployment-1180")
	await unchanged_drag(member_point("guard"),Vector2(1500,950),"release outside game window rejected")
	await native_resize(Vector2i(1920,1080));var neutral=neutral_free();check(neutral.x>=0,"explicit neutral in-window board area is available")
	count=drops.size();await drag_os(member_point("guard"),neutral)
	check(ally("guard").is_empty() and drops.size()==count+1,"OS neutral-area drop removes member once")
	count=drops.size();await drag_os(screen(node("PartyFace_guard-2")),cell_point(1))
	check(not ally("guard-2").is_empty() and drops.size()==count+1 and Drag.deployed(game).size()==5,"OS reserve card upward drag enters empty ally cell")
	count=drops.size();await drag_os(screen(node("PartyFace_mage-2")),member_point("archer"))
	check(ally("archer").is_empty() and not ally("mage-2").is_empty() and drops.size()==count+1 and Drag.deployed(game).size()==5,"OS reserve card replaces occupied ally even when full")
	count=drops.size();var requests_before=assignment_requests();await drag_os(member_point("guard-2"),screen(game.deployment_party_strip))
	check(ally("guard-2").is_empty() and drops.size()==count and assignment_requests()==requests_before+1,"OS board-to-partybar sends one canonical request and returns member without legacy board signal")
	await unchanged_drag(member_point("mage-2"),screen(node("DeploymentBegin")),"UI button drop cancels without starting battle")
	count=drops.size();await drag_os(member_point("porter"),neutral_free())
	check(ally("porter").is_empty() and drops.size()==count+1,"OS preparation may return porter to reserve after accepting journey")
	check(not is_instance_valid(game.dialog.window) or not game.dialog.window.visible,"native D&D does not accidentally open member status")
	check(legacy_dispatches.is_empty(),"old manual release signal never duplicates native D&D")
	var final=await saved();check(final.state.gold==original.state.gold and final.state.characters==original.state.characters and final.state.battle.actions==0,"OS D&D preserves inventory economy character HP and battle action count")
	await native_resize(Vector2i(960,540));layout("960 actual");await shot("deployment-960")
	await unchanged_drag(member_point("scout"),cell_point(33),"960 narrow ESC native cancel",true)
	await native_resize(Vector2i(1920,1080));await shot("deployment-FHD-after")
	var right_handle=screen(game.hud.right_panel.find_child("DragHandle",true,false))
	await request({"action":"drag","x":right_handle.x,"y":right_handle.y,"end_x":right_handle.x+1000,"end_y":right_handle.y})
	var handle=game.hud.left_panel.find_child("DragHandle",true,false);var old_panel=game.hud.left_panel.global_position;var handle_at=screen(handle)
	await request({"action":"drag","x":handle_at.x,"y":handle_at.y,"end_x":handle_at.x+400,"end_y":handle_at.y})
	check(game.hud.left_panel.global_position.x>old_panel.x+300,"OS floating information panel can move to reveal edge cells")
	count=drops.size();await drag_os(member_point("scout"),cell_point(0))
	check(ally("scout").pos==0 and drops.size()==count+1,"OS formerly covered ally edge cell accepts drop after panel drag")
	await shot("deployment-panel-moved-edge-cell")
	await request({"action":"click","x":screen(node("DeploymentBegin")).x,"y":screen(node("DeploymentBegin")).y})
	check(game.campaign().phase=="battle" and node("BattleDetails")!=null and node("BattleDetails").is_visible_in_tree(),"central OS start works without porter and battle details remain available")
	await shot("battle-details-returned")
	check(game.audio.muted.values().all(func(v):return v),"BGM voice SE OFF")
	for spec in [["checks.json",checks],["layout.json",layouts],["dispatch.json",drops]]:
		var f=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
