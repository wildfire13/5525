extends "res://tests/facility_gui_261022.gd"
func run():
	create_timer(120).timeout.connect(func():print("FAIL extra GUI watchdog");quit(2))
	check(DisplayServer.get_name()!="headless","extra real GUI renderer active")
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true;await settle()
	game.navigate("party");await settle();var art=game.pages.facility_art;var rng_state=art.rng.state;var artwork=art.artwork.duplicate()
	game.pages.party_view.open_detail("guard");await settle()
	for tab in [1,2,0]:
		await os_click(node("StatusTab_"+str(tab)))
		check(game.pages.party_view.detail_tab==tab and art.rng.state==rng_state and art.artwork==artwork,"OS status tab holds visit artwork "+str(tab))
	game.dialog.close();await settle();check(art.rng.state==rng_state and art.artwork==artwork,"status close holds visit artwork")
	# Archer at cell24 has an enemy at25; the guard fixture intentionally
	# has no in-range attack target and is for inventory/hover checks.
	await game.update({"op":"campaign_load","data":battle_fixture().archer});await settle();await game.choose_command("attack");await settle()
	var before=await saved();var target=str(game.data.choices.attack[0]);var target_cell=-1
	for u in game.state().units:
		if u.id==target:target_cell=int(u.pos)
	check(target_cell>=0,"valid real attack target")
	game.hud.left_panel.hide();game.hud.right_panel.hide()
	await os_mouse(game.board.project_cell(target_cell),"click")
	check(game.pending==target and game.hud.selected_cell==target_cell and game.preview_ready,"OS click selects real target and loads preview")
	await snapshot("real_attack_selection")
	var empty=-1
	for p in range(50):
		if game.board.unit_at(p).is_empty():empty=p;break
	game.hud.left_panel.hide();game.hud.right_panel.hide()
	await os_mouse(game.board.project_cell(empty))
	check(game.pending==target and game.board.hover_uid.is_empty() and not game.hud.person_box.has_meta("inspected_unit"),"OS empty hover clears inspection and retains real target")
	game.cancel();await settle();game.hud.left_panel.hide();game.hud.right_panel.hide()
	var yaw=game.board.camera_yaw;var pitch=game.board.camera_pitch
	await os_mouse(Vector2(600,400),"camera_drag",Vector2(650,425))
	check(game.board.camera_yaw!=yaw and game.board.camera_pitch!=pitch,"OS middle drag rotates camera")
	await os_mouse(game.board.project_cell(target_cell))
	check(game.board.hover_uid==target and game.hud.person_box.get_meta("inspected_unit","")==target,"OS hover after camera rotation uses projected floor")
	game.hud.left_panel.show();game.hud.right_panel.show();await snapshot("real_camera_hover")
	check(await saved()==before,"real selection cancellation and camera controls preserve save and progress RNG")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
