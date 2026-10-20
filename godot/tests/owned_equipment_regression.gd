extends SceneTree
class DelayedEngine extends Node:
	var actual
	var hold_next=true
	var held=false
	var release=false
	var busy:
		get:return actual.busy
	var disconnected:
		get:return actual.disconnected
	var connection_generation:
		get:return actual.connection_generation
	var handles:
		get:return actual.handles
	var last_error:
		get:return actual.last_error
	func request(payload):
		var hold=hold_next and payload.get("action")=="previewGear"
		if hold:hold_next=false
		var reply=await actual.request(payload)
		if hold:
			held=true
			while not release:await get_tree().process_frame
			held=false
		return reply
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func node(n):return game.find_child(n,true,false)
func frames(n:=10):
	for i in range(n):await process_frame
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting:await process_frame
	await frames()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func tap(n):node(n).pressed.emit();await settle()
func choose_slot(id):
	var chooser=node("OwnedEquipmentSlot")
	for i in range(chooser.item_count):
		if chooser.get_item_metadata(i)==id:chooser.select(i);chooser.item_selected.emit(i);await settle();return
func hover(id):node("OwnedEquipmentActions_"+id).mouse_entered.emit();await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.gold=0;seed.state.characters.guard.inventory={"potion":2,"ether":1,"spear-wood":2,"swift-boots":1,"bow-wood":1,"lone-ring-2":1}
	check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"valid fixture with zero gold outside equipment shop")
	var p=game.pages.party_view;p.open_detail("guard");await settle()
	check(node("EquipmentSlots").get_child_count()==8,"eight equipped slots retained")
	check(node("OwnedEquipment_spear-wood")!=null and node("OwnedEquipment_swift-boots")!=null and node("OwnedEquipment_potion")!=null and node("OwnedEquipment_ether")!=null,"owned list includes all personal equipment and consumables")
	check(node("OwnedEquipment_spear-wood").text.contains("2個"),"quantity comes from same personal inventory")
	var before=await saved()
	await hover("spear-wood")
	check(node("OwnedEquipmentComparison").text.contains("比較する装備枠を選択"),"ambiguous hands require explicit slot")
	await hover("swift-boots")
	check(node("OwnedEquipmentComparison").text.contains("俊足") and not node("OwnedEquipmentComparison").text.contains("人物全体"),"unique slot compares without shop or money gating")
	check(not node("OwnedEquipmentComparison").text.contains("所持金") and not node("OwnedEquipmentComparison").text.contains("購入"),"comparison excludes purchase conditions")
	await hover("lone-ring-2")
	check(node("OwnedEquipmentComparison").text.contains("比較する装備枠を選択"),"accessories also require explicit comparison slot")
	await choose_slot("accessory1");await hover("lone-ring-2")
	check(p.owned_equipment_view.slot=="accessory1" and not node("OwnedEquipmentComparison").text.is_empty(),"accessory one explicitly identified")
	await choose_slot("accessory2");await hover("lone-ring-2")
	check(p.owned_equipment_view.slot=="accessory2" and not node("OwnedEquipmentComparison").text.is_empty(),"accessory two updates comparison target")
	await choose_slot("leftHand");await hover("spear-wood")
	check(node("OwnedEquipment_swift-boots")==null and p.owned_equipment_view.slot=="leftHand" and not node("OwnedEquipmentComparison").text.is_empty(),"slot filters candidates and identifies left hand")
	check((await saved())==before,"hover and filtering do not change save")
	var expected=(await game.engine.request({"op":"campaign","action":"previewGear","args":["guard","spear-wood","leftHand"]})).previewGear.after
	await tap("OwnedEquipmentActions_spear-wood")
	check(p.inventory_view.stage=="confirm" and p.inventory_view.quote.slot=="leftHand" and not p.inventory_view.equipment_comparison.is_empty(),"click reuses equip quote with same slot and comparison")
	await tap("InventoryCancel")
	check((await saved())==before,"cancel leaves equipment counts gold and resources unchanged")
	await tap("StatusTab_0");await tap("OwnedEquipmentActions_spear-wood");await tap("InventoryConfirm")
	var equipped=await saved()
	check(game.roster().filter(func(u):return u.id=="guard")[0].stats==expected,"preview effective stats equal confirmed equipment result")
	check(equipped.state.characters.guard.inventory["spear-wood"]==1 and equipped.state.gold==0,"confirmed equip consumes one owned item with no purchase")
	await tap("StatusTab_0")
	check(node("OwnedEquipment_spear-wood").text.contains("1個"),"filtered view refreshes after equipment change")
	await all_inventory()
	check(node("OwnedEquipment_spear-wood")!=null and node("OwnedEquipment_potion")!=null and node("OwnedEquipment_ether")!=null,"original mixed inventory retains equipment and consumables")
	check(node("OwnedEquipment_spear-wood").text.contains("1個"),"both views show same updated quantity")
	await all_inventory();await tap("OwnedEquipment_spear-wood")
	check(node("InventoryTransfer")!=null and node("InventoryDiscard")!=null and node("InventoryEquip")!=null,"actions reuse original transfer discard and equip flow")
	await tap("InventoryTransfer");await tap("InventoryTarget_porter");await tap("InventoryConfirm");await tap("StatusTab_0")
	check(node("OwnedEquipment_spear-wood")==null,"transferred last copy disappears from equipment filter")
	await all_inventory()
	check(node("OwnedEquipment_spear-wood")==null,"transferred last copy also disappears from mixed inventory")
	game.dialog.close(false);await settle()
	check((await game.update({"op":"campaign_load","data":equipped})).get("ok",false),"save reload retains inventory without schema change")
	p.open_detail("porter");await settle()
	check(node("OwnedEquipment_spear-wood")==null and node("OwnedEquipmentOwner").text.contains(game.member_name("porter")),"changing person never shows previous owner stock")
	game.dialog.close(false);await settle();p.open_detail("guard");await settle()
	await choose_slot("rightHand");await hover("bow-wood")
	check(node("OwnedEquipmentComparison").text.contains("装備不可"),"two handed conflict explained without hiding comparison")
	var unchanged=await saved();await tap("OwnedEquipmentActions_bow-wood")
	check(p.detail_tab==0 and (await saved())==unchanged,"ineligible equipment never enters transaction")
	node("OwnedEquipmentActions_spear-wood").focus_entered.emit();await settle()
	check(not node("OwnedEquipmentComparison").text.is_empty() and not node("OwnedEquipmentComparison").text.contains("+0"),"keyboard focus exposes effective comparison and current resources")
	var actual=game.engine;var delayed=DelayedEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
	node("OwnedEquipmentActions_spear-wood").mouse_entered.emit()
	while not delayed.held:await process_frame
	await hover("bow-wood");var latest=node("OwnedEquipmentComparison").text;delayed.release=true;await settle()
	check(node("OwnedEquipmentComparison").text==latest and latest.contains("装備不可"),"late earlier hover cannot overwrite newer comparison")
	game.engine=actual;delayed.queue_free();await frames()
	node("OwnedEquipmentActions_spear-wood").mouse_entered.emit();game.dialog.close(false);await settle()
	check(not game.modal_open() and (await saved())==unchanged,"closing during asynchronous hover leaves state unchanged")
	await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle()
	var cargo=str(game.campaign().activeQuest.cargoItemId);p.open_detail("porter");await settle()
	check(p.owned_equipment_view.entries("porter").any(func(e):return e.id==cargo) and node("OwnedEquipmentActions_"+cargo)==null,"mixed owner inventory includes cargo without an equip action")
	await all_inventory()
	check(game.find_children("*","Button",true,false).any(func(b):return b.get_meta("ui_key","")=="inventory_porter_"+cargo),"quest cargo remains in original mixed inventory")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("owned-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(r):return r.passed) else 1)

func all_inventory():
	var chooser=game.find_child("OwnedEquipmentSlot",true,false)
	chooser.select(0);chooser.item_selected.emit(0);await settle()
