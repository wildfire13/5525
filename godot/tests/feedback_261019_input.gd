extends "res://tests/feedback_261019_skills.gd"
var mask=0
func send(point: Vector2,button:=0,pressed:=false,delta:=Vector2.ZERO):
	var event
	if button==0:event=InputEventMouseMotion.new();event.relative=delta
	else:event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
	if button>0:
		if pressed:mask|=1<<(button-1)
		else:mask&=~(1<<(button-1))
	event.button_mask=mask;event.position=point;event.global_position=point;root.push_input(event,true);await frames(2)
func drag(panel,delta: Vector2,label: String):
	var header=panel.find_child("DragHandle",true,false);var point=header.get_global_rect().get_center();var start=panel.position
	await send(point)
	var hovered=root.gui_get_hovered_control();print("HIT ",label," ",hovered.get_path() if hovered!=null else "null"," panel=",panel.get_global_rect()," visible=",panel.is_visible_in_tree())
	await send(point,MOUSE_BUTTON_LEFT,true);print("PRESSED dragging=",panel.dragging," moving=",panel.moving)
	await send(point+delta,0,false,delta);await send(point+delta,MOUSE_BUTTON_LEFT,false)
	check(panel.position!=start,label)
func run():
	create_timer(100).timeout.connect(func():print("FAIL drag review watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=false
	var cases=source_cases()
	for id in ["town","sweep100"]:
		var f=FileAccess.open(evidence.path_join(id+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(cases[id]));f.close()
	for resolution in [Vector2i(1920,1080)]:
		root.size=resolution;await settle()
		for cycle in range(2):
			await game.load_game(evidence.path_join("town.json"));await settle()
			await game.load_game(evidence.path_join("sweep100.json"));await settle();await create_timer(.4).timeout
			var before=await saved();var camera=game.preferences.camera().duplicate(true)
			for panel in [game.hud.left_panel,game.hud.right_panel]:
				if cycle==1:check(panel.global_position.y==0,"top position survives town and reload "+str(resolution)+str(panel.name))
				await drag(panel,Vector2(-20,30),"normal header "+str(resolution)+str(cycle)+str(panel.name))
				await drag(panel,Vector2(0,-1000),"to top "+str(panel.name))
				await drag(panel,Vector2(-20,30),"from top "+str(panel.name))
				await drag(panel,Vector2(0,-1000),"save at top "+str(panel.name))
			check(await saved()==before and game.preferences.camera()==camera,"dragging leaves game and camera unchanged")
		var left=game.hud.left_panel;var right=game.hud.right_panel
		left.global_position=Vector2(200,200);right.global_position=Vector2(350,200);await frames()
		# Click an exposed header; compare GUI input target with visible front window.
		for panel in [left,right]:
			var point=panel.global_position+Vector2(25 if panel==left else panel.size.x-25,25)
			await send(point);await send(point,MOUSE_BUTTON_LEFT,true);await send(point,MOUSE_BUTTON_LEFT,false)
			await send(Vector2(420,225));var hit=root.gui_get_hovered_control()
			check(hit!=null and (hit==panel or panel.is_ancestor_of(hit)) and panel.get_index()>((right if panel==left else left).get_index()),"clicked panel owns foreground drawing and input "+str(panel.name))
		left.global_position=Vector2(20,68);await frames();await drag(left,Vector2(20,30),"header overlaps toolbar")
		left.global_position=Vector2(20,0);await frames();await drag(left,Vector2(20,30),"header overlaps root top")
		# Observe the normal-speed opening from its first frame, not just a final rectangle.
		game.hud.clear_opening_visual();left.show();game.hud.open_actor_panel()
		while not is_instance_valid(game.hud.opening_visual):await process_frame
		var ghost=game.hud.opening_visual;var first=node("TurnCard_0")
		check(ghost.global_position.distance_to(first.global_position)<3 and ghost.z_index<game.battle_header.z_index,"opening begins behind current first card")
		check(ghost.mouse_filter==Control.MOUSE_FILTER_IGNORE and ghost.find_children("*","Control",true,false).all(func(c):return c.mouse_filter==Control.MOUSE_FILTER_IGNORE),"opening copy and all descendants ignore input")
		await create_timer(.12).timeout
		check(is_instance_valid(ghost) and ghost.global_position.distance_to(first.global_position)>3,"opening moves toward saved command window at normal speed")
		await create_timer(.3).timeout
		check(left.visible and not is_instance_valid(game.hud.opening_visual),"opening finishes and restores interactive window")
	var f=FileAccess.open(evidence.path_join("input-review.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
