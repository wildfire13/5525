extends "res://tests/ui_feedback2_20261016.gd"
func source_cases():
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/feedback_261019_fixtures.cjs")]),output,true,false)
	return JSON.parse_string("".join(output))
func run():
	create_timer(100).timeout.connect(func():print("FAIL new skills watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;var cases=source_cases()
	for id in ["sweep50","sweep100"]:
		await game.update({"op":"campaign_load","data":cases[id]});await settle()
		await game.select_skill("legSweep");await settle()
		check(game.pending=="guard" and game.preview_ready and game.preview.cells.size()==8,"self-target sweep selects eight surrounding cells "+id)
		var predictions=game.preview.effectPreview.filter(func(e):return e.has("skipChance"))
		check(predictions.size()==3 and predictions.all(func(e):return e.skipChance==(.5 if id=="sweep50" else 1.0)),"independent per-enemy success probabilities "+id)
		var before=await saved();game.cancel();await settle();check(await saved()==before,"cancel sweep preserves all resources "+id)
		if id=="sweep100":
			await game.select_skill("legSweep");await settle();game.hud.animation_trace.clear();game.checks_fast=false;game.commit()
			var deadline=Time.get_ticks_msec()+10000
			while node("TurnSkipFlight")==null and Time.get_ticks_msec()<deadline:await process_frame
			var flying=node("TurnSkipFlight")
			check(flying!=null,"skipped turn creates detached flying order card")
			if flying!=null:
				var start=flying.position.x;await create_timer(.12).timeout
				check(is_instance_valid(flying) and flying.position.x>start,"skipped card flies toward screen right at normal speed")
			await settle();game.checks_fast=true
			check(game.hud.animation_trace.filter(func(e):return e.stage=="skip_fly_right").size()==3,"each affected enemy skips exactly one visible turn")
			check(game.state().actions==1 and game.state().units.filter(func(u):return u.id=="guard")[0].mp==5,"sweep action consumes MP1 and only one action")
	await game.update({"op":"campaign_load","data":cases.vault});await settle();await game.select_skill("poleVault");await settle()
	check(game.data.skill=="ポールヴォールト" and game.data.choices.skill.map(func(n):return int(n)).has(24) and not game.data.choices.skill.map(func(n):return int(n)).has(23),"vault label and orthogonal two-cell destinations")
	await game.on_cell(24);await settle();var before=await saved()
	check(game.preview_ready and game.preview.destination==24 and game.board.ghost.visible,"vault target produces movement ghost without moving actor")
	game.cancel();await settle();check(await saved()==before and game.state().units.filter(func(u):return u.id=="guard")[0].pos==22,"cancel vault preserves original position and MP")
	await game.on_cell(24);await settle();await game.commit();await settle()
	check(game.state().units.filter(func(u):return u.id=="guard")[0].pos==24 and game.state().actions==1,"vault commits across occupied intermediate cell once")
	for id in ["grapple","grapple-blocked"]:
		await game.update({"op":"campaign_load","data":cases[id]});await settle();await game.select_skill("grapple");await game.on_cell(24);await settle()
		var enemy=game.state().units.filter(func(u):return u.side=="enemy" and u.pos==24)[0]
		check(game.preview_ready and game.can_commit(),"grapple remains selectable with occupied middle "+id)
		before=await saved();game.cancel();await settle();check(await saved()==before,"cancel grapple leaves target and MP unchanged "+id)
		await game.on_cell(24);await settle();await game.commit();await settle()
		check(game.state().units.filter(func(u):return u.id==enemy.id)[0].pos==(23 if id=="grapple" else 24) and game.state().actions==1,"grapple moves or consumes without movement "+id)
	for id in ["item1","item2","item3"]:
		await game.update({"op":"campaign_load","data":cases[id]});await settle()
		await game.choose_command("item");await settle()
		check(game.hud.item_list and node("BattleItemList")!=null,"passive fist permits item command "+id)
		check(node("BattleItem_potion").tooltip_text.contains("射程無限" if id=="item3" else "自分のみ"),"item tooltip uses equipped level "+id)
		await click("BattleItem_potion");var target=game.hud.acting() if id!="item3" else game.state().units.filter(func(u):return u.id=="mage")[0]
		await game.on_cell(int(target.pos));await settle();before=await saved()
		check(game.can_commit() and game.preview.effectPreview.any(func(e):return e.get("hp",0)>0),"level permits selected healing target "+id)
		game.cancel();await settle();check(await saved()==before,"cancel item use keeps owner stock and actions "+id)
	var f=FileAccess.open(evidence.path_join("feedback-261019-skills.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
