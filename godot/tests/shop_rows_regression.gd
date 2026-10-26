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
	game.audio.fast_mode=true;game.checks_fast=true;seed=await saved()
	await load_at("east")
	var shop=game.pages.shop_view
	check(shop.filter_slot=="all" and game.find_child("ShopSlotFilter",true,false).get_item_text(0)=="商品リスト（すべて）","default filter is all")
	check(not exists("ShopMemberPortrait") and not exists("ShopModes") and not exists("GearQuote") and not exists("AddPurchasePlan"),"removed equipment target, tabs, comparison and purchase plan UI")
	check(not exists("Product_empty-rightHand"),"empty equipment slots are not purchase products")
	check(button("ProductBuy_javelin-wood")!=null and button("ProductTrial_javelin-wood")!=null,"purchase and trial are per product row")
	var info=button("Product_javelin-wood")
	check(info.heading=="木製の投げ槍" and info.tooltip_text.contains("通常攻撃射程：3") and info.get_script().resource_path=="res://equipment_tooltip.gd","product hover reuses real equipment tooltip")
	shop.select_slot("spear");await settle()
	check(not exists("Product_greatsword-wood") and exists("Product_javelin-wood") and game.shop_slot=="rightHand","filter changes product list, not equipment destination")
	shop.select_slot("all");await settle()
	var before=await saved()
	await tap("ProductBuy_javelin-wood")
	check(game.dialog.window.title=="購入の確認" and exists("PurchasePayment") and not exists("PurchaseRecipient_mage"),"payment consent precedes recipient selection")
	check((await saved())==before,"opening payment consent is pure")
	await tap("PurchaseDecline")
	check((await saved())==before and shop.stage=="S0","declining consent leaves money/inventory unchanged")
	await tap("ProductBuy_javelin-wood");await tap("PurchaseAgree")
	check(game.dialog.window.title=="受取人の選択" and exists("PurchaseRecipient_mage") and game.campaign().gold==1000,"recipient selection appears only after consent; no debit yet")
	await tap("PurchaseRecipientCancel")
	check((await saved())==before and shop.stage=="S0","canceling recipient leaves full save unchanged")
	await tap("ProductBuy_javelin-wood");await tap("PurchaseAgree")
	var recipient=button("PurchaseRecipient_mage");recipient.pressed.emit();recipient.pressed.emit();await settle()
	var after=await saved()
	check(after.state.gold==900 and after.state.characters.mage.inventory.get("javelin-wood",0)==1,"double click commits exactly one unit to mage")
	check(after.state.characters.mage.weapon==before.state.characters.mage.weapon and after.state.characters.guard==before.state.characters.guard,"no automatic equipment or other owner's inventory mutation")
	check(shop.stage=="S0" and not game.modal_open(),"successful receipt returns safely to product list")
	await tap("PartyFace_mage")
	check(game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="mage","shop lower face still opens personal status")
	await all_inventory()
	check(exists("OwnedInventorySell_javelin-wood"),"shop inventory exposes per-item sale")
	await tap("OwnedInventorySell_javelin-wood");await tap("InventoryPrepareSale")
	var inv=game.pages.party_view.inventory_view
	check(inv.quote.get("action")=="sell" and inv.quote.get("count")==1 and inv.quote.get("afterGold")==1000,"sale confirmation shows quantity and payment from actual owner")
	await tap("InventoryCancel")
	check((await saved())==after,"canceling sale leaves purchased item and funds")
	check(inv.stage=="targets" and inv.owner_id=="mage" and inv.item_id=="javelin-wood" and inv.amount==1 and inv.quote.is_empty(),"cancel preserves sale target and quantity, ready to requote without reselecting")
	await tap("InventoryPrepareSale");await tap("InventoryConfirm")
	check(game.campaign().gold==1000 and not game.campaign().characters.mage.inventory.has("javelin-wood"),"sale commits once, removes actual owner's unit")
	game.dialog.close();await settle()
	await load_at("astaris",1000,{"javelin-wood":1});game.navigate("board");await settle();game.pages.party_view.open_inventory("mage");await settle()
	check(not exists("OwnedInventorySell_javelin-wood"),"sale is absent outside equipment shop")
	await tap("OwnedEquipment_javelin-wood");check(not exists("InventorySell"),"item action has no sale outside shop")
	await load_at("east",0)
	check(button("ProductBuy_javelin-wood").disabled and not button("ProductTrial_javelin-wood").disabled,"insufficient money blocks purchase, not trial")
	before=await saved();await shop.confirm_purchase("javelin-wood");await settle()
	check((await saved())==before and shop.stage=="S0" and not game.modal_open(),"programmatic insufficient purchase also leaves state unchanged")
	await tap("ProductTrial_javelin-wood")
	check(game.dialog.window.title=="木人で試す人物" and exists("TrialRecipient_guard"),"trial first asks who after product action")
	await tap("TrialRecipientCancel")
	check((await saved())==before and shop.stage=="S0","cancel trial selection is pure")
	await tap("ProductTrial_greatsword-wood")
	check(button("TrialRecipient_archer").disabled and button("TrialRecipient_guard").disabled and not button("TrialRecipient_mage").disabled,"trial preserves required STR and occupied left-hand conditions")
	await tap("TrialRecipientCancel")
	await tap("ProductTrial_sword-iron-1")
	check(button("TrialRecipient_mage").disabled and not button("TrialRecipient_guard").disabled,"trial preserves existing racial metal restrictions")
	await tap("TrialRecipientCancel")
	await tap("ProductTrial_javelin-wood");await tap("TrialRecipient_guard")
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
