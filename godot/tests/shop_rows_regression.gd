extends SceneTree
var game
var checks=[]
var seed={}
const MAGE="character_merina"
const GUARD="character_mirei"
const SCOUT="character_shion"
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
func select_with_details(name_: String):
	await tap(name_)
	await tap("SkillDetailsBack")
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func load_at(place: String,gold:=1000,inventory: Dictionary={}):
	game.dialog.close(false)
	var data=seed.duplicate(true);data.state.location=place;data.state.gold=gold
	data.state.characters[MAGE].inventory=inventory.duplicate(true)
	await game.update({"op":"campaign_load","data":data})
	if place!="astaris":await enter_facility("shop")
	await settle()
func run():
	var evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.audio.fast_mode=true;game.checks_fast=true;seed=await saved()
	await load_at("east")
	var shop=game.pages.shop_view
	check(shop.filter_slot=="all" and game.find_child("ShopSlotFilter",true,false).get_item_text(0)=="すべて" and node("ShopSlotFilter").get_item_metadata(0)=="all","default filter is all")
	check(not exists("Product_empty-rightHand"),"empty equipment slots are not purchase products")
	check(exists("ShopInventory") and exists("ShopTransaction") and exists("ShopCatalog") and button("Product_javelin-wood")!=null,"inventory, transaction and catalog share one workspace")
	var info=button("Product_javelin-wood")
	check(info.tooltip_text=="木製の投げ槍" and info.find_children("*","TextureRect",true,false).any(func(icon):return icon.get_meta("ui_icon_id","")=="approved:equipment:javelin-wood"),"product row exposes full name tooltip and individual equipment image")
	var source_javelin=shop.offered().filter(func(g):return g.id=="javelin-wood")[0]
	await select_with_details("Product_javelin-wood")
	check(node("ShopTransaction").find_children("*","Label",true,false).any(func(label):return label.text.contains(source_javelin.flavor)) and node("ShopComparisonNotes").text==source_javelin.note,"inline product details expose full approved flavor and unchanged original note")
	await tap("ShopComparisonProduct")
	var detail=node("SkillDetailsWindow")
	check(detail!=null and detail.visible and detail.find_children("*","Label",true,false).any(func(label):return label.text.contains(source_javelin.note)),"comparison item opens common detail with the original note")
	await tap("SkillDetailsBack")
	var greatsword=button("Product_greatsword-wood")
	shop.select_slot("spear");await settle()
	check(is_instance_valid(greatsword) and not greatsword.is_visible_in_tree() and button("Product_javelin-wood").is_visible_in_tree() and game.shop_slot=="rightHand","spear filter shows javelin, hides greatsword and keeps equipment destination")
	shop.select_slot("all");await settle()
	check(is_instance_valid(greatsword) and greatsword==button("Product_greatsword-wood") and greatsword.is_visible_in_tree(),"clearing filter restores the same greatsword row")
	var before=await saved()
	await tap("RosterMember_"+MAGE);await select_with_details("Product_javelin-wood")
	check(shop.selected_owner()==MAGE and shop.comparison_view.owner_id==MAGE and await saved()==before,"roster selection chooses purchase owner without changing campaign save")
	var buy=button("ShopComparisonBuy");buy.pressed.emit();buy.pressed.emit();await settle()
	check(not game.modal_open() and game.save_notice.visible and game.save_notice.caption.text=="%sへ 木製の投げ槍×1 / 支払100G" % game.member_name(MAGE),"non-modal purchase notice identifies selected recipient, product, count and payment")
	var after=await saved()
	check(after.state.gold==900 and after.state.characters[MAGE].inventory.get("javelin-wood",0)==1,"double click commits exactly one unit to current mage")
	check(after.state.characters[MAGE].weapon==before.state.characters[MAGE].weapon and after.state.characters[GUARD]==before.state.characters[GUARD],"no automatic equipment or other owner's inventory mutation")
	check(shop.stage=="S0" and not game.modal_open(),"successful receipt returns safely to trading workspace")
	await tap("ShopInventoryTab_inventory")
	check(exists("SaleItem_javelin-wood") and shop.sale.owner_id==MAGE,"shop inventory exposes purchased item for selected owner's sale")
	var sale_row=button("SaleItem_javelin-wood")
	if sale_row==null:quit(2);return
	sale_row.grab_focus()
	await select_with_details("SaleItem_javelin-wood")
	var rebuilt_row=button("SaleItem_javelin-wood")
	check(rebuilt_row!=null and rebuilt_row.has_focus(),"closing sale details restores focus to the rebuilt item row")
	await tap("FacilitySalePrepare")
	var inv=shop.sale
	check(inv.quote.get("ownerId")==MAGE and inv.quote.get("itemId")=="javelin-wood" and inv.quote.get("count")==1 and inv.quote.get("afterGold")==1000 and inv.stage=="confirm","sale confirmation shows quantity and payment from actual owner")
	await tap("FacilitySaleCancel")
	check((await saved())==after,"canceling sale leaves purchased item and funds")
	check(inv.stage=="selected" and inv.owner_id==MAGE and inv.item_id=="javelin-wood" and inv.amount==1 and inv.quote.get("ok",false),"cancel preserves sale target and quantity with valid quote, ready to confirm without reselecting")
	await tap("FacilitySalePrepare")
	var sale_dialog=inv.confirmation
	if not is_instance_valid(sale_dialog):quit(2);return
	sale_dialog.confirmed.emit();sale_dialog.confirmed.emit();await settle()
	check(game.campaign().gold==1000 and not game.campaign().characters[MAGE].inventory.has("javelin-wood"),"repeated sale confirmation commits once and removes actual owner's unit")
	game.dialog.close();await settle()
	await load_at("astaris",1000,{"javelin-wood":1});game.navigate("map");await settle();await tap("RosterMember_"+MAGE);await tap("CharacterTab_inventory")
	var inventory=node("CharacterInventoryFilter").get_parent()
	var owned=inventory.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==source_javelin.name)
	check(owned.size()==1 and not exists("FacilitySalePrepare"),"character inventory shows the owned weapon outside the shop")
	if owned.size()==1:owned[0].pressed.emit();await settle();await tap("SkillDetailsBack")
	check(exists("CharacterDiscard") and not exists("FacilitySalePrepare") and not exists("FacilitySaleConfirm"),"character item actions outside shop exclude sale")
	await load_at("east",0,{"hammer-wood":1})
	await select_with_details("Product_javelin-wood")
	check(button("ShopComparisonBuy").disabled and not button("ProductTrial_javelin-wood").disabled,"insufficient money blocks purchase, not trial")
	before=await saved();await shop.confirm_purchase("javelin-wood");await settle()
	check((await saved())==before and shop.stage=="S0" and not game.modal_open(),"programmatic insufficient purchase also leaves state unchanged")
	await tap("ProductTrial_javelin-wood")
	check(game.dialog.window.title=="木人で試す人物" and exists("TrialRecipient_"+GUARD),"trial first asks who after product action")
	await tap("TrialRecipientCancel")
	check((await saved())==before and shop.stage=="S0","cancel trial selection is pure")
	await select_with_details("Product_greatsword-wood");await tap("ProductTrial_greatsword-wood")
	check(button("TrialRecipient_"+SCOUT).disabled and button("TrialRecipient_"+GUARD).disabled and not button("TrialRecipient_"+MAGE).disabled,"trial preserves required STR and occupied left-hand conditions")
	await tap("TrialRecipientCancel")
	await select_with_details("Product_sword-iron-1");await tap("ProductTrial_sword-iron-1")
	check(button("TrialRecipient_"+MAGE).disabled and not button("TrialRecipient_"+GUARD).disabled,"trial preserves existing racial metal restrictions")
	await tap("TrialRecipientCancel")
	await select_with_details("Product_javelin-wood");await tap("ProductTrial_javelin-wood");await tap("TrialRecipient_"+GUARD)
	check(game.data.get("trial") is Dictionary and game.data.trial.characterId==GUARD and game.data.trial.gearId=="javelin-wood","selected character and product enter isolated trial")
	await game.act("endTrial",[]);await settle()
	check(game.page=="shop" and shop.stage=="S0" and (await saved())==before and shop.filter_slot=="all","trial returns to same shop/filter and original complete campaign save")
	await tap("RosterMember_"+MAGE);await tap("ShopInventoryTab_inventory");await select_with_details("SaleItem_hammer-wood");await tap("FacilitySalePrepare")
	await tap("FacilitySaleConfirm")
	await tap("RosterMember_"+GUARD);await select_with_details("Product_staff-wood");await tap("ShopComparisonBuy")
	check(game.campaign().gold==30 and game.campaign().characters[GUARD].inventory.get("staff-wood",0)==1 and not game.campaign().characters[MAGE].inventory.has("hammer-wood"),"one member's sale funds another member's purchase")
	await load_at("west");shop.select_slot("feet");await settle()
	check(shop.offered().all(func(g):return g.slot=="feet") and exists("Product_swift-boots"),"feet filter includes swift boots only in allowed department")
	game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var file=FileAccess.open(evidence.path_join("focused-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
