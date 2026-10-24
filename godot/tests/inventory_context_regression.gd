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
func selected_names() -> Array:
	return game.find_children("OwnedEquipment_*","Button",true,false).filter(func(b):return b.get_meta("selected_inventory_item",false)).map(func(b):return str(b.name))
func ready_item(id: String):
	var scroll=node("OwnedEquipmentScroll");var source=node("OwnedInventorySell_"+id)
	source.grab_focus();scroll.ensure_control_visible(source);await settle()
func run():
	create_timer(180).timeout.connect(func():print("FAIL inventory context watchdog");quit(2))
	var qa=OS.get_environment("INVENTORY_QA_ROOT")
	if qa.is_empty() or not OS.get_user_data_dir().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[]
	var generated=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
	check(generated==0,"many-item fixture uses current real equipment definitions")
	var gear=JSON.parse_string("".join(output));var seed=await saved();seed.state.location="east";seed.state.gold=500;seed.state.characters.guard.inventory={}
	for id in gear:seed.state.characters.guard.inventory[id]=3
	seed.state.characters.guard.inventory.potion=5;seed.state.characters.guard.inventory.ether=2
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims
		check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"many real item IDs load without new inventory rules "+str(dims.x))
		game.navigate("shop");await settle();game.pages.party_view.open_detail("guard");await settle()
		var before=await saved();var inv=game.pages.party_view.inventory_view;var owned=game.pages.party_view.owned_equipment_view
		check(audio_off(),"all audio remains OFF "+str(dims.x))
		check(node("OwnedEquipmentList").get_parent()==node("OwnedEquipmentScroll") and node("OwnedEquipmentList").get_child_count()/3>=40,"real long list remains same three-column item API in its own scroll "+str(dims.x))
		check(node("OwnedEquipmentList").size.y>node("OwnedEquipmentScroll").size.y and node("OwnedEquipmentScroll").size.y<=360,"large inventory is bounded instead of moving details below all rows "+str(dims.x))
		check(node("OwnedEquipment_lone-ring-1")!=null and node("OwnedEquipment_lone-ring-2")!=null and node("OwnedEquipment_lone-ring-1").text.contains("3個") and node("OwnedEquipment_lone-ring-2").text.contains("3個"),"existing same-name equipment IDs and counts remain distinct "+str(dims.x))
		await choose_slot("rightHand");await ready_item("twin-bow")
		var original_scroll=node("OwnedEquipmentScroll").scroll_vertical;var outer_scroll=node("ModalDetailScroll").scroll_vertical
		await tap("OwnedInventorySell_twin-bow")
		check(inv.owner_id=="guard" and inv.item_id=="twin-bow" and selected_names()==["OwnedEquipment_twin-bow"] and node("OwnedEquipment_twin-bow").text.contains("選択中"),"selected item is named and marked in same owner/category "+str(dims.x)+" selected="+str(selected_names())+" text="+node("OwnedEquipment_twin-bow").text)
		check(node("OwnedEquipmentScroll").get_global_rect().encloses(node("OwnedEquipment_twin-bow").get_global_rect()),"selecting from long list reveals selected row after detail shrinks list "+str(dims.x))
		var viewport=node("ModalDetailScroll").get_global_rect();var actions=node("StatusInventoryActions").get_global_rect()
		check(viewport.encloses(actions) and node("InventoryPrepareSale").get_global_rect().end.y<=viewport.end.y and node("InventoryList").get_global_rect().end.y<=viewport.end.y,"quantity totals confirm and return stay visible for long list "+str(dims.x))
		var stable_actions=actions.position;node("OwnedEquipmentScroll").scroll_vertical=0;await settle()
		check(node("StatusInventoryActions").global_position==stable_actions,"scrolling inventory does not move selected detail controls "+str(dims.x))
		await ready_item("twin-bow")
		node("InventoryQuantity").value=2;await settle()
		var canonical=(await game.engine.request({"op":"campaign","action":"saleQuote","args":["guard","twin-bow",2]})).saleQuote
		check(node("InventorySaleTotals").text.contains("ガロの双射の弓 ×2") and node("InventorySaleTotals").text.contains(str(int(canonical.afterGold))+"G") and (await saved())==before,"quantity preview uses canonical price and cannot mutate save "+str(dims.x)+" text="+node("InventorySaleTotals").text)
		var editing_scroll=node("OwnedEquipmentScroll").scroll_vertical
		await tap("InventoryPrepareSale");await tap("InventoryCancel")
		check(inv.stage=="targets" and inv.amount==2 and inv.owner_id=="guard" and inv.item_id=="twin-bow" and owned.slot=="rightHand" and inv.quote.is_empty(),"NO keeps exact owner item quantity category and discards confirmation quote "+str(dims.x))
		check(node("InventoryQuantity")!=null and int(node("InventoryQuantity").value)==2 and (node("InventoryQuantity").has_focus() or node("InventoryQuantity").get_line_edit().has_focus()),"NO restores quantity editing focus "+str(dims.x))
		check(node("OwnedEquipmentScroll").scroll_vertical==editing_scroll and node("ModalDetailScroll").scroll_vertical==outer_scroll and (await saved())==before,"NO restores confirmation's editing position without consuming anything "+str(dims.x)+" expected="+str(editing_scroll)+" actual="+str(node("OwnedEquipmentScroll").scroll_vertical)+" outer="+str(node("ModalDetailScroll").scroll_vertical)+" expectedOuter="+str(outer_scroll)+" ctx="+str(inv.confirmation_list_context))
		await tap("InventoryPrepareSale");inv.confirmation.close_requested.emit();await settle()
		check(inv.stage=="targets" and inv.amount==2 and inv.quote.is_empty() and (await saved())==before,"window close cancellation retains quantity and state "+str(dims.x))
		await tap("InventoryPrepareSale");game.pages.party_view.detail_escape();await settle()
		check(inv.stage=="targets" and inv.amount==2 and inv.quote.is_empty() and (await saved())==before,"existing Escape handler returns sale to same quantity without closing status "+str(dims.x))
		await tap("InventoryList")
		check(inv.stage=="list" and selected_names().is_empty() and node("OwnedInventorySell_twin-bow").has_focus() and node("OwnedEquipmentScroll").scroll_vertical==original_scroll,"list return restores original row focus and position "+str(dims.x))
		await choose_slot("items");owned.sell_item("guard","twin-bow");await settle()
		check(inv.stage=="list" and inv.item_id.is_empty() and selected_names().is_empty() and owned.slot=="items","hidden item callback cannot revive old equipment sale after filter change "+str(dims.x))
		await choose_slot("rightHand");await ready_item("twin-bow");await tap("OwnedInventorySell_twin-bow");node("InventoryQuantity").value=2;await settle();await tap("InventoryPrepareSale")
		var confirmed=inv.quote.duplicate(true);inv.commit();inv.commit();await settle()
		check(int(game.campaign().gold)==int(confirmed.afterGold) and int(game.campaign().characters.guard.inventory["twin-bow"])==1,"double confirmation commits only canonical selected owner and quantity once "+str(dims.x))
		var committed=await saved();await game.update({"op":"campaign_load","data":committed});game.navigate("shop");await settle();game.pages.party_view.open_detail("guard");await settle()
		check((await saved())==committed and inv.item_id.is_empty() and selected_names().is_empty(),"reload retains exact committed inventory and clears ephemeral selection "+str(dims.x))
		for entry in game.data.campaign.inventoryByCharacter.guard.entries:
			if entry.id=="twin-bow":entry.name="長い名前でも対象と所持数を見失わないための双射の弓"
		game.pages.party_view.refresh_modal();await settle()
		check(node("OwnedEquipment_twin-bow").heading.contains("長い名前") and node("OwnedEquipment_twin-bow").text.contains("1個") and node("OwnedEquipmentScroll").get_global_rect().end.x<=node("StatusOwnedInventory").get_global_rect().end.x,"long item name and count wrap inside independent list "+str(dims.x))
		game.dialog.close();await settle()
	# A late sale preview and an obsolete row callback cannot cross owners.
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();game.pages.party_view.open_detail("guard");await settle()
	var actual=game.engine;var delayed=DelayedSaleEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
	game.pages.party_view.owned_equipment_view.sell_item("guard","twin-bow")
	while not delayed.held:await process_frame
	game.pages.party_view.portrait_pressed("archer");await settle();var switched=await actual.request({"op":"campaign_save"})
	delayed.release=true;await settle();game.pages.party_view.owned_equipment_view.sell_item("guard","twin-bow");await settle()
	check(game.pages.party_view.detail_uid=="archer" and node("InventorySaleTotals")==null and selected_names().is_empty() and game.pages.party_view.inventory_view.item_id.is_empty(),"late old-owner preview and old row callback cannot replace current detail")
	game.engine=actual;delayed.queue_free();check((await saved())==switched.data,"owner switch and rejected stale sale preserve exact game save")
	check(audio_off(),"all inventory checks kept BGM voice and SE OFF")
	var f=FileAccess.open(qa.path_join("inventory-context-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
