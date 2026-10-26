extends "res://tests/inventory_context_regression.gd"
## F3: real inventory actions must fit a 619px-high character window.
var measurements=[]
func visible_actions(tag: String,names: Array):
	var viewport=node("ModalDetailScroll").get_global_rect();var rects={}
	for id in names:
		var control=node(str(id));check(control!=null,"F3 action exists "+str(id)+" "+tag)
		if control==null:continue
		var rect=control.get_global_rect();rects[str(id)]=str(rect)
		check(viewport.encloses(rect),"F3 action fully visible "+str(id)+" "+tag)
	check(node("OwnedEquipmentList").size.y>node("OwnedEquipmentScroll").size.y,"F3 only the inventory list needs scrolling "+tag)
	measurements.append({"case":tag,"parent_window":str(root.size),"character_window":str(game.dialog.window.size),"viewport":str(viewport),"list":str(node("OwnedEquipmentScroll").get_global_rect()),"actions":rects,"outer_scroll":node("ModalDetailScroll").scroll_vertical})
func run():
	create_timer(150).timeout.connect(func():print("FAIL F3 watchdog");quit(2))
	var qa=OS.get_environment("INVENTORY_QA_ROOT")
	if qa.is_empty() or not OS.get_user_data_dir().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1180,812);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
	var gear=JSON.parse_string("".join(output));check(code==0 and gear.size()==47,"F3 fixture uses 47 real gear definitions")
	var seed=await saved();seed.state.location="east";seed.state.gold=500;seed.state.characters.guard.inventory={}
	for id in gear:seed.state.characters.guard.inventory[id]=3
	seed.state.characters.guard.inventory.potion=5;seed.state.characters.guard.inventory.ether=2
	for spec in [[Vector2i(1180,812),Vector2i(1180,619)],[Vector2i(1920,1080),Vector2i(1920,780)],[Vector2i(1920,1080),Vector2i(1180,619)]]:
		var dims: Vector2i=spec[0]
		root.size=dims;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle();game.pages.party_view.open_detail("guard");await settle()
		game.dialog.window.size=spec[1];await frames(24)
		var before=await saved();var inv=game.pages.party_view.inventory_view;var owned=game.pages.party_view.owned_equipment_view
		check(owned.entries("guard").size()==49,"F3 fixture has all 49 distinct personal items "+str(dims.x))
		owned.actions("guard","kungfu-pants");await settle()
		visible_actions("equipment-before-details-"+str(dims.x),["InventoryDetails","InventoryEquip","InventoryList"])
		await tap("InventoryDetails");check(node("SkillDetailsWindow")!=null,"F3 equipment explanation opens "+str(dims.x));await tap("SkillDetailsBack")
		visible_actions("equipment-after-details-"+str(dims.x),["InventoryDetails","InventoryEquip","InventoryList"])
		check(inv.item_id=="kungfu-pants" and inv.owner_id=="guard" and owned.slot.is_empty() and (await saved())==before,"F3 explanation close keeps owner item category and exact save "+str(dims.x))
		await tap("InventoryList");await choose_slot("rightHand");await ready_item("spear-wood")
		var original_scroll=node("OwnedEquipmentScroll").scroll_vertical
		await tap("OwnedInventorySell_spear-wood");node("InventoryQuantity").value=2;await settle()
		visible_actions("sale-before-confirm-"+str(dims.x),["InventoryQuantity","InventorySaleTotals","InventoryPrepareSale","InventoryList"])
		var editing_scroll=node("OwnedEquipmentScroll").scroll_vertical;var canonical=(await game.engine.request({"op":"campaign","action":"saleQuote","args":["guard","spear-wood",2]})).saleQuote
		check(node("InventorySaleTotals").text.contains(str(int(canonical.proceeds))+"G") and node("InventorySaleTotals").text.contains(str(int(canonical.afterGold))+"G"),"F3 sale totals still use canonical quote "+str(dims.x))
		await tap("InventoryPrepareSale");await tap("InventoryCancel")
		visible_actions("sale-after-NO-"+str(dims.x),["InventoryQuantity","InventorySaleTotals","InventoryPrepareSale","InventoryList"])
		check(inv.stage=="targets" and inv.amount==2 and inv.item_id=="spear-wood" and inv.owner_id=="guard" and owned.slot=="rightHand" and inv.quote.is_empty(),"F3 NO keeps owner item quantity category and requires a fresh quote "+str(dims.x))
		check(node("OwnedEquipmentScroll").scroll_vertical==editing_scroll and node("InventoryQuantity").get_line_edit().has_focus() and (await saved())==before,"F3 NO restores editing scroll and keyboard focus without mutation "+str(dims.x))
		await tap("InventoryList")
		check(node("OwnedEquipmentScroll").scroll_vertical==original_scroll and node("OwnedInventorySell_spear-wood").has_focus() and inv.stage=="list","F3 list return restores original row position and focus "+str(dims.x))
		game.dialog.close();await settle()
	check(audio_off(),"F3 kept BGM voice and SE OFF")
	var f=FileAccess.open(qa.path_join("inventory-short-window-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"measurements":measurements},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
