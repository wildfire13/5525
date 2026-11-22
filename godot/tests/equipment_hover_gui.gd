extends "res://tests/research2_gui.gd"

func os_resize(dims: Vector2i):
	request_id+=1
	var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"id":request_id,"action":"resize_window","window":DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),"width":dims.x,"height":dims.y}));f.close()
	var deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if FileAccess.file_exists(evidence.path_join("response.json")):
			var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
			if response is Dictionary and response.get("id")==request_id:break
		await process_frame
	await create_timer(.4).timeout;await settle()
	check(root.size==dims,"X11 native resize delivered "+str(dims))

func screen_rect(c: Control) -> Rect2:return Rect2(c.get_global_rect().position+Vector2(c.get_window().position),c.size)

func run():
	create_timer(90).timeout.connect(func():quit(2))
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1280,800)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east"
	await game.update({"op":"campaign_load","data":seed})
	await game.act("depart",["astaris","convoy"]);await game.act("travel",["safe"])
	await game.hud.open_equipment_sheet("character_mirei");await settle()
	var before=await saved()
	for dims in [Vector2i(1280,800),Vector2i(1180,812),Vector2i(1920,1080)]:
		await os_resize(dims)
		var source=node("BattleSlot_upperBody")
		await os_mouse(screen_rect(source).get_center());await create_timer(.65).timeout
		var popup=source.hover_window
		check(is_instance_valid(popup) and popup.visible and popup.body.text.contains("Wt"),"OS pointer opens the compact equipment hover "+str(dims))
		await snapshot("F4-compact-"+str(dims.x))
		await os_mouse(Vector2(root.size)-Vector2(4,4));await frames()
		check(not is_instance_valid(popup) or not popup.visible,"OS pointer leave closes hover "+str(dims))
		check(await saved()==before,"hover and resize do not change the save "+str(dims))
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
