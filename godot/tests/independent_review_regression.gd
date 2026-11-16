extends SceneTree
const OWNER="character_mirei"
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
	while game.locked or game.engine.busy or game.presenting or shop().quote_worker:await process_frame
func clean():
	return game.campaign().characters.values().all(func(c):return c.inventory.keys().all(func(id):return not str(id).begins_with("empty-")))
func enter_shop():
	game.navigate("shop");await settle()
	node("FacilityChoice_buy").pressed.emit();await settle()
func empty_slots(seed):
	var fixture=seed.duplicate(true);fixture.state.location="north";fixture.state.gold=1000
	fixture.state.characters[OWNER].inventory={}
	fixture.state.characters[OWNER].accessory1="empty-accessory1"
	var inspection=fixture.duplicate(true);inspection.state.characters[OWNER].accessory2="empty-accessory2"
	await game.update({"op":"campaign_load","data":inspection});game.navigate("character");await settle()
	var workspace=game.pages.party_view.workspace
	for slot in ["accessory1","accessory2"]:
		var original=await saved()
		node("CharacterSlot_"+slot).pressed.emit();await settle()
		var remove=game.find_children("*","Button",true,false).filter(func(button):return button.text=="装備を外す")
		check("EMPTY-ui-"+slot,remove.is_empty() and workspace.picked.type=="empty" and await saved()==original,"empty accessory detail exposes no unequip action")
	# Restore the fixture's capacity pouch for the inventory purchase.
	await game.update({"op":"campaign_load","data":fixture});await enter_shop()
	node("Product_lone-ring-1").pressed.emit();await settle()
	var comparison=shop().comparison_view
	var quote=(await game.engine.request({"op":"campaign","action":"previewGear","args":[comparison.owner_id,comparison.item_id,comparison.slot]})).get("previewGear",{})
	check("EMPTY-quote",quote.has("retained") and not quote.retained,"selected shop comparison retains no empty accessory")
	node("ShopComparisonBuy").pressed.emit();await settle();node("PurchaseAgree").pressed.emit();await settle()
	check("EMPTY-purchase",game.campaign().characters[OWNER].inventory.get("lone-ring-1")==1 and game.campaign().gold==930 and clean(),"single purchase places only the real ring in inventory")
	game.pages.party_view.open_inventory(OWNER);await settle()
	var entry=game.campaign().inventoryByCharacter[OWNER].entries.filter(func(e):return e.id=="lone-ring-1")[0]
	for attempt in range(2):
		var row=game.find_children("*","Button",true,false).filter(func(button):return button.tooltip_text==entry.name)[0]
		row.pressed.emit();await settle();node("CharacterEquip").pressed.emit();await settle()
		check("EMPTY-equip-"+str(attempt),game.campaign().characters[OWNER].accessory1==entry.id and not game.campaign().characters[OWNER].inventory.has(entry.id) and clean() and game.campaign().gold==930,"equipping consumes exactly one real accessory")
		if attempt==0:
			node("CharacterTab_equipment").pressed.emit();await settle();node("CharacterSlot_accessory1").pressed.emit();await settle()
			var remove=game.find_children("*","Button",true,false).filter(func(button):return button.text=="装備を外す")[0]
			remove.pressed.emit();await settle()
			check("EMPTY-unequip",game.campaign().characters[OWNER].inventory.get(entry.id)==1 and clean(),"removal returns exactly one real accessory")
			node("CharacterTab_inventory").pressed.emit();await settle()
	var before=await saved()
	await game.update({"op":"campaign_load","data":before});await settle()
	check("EMPTY-roundtrip",await saved()==before and clean(),"saved and reloaded legitimate inventory stays exact")
	var invalid=before.duplicate(true);invalid.state.characters[OWNER].inventory["empty-accessory1"]=3
	var path=evidence.path_join("contaminated-candidate.json");var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(invalid));f.close();var bytes=FileAccess.get_file_as_bytes(path)
	await game.load_game(path);await settle()
	check("EMPTY-invalid-preserved",await saved()==before and FileAccess.get_file_as_bytes(path)==bytes and game.notice.contains("空の装備枠"),"contaminated candidate save is explained and rejected without modifying file or current progress")
func prices(seed):
	for size_ in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(800,600)]:
		root.size=size_;await settle()
		for place in ["east","west","north"]:
			var fixture=seed.duplicate(true);fixture.state.location=place
			await game.update({"op":"campaign_load","data":fixture});await enter_shop()
			var offered=shop().offered();var valid=not offered.is_empty()
			for item in offered:
				var product=node("Product_"+str(item.id))
				var labels=product.find_children("*","Label",true,false).filter(func(label):return label.text=="%dG" % int(item.price))
				if labels.size()!=1:
					valid=false
					continue
				var price=labels[0];var font=price.get_theme_font("font");var natural=font.get_string_size(price.text,HORIZONTAL_ALIGNMENT_LEFT,-1,price.get_theme_font_size("font_size")).x
				var fits=price.get_line_count()==1 and price.size.x+1>=natural and product.get_global_rect().encloses(price.get_global_rect())
				geometry.append({"viewport":str(size_),"store":place,"id":str(item.id),"text":price.text,"width":price.size.x,"natural_width":natural,"lines":price.get_line_count(),"fits":fits});valid=valid and fits
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
