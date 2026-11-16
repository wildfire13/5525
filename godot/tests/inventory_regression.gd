extends SceneTree
## Run only with a separate APPDATA directory inside INVENTORY_QA_ROOT.
var game
var checks: Array=[]
var failures: Array=[]
var evidence := ""
func _initialize():call_deferred("run")
func check(id: String,passed: bool,detail: String):
	checks.append({"id":id,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+id+" "+detail)
	if not passed:failures.append(id)
func settle():
	for i in range(6):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func inventory():return game.pages.party_view.workspace
func button(name: String):return game.find_child(name,true,false)
func open_inventory(uid: String):
	if is_instance_valid(game.dialog.window):game.dialog.close(false)
	if game.page=="character":button("RosterMember_"+uid).pressed.emit()
	else:game.pages.party_view.open_inventory(uid)
	await settle()
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").simplify_path()
	var user_dir=OS.get_user_data_dir().replace("\\","/").simplify_path()
	if evidence.is_empty() or not user_dir.to_lower().begins_with(evidence.to_lower()+"/"):
		push_error("Refusing UI test: user data must be isolated inside INVENTORY_QA_ROOT");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east";seed.state.characters.mage.hp=1
	await game.update({"op":"campaign_load","data":seed})
	game.shop_uid="guard";game.shop_slot="rightHand";await enter_facility("shop");await settle()
	game.pages.shop_view.open_comparison("staff-wood");await settle()
	var selected=game.pages.gear_id;var shop_slot=game.shop_slot
	await open_inventory("mage")
	check("INV-UI-01",game.page=="character" and inventory().owner=="mage","inventory names its owner")
	check("INV-UI-02",game.shop_uid=="guard" and game.pages.gear_id==selected and game.shop_slot==shop_slot,"inspection preserves shop selection")
	check("INV-UI-03",not game.campaign().inventoryByCharacter.mage.entries.any(func(e):return e.id=="potion"),"mage does not own another character's potion")
	await open_inventory("guard")
	var quote=(await game.engine.request({"op":"campaign","action":"inventoryQuote","args":["guard","potion","use","mage",1,null]})).inventoryQuote
	check("INV-UI-04",quote.ownerId=="guard" and quote.targetId=="mage" and quote.count==1 and quote.after==56,"use quote names source recipient effect and consumption")
	inventory().perform("guard","potion","use","mage",1,null)
	await inventory().perform("guard","potion","use","mage",1,null);await settle()
	check("INV-UI-06",game.campaign().characters.guard.inventory.potion==2 and game.campaign().characters.mage.hp==56,"double use consumes once and updates target")
	check("INV-UI-07",game.shop_uid=="guard" and game.pages.gear_id==selected and game.shop_slot==shop_slot and game.gear_preview.is_empty(),"use preserves shop selection and clears stale preview")
	await inventory().perform("guard","potion","transfer","mage",1,null);await settle()
	check("INV-UI-08",game.campaign().characters.guard.inventory.potion==1 and game.campaign().characters.mage.inventory.potion==1,"transfer updates both owners once")
	await open_inventory("mage")
	var potion=game.campaign().inventoryByCharacter.mage.entries.filter(func(e):return e.id=="potion")[0]
	var before=await saved()
	inventory().confirm_discard("mage",potion);await settle();game.dialog.close();await settle()
	check("INV-UI-09",await saved()==before,"discard cancellation preserves exact save")
	inventory().confirm_discard("mage",potion);await settle();button("CharacterDiscardConfirm").pressed.emit();await settle()
	check("INV-UI-10",not game.campaign().characters.mage.inventory.has("potion") and game.campaign().characters.guard.inventory.potion==1,"discard removes only named owner's item")
	await open_inventory("guard")
	await inventory().perform("guard","sword-wood","unequip",null,1,"rightHand");await settle()
	check("INV-UI-11",game.campaign().characters.guard.weapon=="empty-rightHand" and game.campaign().characters.guard.inventory["sword-wood"]==1,"unequip retains the item with its owner")
	await inventory().perform("guard","sword-wood","equip",null,1,"rightHand");await settle()
	check("INV-UI-12",game.campaign().characters.guard.weapon=="sword-wood" and not game.campaign().characters.guard.inventory.has("sword-wood"),"owned gear equips without purchase or duplication")
	check("INV-UI-13",game.pages.gear_id==selected and game.shop_uid=="guard" and game.shop_slot==shop_slot,"equipment operations retain purchase selection")
	DirAccess.make_dir_recursive_absolute(evidence)
	var report=FileAccess.open(evidence.path_join("inventory-ui.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(4):await process_frame
	quit(0 if failures.is_empty() else 1)

func enter_facility(page: String):
	game.navigate(page);await settle()
	var service={"shop":"buy","party":"guild","inn":"inn"}.get(page,"")
	var choice=game.find_child("FacilityChoice_"+service,true,false)
	if choice!=null and choice.is_visible_in_tree():
		choice.pressed.emit();await settle()
