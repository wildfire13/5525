extends "res://tests/npc_meeting_regression.gd"
## Actual Control bounds and Godot input dispatch, using only synthetic saves.
## These assertions do not substitute for rendered/Windows visual inspection.
func click_at(point: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion);await process_frame
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
func hub_bounds(context: String):
	var hub=node("TownHub");var meeting=node("HubMeetingPanel")
	check(hub is Control and meeting is PanelContainer,context+" hub and meeting panel exist")
	if not hub is Control or not meeting is PanelContainer:return
	var bounds: Rect2=meeting.get_global_rect()
	check(contained(meeting),context+" meeting panel fits viewport")
	for child in hub.get_children():
		if not child is Button:continue
		var rect: Rect2=child.get_global_rect()
		print("RECT ",context," ",child.name," ",rect," meeting ",bounds)
		check(contained(child),context+" "+child.name+" fits viewport")
		check(not bounds.intersects(rect),context+" "+child.name+" avoids meeting panel")
		check(bounds.position.x-rect.end.x>=15.5,context+" "+child.name+" retains 16px side gap")
		for other in hub.get_children():
			if other is Button and other.get_index()>child.get_index():check(not rect.intersects(other.get_global_rect()),context+" "+child.name+" avoids "+other.name)
func run():
	create_timer(180).timeout.connect(func():print("FAIL town meeting layout watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();await install(seed,"east",0,"board")
	var porter=game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id==uid and c.job=="porter"))[0]
	await game.act("accept",["standalone-wheel",porter]);await settle();var wheel=await saved()
	var missing=wheel.duplicate(true);missing.state.selected.erase(missing.state.activeQuest.cargoOwnerId)
	for sample in [[wheel,"astaris",18],[wheel,"astaris",9],[wheel,"astaris",10],[missing,"astaris",10],[wheel,"south",15],[wheel,"south",37],[wheel,"east",0],[wheel,"west",0],[wheel,"north",0]]:
		await install(sample[0],sample[1],sample[2]);var context="%s %s %dh" % [root.size,sample[1],sample[2]]
		var before=await bytes();hub_bounds(context)
		await press("HubScheduleToggle");hub_bounds(context+" schedule open")
		await press("HubScheduleToggle");check(await bytes()==before,context+" layout and schedule preserve save bytes")
	# Check both facility buttons at the left, middle, and right hit targets.
	for sample in [["astaris",18,"HubFacility_inn","inn"],["south",15,"HubFacility_board","board"]]:
		for fraction in [.1,.5,.9]:
			await install(wheel,sample[0],sample[1]);var before=await bytes();var button=node(sample[2]);var rect: Rect2=button.get_global_rect()
			await click_at(rect.position+Vector2(rect.size.x*fraction,rect.size.y*.5))
			check(game.page==sample[3],"%s %s click %.1f navigates" % [root.size,sample[2],fraction])
			check(await bytes()==before,"facility navigation preserves campaign save bytes")
	# No-quest hubs keep the adopted artwork-relative positions.
	await install(seed,"astaris",0);check(node("HubMeetingPanel")==null,"no meeting panel without active wheel")
	var hub=node("TownHub")
	for pair in [["HubFacility_guild",.18],["HubFacility_board",.58],["HubFacility_inn",.64],["HubMap",.12]]:
		check(absf(node(pair[0]).position.x-hub.size.x*pair[1])<1,"no-quest original anchor retained: "+pair[0])
	print("Town meeting layout regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
