extends SceneTree
var failures: Array[String]=[]
var checks:=0
var game
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var deadline=Time.get_ticks_msec()+15000
	while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if game.data.is_empty():check(false,"campaign initializes");quit(1);return
	game.checks_fast=true;await process_frame;await process_frame
	var saved=await game.engine.request({"op":"campaign_save"})
	var incoming=saved.data.duplicate(true);incoming.state.location="north"
	await game.update({"op":"campaign_load","data":incoming});await process_frame
	game.navigate("board");await process_frame;await process_frame
	check(game.campaign().board.any(func(q):return q.get("eventId")=="turnip"),"North board lists the time-limited turnip event")
	var quest_choice=game.find_child("QuestChoice_standalone-turnip",true,false)
	if quest_choice is Button:quest_choice.pressed.emit();await process_frame
	var story_button=game.find_child("QuestStory_standalone-turnip",true,false)
	check(story_button is Button,"story can be read separately from accepting cargo")
	if story_button==null:quit(1);return
	story_button.pressed.emit();await process_frame;await process_frame
	var scene=game.find_child("QuestDialogue",true,false)
	check(scene!=null,"dialogue overlay opens on top of the existing town scene")
	if scene==null:quit(1);return
	var left=scene.find_child("QuestPortrait",true,false);var right=scene.find_child("QuestPortraitRight",true,false)
	check(left is TextureRect and right is TextureRect and left.visible and right.visible,"both supplied NPC portraits remain in the scene")
	check(left.texture!=null and right.texture!=null and left.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and right.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"portrait source proportions are preserved")
	check(left.modulate.r>right.modulate.r and scene.find_child("QuestSpeaker",true,false).text=="農夫","speaker is bright and the listener stays dim; name tab remains in place")
	check(root.size==Vector2i(1920,1080),"dialogue layout measured at FHD 1920×1080")
	var panel=scene.find_child("QuestDialoguePanel",true,false)
	check(panel.position.x>=0 and panel.position.y>=0 and panel.position.x+panel.size.x<=1920 and panel.position.y+panel.size.y<=1080,"black dialogue panel remains inside the FHD viewport")
	check(game.campaign().activeQuest==null,"reading the opening scene does not accept the quest")
	for i in range(scene.lines.size()*2):scene._advance()
	await process_frame
	check(scene.find_child("QuestStoryAccept",true,false) is Button and scene.find_child("QuestStoryDecline",true,false) is Button,"choice appears after all typewritten lines")
	if scene.find_child("QuestStoryAccept",true,false) is Button:
		scene.find_child("QuestStoryAccept",true,false).pressed.emit();await process_frame;await process_frame
		check(game.campaign().activeQuest==null and game.dialog.window!=null and game.dialog.window.visible,"accept choice leads to carrier selection before cargo is issued")
		if game.dialog.window!=null:game.dialog.close(false)
	# The moving recipient's board copy must keep its destination and explanatory text aligned.
	var wheel_save=await game.engine.request({"op":"campaign_save"});var wheel_fixture=wheel_save.data.duplicate(true)
	wheel_fixture.state.location="east";wheel_fixture.state.worldTime=22;wheel_fixture.state.hours=22
	await game.update({"op":"campaign_load","data":wheel_fixture});game.navigate("board");await process_frame;await process_frame
	var wheel_offer=game.campaign().board.filter(func(q):return q.get("eventId","")=="wheel")
	check(wheel_offer.size()==1 and wheel_offer[0].to=="south" and wheel_offer[0].text.contains("サウス"),"moving quest destination and description agree at +22h")
	var wheel_choice=game.find_child("QuestChoice_standalone-wheel",true,false)
	if wheel_choice is Button:wheel_choice.pressed.emit();await process_frame
	var window_label=game.find_child("QuestMerchantWindow",true,false);var availability=game.find_child("QuestMerchantAvailability",true,false)
	check(window_label is Label and window_label.text.contains("サウス") and window_label.text.contains("18時間以上36時間まで"),"board shows South stop window with inclusive end")
	check(availability is Label and availability.text.contains("サウスへ向かってください"),"board directs player to merchant's different stop")
	var carrier=game.campaign().selected.filter(func(id):return game.campaign().roster.any(func(c):return c.id==id and c.job=="porter"))[0]
	await game.act("accept",["standalone-wheel",carrier]);await process_frame;await process_frame
	var accepted_save=await game.engine.request({"op":"campaign_save"});var wait_fixture=accepted_save.data.duplicate(true)
	wait_fixture.state.location="astaris";wait_fixture.state.worldTime=8;wait_fixture.state.hours=8
	await game.update({"op":"campaign_load","data":wait_fixture});game.navigate("board");await process_frame;await process_frame
	game.navigate("hub");await process_frame;await process_frame
	check(game.find_child("HubDeliverCargo",true,false)==null and game.find_child("MerchantArrivalWait",true,false)!=null,"hub prevents handoff before merchant arrival")
	game.navigate("board");await process_frame;await process_frame
	var wait_button=game.find_child("WaitForMerchant",true,false)
	check(wait_button is Button and wait_button.text.contains("アスタリス") and wait_button.text.contains("2時間"),"waiting is offered at the correct first stop")
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
	await game.forecast_action("short","travel",["short"]);await process_frame;await process_frame
	var forecast_message=game.find_child("ConfirmationMessage",true,false)
	check(forecast_message is Label and forecast_message.text.contains("サウス") and forecast_message.text.contains("アスタリスでは受け取れません") and forecast_message.text.contains("見込み報酬 0G"),"ETA warning rejects a town where the merchant will not be")
	for node in game.find_children("*","ConfirmationDialog",true,false):node.get_cancel_button().pressed.emit()
	var before_fixture=accepted_save.data.duplicate(true);before_fixture.state.location="east";before_fixture.state.worldTime=3;before_fixture.state.hours=3
	await game.update({"op":"campaign_load","data":before_fixture});game.navigate("map");await process_frame;await process_frame
	var before_depart=await game.engine.request({"op":"campaign","action":"depart","args":["astaris","convoy"]})
	if before_depart.get("campaign") is Dictionary:game.data=before_depart;game.render();await process_frame
	await game.forecast_action("short","travel",["short"]);await process_frame;await process_frame
	var before_message=game.find_child("ConfirmationMessage",true,false)
	check(before_message is Label and before_message.text.contains("まだアスタリスに到着前") and before_message.text.contains("待機できます") and not before_message.text.contains("null"),"ETA under +10h explains pending arrival without null stop text")
	for node in game.find_children("*","ConfirmationDialog",true,false):node.get_cancel_button().pressed.emit()
	var south_stop_fixture=accepted_save.data.duplicate(true);south_stop_fixture.state.location="astaris";south_stop_fixture.state.worldTime=22;south_stop_fixture.state.hours=22
	await game.update({"op":"campaign_load","data":south_stop_fixture});game.navigate("board");await process_frame;await process_frame
	var south_stop_label=game.find_child("QuestMerchantAvailability",true,false)
	check(south_stop_label is Label and south_stop_label.text.contains("サウスへ向かってください") and not south_stop_label.text.contains("到着待ち"),"at +22h in Astaris the board directs the player South, not to wait")
	var departed_fixture=accepted_save.data.duplicate(true);departed_fixture.state.location="east";departed_fixture.state.worldTime=31;departed_fixture.state.hours=31
	await game.update({"op":"campaign_load","data":departed_fixture});game.navigate("map");await process_frame;await process_frame
	var departed_reply=await game.engine.request({"op":"campaign","action":"depart","args":["south","convoy"]})
	if departed_reply.get("campaign") is Dictionary:game.data=departed_reply;game.render();await process_frame
	await game.forecast_action("short","travel",["short"]);await process_frame;await process_frame
	var departed_message=game.find_child("ConfirmationMessage",true,false)
	check(departed_message is Label and departed_message.text.contains("サウスを出発済み") and not departed_message.text.contains("null"),"ETA beyond +36h explains departure without null stop text")
	for node in game.find_children("*","ConfirmationDialog",true,false):node.get_cancel_button().pressed.emit()
	if not failures.is_empty():print("FAILURES: "+"; ".join(failures))
	else:print("quest story regression: "+str(checks)+" checks passed; FHD geometry verified without a GUI framebuffer")
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine()
	await create_timer(.15).timeout;game.queue_free()
	for i in range(6):await process_frame
	quit(1 if not failures.is_empty() else 0)
