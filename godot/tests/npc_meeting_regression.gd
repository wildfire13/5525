extends SceneTree
## Synthetic campaign round trips only. No real player saves or OS dialogs.
var game
var checks := 0
var failures: Array[String] = []
func _initialize():call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)
func settle():
	for i in range(10):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func bytes():return JSON.stringify(await saved())
func node(id: String):return game.find_child(id,true,false)
func install(seed: Dictionary, location: String, age: int, page := "hub"):
	var fixture=seed.duplicate(true);fixture.state.location=location;fixture.state.worldTime=age;fixture.state.hours=age
	await game.update({"op":"campaign_load","data":fixture});await settle();game.navigate(page);await settle()
func press(id: String):
	var button=node(id);check(button is Button,"button exists: "+id)
	if button is Button:button.pressed.emit();await settle()
func cancel(d):
	if is_instance_valid(d):d.canceled.emit();await settle()
func escape():
	for down in [true,false]:
		var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=down;Input.parse_input_event(event);await process_frame
	await settle()
func contained(c: Control):return Rect2(Vector2.ZERO,game.size).encloses(c.get_global_rect())
func dialogue_cast(expected: Array, context: String):
	var scene=node("QuestDialogue");check(scene!=null,context+" opens")
	if scene==null:return
	check(scene.quest.cast==expected,context+" uses scene-specific cast")
	check(scene.portrait.visible and scene.portrait.texture!=null and scene.portrait_right.visible==(expected.size()>1),context+" portrait visibility matches cast")
	check(contained(node("QuestDialoguePanel")),context+" dialogue panel contained")
func close_story():
	var scene=node("QuestDialogue")
	if scene!=null:scene._close();await settle()
func run():
	create_timer(180).timeout.connect(func():print("FAIL NPC meeting watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();var accepted={}
	for sample in [["turnip","north","astaris",["farmer"],["weigher","farmer"]],["kiln","astaris","east",["apprentice"],["master"]],["wheel","east","astaris",["wheelwright"],["merchant"]]]:
		var id="standalone-"+sample[0]
		await install(seed,sample[1],0,"board");await press("QuestChoice_"+id)
		var before=await bytes();await press("QuestStory_"+id);dialogue_cast(sample[3],id+" request")
		check(await bytes()==before,id+" request reading preserves save bytes");await close_story()
		var porter=game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id==uid and c.job=="porter"))[0]
		await game.act("accept",[id,porter]);await settle();accepted[sample[0]]=await saved()
		game.navigate("board");await settle();before=await bytes();await press("QuestStory_"+id)
		var scene=node("QuestDialogue");dialogue_cast(sample[3],id+" active reread")
		if scene!=null:
			check(node("QuestSceneLabel").text=="依頼時の話",id+" active reread labeled as past")
			while not scene.choice_row.visible:scene._advance()
			check(node("QuestStoryAccept")==null and node("QuestStoryClose") is Button,id+" active reread cannot reaccept")
		await escape();check(await bytes()==before,id+" active reread Escape preserves save bytes")
		await install(accepted[sample[0]],sample[2],10)
		await game.act("completeQuest",[]);await settle();before=await bytes();await press("ResultStory");dialogue_cast(sample[4],id+" delivery")
		await close_story();check(await bytes()==before,id+" delivery reading preserves save bytes");game.results_view.reset();await settle()
	var wheel=accepted.wheel.duplicate(true)
	for member in wheel.state.characters.values():member.hp=maxi(1,int(member.hp)-1);member.mp=0
	for page in ["hub","board"]:
		for age in [9,15,17]:
			await install(wheel,"south",age,page)
			var button_id="HubWaitForMerchant" if page=="hub" else "WaitForMerchant"
			if age==9:
				var status=node("HubStatus" if page=="hub" else "QuestStatus")
				check(status is Label and status.text.contains("アスタリスへ移動中") and status.text.contains("この町へ9時間後") and not status.text.contains("サウスへ移動中"),"South9 separates current transit from later local stop on "+page)
			var before=await bytes();await press(button_id);var d=node("MerchantWaitConfirmation")
			check(d is ConfirmationDialog,"South %dh %s wait confirmation" % [age,page])
			if d==null:continue
			check(d.dialog_text.contains("%d時間待ち" % (18-age)) and d.dialog_text.contains("%d → 18" % age) and d.dialog_text.contains("他の依頼") and d.dialog_text.contains("HP・MPは回復しません"),"confirmation explains duration, world time and effects")
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(d.position),Vector2(d.size))),"confirmation fits FHD")
			check(await bytes()==before,"opening wait preserves save bytes")
			await cancel(d);check(await bytes()==before,"cancel wait preserves save bytes")
			await press(button_id);await escape();check(await bytes()==before and game.page==page,"Escape wait preserves save bytes and page")
			await press(button_id);d=node("MerchantWaitConfirmation");var state_before=await saved()
			if d!=null:d.confirmed.emit();d.confirmed.emit();await settle()
			var after=await saved();check(after.state.worldTime==18 and after.state.hours==18,"double confirm advances exactly once to South 18h")
			var contract_before=state_before.state.activeQuest.duplicate(true);var contract_after=after.state.activeQuest.duplicate(true)
			for key in ["to","text"]:contract_before.erase(key);contract_after.erase(key)
			check(after.state.characters==state_before.state.characters and after.state.gold==state_before.state.gold and contract_after==contract_before,"wait preserves roster HP/MP/cargo, gold and contract")
			check(node(button_id)==null and game.campaign().activeQuest.meeting.canDeliver,"wait ends with explicit handoff available, not automatic delivery")
	# Old modal callbacks must never consume a replacement state or navigate behind it.
	for kind in ["page","round_trip","load"]:
		await install(wheel,"south",9);await press("HubWaitForMerchant");var d=node("MerchantWaitConfirmation")
		if kind in ["page","round_trip"]:
			game.navigate("board");await settle()
			if kind=="round_trip":game.navigate("hub");await settle()
		else:await install(wheel,"south",9)
		var before=await bytes()
		if is_instance_valid(d):d.confirmed.emit();await settle()
		check(await bytes()==before,"stale callback after "+kind+" leaves save bytes unchanged")
		await cancel(d)
	for age in [24,36]:
		for page in ["hub","board"]:
			await install(wheel,"south",age,page);var prefix="Hub" if page=="hub" else "Quest";var deadline=node(prefix+"Deadline")
			check(deadline is Label and deadline.text.contains("今なら希望条件達成" if age==24 else "今なら受取可能") and deadline.text.contains("次に時間が進むと"),"inclusive %dh boundary copy on %s" % [age,page])
			check(game.campaign().activeQuest.meeting.canDeliver,"inclusive boundary remains deliverable")
	for page in ["hub","board"]:
		var prefix="Hub" if page=="hub" else "Quest"
		await install(wheel,"astaris",36,page)
		check(node(prefix+"Deadline") is Label and not node(prefix+"Deadline").text.contains("今なら受取可能"),"Astaris36 does not promise local receipt on "+page)
		var offparty=wheel.duplicate(true);offparty.state.selected.erase(offparty.state.activeQuest.cargoOwnerId)
		await install(offparty,"south",36,page)
		check(node(prefix+"Deadline") is Label and not node(prefix+"Deadline").text.contains("今なら受取可能"),"South36 off-party cargo does not promise receipt on "+page)
	await install(wheel,"astaris",36,"map");await game.act("depart",["south","convoy"]);await settle()
	var summary=node("TravelQuestSummary");var summary_text=""
	if summary!=null:
		for label in summary.find_children("*","Label",true,false):summary_text+=label.text+"\n"
	check(summary!=null and summary_text.contains("サウス") and summary_text.contains("次に時間が進むと受取終了") and not summary_text.contains("今なら受取可能"),"road36 summary shares meeting deadline without local receipt promise")
	# Presentation uses actual native forecasts, including fixed-destination quests.
	for sample in [["wheel","east","astaris",0],["wheel","east","astaris",22],["turnip","north","east",0],["kiln","astaris","south",0]]:
		await install(accepted[sample[0]],sample[1],sample[3],"map");await game.act("depart",[sample[2],"convoy"]);await settle()
		await game.forecast_action("short","travel",["short"]);await settle();var message=node("ConfirmationMessage")
		check(message is Label,"real forecast confirmation for "+sample[0])
		if message is Label:
			if sample[0]=="wheel" and sample[3]==0:check(message.text.contains("到着直後") and message.text.contains("待機後") and message.text.contains("納品可能") and not message.text.contains("見込み報酬 0G"),"early arrival distinguishes wait from zero reward")
			else:check(message.text.contains("では今は受け取れません") or message.text.contains("では納品できません"),"wrong town forecast never promises handoff")
		for d in game.find_children("*","ConfirmationDialog",true,false):await cancel(d)
	for sample in [["kiln","astaris","south",21,"イース"],["wheel","east","astaris",31,"サウス"]]:
		await install(accepted[sample[0]],sample[1],sample[3],"map");await game.act("depart",[sample[2],"convoy"]);await settle()
		await game.forecast_action("short","travel",["short"]);await settle();var message=node("ConfirmationMessage")
		check(message is Label and (message.text.contains("受取期限を超える") if sample[0]=="wheel" else message.text.contains("受取期限は終了")) and message.text.contains(sample[4]) and not message.text.contains("遅配"),"expired wrong-town forecast points to settlement without late-success: "+sample[0])
		for d in game.find_children("*","ConfirmationDialog",true,false):await cancel(d)
	# Resize assertions concern logical UI containment, not screenshot/visual approval.
	for dims in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=dims;await settle()
		for page in ["hub","board"]:
			await install(wheel,"south",15,page);var id="HubWaitForMerchant" if page=="hub" else "WaitForMerchant"
			var button=node(id);check(button is Button and contained(button),"wait action contained at "+str(dims)+" "+page)
			await press(id);var d=node("MerchantWaitConfirmation")
			check(d is ConfirmationDialog and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(d.position),Vector2(d.size))),"wait confirmation contained at "+str(dims)+" "+page);await cancel(d)
	print("NPC meeting regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
