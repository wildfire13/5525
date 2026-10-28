extends "res://tests/inventory_header_261020.gd"
func payload(kind: String,id: String,owner: String="") -> Dictionary:
	return {"kind":kind,"item":id,"owner":owner,"connection":game.engine.connection_generation,"token":game.campaign().get("inventoryToken"),"epoch":game.pages.epoch}
func run():
	create_timer(120).timeout.connect(func():print("FAIL feedback21 watchdog");quit(2))
	if evidence.is_empty():quit(2);return
	root.size=Vector2i(1364,1024);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.location="east";seed.state.gold=1000;seed.state.characters.guard.inventory={"spear-wood":1,"greatsword-wood":1,"lone-ring-1":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var p=game.pages.party_view;p.open_detail("guard");await settle()
	var owned=p.owned_equipment_view;var before=await saved()
	check(owned.can_drop(payload("owned_equipment","spear-wood","guard"),"guard","leftHand"),"drop respects left hand")
	check(not owned.can_drop(payload("owned_equipment","spear-wood","guard"),"guard","feet"),"invalid slot rejects drop")
	check(not owned.can_drop(payload("owned_equipment","greatsword-wood","guard"),"guard","leftHand"),"two handed weapon rejects left hand")
	check(owned.can_drop(payload("owned_equipment","lone-ring-1","guard"),"guard","accessory2"),"accessory drop respects second slot")
	var stale=payload("owned_equipment","spear-wood","guard");stale.token="stale"
	check(not owned.can_drop(stale,"guard","leftHand"),"stale drag rejects")
	await owned.drop_equipment(payload("owned_equipment","spear-wood","guard"),"guard","leftHand");await settle()
	check(p.inventory_view.stage=="confirm" and await saved()==before,"equipment drop opens pure confirmation")
	await consent(false);check(await saved()==before,"drop cancel preserves complete state")
	await owned.drop_equipment(payload("owned_equipment","spear-wood","guard"),"guard","leftHand");await settle();await consent(true)
	check(game.campaign().characters.guard.leftHand=="spear-wood","confirmed drop equips specified hand")
	game.dialog.close();await enter_facility("shop");await settle()
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
	check(node("BattleSkill_mage").text.begins_with("● ") and game.hud.buttons.skill.text.begins_with("● "),"selected skill and its parent category both carry selection marks")
	check(node("ActionCost").text=="消費MP: 1" and node("TargetSummary").text=="クリックしてターゲットを選択してください。","actual MP cost and single targeting instruction")
	await game.on_cell(int(game.hud.acting().pos));await settle()
	check(node("Inspect_hp")!=null and not game.find_children("*","Button",true,false).any(func(b):return b.text=="能力・詳細"),"target abilities displayed inline without detail button")
	check(node("BattleConsent")==null and node("ActionAvailability").text.is_empty(),"redundant success and consent text removed")
	before=await saved();game.cancel();await settle();check(await saved()==before,"skill cancel consumes no MP or action")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
