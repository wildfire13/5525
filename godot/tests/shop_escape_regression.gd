extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
func tap(name_: String):game.find_child(name_,true,false).pressed.emit();await settle()
func escape_twice():
	var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE
	var window=game.dialog.window;var margin=window.get_child(0)
	window.window_input.emit(event)
	margin._unhandled_key_input(event)
	await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=(await game.engine.request({"op":"campaign_save"})).data;seed.state.location="east";seed.state.characters.archer.inventory={"twin-bow":3}
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle()
	var before=(await game.engine.request({"op":"campaign_save"})).data
	game.pages.party_view.open_inventory("archer");await settle();await tap("InventorySell_twin-bow")
	var inv=game.pages.party_view.inventory_view;inv.amount=2;await tap("InventoryPrepareSale");await escape_twice()
	check(game.modal_open() and inv.stage=="targets" and inv.amount==2 and inv.quote.is_empty(),"one real key through both routes only returns sale to quantity once")
	check((await game.engine.request({"op":"campaign_save"})).data==before,"duplicate sale Escape leaves complete save unchanged")
	await tap("InventoryPrepareSale");await tap("StatusBack")
	check(inv.stage=="targets" and inv.amount==2,"Back still retains quantity after Escape handling")
	game.dialog.close();await settle()
	await tap("ProductBuy_undertow-sword");await escape_twice()
	check(not game.modal_open() and game.pages.shop_view.stage=="S0","purchase consent Escape still cancels normally")
	game.pages.party_view.open_inventory("archer");await settle();await tap("InventoryItem_twin-bow");await tap("InventoryDiscard");await tap("InventoryPrepareDiscard");await escape_twice()
	check(not game.modal_open(),"non-sale Escape preserves status-close behavior")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("escape-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
