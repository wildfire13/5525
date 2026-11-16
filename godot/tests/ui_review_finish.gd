extends "res://tests/ui_feedback_20261016.gd"
func run():
	create_timer(70).timeout.connect(func():print("FAIL finish watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	var fixtures=JSON.parse_string("".join(output));await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	var hud=game.hud
	check(not hud.tools.get_global_rect().intersects(hud.left_panel.find_child("DragHandle",true,false).get_global_rect()),"R1 toolbar never overlaps default actor heading")
	# A saved panel can now occupy the top of the viewport.
	hud.left_panel.position.y=50;hud.left_panel.constrain();await settle()
	check(root.get_visible_rect().encloses(hud.left_panel.get_global_rect()),"R1 restored actor panel stays within the viewport")
	var original_queue=game.data.queue.duplicate(true);game.data.queue=[]
	for i in range(40):game.data.queue.append(original_queue[i%original_queue.size()])
	hud.render();await frames()
	var cards=node("TurnOrder").get_children().filter(func(c):return c is PanelContainer)
	check(cards.size()==5 and cards.all(func(c):return c.size.x>=180),"R4 first five of forty entries keep readable fixed widths")
	check(cards.all(func(c):return c.find_children("*","Label",true,false).any(func(label):return label.size.x>=132 and not label.text.is_empty())),"R4 every card retains visible name area")
	await click("BattleOrderDetails")
	check(game.dialog.window.find_children("OrderDetail_*","Label",true,false).size()==40,"R4 all forty entries remain available in order details")
	game.dialog.close()
	game.data.queue=original_queue;game.render();await settle()
	await game.choose_command("item");await game.on_cell(int(hud.acting().pos));await settle()
	var viewport=game.hud.right_panel.body.get_parent().get_global_rect()
	check(node("PredictionSummary")!=null and viewport.encloses(node("PredictionSummary").get_global_rect()),"R3 self-potion HP prediction visible without scrolling")
	var confirm=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="battle_commit")[0]
	check(game.hud.right_panel.get_global_rect().encloses(confirm.get_global_rect()) and not confirm.disabled,"R3 self-potion enabled confirm pinned inside initial panel")
	check(not game.hud.right_panel.body.is_ancestor_of(confirm),"R3 confirm is outside scrolling details")
	var f=FileAccess.open(evidence.path_join("ui-review-finish.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
