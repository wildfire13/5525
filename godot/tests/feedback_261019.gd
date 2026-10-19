extends "res://tests/ui_feedback2_20261016.gd"
func escape_key():
	var event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true
	game._unhandled_key_input(event);await settle()
func run():
	create_timer(80).timeout.connect(func():print("FAIL feedback 261019 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.characters.guard.inventory={"potion":3,"spear-wood":1,"kungfu-pants":1,"fist-1":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var menu_button=node("CommonMenuButton");var rect=menu_button.get_global_rect()
	check(rect.position.x>1700 and rect.position.y>1000 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect),"menu fixed in FHD bottom right: "+str(rect))
	var party=game.pages.party_view;party.open_detail("guard");await settle()
	check(node("StatusEquipped").get_global_rect().end.x<=node("StatusOwnedInventory").global_position.x,"owned inventory alongside equipped slots")
	check(node("OwnedEquipment_potion")!=null and node("OwnedEquipment_fist-1")!=null,"equipment view includes consumables and equipment")
	# Stress only the view projection; never send synthetic item IDs to the engine.
	var original_entries=game.campaign().inventoryByCharacter.guard.entries.duplicate(true)
	var long_entries=[]
	for i in range(36):
		var entry=original_entries[i%original_entries.size()].duplicate(true);entry.id="layout-stress-"+str(i);entry.name="長い所持品の名称".repeat(12);long_entries.append(entry)
	game.campaign().inventoryByCharacter.guard.entries=long_entries;party.refresh_modal();await settle()
	check(node("OwnedEquipmentList").get_child_count()==36*3 and node("StatusEquipmentSplit").size.x<=game.dialog.window.size.x,"many long inventory names wrap inside status width")
	check(node("OwnedEquipmentList").size.y>game.dialog.window.size.y,"large owner inventory remains in scrollable dialog content")
	game.campaign().inventoryByCharacter.guard.entries=original_entries;party.refresh_modal();await settle()
	var slot=game.campaign().roster.filter(func(u):return u.id=="guard")[0].equipmentSlots.filter(func(e):return e.slot=="lowerBody")[0]
	party.open_equipment(game.campaign().roster.filter(func(u):return u.id=="guard")[0],slot);await settle()
	check(party.owned_equipment_view.slot=="lowerBody" and node("OwnedEquipment_kungfu-pants")!=null and node("OwnedEquipment_potion")==null,"clicking equipped body part filters owner inventory")
	var before=await saved();await click("OwnedEquipmentActions_kungfu-pants");await consent(false)
	check(await saved()==before,"cancel equipment preview preserves full state")
	game.dialog.close();await game.new_game();await settle()
	# Both free travel and quest arrival normalize before the first visible render.
	for quest in [false,true]:
		await game.new_game();await settle()
		if quest:await game.act("accept",[game.campaign().board[0].id,"porter"])
		var cash=game.campaign().gold;await game.act("depart",["east"])
		var arrival=await saved();arrival.state.phase="arrival";arrival.state.journey.phase="delivery";arrival.state.journey.stage=2;arrival.state.journey.hours=4
		arrival.state.journey.party=game.roster().filter(func(u):return game.campaign().selected.has(u.id)).duplicate(true)
		await game.update({"op":"campaign_load","data":arrival});await settle()
		check(game.campaign().phase=="town" and game.page=="hub" and node("TownHub")!=null,"direct hub arrival quest="+str(quest))
		check(game.save_notice.visible and game.campaign().gold==cash,"arrival notice with no automatic cargo reward quest="+str(quest))
		if quest:
			check(node("HubDeliverCargo")!=null and not node("HubDeliverCargo").disabled,"destination hub has cargo delivery")
			await click("HubFacility_board");check(node("QuestComplete")==null,"board no longer owns delivery action")
			game.navigate("hub");await settle();await click("HubDeliverCargo")
			check(game.campaign().activeQuest==null and game.campaign().gold>cash,"hub delivers and pays existing reward")
	var fixture=battle_fixture();await game.update({"op":"campaign_load","data":fixture.archer});await settle()
	game.checks_fast=false;game.hud.last_actor="";game.render();await create_timer(.06).timeout
	check(node("CommandOpeningFlight")!=null and node("CommandOpeningFlight").z_index<game.battle_header.z_index and not game.hud.left_panel.visible,"command panel opens from behind actor card")
	await create_timer(.4).timeout;game.checks_fast=true
	check(game.hud.left_panel.visible and node("CommandOpeningFlight")==null,"command panel opening settles and frees visual")
	check(node("Retreat")==null,"retreat button removed")
	game.hud.toggle_details();await settle()
	var labels=game.dialog.window.find_children("*","Label",true,false).map(func(n):return n.text)
	check(not labels.any(func(t):return t.contains("全行動順") or t.begins_with("所持:")) and labels.any(func(t):return t.contains("条件マス")),"battle details retain unique formation and intent reasoning only")
	game.dialog.close();await settle()
	for panel in [game.hud.left_panel,game.hud.right_panel]:
		panel.position=Vector2(-500,-500);panel.constrain();await frames()
		check(panel.global_position.y==0 and panel.global_position.x==0 and panel.z_index>=10,"floating panel reaches screen top while remaining visible")
		panel.position=Vector2(5000,5000);panel.constrain();await frames()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(panel.get_global_rect()),"floating panel cannot be lost off screen")
	before=await saved();await game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]));await settle()
	await escape_key();check(await saved()==before and game.pending==null,"ESC cancels selected target without action consumption")
	while not game.hud.action_menu:game.cancel();await settle()
	await escape_key()
	var confirmations=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)
	check(confirmations.size()==1 and not game.menu.visible,"normal battle ESC opens retreat confirmation rather than menu")
	if not confirmations.is_empty():confirmations[0].canceled.emit()
	await settle();check(await saved()==before,"cancel retreat preserves equipment inventory and battle")
	var f=FileAccess.open(evidence.path_join("feedback-261019.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
