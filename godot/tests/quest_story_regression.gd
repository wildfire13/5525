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
	if not failures.is_empty():print("FAILURES: "+"; ".join(failures))
	else:print("quest story regression: "+str(checks)+" checks passed; FHD geometry verified without a GUI framebuffer")
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine()
	await create_timer(.15).timeout;game.queue_free()
	for i in range(6):await process_frame
	quit(1 if not failures.is_empty() else 0)
