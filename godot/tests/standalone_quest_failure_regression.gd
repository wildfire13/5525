extends SceneTree
## Synthetic API fixtures only. Covers requester labels and deadline failure receipts.
var game
var checks := 0
var failures: Array[String] = []
func _initialize():call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func visible_text() -> String:
	var texts: Array[String] = []
	for label in game.find_children("*","Label",true,false):
		if label.is_visible_in_tree():texts.append(label.text)
	return "\n".join(texts)
func verify_client(q: Dictionary, context: String):
	var body = game.find_child("QuestDetailBody",true,false)
	var found := false
	if body:
		for label in body.find_children("*","Label",true,false):
			if label.text != str(q.client):continue
			var caption = label.get_parent().get_child(0)
			found = caption is Label and caption.text == "依頼者"
	check(found,context + " identifies client as requester")
func verify_failure(context: String):
	var text = visible_text()
	check(text.contains("納品期限を過ぎました"),context + " explains deadline failure")
	check(text.contains("世界の時刻は巻き戻りません"),context + " explains continuing world time")
	check(not text.contains("護送隊が敗北しました"),context + " never claims battle defeat")
	check(not game.results_view.active,context + " does not show successful quest receipt")
func run():
	create_timer(150).timeout.connect(func():print("FAIL standalone failure watchdog");quit(2))
	root.size = Vector2i(1920,1080)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast = true;game.audio.fast_mode = true;await settle()
	var seed = await saved()
	for sample in [["turnip","north","astaris",19],["kiln","astaris","east",21],["wheel","east","south",37]]:
		var id = "standalone-" + sample[0]
		var fixture = seed.duplicate(true);fixture.state.location = sample[1]
		await game.update({"op":"campaign_load","data":fixture});await settle()
		game.navigate("board");await settle()
		var choice = game.find_child("QuestChoice_" + id,true,false)
		check(choice is Button,id + " selectable")
		if not choice is Button:continue
		choice.pressed.emit();await settle()
		var q = game.campaign().board.filter(func(entry):return entry.id == id)[0]
		verify_client(q,id + " offered")
		check(await saved() == fixture,id + " board rendering is read-only")
		var carrier = game.campaign().selected.filter(func(uid):return game.campaign().roster.any(func(c):return c.id == uid and c.job == "porter"))[0]
		await game.act("accept",[id,carrier]);await settle()
		verify_client(game.campaign().activeQuest,id + " accepted")
		var accepted = await saved();accepted.state.location = sample[2]
		accepted.state.worldTime = sample[3];accepted.state.hours = sample[3]
		await game.update({"op":"campaign_load","data":accepted});await settle()
		game.navigate("hub");await settle()
		await game.act("completeQuest",[]);await settle()
		check(game.campaign().result.outcome == "failed",id + " deadline failure reached")
		verify_failure(id)
		check(game.campaign().worldTime == sample[3] and game.campaign().hours == 0,id + " world time retained while party snapshot restored")
		check(game.campaign().location == sample[1] and game.campaign().gold == seed.state.gold,id + " original location and gold restored")
		var failed = await saved()
		await game.update({"op":"campaign_load","data":failed});await settle()
		verify_failure(id + " reloaded")
		# Older failed saves omitted reason. Derive a display fallback without rewriting them.
		var legacy = failed.duplicate(true);legacy.state.result.erase("reason")
		await game.update({"op":"campaign_load","data":legacy});await settle()
		verify_failure(id + " legacy")
		check(await saved() == legacy,id + " legacy display does not rewrite saved data")
		await game.act("acknowledge",[]);await settle()
		check(game.campaign().phase == "town" and game.campaign().activeQuest == null,id + " failure can be dismissed")
		check(not game.campaign().board.any(func(entry):return entry.id == id),id + " failed event is not offered twice")
	print("standalone quest failure regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing = true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
