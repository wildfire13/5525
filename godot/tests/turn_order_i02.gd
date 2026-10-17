extends "res://tests/ui_feedback2_20261016.gd"
func cards() -> Array:
	return node("TurnOrder").get_children().filter(func(c):return c is PanelContainer)
func run():
	create_timer(90).timeout.connect(func():quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var fixtures=battle_fixture();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	var original=game.data.duplicate(true);var before=await saved();var reference=node("BattleOrderDetails").global_position
	for count in [0,1,2,4,5,10,20]:
		game.data=original.duplicate(true);game.data.queue=[]
		for i in range(count):game.data.queue.append(original.queue[i%original.queue.size()])
		for u in game.data.state.units:u.name="長い名前の表示検証".repeat(8)
		game.render();await settle()
		var shown=cards();var viewport=node("TurnOrderViewport").get_global_rect()
		check(shown.size()==mini(count,5),"only first five cards for queue size %d" % count)
		check(node("BattleOrderDetails").global_position.is_equal_approx(reference),"sixth-slot button fixed for queue size %d" % count)
		check(shown.all(func(c):return viewport.encloses(c.get_global_rect())) and viewport.end.x<reference.x,"long names cannot enlarge or spill cards")
		var history=node("BattleHistory")
		check(history.global_position.x==viewport.position.x and history.global_position.y>=viewport.end.y and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(history.get_global_rect()),"history below first slot and within FHD")
		await click("BattleOrderDetails")
		check(game.dialog.window.find_children("OrderDetail_*","Label",true,false).size()==count,"details preserve every predicted occurrence including sixth onward")
		game.dialog.close();await settle()
	game.data=original.duplicate(true)
	for i in range(2,game.data.state.units.size()):game.data.state.units[i].hp=0
	game.render();await settle()
	check(cards().size()<=5 and node("BattleOrderDetails").global_position.is_equal_approx(reference),"fewer than five living characters do not move details")
	game.data=original.duplicate(true);game.data.state.log=[]
	for i in range(60):game.data.state.log.append("history-test-%02d" % i)
	game.render();await settle();await click("BattleHistory")
	var labels=game.dialog.window.find_children("*","Label",true,false).map(func(n):return n.text)
	check(game.dialog.window.title=="戦闘履歴" and labels.has("history-test-20") and labels.has("history-test-59") and not labels.has("history-test-19"),"history displays former detail log last forty entries")
	game.dialog.close();game.hud.toggle_details();await settle()
	check(not game.dialog.window.find_children("*","Label",true,false).any(func(n):return n.text.begins_with("history-test-")),"battle details no longer duplicate history")
	game.dialog.close();game.data=original;game.render();await settle()
	check(await saved()==before,"reading order and history never mutates engine state")
	# Real action at normal speed: fixed controls must remain outside the slide.
	game.hud.choose_command("guard");await settle();game.checks_fast=false;game.commit()
	while game.hud.animation_trace.size()<2:await process_frame
	var detail_position=node("BattleOrderDetails").global_position;var history_position=node("BattleHistory").global_position
	await create_timer(.12).timeout
	check(node("TurnOrderViewport").scroll_horizontal>0,"queue moves during action animation")
	check(node("BattleOrderDetails").global_position.is_equal_approx(detail_position) and node("BattleHistory").global_position.is_equal_approx(history_position),"order and history controls stay fixed during queue slide")
	check(node("TurnOrderViewport").get_global_rect().end.x<node("BattleOrderDetails").global_position.x,"offscreen sixth card cannot cover details button")
	await settle();game.checks_fast=true
	check(cards().size()==5 and node("TurnOrderViewport").scroll_horizontal==0,"next live queue returns to five cards with no scroll offset")
	check(game.hud.animation_trace.slice(0,3).map(func(e):return e.stage)==["command_shrink","queue_slide","character_action"],"existing animation stage order preserved")
	var f=FileAccess.open(evidence.path_join("turn-order-i02.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
