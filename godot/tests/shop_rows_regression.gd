extends SceneTree
var game
var checks=[]
var seed={}
func _initialize():call_deferred("run")
func check(ok,label):
	checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
	for i in range(4):await process_frame
func nodes():return game.find_children("*","",true,false)
func node(name_: String):return game.find_child(name_,true,false)
func button(name_: String):
	var matches=nodes().filter(func(n):return n is Button and n.name==name_)
	return matches[0] if not matches.is_empty() else null
func exists(name_: String):return nodes().any(func(n):return n.name==name_)
func tap(name_: String):
	var control=button(name_)
	if control==null:push_error("Missing button "+name_);quit(2);return
	control.pressed.emit();await settle()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func load_at(place: String,gold:=1000,inventory: Dictionary={}):
	game.dialog.close(false)
	var data=seed.duplicate(true);data.state.location=place;data.state.gold=gold
	data.state.characters.mage.inventory=inventory.duplicate(true)
	await game.update({"op":"campaign_load","data":data});await enter_facility("shop");await settle()
func run():
	var evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.audio.fast_mode=true;game.checks_fast=true;seed=await saved()
	await load_at("east")
	var shop=game.pages.shop_view
	check(shop.filter_slot=="all" and game.find_child("ShopSlotFilter",true,false).get_item_text(0)=="すべて" and node("ShopSlotFilter").get_item_metadata(0)=="all","default filter is all")
	check(not exists("ShopMemberPortrait") and not exists("ShopModes") and not exists("GearQuote") and not exists("AddPurchasePlan"),"removed equipment target, tabs, comparison and purchase plan UI")
	check(not exists("Product_empty-rightHand"),"empty equipment slots are not purchase products")
	check(exists("ShopInventory") and exists("ShopTransaction") and exists("ShopCatalog") and button("Product_javelin-wood")!=null,"inventory, transaction and catalog share one workspace")
	var info=button("Product_javelin-wood")
	check(info.tooltip_text=="木製の投げ槍" and info.find_children("*","TextureRect",true,false).any(func(icon):return icon.get_meta("ui_icon_id","")=="approved:equipment:javelin-wood"),"product row exposes full name tooltip and individual equipment image")
	var source_javelin=shop.offered().filter(func(g):return g.id=="javelin-wood")[0]
	await tap("Product_javelin-wood")
	check(node("ShopTransaction").find_children("*","Label",true,false).any(func(label):return label.text.contains(source_javelin.flavor)) and node("ShopComparisonNotes").text==source_javelin.note,"inline product details expose full approved flavor and unchanged original note")
	shop.open_comparison("javelin-wood");await settle()
	var compared=shop.comparison_view.item()
	check(node("ShopTransaction").find_children("*","Label",true,false).any(func(label):return label.text.contains(compared.flavor)) and exists("ShopComparisonNotes") and node("ShopComparisonNotes").text==compared.note,"shop comparison exposes full approved flavor and original note for a note-bearing item")
	game.dialog.close(false);await settle()
	shop.select_slot("spear");await settle()
	check(not exists("Product_greatsword-wood") and exists("Product_javelin-wood") and game.shop_slot=="rightHand","filter changes product list, not equipment destination")
	shop.select_slot("all");await settle()
	var before=await saved()
	await tap("RosterMember_mage");await tap("Product_javelin-wood")
	check(shop.selected_owner()=="mage" and shop.comparison_view.owner_id=="mage" and await saved()==before,"roster selection chooses purchase owner without changing campaign save")
	await tap("ShopComparisonBuy")
	check(game.dialog.window.title=="購入の確認" and exists("PurchasePayment") and not exists("PurchaseRecipient_mage") and game.dialog.body.find_children("*","Label",true,false).any(func(label):return label.text.contains(game.member_name("mage")) and label.text.contains("インベントリへ購入")),"payment consent identifies the already selected recipient")
	check((await saved())==before,"opening payment consent is pure")
	await tap("PurchaseDecline")
	check((await saved())==before and shop.stage=="S0","declining consent leaves money/inventory unchanged")
	await tap("ShopComparisonBuy");game.dialog.close();await settle()
	check((await saved())==before and shop.stage=="S0" and shop.selected_owner()=="mage","closing consent preserves full save and selected recipient")
	await tap("ShopComparisonBuy")
	var agree=button("PurchaseAgree");agree.pressed.emit();agree.pressed.emit();await settle()
	var after=await saved()
	check(after.state.gold==900 and after.state.characters.mage.inventory.get("javelin-wood",0)==1,"double click commits exactly one unit to mage")
	check(after.state.characters.mage.weapon==before.state.characters.mage.weapon and after.state.characters.guard==before.state.characters.guard,"no automatic equipment or other owner's inventory mutation")
	check(shop.stage=="S0" and not game.modal_open(),"successful receipt returns safely to trading workspace")
	game.pages.party_view.open_detail("mage");await settle()
	check(game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="mage","personal status remains available during shop transaction")
	game.dialog.close();await settle()
	check(exists("SaleItem_javelin-wood") and shop.sale.owner_id=="mage","shop inventory exposes purchased item for selected owner's sale")
	await tap("SaleItem_javelin-wood");await tap("FacilitySalePrepare")
	var inv=shop.sale
	check(inv.quote.get("ownerId")=="mage" and inv.quote.get("itemId")=="javelin-wood" and inv.quote.get("count")==1 and inv.quote.get("afterGold")==1000 and inv.stage=="confirm","sale confirmation shows quantity and payment from actual owner")
	inv.confirmation.canceled.emit();await settle()
	check((await saved())==after,"canceling sale leaves purchased item and funds")
	check(inv.stage=="selected" and inv.owner_id=="mage" and inv.item_id=="javelin-wood" and inv.amount==1 and inv.quote.get("ok",false),"cancel preserves sale target and quantity with valid quote, ready to confirm without reselecting")
	await tap("FacilitySalePrepare")
	var sale_dialog=inv.confirmation;sale_dialog.confirmed.emit();sale_dialog.confirmed.emit();await settle()
	check(game.campaign().gold==1000 and not game.campaign().characters.mage.inventory.has("javelin-wood"),"repeated sale confirmation commits once and removes actual owner's unit")
	game.dialog.close();await settle()
	await load_at("astaris",1000,{"javelin-wood":1});game.navigate("board");await settle();game.pages.party_view.open_inventory("mage");await settle()
	check(not exists("OwnedInventorySell_javelin-wood"),"sale is absent outside equipment shop")
	await tap("OwnedEquipment_javelin-wood");check(not exists("InventorySell"),"item action has no sale outside shop")
	await load_at("east",0)
	await tap("Product_javelin-wood")
	check(button("ShopComparisonBuy").disabled and not button("ProductTrial_javelin-wood").disabled,"insufficient money blocks purchase, not trial")
	before=await saved();await shop.confirm_purchase("javelin-wood");await settle()
	check((await saved())==before and shop.stage=="S0" and not game.modal_open(),"programmatic insufficient purchase also leaves state unchanged")
	await tap("ProductTrial_javelin-wood")
	check(game.dialog.window.title=="木人で試す人物" and exists("TrialRecipient_guard"),"trial first asks who after product action")
	await tap("TrialRecipientCancel")
	check((await saved())==before and shop.stage=="S0","cancel trial selection is pure")
	await tap("Product_greatsword-wood");await tap("ProductTrial_greatsword-wood")
	check(button("TrialRecipient_archer").disabled and button("TrialRecipient_guard").disabled and not button("TrialRecipient_mage").disabled,"trial preserves required STR and occupied left-hand conditions")
	await tap("TrialRecipientCancel")
	await tap("Product_sword-iron-1");await tap("ProductTrial_sword-iron-1")
	check(button("TrialRecipient_mage").disabled and not button("TrialRecipient_guard").disabled,"trial preserves existing racial metal restrictions")
	await tap("TrialRecipientCancel")
	await tap("Product_javelin-wood");await tap("ProductTrial_javelin-wood");await tap("TrialRecipient_guard")
	check(game.data.get("trial") is Dictionary and game.data.trial.characterId=="guard" and game.data.trial.gearId=="javelin-wood","selected character and product enter isolated trial")
	await game.act("endTrial",[]);await settle()
	check(game.page=="shop" and shop.stage=="S0" and (await saved())==before and shop.filter_slot=="all","trial returns to same shop/filter and original complete campaign save")
	await load_at("west");shop.select_slot("feet");await settle()
	check(shop.offered().all(func(g):return g.slot=="feet") and exists("Product_swift-boots"),"feet filter includes swift boots only in allowed department")
	game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var file=FileAccess.open(evidence.path_join("focused-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)

func all_inventory():
	var chooser=game.find_child("OwnedEquipmentSlot",true,false)
	chooser.select(0);chooser.item_selected.emit(0);await settle()

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
