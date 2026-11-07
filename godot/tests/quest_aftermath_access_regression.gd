extends "res://tests/npc_meeting_regression.gd"
## Test actual visible hit targets, not pressed signals on offscreen Controls.
func click_visible(id: String) -> bool:
	var button=node(id)
	check(button is Button,"aftermath button exists: "+id)
	if not button is Button:return false
	var scrolls: Array=[];var parent=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:scrolls.append(parent)
		parent=parent.get_parent()
	check(not scrolls.is_empty(),id+" belongs to a scrollable quest list")
	for scroll in scrolls:scroll.ensure_control_visible(button)
	await settle()
	var reachable=contained(button)
	for scroll in scrolls:reachable=reachable and scroll.get_global_rect().encloses(button.get_global_rect())
	check(reachable,id+" is wholly visible inside viewport and scroll clip")
	if not reachable:return false
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
		root.push_input(event,true);await process_frame
	await settle()
	return true
func run():
	create_timer(120).timeout.connect(func():print("FAIL aftermath access watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();await install(seed,"astaris",0)
	var porter=game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id==uid and c.job=="porter"))[0]
	await game.act("accept",["standalone-kiln",porter]);await settle();var kiln=await saved()
	await install(kiln,"east",20);await game.act("completeQuest",[]);await settle();await press("ResultContinue");var completed=await saved()
	for dims in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=dims;await settle()
		for sample in [[seed,"south",37,"wheel-aftermath"],[completed,"east",23,"kiln-return"]]:
			await install(sample[0],sample[1],sample[2],"board");var before=await bytes()
			check(game.campaign().board.size()>0,"repeatable quests coexist with aftermath")
			var clicked=await click_visible("QuestAftermathStory_"+sample[3]);var scene=node("QuestDialogue")
			check(clicked and scene!=null,"actual viewport mouse opens "+sample[3]+" at "+str(dims))
			if scene!=null:
				if sample[3]=="kiln-return":check(scene.quest.story[0][1].contains("イースの工房を訪ね"),"visible kiln story includes visit narration")
				await escape()
			check(await bytes()==before,"read/escape preserves save bytes for "+sample[3])
			check(game.page=="board" and node("QuestDialogue")==null,"Escape returns to the same board")
			game.navigate("hub");await settle();game.navigate("board");await settle()
			check(await bytes()==before,"board round trip preserves save bytes")
	print("Quest aftermath access: %d checks, %d failures" % [checks,failures.size()])
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
