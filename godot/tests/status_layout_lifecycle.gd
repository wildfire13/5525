extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(75).timeout.connect(func():print("FAIL status lifecycle watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	game.preferences.store_rect("status",Rect2(100,80,800,600));game.preferences.config.set_value("migration","status_feedback3",false)
	game.pages.party_view.open_detail("guard");await settle()
	check(game.dialog.window.size==Vector2i(1760,600),"old800x600 migrates width only")
	game.preferences.store_camera({"pan":Vector2(1.5,-2),"yaw":.35,"pitch":.6,"zoom":14.0})
	var before=await saved();var camera=game.preferences.camera().duplicate(true)
	# Reproduce saving between tree reconstruction and Container's deferred sort.
	game.render()
	print("LAYOUT before remember: faces=",node("PartyFaceBar").get_global_rect()," status=",Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size)))
	game.dialog.remember()
	print("LAYOUT after remember: status=",Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))," stored=",game.preferences.config.get_value("windows","status"))
	check(game.dialog.window.size.y==600,"same-frame reconstruction cannot crush status height")
	game.dialog.close();await settle();game.pages.party_view.open_detail("guard");await settle()
	check(game.dialog.window.size.y==600,"close reopen after reconstruction preserves height")
	check(game.preferences.camera()==camera and await saved()==before,"layout operations preserve camera and full campaign")
	for resolution in [Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		for page in ["hub","board","inn","party","shop"]:
			game.dialog.close();game.navigate(page);await settle();game.pages.party_view.open_detail("guard");await settle()
			game.render();game.dialog.keep_visible();game.dialog.remember();game.dialog.close()
			check(game.preferences.config.get_value("windows","status").size.y==600,"same-frame close preserves600 "+page+str(resolution))
			game.pages.party_view.open_detail("guard");await settle()
			check(game.dialog.window.size.y==600,"page reopen preserves600 "+page+str(resolution))
			check(game.dialog.window.position.y+game.dialog.window.size.y<=node("PartyFaceBar").global_position.y-8 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))),"stable bounds keep status above portraits and onscreen "+page+str(resolution))
	game.dialog.close();var cases=battle_fixture()
	await game.update({"op":"campaign_load","data":cases.archer});await settle()
	game.hud.left_panel.position+=Vector2(25,20);game.hud.left_panel.persist();var battle_rect=game.preferences.config.get_value("windows","battle_actor")
	await game.update({"op":"campaign_load","data":before})
	# Open immediately after the load's render, before the newly built row sorts.
	game.pages.party_view.open_detail("guard");game.dialog.remember();await settle()
	check(game.dialog.window.size.y==600,"battle load panel move town load preserves600")
	check(game.preferences.config.get_value("windows","battle_actor")==battle_rect and game.preferences.camera()==camera,"status lifecycle leaves saved battle panel and camera intact")
	game.dialog.window.size=Vector2i(1100,662);game.render();game.dialog.close();game.pages.party_view.open_detail("guard");await settle()
	check(game.dialog.window.size==Vector2i(1100,662),"manual1100x662 survives immediate render close reopen")
	game.dialog.window.size=Vector2i(1100,300);game.dialog.close();await settle();game.pages.party_view.open_detail("guard");await settle()
	check(game.dialog.window.size.y==300,"intentional manual minimum height remains respected")
	game.dialog.window.size=Vector2i(1100,662);game.dialog.remember();game.dialog.window.position=Vector2i(1850,1000);game.dialog.keep_visible();await settle()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))) and game.dialog.window.position.y+game.dialog.window.size.y<=node("PartyFaceBar").global_position.y-8,"offscreen status is clamped above portraits at FHD")
	check(await saved()==before,"all page load and sizing checks preserve campaign")

	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
