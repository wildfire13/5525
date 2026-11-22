extends SceneTree
var failures: Array[String]=[]
var checks:=0
var game
const Grid=preload("res://screen_grid.gd")
func grid_area(area: String):
	var control=game.find_child(area,true,false)
	if not control is Control or not control.is_visible_in_tree():check(false,area+" visible");return
	var rect: Rect2=control.get_global_rect()
	check(Grid.snap_rect(rect,Vector2(root.size)).is_equal_approx(rect),area+" actual FHD rectangle "+str(rect))
func screenshot(label: String):
	var proof=OS.get_environment("UIUX_REVIEW_EVIDENCE")
	if not proof.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		check(image.get_size()==Vector2i(1920,1080) and image.save_png(proof.path_join(label+".png"))==OK,"rendered FHD evidence "+label)
func escape_dialogue():
	for down in [true,false]:
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=down
		Input.parse_input_event(event)
		await process_frame
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	create_timer(90).timeout.connect(func():quit(2))
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"campaign initializes");quit(1);return
	game.checks_fast=true;await process_frame;await process_frame
	var saved=await game.engine.request({"op":"campaign_save"})
	for town in ["west","astaris","south","east","north"]:
		var visit=saved.data.duplicate(true);visit.state.location=town
		await game.update({"op":"campaign_load","data":visit});game.navigate("board")
		for frame in range(8):await process_frame
		var choices=game.find_children("QuestChoice_*","Button",true,false)
		for i in range(mini(2,choices.size())):
			if i>0:choices[i].pressed.emit()
			for frame in range(4):await process_frame
			var art=game.find_child("QuestRequesterPortrait",true,false)
			var bounds=game.find_child("QuestRequester",true,false).get_global_rect()
			check(art.texture!=null and art.get_global_rect().is_equal_approx(bounds),town+" requester fills the stage on entry/selection "+str(i))
	var incoming=saved.data.duplicate(true);incoming.state.location="north"
	await game.update({"op":"campaign_load","data":incoming});await process_frame
	game.navigate("board");await process_frame;await process_frame
	check(game.campaign().board.any(func(q):return q.get("eventId")=="turnip"),"North board lists the time-limited turnip event")
	var quest_choice=game.find_child("QuestChoice_standalone-turnip",true,false)
	if quest_choice is Button:quest_choice.pressed.emit();await process_frame
	var story_button=game.find_child("QuestStory_standalone-turnip",true,false)
	check(story_button is Button,"story can be read separately from accepting cargo")
	if story_button==null:quit(1);return
	var requester=game.find_child("QuestRequesterPortrait",true,false);var home=requester.global_position
	story_button.pressed.emit();await create_timer(.35).timeout
	var scene=game.find_child("QuestDialogue",true,false)
	check(scene!=null,"dialogue overlay opens on top of the existing town scene")
	if scene==null:quit(1);return
	var left=scene.find_child("QuestPortrait",true,false);var right=scene.find_child("QuestPortraitRight",true,false)
	check(left==null and right is TextureRect and not right.visible and requester.is_visible_in_tree() and requester.global_position.x<home.x-200,"request scene contains only the farmer, not the recipient")
	check(requester.texture!=null and requester.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and right.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"portrait source proportions are preserved")
	check(requester.modulate.r==1.0 and scene.find_child("QuestSpeaker",true,false).text=="農夫","requester is bright; name tab remains in place")
	check(root.size==Vector2i(1920,1080),"dialogue layout measured at FHD 1920×1080")
	var panel=scene.find_child("QuestDialoguePanel",true,false)
	check(panel.position.x>=0 and panel.position.y>=0 and panel.position.x+panel.size.x<=1920 and panel.position.y+panel.size.y<=1080,"black dialogue panel remains inside the FHD viewport")
	check(game.campaign().activeQuest==null,"reading the opening scene does not accept the quest")
	for area in ["DialogueScreen","QuestRequesterPortrait","QuestDialoguePanel"]:grid_area(area)
	await screenshot("board-story")
	await escape_dialogue()
	check(not is_instance_valid(scene) and requester.global_position.is_equal_approx(home),"Escape closes talk and returns the same requester")
	story_button.pressed.emit();await create_timer(.35).timeout
	scene=game.find_child("QuestDialogue",true,false)
	while not scene.choice_row.visible:scene._advance()
	await process_frame
	check(scene.find_child("QuestStoryAccept",true,false) is Button and scene.find_child("QuestStoryDecline",true,false) is Button,"choice appears after all typewritten lines")
	grid_area("QuestStoryChoices")
	await screenshot("board-story-choices")
	if scene.find_child("QuestStoryAccept",true,false) is Button:
		scene.find_child("QuestStoryAccept",true,false).pressed.emit();await process_frame;await process_frame
		check(game.campaign().activeQuest==null and game.dialog.window!=null and game.dialog.window.visible,"accept choice leads to carrier selection before cargo is issued")
		await create_timer(.35).timeout
		check(requester.global_position.is_equal_approx(home),"accepting the story returns the requester while the carrier picker is open")
		if game.dialog.window!=null:game.dialog.close(false)
	game.pages.quest_board.play_scene([["weigher","荷物を受け取ります。"],["farmer","ありがとう。"]],"weigher",[],"turnip")
	await process_frame
	for area in ["DialogueScreen","QuestPortrait","QuestPortraitRight","QuestDialoguePanel"]:grid_area(area)
	await screenshot("delivery-story-two-portraits")
	scene=game.find_child("QuestDialogue",true,false)
	await escape_dialogue()
	check(not is_instance_valid(scene),"Escape closes delivery story")
	# The moving recipient's board copy must keep its destination and explanatory text aligned.
	var wheel_save=await game.engine.request({"op":"campaign_save"});var wheel_fixture=wheel_save.data.duplicate(true)
	wheel_fixture.state.location="east";wheel_fixture.state.worldTime=22;wheel_fixture.state.hours=22
	await game.update({"op":"campaign_load","data":wheel_fixture});game.navigate("board");await process_frame;await process_frame
	var wheel_offer=game.campaign().board.filter(func(q):return q.get("eventId","")=="wheel")
	check(wheel_offer.size()==1 and wheel_offer[0].to=="south" and wheel_offer[0].text.contains("サウス"),"moving quest destination and description agree at +22h")
	var wheel_choice=game.find_child("QuestChoice_standalone-wheel",true,false)
	if wheel_choice is Button:wheel_choice.pressed.emit();await process_frame
	var window_label=game.find_child("QuestMerchantWindow",true,false);var availability=game.find_child("QuestMerchantStatus",true,false)
	check(window_label.get_parent().get_children().any(func(child):return child is Label and child.text=="依頼掲載からの経過時間：22時間"),"schedule time starts at posting even before acceptance")
	check(window_label is Label and not window_label.text.contains("希望条件") and window_label.text.contains("サウス") and window_label.text.contains("18時間以上36時間まで"),"board shows South stop window with inclusive end")
	check(game.find_child("QuestStatus",true,false)==null,"board omits redundant current-stop line")
	check(availability is Label and availability.text.contains("サウスへ向かってください"),"board directs player to merchant's different stop")
	grid_area("QuestMerchantAvailability")
	var schedule=game.find_child("QuestScheduleToggle",true,false)
	schedule.pressed.emit();await process_frame;await process_frame
	var detail_scroll=schedule.get_parent().get_parent() as ScrollContainer
	detail_scroll.scroll_vertical=int(detail_scroll.get_v_scroll_bar().max_value)
	await process_frame
	check(window_label.is_visible_in_tree() and (detail_scroll.scroll_vertical>0 or detail_scroll.get_global_rect().encloses(window_label.get_global_rect())),"expanded merchant schedule can be read within the detail viewport")
	grid_area("QuestMerchantAvailability")
	grid_area("QuestDetailActions")
	await screenshot("wheel-board-schedule")
	var carrier=game.campaign().selected.filter(func(id):return game.campaign().roster.any(func(c):return c.id==id and c.job=="job_porter"))[0]
	await game.act("accept",["standalone-wheel",carrier]);await process_frame;await process_frame
	var accepted_save=await game.engine.request({"op":"campaign_save"});var wait_fixture=accepted_save.data.duplicate(true)
	wait_fixture.state.location="astaris";wait_fixture.state.worldTime=8;wait_fixture.state.hours=8
	await game.update({"op":"campaign_load","data":wait_fixture});game.navigate("board");await process_frame;await process_frame
	game.navigate("hub");await process_frame;await process_frame
	check(game.find_child("HubDeliverCargo",true,false)==null and game.find_child("HubWaitForMerchant",true,false) is Button,"hub prevents handoff before merchant arrival")
	game.navigate("board");await process_frame;await process_frame
	var wait_button=game.find_child("WaitForMerchant",true,false)
	check(wait_button is Button and wait_button.text.contains("2時間"),"waiting is offered at the correct first stop")
	var wait_reply={}
	if wait_button is Button:wait_reply=await game.engine.request({"op":"campaign","action":"waitForEvent","args":[]})
	if wait_reply.get("campaign") is Dictionary:game.data=wait_reply;game.render();await process_frame
	var waited=game.campaign();check(wait_reply.get("ok",false) and waited.worldTime==10 and waited.activeQuest.merchantAtStop and waited.activeQuest.to=="astaris","waiting advances to arrival and enables handoff "+str(wait_reply.get("error","")))
	game.navigate("hub");await process_frame;await process_frame
	check(game.find_child("HubDeliverCargo",true,false) is Button,"hub enables handoff after merchant arrival")
	var forecast_fixture=accepted_save.data.duplicate(true);forecast_fixture.state.location="east";forecast_fixture.state.worldTime=22;forecast_fixture.state.hours=22
	await game.update({"op":"campaign_load","data":forecast_fixture});game.navigate("map");await process_frame;await process_frame
	var depart_reply=await game.engine.request({"op":"campaign","action":"depart","args":["astaris","convoy"]})
	if depart_reply.get("campaign") is Dictionary:game.data=depart_reply;game.render();await process_frame
	game.find_child("RouteChoice_short",true,false).pressed.emit();await process_frame
	while game.locked or game.engine.busy or game.loading_screen.active:await process_frame
	check(not game.modal_open() and game.campaign().phase=="deployment","route selection proceeds directly (merchant already in South)")
	var before_fixture=accepted_save.data.duplicate(true);before_fixture.state.location="east";before_fixture.state.worldTime=3;before_fixture.state.hours=3
	await game.update({"op":"campaign_load","data":before_fixture});game.navigate("map");await process_frame;await process_frame
	var before_depart=await game.engine.request({"op":"campaign","action":"depart","args":["astaris","convoy"]})
	if before_depart.get("campaign") is Dictionary:game.data=before_depart;game.render();await process_frame
	game.find_child("RouteChoice_short",true,false).pressed.emit();await process_frame
	while game.locked or game.engine.busy or game.loading_screen.active:await process_frame
	check(not game.modal_open() and game.campaign().phase=="deployment","route selection proceeds directly (merchant still travelling)")
	var south_stop_fixture=accepted_save.data.duplicate(true);south_stop_fixture.state.location="astaris";south_stop_fixture.state.worldTime=22;south_stop_fixture.state.hours=22
	await game.update({"op":"campaign_load","data":south_stop_fixture});game.navigate("board");await process_frame;await process_frame
	var south_stop_label=game.find_child("QuestMerchantStatus",true,false)
	check(south_stop_label is Label and south_stop_label.text.contains("サウスへ向かってください") and not south_stop_label.text.contains("到着待ち"),"at +22h in Astaris the board directs the player South, not to wait")
	var departed_fixture=accepted_save.data.duplicate(true);departed_fixture.state.location="east";departed_fixture.state.worldTime=31;departed_fixture.state.hours=31
	await game.update({"op":"campaign_load","data":departed_fixture});game.navigate("map");await process_frame;await process_frame
	var departed_reply=await game.engine.request({"op":"campaign","action":"depart","args":["south","convoy"]})
	if departed_reply.get("campaign") is Dictionary:game.data=departed_reply;game.render();await process_frame
	game.find_child("RouteChoice_short",true,false).pressed.emit();await process_frame
	while game.locked or game.engine.busy or game.loading_screen.active:await process_frame
	check(not game.modal_open() and game.campaign().phase=="deployment","route selection proceeds directly (receipt deadline approaching)")
	if not failures.is_empty():print("FAILURES: "+"; ".join(failures))
	else:print("quest story regression: "+str(checks)+" checks passed; FHD layout verified")
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine()
	await create_timer(.15).timeout;game.queue_free()
	for i in range(6):await process_frame
	quit(1 if not failures.is_empty() else 0)
