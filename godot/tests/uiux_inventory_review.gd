extends SceneTree
var game
var checks=[]
var evidence=""
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func shop():return game.pages.shop_view
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or shop().quote_worker or shop().sale.previewing:await process_frame
func shop_cases():
	var before=await saved()
	node("RosterMember_character_mirei").pressed.emit();await settle()
	node("Product_spear-wood").pressed.emit();await settle()
	var comparison=shop().comparison_view
	for rule in [[10,9,"#ffb1a6"],[10,11,"#8ee6ab"],[10,10,"#d5dbe2"]]:
		check("COLOR-"+str(rule[1]),comparison.change("▼ ▲ ＝",rule[0],rule[1]).contains("[color="+rule[2]+"]"),"comparison color follows numeric change")
	var canonical=(await game.engine.request({"op":"campaign","action":"previewGear","args":["character_mirei","spear-wood","rightHand"]})).previewGear
	check("COMPARE-present",comparison.panels.size()==2,"shop shows current and candidate equipment")
	for side in range(2):
		var gear=canonical.current if side==0 else canonical.gear
		var labels=comparison.panels[side].find_children("*","Label",true,false)
		check("COMPARE-ATK"+str(side),labels.any(func(label):return label.is_visible_in_tree() and label.text.begins_with("物理ATK：%d" % int(gear.atk))),"visible attack comes from the item itself")
	node("RosterMember_character_merina").pressed.emit();await settle()
	node("SaleItem_hammer-wood").pressed.emit();await settle()
	var sale=shop().sale
	var quote=sale.quote.duplicate(true)
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;game.render();await settle()
		var totals=node("FacilitySaleTotals")
		check("SALE-visible-"+str(dims.x),quote.get("ok",false) and totals.text.contains(str(int(quote.afterGold))) and root.get_visible_rect().encloses(totals.get_global_rect()),"quoted balance is visible before sale")
	root.size=Vector2i(1920,1080);await settle()
	node("FacilitySalePrepare").pressed.emit();await settle()
	sale.confirmation.canceled.emit();sale.confirmation.hide();await settle()
	check("SALE-cancel",await saved()==before and sale.item_id=="hammer-wood" and sale.quote==quote,"cancel retains item, quote and complete save")
	node("FacilitySalePrepare").pressed.emit();await settle()
	sale.confirmation.confirmed.emit();await settle()
	var after=await saved()
	check("SALE-context",shop().selected_owner()=="character_merina" and after.state.gold==quote.afterGold and not after.state.characters["character_merina"].inventory.has("hammer-wood"),"sale credits quoted proceeds for the selected owner")
func pending_cases(seed):
	game.engine.close_engine();game.engine.queue_free();await process_frame
	var probe=preload("res://tests/inventory_pending_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine()
	await game.new_game();await game.update({"op":"campaign_load","data":seed});await settle()
	game.pages.party_view.open_inventory("character_mirei");await settle()
	var workspace=game.pages.party_view.workspace
	for action in ["inventoryQuote","inventoryAction"]:
		var before=await saved()
		probe.hold_action=action
		workspace.perform("character_mirei","potion","use","character_merina",1,null)
		while not probe.waiting:await process_frame
		check("LOCK-"+action,workspace.busy,"workspace is busy during "+action)
		if action=="inventoryQuote":
			check("LOCK-quote-pure",await saved()==before,"held quote has not consumed an item")
		workspace.perform("character_mirei","potion","use","character_merina",1,null)
		probe.deliver=true
		while workspace.busy:await process_frame
		var after=await saved()
		check("LOCK-once-"+action,after.state.characters["character_mirei"].inventory.potion==2 and after.state.characters["character_merina"].hp==56,"duplicate use consumes and heals exactly once")
		if action=="inventoryQuote":
			await game.update({"op":"campaign_load","data":seed});await settle()
			game.pages.party_view.open_inventory("character_mirei");await settle()
func run():
	create_timer(150).timeout.connect(func():print("FAIL inventory review watchdog");quit(2))
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east";seed.state.characters["character_mirei"].inventory={"potion":3};seed.state.gold=120;seed.state.characters["character_merina"].inventory["hammer-wood"]=1;seed.state.characters["character_merina"].hp=1
	await game.update({"op":"campaign_load","data":seed});game.shop_uid="character_mirei";game.shop_slot="rightHand";game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
	await shop_cases();await pending_cases(seed)
	var f=FileAccess.open(evidence.path_join("uiux-inventory-review.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks},"\t"));f.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
