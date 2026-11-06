extends SceneTree
## Exercise actual campaign views, including accepted revisionless save data.
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
func reward_row(caption: String):
	var detail = game.find_child("QuestDetail",true,false)
	for label in detail.find_children("*","Label",true,false):
		if label.text == caption:return label.get_parent()
	return null
func verify_row(caption: String, kind: String, amount: int, rp: int, context: String):
	var row = reward_row(caption)
	check(row != null,context + " / " + caption + " exists")
	if row == null:return
	var labels: Array = []
	for child in row.get_children():
		if child is Label:labels.append(child.text)
	var expected = [caption,"×%d" % amount]
	if rp > 0:expected.append("RP ×%d" % rp)
	check(labels == expected,context + " / " + caption + " amounts " + str(expected))
	var icons = row.find_children("*","TextureRect",true,false)
	check(icons.size() == 1 and icons[0].get_meta("ui_icon_id","") == kind,context + " / " + caption + " " + kind + " icon")
func verify_rewards(q: Dictionary, base: int, bonus: int, base_rp: int, bonus_rp: int, legacy: bool, context: String):
	var before = await saved()
	game.navigate("board");await settle()
	var choice = game.find_child("QuestChoice_" + str(q.id),true,false)
	check(choice is Button,context + " quest selectable")
	if choice is Button:choice.pressed.emit();await settle()
	var kind = "experience" if q.get("rewardType", "money") == "experience" else "money"
	verify_row("基本報酬",kind,base,base_rp,context)
	verify_row("希望条件達成報酬",kind,bonus,bonus_rp,context)
	if legacy:verify_row("キャラクター報酬","experience",int(q.xp),0,context)
	else:check(reward_row("キャラクター報酬") == null,context + " RP is not character EXP")
	check(await saved() == before,context + " rendering preserves saved state")
func run():
	create_timer(150).timeout.connect(func():print("FAIL reward display watchdog");quit(2))
	root.size = Vector2i(1920,1080)
	game = load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast = true;game.audio.fast_mode = true;await settle()
	var seed = await saved()
	var cases = [
		["astaris","standalone-kiln",0,150,0,100],
		["east","standalone-wheel",110,110,60,40],
		["north","standalone-turnip",0,240,0,100],
		["astaris","astaris-east-0-0",117,63,60,40],
		["astaris","astaris-west-0-1",97,53,60,40],
	]
	for sample in cases:
		var fixture = seed.duplicate(true);fixture.state.location = sample[0]
		await game.update({"op":"campaign_load","data":fixture});await settle()
		var offers = game.campaign().board.filter(func(q):return q.id == sample[1])
		check(offers.size() == 1,str(sample[1]) + " real API offer available")
		if offers.size() != 1:continue
		var q = offers[0]
		await verify_rewards(q,sample[2],sample[3],sample[4],sample[5],false,str(q.id) + " offered")
		var carrier = game.campaign().selected.filter(func(id):return game.campaign().roster.any(func(c):return c.id == id and c.job == "porter"))[0]
		await game.act("accept",[q.id,carrier]);await settle()
		check(game.campaign().activeQuest is Dictionary,str(q.id) + " accepted")
		await verify_rewards(game.campaign().activeQuest,sample[2],sample[3],sample[4],sample[5],false,str(q.id) + " accepted")
		# Revisionless saves predate rewardType and retain gold plus character EXP.
		var legacy = (await saved()).duplicate(true)
		legacy.state.activeQuest.erase("rewardRevision")
		legacy.state.activeQuest.erase("rewardType")
		await game.update({"op":"campaign_load","data":legacy});await settle()
		await verify_rewards(game.campaign().activeQuest,sample[2],sample[3],0,0,true,str(q.id) + " legacy accepted")
	print("quest reward display regression: %d checks, %d failures" % [checks,failures.size()])
	game.closing = true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
