extends "res://tests/feedback_261019_3.gd"
const INVENTORY_OWNER="character_mirei"
const INVENTORY_PORTER="character_yuno"
const INVENTORY_SCOUT="character_shion"
func character_item(uid: String,id: String):
	var filter=node("CharacterInventoryFilter")
	var entries=game.campaign().inventoryByCharacter[uid].entries
	for entry in entries:
		if entry.id==id:
			for row in filter.get_parent().find_children("*","Button",true,false):
				if row.tooltip_text==entry.name:return row
	return null

func filter_to(value):
	var chooser=node("CharacterInventoryFilter")
	for i in range(chooser.item_count):
		if chooser.get_item_metadata(i)==value:
			chooser.select(i);chooser.item_selected.emit(i);await settle();return
	check(false,"inventory filter exists "+value)

func run():
	create_timer(120).timeout.connect(func():print("FAIL inventory header watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.characters[INVENTORY_OWNER].inventory={"potion":2,"spear-wood":2,"swift-boots":1};seed.state.characters[INVENTORY_OWNER].hp=1
	await game.update({"op":"campaign_load","data":seed});await settle()
	await game.act("accept",[game.campaign().board[0].id,INVENTORY_PORTER]);await settle()
	var cargo=str(game.campaign().activeQuest.cargoItemId);var before=await saved();var p=game.pages.party_view
	p.open_inventory(INVENTORY_OWNER);await settle();await filter_to("rightHand")
	check(character_item(INVENTORY_OWNER,"potion")==null and character_item(INVENTORY_OWNER,"spear-wood")!=null,"right hand filter keeps compatible equipment")
	await click("RosterMember_"+INVENTORY_PORTER);await filter_to("items")
	var row=character_item(INVENTORY_PORTER,cargo)
	check(row!=null,"quest cargo appears in the carrier's inventory")
	if row!=null:
		row.pressed.emit();await settle()
		check(node("CharacterDiscard").disabled,"quest cargo cannot be discarded")
		check(p.workspace.payload(p.workspace.picked,"transfer",null).allowed.has(INVENTORY_SCOUT),"quest cargo can transfer to a companion with room")
	await click("RosterMember_"+INVENTORY_SCOUT)
	check(p.workspace.picked.is_empty() and character_item(INVENTORY_SCOUT,"potion")==null,"changing owner clears previous selection and stock")
	check(await saved()==before,"inventory inspection preserves inventory equipment and cargo")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
