extends "res://tests/npc_meeting_regression.gd"
## Actual Control bounds and Godot input dispatch, using only synthetic saves.
## These assertions do not substitute for rendered/Windows visual inspection.
const Grid=preload("res://screen_grid.gd")
func click_at(point: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await process_frame
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;root.push_input(event,true);await process_frame
	await settle()
func click_control(control: Control):
	var point=control.get_global_rect().get_center()
	if control.get_window()!=root:point+=Vector2(control.get_window().position)
	await click_at(point)
func shot(label: String):
	if DisplayServer.get_name()=="headless" or OS.get_environment("UIUX_REVIEW_EVIDENCE").is_empty():return
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image.get_size()==Vector2i(1920,1080),label+" rendered at FHD")
	image.save_png(OS.get_environment("UIUX_REVIEW_EVIDENCE").path_join(label+".png"))
func hub_bounds(context: String):
	var hub=node("TownHub");var meeting=node("HubMeetingPanel")
	check(hub is Control and meeting is PanelContainer,context+" hub and meeting panel exist")
	if not hub is Control or not meeting is PanelContainer:return
	var bounds: Rect2=meeting.get_global_rect()
	check(contained(meeting),context+" meeting panel fits viewport")
	check(bounds==Grid.cell_rect(Vector2(root.size),7,1,3,8),context+" meeting panel has four grid edges: "+str(bounds))
	for child in hub.get_children():
		if not child is Button:continue
		var rect: Rect2=child.get_global_rect()
		print("RECT ",context," ",child.name," ",rect," meeting ",bounds)
		check(contained(child),context+" "+child.name+" fits viewport")
		check(not bounds.intersects(rect),context+" "+child.name+" avoids meeting panel")
		for other in hub.get_children():
			if other is Button and other.get_index()>child.get_index():check(not rect.intersects(other.get_global_rect()),context+" "+child.name+" avoids "+other.name)
func run():
	create_timer(180).timeout.connect(func():print("FAIL town meeting layout watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();await install(seed,"east",0,"board")
	var porter=game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id==uid and c.job=="job_porter"))[0]
	await game.act("accept",["standalone-wheel",porter]);await settle();var wheel=await saved()
	var missing=wheel.duplicate(true);missing.state.selected.erase(missing.state.activeQuest.cargoOwnerId)
	for sample in [[wheel,"astaris",18],[wheel,"astaris",9],[wheel,"astaris",10],[missing,"astaris",10],[wheel,"south",15],[wheel,"south",37],[wheel,"east",0],[wheel,"west",0],[wheel,"north",0]]:
		await install(sample[0],sample[1],sample[2]);var context="%s %s %dh" % [root.size,sample[1],sample[2]]
		var before=await bytes();hub_bounds(context)
		var schedule=node("HubScheduleDetails")
		await click_control(node("HubScheduleToggle"));hub_bounds(context+" schedule open")
		check(schedule.is_visible_in_tree() and not node("QuestMerchantWindow").text.is_empty(),context+" schedule text shown")
		if sample[1]=="south" and sample[2]==15:await shot("merchant-schedule")
		await click_control(node("HubScheduleToggle"))
		check(not schedule.visible and await bytes()==before,context+" closing schedule preserves save bytes")
	await install(wheel,"south",15)
	var before_wait=await saved()
	await click_control(node("HubWaitForMerchant"))
	var wait=node("MerchantWaitConfirmation")
	check(wait is ConfirmationDialog,"arrival wait opens via pointer")
	if wait is ConfirmationDialog:
		var rect=Rect2(Vector2(wait.position)-game.preferences.window_origin(wait),Vector2(wait.size))
		check(rect==Grid.snap_rect(rect,Vector2(root.size)), "wait window has four grid edges: "+str(rect))
		check(node("ConfirmationText").text==wait.dialog_text and wait.dialog_text.contains("15 → 18") and wait.get_cancel_button().has_focus(),"wait shows full explanation and defaults to cancel")
		await shot("merchant-wait")
		await click_control(wait.get_cancel_button())
		check(await saved()==before_wait,"wait cancel leaves state unchanged")
		await click_control(node("HubWaitForMerchant"))
		wait=node("MerchantWaitConfirmation")
		if wait is ConfirmationDialog:await click_control(wait.get_ok_button())
		var after_wait=await saved()
		check(after_wait.state.worldTime==18 and after_wait.state.characters==before_wait.state.characters and after_wait.state.gold==before_wait.state.gold and node("HubDeliverCargo") is Button,"wait advances to arrival without recovery, reward or auto-delivery")
		if node("HubDeliverCargo") is Button:
			await click_control(node("HubDeliverCargo"))
			check(game.results_view.active and game.campaign().get("activeQuest")==null,"explicit handoff completes the current merchant meeting")
			await shot("merchant-delivery")
			var delivered=await bytes()
			await click_control(node("ResultStory"))
			dialogue_cast(["merchant"],"delivered wheel merchant story")
			await shot("merchant-dialogue")
			await escape()
			check(node("QuestDialogue")==null and game.results_view.active and await bytes()==delivered,"Escape closes the merchant story without acknowledging the delivery")
			game.results_view.reset();await settle()
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
	for pair in [["HubFacility_guild",.50],["HubFacility_board",.645],["HubFacility_inn",.885],["HubMap",.485]]:
		check(absf(node(pair[0]).position.x-hub.size.x*pair[1])<1,"no-quest original anchor retained: "+pair[0])
	print("Town meeting layout regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
