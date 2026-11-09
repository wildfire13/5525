extends "res://tests/owned_equipment_regression.gd"
## Existing inventory rules, many real item IDs, and session-only UI context.
class DelayedSaleEngine extends DelayedEngine:
	func request(payload):
		var hold=hold_next and payload.get("action")=="saleQuote"
		if hold:hold_next=false
		var reply=await actual.request(payload)
		if hold:
			held=true
			while not release:await get_tree().process_frame
			held=false
		return reply
func audio_off() -> bool:return game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se
func run():
	create_timer(180).timeout.connect(func():print("FAIL inventory context watchdog");quit(2))
	var qa=OS.get_environment("INVENTORY_QA_ROOT")
	if qa.is_empty() or not OS.get_user_data_dir().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[]
	var generated=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
	check(generated==0,"many-item fixture uses current real equipment definitions")
	var gear=JSON.parse_string("".join(output));var seed=await saved();seed.state.location="east";seed.state.gold=500;seed.state.characters.guard.inventory={}
	for id in gear:seed.state.characters.guard.inventory[id]=3
	seed.state.characters.guard.inventory.potion=5;seed.state.characters.guard.inventory.ether=2
	check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"large inventory loads")
	await enter_facility("shop");await tap("RosterMember_guard")
	var before=await saved()
	var sale=game.pages.shop_view.sale
	check(node("SaleItem_lone-ring-1")!=null and node("SaleItem_lone-ring-2")!=null,"same-name ring IDs have separate shop rows")
	var scroll=node("ShopInventoryScroll")
	check(scroll.find_children("SaleItem_*","Button",true,false).size()==gear.size()+2,"shop renders the full stocked inventory")
	scroll.ensure_control_visible(node("SaleItem_twin-bow"));await frames()
	check(scroll.get_global_rect().intersects(node("SaleItem_twin-bow").get_global_rect()),"long shop inventory can reveal the selected row")
	await tap("SaleItem_twin-bow")
	node("FacilitySaleQuantity").value=2;await settle()
	check(sale.quote.get("ownerId")=="guard" and sale.quote.get("count")==2,"visible sale quote uses the selected owner and quantity")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(node("FacilitySalePrepare").get_global_rect()),"sale confirmation stays within the viewport")
	await tap("FacilitySalePrepare")
	sale.confirmation.canceled.emit();sale.confirmation.hide();await settle()
	check((await saved())==before,"cancelling the quote preserves the entire save")

	# Release the first owner's quote after switching via the live roster.
	var actual=game.engine;var delayed=DelayedSaleEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
	node("SaleItem_spear-wood").pressed.emit()
	while not delayed.held:await process_frame
	await tap("RosterMember_archer")
	delayed.release=true
	while delayed.held:await process_frame
	await settle();game.engine=actual;delayed.queue_free()
	check(sale.owner_id=="archer" and sale.item_id.is_empty() and sale.quote.is_empty(),"late quote cannot overwrite the newly selected owner")
	check((await saved())==before,"switching owners during a quote preserves the entire save")
	check(audio_off(),"all inventory checks kept BGM voice and SE OFF")
	var f=FileAccess.open(qa.path_join("inventory-context-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
