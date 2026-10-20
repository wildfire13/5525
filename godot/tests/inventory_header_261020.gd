extends "res://tests/feedback_261019_3.gd"
func filter_to(value):
	var chooser=node("OwnedEquipmentSlot")
	for i in range(chooser.item_count):
		if str(chooser.get_item_metadata(i))==value:chooser.select(i);chooser.item_selected.emit(i);break
	await settle()
func layout_check():
	check(node("StatusTab_3")==null and node("OwnedInventoryHeader")!=null,"no inventory tab; real header is present")
	check(node("OwnedEquipmentOwner") is Label and node("OwnedEquipmentSlot") is OptionButton,"owner column heading and filter are in header")
	check(absf(node("OwnedInventoryHeader").global_position.x-node("StatusOwnedInventory").global_position.x)<2 and absf(node("OwnedInventoryHeader").get_global_rect().end.x-node("StatusOwnedInventory").get_global_rect().end.x)<2,"header and list edges align")
	check(node("OwnedInventoryHeader").get_global_rect().end.y<=node("StatusOwnedInventory").global_position.y,"header precedes its list")
	check(node("StatusEquipmentSplit").get_global_rect().end.x<=game.dialog.window.size.x-8,"two columns fit status width")
func run():
	create_timer(120).timeout.connect(func():print("FAIL inventory header watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.characters.guard.inventory={"potion":2,"spear-wood":2,"swift-boots":1};seed.state.characters.guard.hp=1
	await game.update({"op":"campaign_load","data":seed});await settle()
	await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle()
	var cargo=str(game.campaign().activeQuest.cargoItemId);var before=await saved();var p=game.pages.party_view
	for resolution in [Vector2i(1920,1080),Vector2i(1364,1024)]:
		root.size=resolution;p.open_detail("guard");await settle();game.dialog.window.size=Vector2i(resolution.x,662);await settle()
		for tab in range(3):
			await click("StatusTab_"+str(tab));layout_check()
			check(node("OwnedEquipment_potion")!=null and node("OwnedEquipment_spear-wood")!=null,"inventory always visible next to left detail "+str(tab))
		await filter_to("rightHand");check(node("OwnedEquipment_potion")==null and node("OwnedEquipment_spear-wood")!=null,"equipment filter preserved")
		await click("StatusTab_1");check(p.owned_equipment_view.slot=="rightHand" and node("OwnedEquipment_spear-wood")!=null,"left tab preserves filter")
		await filter_to("");await click("OwnedEquipment_potion");await click("InventoryDiscard");await click("InventoryPrepareDiscard");await consent(false)
		check(await saved()==before and p.detail_tab==1 and node("OwnedEquipment_potion")!=null,"discard cancel retains left tab and full state")
		layout_check();await filter_to("rightHand");await click("OwnedEquipmentActions_spear-wood");await consent(false)
		check(p.detail_tab==1 and await saved()==before,"equipment cancel on growth tab preserves left tab and state")
		await click("PartyFace_porter");await filter_to("items");var cargo_rows=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="inventory_porter_"+cargo);check(cargo_rows.size()==1,"cargo stays in persistent owner list")
		if not cargo_rows.is_empty():cargo_rows[0].pressed.emit();await settle()
		check(node("InventoryTransfer")!=null and node("InventoryDiscard").disabled,"cargo actions retain restrictions")
		await click("PartyFace_archer");check(node("OwnedInventoryEmpty")!=null and node("OwnedEquipment_potion")==null and node("StatusInventoryActions")==null,"person switch resets action and shows empty owner")
		check(node("OwnedEquipmentOwner").text==game.member_name("archer")+"のインベントリ" and game.dialog.window.size==Vector2i(resolution.x,662),"owner header and saved size follow portrait switch")
		await click("PartyFace_guard")
		for u in game.campaign().roster:
			if u.id=="guard":u.name="とても長い名前を持つ人物の表示確認用ガロ"
		p.refresh_modal();await settle();layout_check()
		check(node("OwnedEquipmentOwner").tooltip_text.contains("とても長い名前"),"long owner title is available on hover")
		game.dialog.close();await settle()
		await game.update({"op":"campaign_load","data":before});await settle()
	check(await saved()==before,"all inspection and cancellation preserves inventory equipment and cargo")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
