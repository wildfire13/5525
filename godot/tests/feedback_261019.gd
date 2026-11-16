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
	var menu_button=node("CommonMenuButton");var rect=menu_button.get_global_rect()
	check(rect.position.x>1700 and rect.position.y>1000 and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect),"menu fixed in FHD bottom right: "+str(rect))
	await game.new_game();
	var stock=await saved()
	stock.state.characters["recruit-guard-human-female"].inventory={"potion":3,"kungfu-pants":1,"javelin-wood":1}
	await game.update({"op":"campaign_load","data":stock});await settle()
	var before_preview=await saved()
	game.pages.party_view.open_inventory("recruit-guard-human-female");await settle()
	var entries=game.campaign().inventoryByCharacter["recruit-guard-human-female"].entries
	var names={}
	for item in entries:names[item.id]=item.name
	var rows=game.find_children("*","Button",true,false)
	for id in ["potion","javelin-wood"]:
		check(rows.any(func(b):return b.tooltip_text==names[id]),"inventory includes "+id)
	var filter=node("CharacterInventoryFilter")
	for index in range(filter.item_count):
		if filter.get_item_metadata(index)=="lowerBody":
			filter.select(index);filter.item_selected.emit(index);break
	await settle()
	rows=game.find_children("*","Button",true,false)
	var pants=rows.filter(func(b):return b.tooltip_text==names["kungfu-pants"])
	check(pants.size()==1 and not rows.any(func(b):return b.tooltip_text==names["potion"]),"lower body filter shows matching owned equipment")
	if pants.size()==1:
		pants[0].pressed.emit();await settle()
		check(node("CharacterEquipmentComparison")!=null,"selected equipment opens an inline preview")
		await click("Header_character")
		check(await saved()==before_preview,"leaving equipment preview preserves the full save")
	# Both free travel and quest arrival normalize before the first visible render.
	for quest in [false,true]:
		await game.new_game();await settle()
		if quest:await game.act("accept",[game.campaign().board[0].id,"recruit-porter-human-female"])
		var cash=game.campaign().gold;await game.act("depart",["east"])
		var arrival=await saved();arrival.state.phase="arrival";arrival.state.journey.phase="delivery";arrival.state.journey.stage=2;arrival.state.journey.hours=4
		arrival.state.journey.party=arrival.state.selected.map(func(id):return game.roster().filter(func(u):return u.id==id)[0].duplicate(true))
		var loaded=await game.update({"op":"campaign_load","data":arrival});await settle()
		check(loaded.get("ok",false),"arrival fixture accepts current selected order quest="+str(quest))
		check(game.campaign().phase=="town" and game.page=="hub" and node("TownHub")!=null,"direct hub arrival quest="+str(quest))
		check(game.save_notice.visible and game.campaign().gold==cash,"arrival notice with no automatic cargo reward quest="+str(quest))
		if quest:
			check(node("HubDeliverCargo")!=null and not node("HubDeliverCargo").disabled,"destination hub has cargo delivery")
			await click("HubFacility_board");check(node("QuestComplete")==null,"board no longer owns delivery action")
			game.navigate("hub");await settle();await click("HubDeliverCargo")
			check(game.campaign().activeQuest==null and game.campaign().gold>cash,"hub delivers and pays existing reward")
			var paid=await saved();var reward=game.campaign().gold
			await game.act("completeQuest",[]);await settle()
			check(game.campaign().gold==reward and await saved()==paid,"repeated delivery cannot pay or consume cargo twice")
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
	var before=await saved();await game.choose_command("move");await game.on_cell(int(game.data.choices.move[0]));await settle()
	await escape_key();check(await saved()==before and game.pending==null,"ESC cancels selected target without action consumption")
	while not game.hud.action_menu:game.cancel();await settle()
	await escape_key()
	var confirmations=game.find_children("*","ConfirmationDialog",true,false).filter(func(w):return w.visible)
	check(confirmations.size()==1 and not game.menu.visible,"normal battle ESC opens retreat confirmation rather than menu")
	if not confirmations.is_empty():confirmations[0].canceled.emit()
	await settle();check(await saved()==before,"cancel retreat preserves equipment inventory and battle")
	var f=FileAccess.open(evidence.path_join("feedback-261019.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
