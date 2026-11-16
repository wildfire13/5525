extends "res://tests/ui_feedback2_20261016.gd"
func payload(kind: String,id: String,owner: String="") -> Dictionary:
	return {"kind":kind,"item":id,"owner":owner,"connection":game.engine.connection_generation,"token":game.campaign().get("inventoryToken"),"epoch":game.pages.epoch}
func run():
	create_timer(120).timeout.connect(func():print("FAIL feedback21 watchdog");quit(2))
	if evidence.is_empty():quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.location="east";seed.state.gold=1000;seed.state.characters.guard.inventory={"spear-wood":1,"greatsword-wood":1,"lone-ring-1":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	game.pages.party_view.open_inventory("guard");await settle()
	var before=await saved()
	for spec in [["spear-wood","feet",false],["greatsword-wood","leftHand",false],["lone-ring-1","accessory2",true],["spear-wood","leftHand",true]]:
		var entry=game.campaign().inventoryByCharacter.guard.entries.filter(func(e):return e.id==spec[0])[0]
		var row=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==entry.name)[0]
		row.pressed.emit();await settle()
		var selector=node("CharacterEquipSlot");var index=-1
		for i in range(selector.item_count):
			if selector.get_item_metadata(i)==spec[1]:index=i
		if index>=0:
			selector.select(index);selector.item_selected.emit(index);await settle()
		check((index>=0 and not node("CharacterEquip").disabled)==spec[2],"equip slot eligibility "+str(spec))
	var workspace=game.pages.party_view.workspace
	var stale=workspace.payload(workspace.picked,"transfer",null);stale.token="stale"
	workspace.drop(stale,"mage");await settle()
	check(await saved()==before,"slot previews and stale transfer preserve full save")
	await click("CharacterEquip")
	check(game.campaign().characters.guard.leftHand=="spear-wood","equip applies to specified hand")
	await enter_facility("shop");await settle()
	var shop=game.pages.shop_view
	check(node("ShopSlotFilter").get_parent()!=node("ShopProductsScroll").get_child(0),"shop filter is outside scrolling list")
	var data=payload("shop_product","spear-wood")
	check(shop.can_drop_product(data,"mage"),"shop drop accepts selected recipient")
	before=await saved();await shop.confirm_purchase("spear-wood","mage");await settle()
	check(await saved()==before and node("PurchaseAgree")!=null,"purchase drop awaits consent without mutation")
	await click("PurchaseDecline");check(await saved()==before,"purchase drop cancel preserves state")
	await shop.confirm_purchase("spear-wood","mage");await settle();await click("PurchaseAgree")
	check(game.campaign().characters.mage.inventory.get("spear-wood",0)==1 and game.campaign().characters.mage.weapon==before.state.characters.mage.weapon,"confirmed purchase enters recipient inventory without equipping")
	var after=await saved();await shop.buy(shop.receipt,"mage",shop.generation);check(await saved()==after,"duplicate purchase confirmation has no effect")
	var south=seed.duplicate(true);south.state.location="south"
	await game.update({"op":"campaign_load","data":south});await enter_facility("shop");await settle()
	before=await saved();await shop.confirm_purchase("potion","mage");await settle();await click("PurchaseDecline")
	check(await saved()==before,"consumable drop decline is pure")
	await shop.confirm_purchase("potion","mage");await settle();await click("PurchaseAgree")
	check(game.campaign().characters.mage.inventory.get("potion",0)==int(before.state.characters.mage.inventory.get("potion",0))+1,"consumable drop buys for exact recipient")
	var fixture=battle_fixture();var heal=fixture.guard.duplicate(true);heal.state.battle.actor="mage"
	for u in heal.state.battle.units:
		u.next=1000
		if u.id=="mage":u.next=1;u.hp=20
	await game.update({"op":"campaign_load","data":heal});await settle()
	game.hud.open_skills();await settle();await click("BattleSkill_mage")
	check(node("BattleSkill_mage").get_meta("selected",false) and game.hud.buttons.skill.get_meta("selected",false) and not node("BattleSkill_mage").text.begins_with("● "),"selected skill and its parent category share selection metadata without a text mark")
	check(node("ActionCost").text=="消費MP: 1" and node("TargetSummary").text=="クリックしてターゲットを選択してください。","actual MP cost and single targeting instruction")
	await game.on_cell(int(game.hud.acting().pos));await settle()
	check(node("Inspect_hp")!=null and not game.find_children("*","Button",true,false).any(func(b):return b.text=="能力・詳細"),"target abilities displayed inline without detail button")
	check(node("BattleConsent")==null and node("ActionAvailability").text.is_empty(),"redundant success and consent text removed")
	before=await saved();game.cancel();await settle();check(await saved()==before,"skill cancel consumes no MP or action")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
