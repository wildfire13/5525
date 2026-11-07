extends "res://tests/npc_meeting_regression.gd"
## Synthetic saves only. Explicit expiry, cancellation and aftermath on the common UI.
func run():
	create_timer(180).timeout.connect(func():print("FAIL quest decisions watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();await install(seed,"east",0,"board")
	var porter=game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id==uid and c.job=="porter"))[0]
	await game.act("accept",["standalone-wheel",porter]);await settle();var wheel=await saved()
	for town in ["astaris","east","west","south","north"]:
		for offparty in [false,true]:
			var fixture=wheel.duplicate(true)
			if offparty:fixture.state.selected.erase(porter)
			await install(fixture,town,37,"board");var before=await bytes()
			check(game.campaign().activeQuest.meeting.canSettleFailure,"expiry offered in "+town+" offparty="+str(offparty))
			check(node("QuestMerchantAvailability").text.contains("この町で期限切れ"),"board explains local settlement")
			check(node("QuestCargoNotice")==null,"expiry does not demand a carrier")
			check(await bytes()==before,"board reads expiry without settling")
			game.navigate("hub");await settle();var b=node("HubDeliverCargo")
			check(b is Button and not b.disabled and contained(b),"enabled expiry action fits in "+town)
			before=await bytes();await press("HubDeliverCargo");var d=node("MerchantFailureConfirmation")
			check(d is ConfirmationDialog,"expiry needs explicit confirmation")
			if d==null:continue
			check(d.dialog_text.contains("受注前の状態") and d.dialog_text.contains("報酬はありません") and d.dialog_text.contains("世界の時刻は巻き戻りません") and d.dialog_text.contains("37時間のまま"),"confirmation explains rollback and continuing clock")
			check(await bytes()==before,"opening confirmation preserves save")
			await cancel(d);check(await bytes()==before,"cancel preserves expired contract")
			await press("HubDeliverCargo");await escape();check(await bytes()==before and game.page=="hub","Escape preserves contract and page")
			await press("HubDeliverCargo");d=node("MerchantFailureConfirmation")
			if d!=null:d.confirmed.emit();d.confirmed.emit();await settle()
			var result=await saved()
			check(result.state.phase=="result" and result.state.result.outcome=="failed" and result.state.activeQuest==null,"double confirmation settles once")
			check(result.state.worldTime==37 and result.state.hours==wheel.state.rollback.hours and result.state.location=="east","failure retains world time and restores location/hours")
			check(result.state.characters==wheel.state.rollback.characters and result.state.selected==wheel.state.rollback.selected and result.state.gold==wheel.state.rollback.gold,"failure restores cargo, party and money")
			check(result.state.result.gold==0 and result.state.result.xp==0 and not game.results_view.active,"no success rewards or receipt")
			await game.update({"op":"campaign_load","data":result});await settle();check(await saved()==result,"failed result reloads unchanged")
			await game.act("completeQuest",[]);await settle();check(await saved()==result,"failed result cannot settle twice")
			await game.act("acknowledge",[]);await settle();check(game.campaign().phase=="town" and not game.campaign().board.any(func(q):return q.id=="standalone-wheel"),"failed contract stays closed after acknowledgment")
	for kind in ["page","round_trip","load"]:
		await install(wheel,"north",37);await press("HubDeliverCargo");var d=node("MerchantFailureConfirmation")
		if kind in ["page","round_trip"]:
			game.navigate("board");await settle()
			if kind=="round_trip":game.navigate("hub");await settle()
		else:await install(wheel,"north",37)
		var before=await bytes()
		if is_instance_valid(d):d.confirmed.emit();await settle()
		check(await bytes()==before,"stale expiry callback after "+kind+" is inert")
		await cancel(d)
	# Boundary and aftermath are based on elapsed schedule age, including old missed states.
	for age in [24,25,36,37]:
		for town in ["south","north"]:
			await install(wheel,town,age);var m=game.campaign().activeQuest.meeting
			check(m.canSettleFailure==(age>36),"failure boundary "+town+str(age))
			check(m.canDeliver==(town=="south" and age<=36),"delivery boundary "+town+str(age))
		var missed=seed.duplicate(true)
		if age>24:missed.state.standaloneEvents.events.wheel.status="missed"
		await install(missed,"south",age,"board");var before=await bytes()
		check((node("QuestAftermath_wheel-aftermath")!=null)==(age>36),"South aftermath appears only after departure at "+str(age))
		if age>36:
			await press("QuestAftermathStory_wheel-aftermath");check(node("QuestDialogue")!=null,"departure aftermath opens");await escape()
		check(await bytes()==before,"aftermath reading preserves old missed save")
	# Visiting the potter stays in East at the existing time with one explanatory line.
	await install(seed,"astaris",0);await game.act("accept",["standalone-kiln",porter]);await settle();var kiln=await saved()
	await install(kiln,"east",20);await game.act("completeQuest",[]);await settle();await press("ResultContinue");var completed=await saved()
	check(completed.state.phase=="town" and completed.state.standaloneEvents.events.kiln.status=="completed","kiln success receipt acknowledged normally")
	for sample in [["east",22,false],["astaris",23,false],["east",23,true]]:
		await install(completed,sample[0],sample[1],"board");var before=await bytes()
		check((node("QuestAftermath_kiln-return")!=null)==sample[2],"kiln aftermath retains place/time "+str(sample))
		if sample[2]:
			await press("QuestAftermathStory_kiln-return");var scene=node("QuestDialogue")
			check(scene!=null and scene.quest.story[0][1].contains("若い陶工") and scene.quest.story[0][1].contains("イースの工房を訪ね"),"kiln scene explains apprentice visit")
			check(scene!=null and scene.quest.portrait=="apprentice","existing apprentice art retained");await escape()
		check(await bytes()==before,"kiln story remains read-only")
	for dims in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=dims;await settle();await install(wheel,"north",37);await press("HubDeliverCargo");var d=node("MerchantFailureConfirmation")
		check(contained(node("HubDeliverCargo")),"expiry action contained at "+str(dims))
		check(d is ConfirmationDialog and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(d.position),Vector2(d.size))),"expiry confirmation contained at "+str(dims));await cancel(d)
	print("Quest decisions regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
