extends "res://tests/ui_feedback2_20261016.gd"
func empty_message_fits() -> bool:
	var overlay=node("CharacterInventoryFilter").get_parent()
	for label in overlay.find_children("*","Label",true,false):
		if label.text=="アイテムはありません":
			return label.size.x>=overlay.size.x*.9 and label.size.y<=60
	return false
func run():
	create_timer(70).timeout.connect(func():print("FAIL empty inventory watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved()
	seed.state.characters.archer.inventory={}
	seed.state.characters.guard.inventory={"potion":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var before=await saved()
	game.navigate("map");await settle()
	await click("RosterMember_archer")
	check(game.page=="character" and game.pages.party_uid=="archer" and not game.modal_open(),"roster opens the selected character workspace")
	await click("CharacterTab_inventory")
	check(empty_message_fits(),"empty inventory message spans the inventory column")
	var filter=node("CharacterInventoryFilter")
	for i in range(filter.item_count):
		if filter.get_item_metadata(i)=="rightHand":
			filter.select(i);filter.item_selected.emit(i);break
	await settle()
	check(node("CharacterInventoryFilter").get_item_metadata(node("CharacterInventoryFilter").selected)=="rightHand" and empty_message_fits(),"filtered empty inventory message fits the column")
	filter=node("CharacterInventoryFilter");filter.select(0);filter.item_selected.emit(0);await settle()
	await click("RosterMember_guard")
	var overlay=node("CharacterInventoryFilter").get_parent()
	check(overlay.find_children("*","Button",true,false).any(func(b):return b.tooltip_text==game.campaign().inventoryByCharacter.guard.get("entries")[0].name),"nonempty owner shows the potion")
	await click("RosterMember_archer")
	check(game.pages.party_uid=="archer" and empty_message_fits() and node("CharacterInventoryFilter").get_parent().find_children("*","ScrollContainer",true,false)[0].find_children("*","Button",true,false).is_empty(),"empty owner inherits no item buttons")
	check(await saved()==before,"roster, inventory filters and owner changes preserve the complete save")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
