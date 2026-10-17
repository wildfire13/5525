extends "res://tests/ui_feedback_20261016.gd"
func run():
	create_timer(70).timeout.connect(func():print("FAIL finish watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.characters.guard.inventory={"potion":2,"spear-wood":2,"swift-boots":1,"bow-wood":1,"lone-ring-2":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var p=game.pages.party_view;p.open_detail("guard");await settle()
	game.dialog.window.size=Vector2i(900,450);await frames()
	var scroll=game.dialog.body.get_parent();scroll.scroll_vertical=100000;await frames();var offset=scroll.scroll_vertical
	var before=await saved();await click("OwnedEquipmentActions_swift-boots");await click("InventoryCancel")
	check(offset>0 and abs(scroll.scroll_vertical-offset)<=2,"R5 NO restores nonzero equipment-list scroll")
	check(p.detail_tab==0 and p.detail_uid=="guard" and p.owned_equipment_view.slot=="" and game.dialog.window.gui_get_focus_owner()==node("OwnedEquipmentActions_swift-boots"),"R5 NO preserves owner slot and selected item focus")
	check(await saved()==before,"R5 cancellation leaves engine save unchanged")
	await click("OwnedEquipmentActions_swift-boots");game.dialog.escape();await settle()
	check(p.detail_tab==0 and abs(scroll.scroll_vertical-offset)<=2 and await saved()==before,"R5 Escape cancels into same list position without mutation")
	game.dialog.window.position=Vector2i(1850,1020);await frames()
	var window_rect=Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(window_rect) and window_rect.position.y>=36,"R6 moved/resized status immediately recovers inside viewport")
	check(node("StatusClose")==null and not game.dialog.window.borderless,"R6 recovered status retains window X without redundant footer close")
	var recovered=window_rect;game.dialog.close();await frames();p.open_detail("guard");await settle()
	check(Rect2(Vector2(game.dialog.window.position),Vector2(game.dialog.window.size))==recovered,"R6 reopening retains recovered geometry")
	game.dialog.close();await settle()
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	var fixtures=JSON.parse_string("".join(output));await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	var hud=game.hud
	check(not hud.tools.get_global_rect().intersects(hud.left_panel.find_child("DragHandle",true,false).get_global_rect()),"R1 toolbar never overlaps default actor heading")
	check(node("Retreat").size.x>=160 and node("Retreat").size.y>=52,"R2 retreat has readable 160px width")
	# Migrate old saved y=50 without requiring manual preference deletion.
	hud.left_panel.position.y=50;await frames();check(hud.left_panel.position.y>=76,"R1 old toolbar-overlapping panel position is recovered")
	var original_queue=game.data.queue.duplicate(true);game.data.queue=[]
	for i in range(40):game.data.queue.append(original_queue[i%original_queue.size()])
	hud.render();await frames()
	var cards=node("TurnOrder").get_children().filter(func(c):return c is PanelContainer)
	check(cards.size()==40 and cards.all(func(c):return c.size.x>=180),"R4 forty action cards keep readable widths with horizontal scrolling")
	check(cards.all(func(c):return c.find_children("*","Label",true,false).any(func(label):return label.size.x>=132 and not label.text.is_empty())),"R4 every card retains visible name area")
	game.data.queue=original_queue;game.render();await settle()
	await game.choose_command("item");await game.on_cell(int(hud.acting().pos));await settle()
	var viewport=game.hud.right_panel.body.get_parent().get_global_rect()
	check(node("PredictionSummary")!=null and viewport.encloses(node("PredictionSummary").get_global_rect()),"R3 self-potion HP prediction visible without scrolling")
	var confirm=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="battle_commit")[0]
	check(game.hud.right_panel.get_global_rect().encloses(confirm.get_global_rect()) and not confirm.disabled,"R3 self-potion enabled confirm pinned inside initial panel")
	check(not game.hud.right_panel.body.is_ancestor_of(confirm),"R3 confirm is outside scrolling details")
	var f=FileAccess.open(evidence.path_join("ui-review-finish.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
