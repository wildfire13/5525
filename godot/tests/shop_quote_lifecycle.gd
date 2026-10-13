extends SceneTree
class HeldEngine extends Node:
	var actual
	var hold_action=""
	var held=false
	var release=false
	var busy:
		get:return actual.busy or held
	var disconnected:
		get:return actual.disconnected
	var connection_generation:
		get:return actual.connection_generation
	var handles:
		get:return actual.handles
	var last_error:
		get:return actual.last_error
	func request(payload: Dictionary) -> Dictionary:
		var reply=await actual.request(payload)
		if str(payload.get("action",""))==hold_action:
			hold_action="";held=true
			while not release:await get_tree().process_frame
			held=false
		return reply
var game
var actual
var gate
var checks=[]
func _initialize():call_deferred("run")
func frames(n:=12):
	for i in range(n):await process_frame
func check(ok,label):
	checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	await frames()
	while game.locked or game.engine.busy or game.presenting:await process_frame
	await frames()
func hold(action: String,name_: String):
	gate.hold_action=action;gate.release=false;game.find_child(name_,true,false).pressed.emit()
	var deadline=Time.get_ticks_msec()+4000
	while not gate.held and Time.get_ticks_msec()<deadline:await process_frame
	if not gate.held:push_error("Response not held "+action);quit(2)
func saved():return (await actual.request({"op":"campaign_save"})).data
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine
	var data=await saved();data.state.location="east";data.state.gold=1000
	await game.update({"op":"campaign_load","data":data});game.navigate("shop");await settle()
	var before=await saved();gate=HeldEngine.new();gate.actual=actual;game.add_child(gate);game.engine=gate
	var shop=game.pages.shop_view
	for action in ["purchaseQuote","previewGear"]:
		var name_="ProductBuy_javelin-wood" if action=="purchaseQuote" else "ProductTrial_javelin-wood"
		await hold(action,name_);var ticket=shop.generation
		game.town_back.pressed.emit();await frames()
		check(game.page=="board" and shop.stage=="S0" and shop.generation>ticket,action+" exit cancels waiting generation immediately")
		gate.release=true;await settle()
		check(not game.modal_open() and shop.stage=="S0",action+" delayed reply opens no dialog after exit")
		game.navigate("shop");await frames()
		check(not shop.busy(),action+" reentry is usable, not stuck S1")
		check((await saved())==before,action+" exit preserves complete campaign save")
	await hold("purchaseQuote","ProductBuy_javelin-wood")
	game.town_back.pressed.emit();game.navigate("shop");await frames()
	game.find_child("ProductBuy_sword-wood",true,false).pressed.emit();await frames(40)
	check(game.modal_open() and shop.consent.get("gearId")=="sword-wood","new purchase after reentry has its own confirmation")
	gate.release=true;await settle()
	check(game.modal_open() and shop.consent.get("gearId")=="sword-wood","obsolete purchase does not replace newer confirmation")
	game.dialog.close();await frames()
	await hold("previewGear","ProductTrial_javelin-wood")
	game.pages.party_view.open_detail("mage");await frames()
	check(game.modal_open() and game.dialog.window.title=="ステータス" and shop.stage=="S0","new personal detail cancels pending trial preview")
	game.dialog.close();await frames();gate.release=true;await settle()
	check(not game.modal_open() and shop.stage=="S0","closed newer detail does not revive old trial selection")
	await hold("purchaseQuote","ProductBuy_javelin-wood")
	var dialog=game.confirm("別の操作",func():pass);await frames();dialog.hide();dialog.queue_free();await frames()
	gate.release=true;await settle()
	check(not game.modal_open() and shop.stage=="S0","closing a newer confirmation does not revive old purchase")
	await hold("purchaseQuote","ProductBuy_javelin-wood")
	game.load_dialog();await frames()
	for child in game.get_children():
		if child is FileDialog:child.hide();child.queue_free()
	await frames();gate.release=true;await settle()
	check(not game.modal_open() and shop.stage=="S0","closing a newer file picker does not revive old purchase")
	check((await saved())==before,"all abandoned quotes and modal changes preserve full save")
	# Reentry can still use the unmodified normal consent -> recipient flow.
	game.find_child("ProductBuy_javelin-wood",true,false).pressed.emit();await settle()
	check(game.dialog.window.title=="購入の確認","fresh payment confirmation remains functional")
	game.find_child("PurchaseAgree",true,false).pressed.emit();await frames()
	check(game.dialog.window.title=="受取人の選択" and shop.stage=="S9","accepted consent still advances to recipient")
	game.find_child("PurchaseRecipient_mage",true,false).pressed.emit();await settle()
	check(shop.stage=="S0" and game.campaign().gold==900 and game.campaign().characters.mage.inventory.get("javelin-wood",0)==1,"normal atomic purchase still completes after lifecycle cancellation")
	game.engine=actual;gate.queue_free();game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames()
	var file=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("lifecycle-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
