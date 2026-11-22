extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func tap(name_: String):game.find_child(name_,true,false).pressed.emit();await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=(await game.engine.request({"op":"campaign_save"})).data
	seed.state.location="east";seed.state.gold=500
	var owner=str(seed.state.selected[0])
	seed.state.characters[owner].inventory={"twin-bow":3}
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy")
	await tap("RosterMember_"+owner)
	var before=(await game.engine.request({"op":"campaign_save"})).data
	await tap("SaleItem_twin-bow")
	var sale=game.pages.shop_view.sale
	game.find_child("FacilitySaleQuantity",true,false).value=2;await settle()
	await tap("FacilitySalePrepare")
	var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	var headless=DisplayServer.get_name()=="headless"
	if headless:
		# Native ConfirmationDialog keyboard dispatch needs a windowing backend.
		# Exercise its cancellation callback without claiming an OS Escape test.
		sale.confirmation.canceled.emit()
	else:
		escape.window_id=sale.confirmation.get_window_id()
		escape.physical_keycode=KEY_ESCAPE
		Input.parse_input_event(escape)
		await process_frame
		var release=escape.duplicate();release.pressed=false
		Input.parse_input_event(release)
	await settle()
	check(not game.modal_open() and sale.stage=="selected" and sale.amount==2 and sale.quote.get("count")==2,("headless sale cancellation" if headless else "sale receipt Escape")+" retains selection and quantity")
	check((await game.engine.request({"op":"campaign_save"})).data==before,("headless sale cancellation" if headless else "sale Escape")+" preserves complete save")
	var list_button=game.find_child("ShopTransactionFooter",true,false).find_children("*","Button",true,false).filter(func(b):return b.text=="商品一覧へ")[0]
	list_button.pressed.emit();await settle()
	await tap("Product_undertow-sword");await tap("ShopComparisonBuy");var purchased=(await game.engine.request({"op":"campaign_save"})).data
	check(not game.modal_open() and game.save_notice.visible and game.save_notice.caption.text=="%sへ %s×1 / 支払%dG" % [game.member_name(game.shop_uid),game.pages.shop_view.receipt.gear.name,int(game.pages.shop_view.receipt.cost)],"purchase completion is a non-modal recipient/item/count/payment notice")
	await tap("Product_undertow-sword")
	check(not game.modal_open() and game.find_child("ShopComparisonBuy",true,false).is_visible_in_tree(),"can select the next product directly after the purchase notice")
	check((await game.engine.request({"op":"campaign_save"})).data==purchased and purchased.state.gold<before.state.gold,"selecting a product retains the completed purchase")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("escape-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
