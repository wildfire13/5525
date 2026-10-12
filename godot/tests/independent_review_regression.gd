extends SceneTree
var game
var checks=[]
var geometry=[]
var evidence=""
func _initialize():call_deferred("run")
func check(id,passed,detail):
	checks.append({"id":id,"passed":bool(passed),"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
func shop():return game.pages.shop_view
func node(id):return game.find_child(id,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or shop().quote_worker or shop().plan.refreshing:await process_frame
func clean():
	return game.campaign().characters.values().all(func(c):return c.inventory.keys().all(func(id):return not str(id).begins_with("empty-")))
func empty_slots(seed):
	var fixture=seed.duplicate(true);fixture.state.location="north";fixture.state.gold=1000
	await game.update({"op":"campaign_load","data":fixture});game.shop_uid="guard";game.shop_slot="accessory1";game.navigate("shop");await settle()
	for slot in ["accessory1","accessory2"]:
		var before=await saved();game.pages.party_view.open_detail("guard");await settle()
		var member=game.roster().filter(func(u):return u.id=="guard")[0]
		game.pages.party_view.open_equipment(member,member.equipmentSlots.filter(func(e):return e.slot==slot)[0]);await settle()
		var remove=game.dialog.body.find_children("*","Button",true,false).filter(func(button):return button.text.ends_with("から外して所持品へ"))
		check("EMPTY-ui-"+slot,remove.is_empty() and game.pages.party_view.detail_gear.type=="empty" and await saved()==before,"empty accessory detail exposes no unequip-to-inventory action")
		node("StatusClose").pressed.emit();await settle()
	await shop().select_product("lone-ring-1");await settle()
	check("EMPTY-quote",not game.gear_preview.retained,"comparison does not claim to retain an empty accessory")
	await shop().confirm_purchase();await settle();game.dialog.actions.get_child(1).pressed.emit();await settle()
	check("EMPTY-purchase",game.campaign().characters.guard.accessory1=="lone-ring-1" and game.campaign().gold==930 and clean(),"actual single purchase callback retains no phantom stock")
	game.pages.party_view.open_inventory("guard");await settle();var inv=game.pages.party_view.inventory_view
	await inv.prepare_unequip("guard","lone-ring-1","accessory1");node("InventoryConfirm").pressed.emit();await settle()
	check("EMPTY-unequip",game.campaign().characters.guard.inventory.get("lone-ring-1")==1 and clean(),"real accessory removal returns exactly one real item")
	inv.pick("lone-ring-1");inv.choose("equip");await inv.prepare(null,"accessory1");node("InventoryConfirm").pressed.emit();await settle()
	check("EMPTY-reequip",not game.campaign().characters.guard.inventory.has("lone-ring-1") and clean() and game.campaign().gold==930,"re-equipping into the empty slot cannot add a placeholder")
	node("StatusClose").pressed.emit();await settle();var before=await saved()
	await game.update({"op":"campaign_load","data":before});await settle()
	check("EMPTY-roundtrip",await saved()==before and clean(),"saved and reloaded legitimate inventory stays exact")
	var invalid=before.duplicate(true);invalid.state.characters.guard.inventory["empty-accessory1"]=3
	var path=evidence.path_join("contaminated-candidate.json");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(invalid));f.close();var bytes=FileAccess.get_file_as_bytes(path)
	await game.load_game(path);await settle()
	check("EMPTY-invalid-preserved",await saved()==before and FileAccess.get_file_as_bytes(path)==bytes and game.notice.contains("空の装備枠"),"contaminated candidate save is explained and rejected without modifying file or current progress")
func prices(seed):
	for size_ in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(800,600)]:
		root.size=size_;await settle()
		for place in ["east","west","north"]:
			var fixture=seed.duplicate(true);fixture.state.location=place
			await game.update({"op":"campaign_load","data":fixture});game.shop_uid="guard";game.shop_slot={"east":"rightHand","west":"upperBody","north":"accessory1"}[place];game.navigate("shop");await settle()
			var labels=game.find_children("ProductPrice_*","Label",true,false);var valid=not labels.is_empty()
			for price in labels:
				var product=node("Product_"+str(price.name).trim_prefix("ProductPrice_"));var font=price.get_theme_font("font");var natural=font.get_string_size(price.text,HORIZONTAL_ALIGNMENT_LEFT,-1,price.get_theme_font_size("font_size")).x
				var fits=price.get_line_count()==1 and price.size.x+1>=natural and product.get_global_rect().encloses(price.get_global_rect())
				geometry.append({"viewport":str(size_),"store":place,"id":str(price.name),"text":price.text,"width":price.size.x,"natural_width":natural,"lines":price.get_line_count(),"fits":fits});valid=valid and fits
			check("PRICE-"+str(size_.x)+"-"+place,valid,"all product prices occupy one complete line inside their row")
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data must be isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;var seed=await saved();await empty_slots(seed);await prices(seed)
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(evidence.path_join("independent-review-regression.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"geometry":geometry},"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
