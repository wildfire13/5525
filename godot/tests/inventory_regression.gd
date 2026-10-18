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
func inventory():return game.pages.party_view.inventory_view
func button(name: String):return game.find_child(name,true,false)
func open_inventory(uid: String):
	if is_instance_valid(game.dialog.window):game.dialog.close(false)
	game.pages.party_view.open_inventory(uid);await settle()
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").simplify_path()
	var user_dir=OS.get_user_data_dir().replace("\\","/").simplify_path()
	if evidence.is_empty() or not user_dir.to_lower().begins_with(evidence.to_lower()+"/"):
		push_error("Refusing UI test: user data must be isolated inside INVENTORY_QA_ROOT");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east";seed.state.characters.mage.hp=1
	await game.update({"op":"campaign_load","data":seed})
	game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
	await game.pages.shop_view.select_product("staff-wood");await settle()
	var selected=game.pages.gear_id;var shop_slot=game.shop_slot
	await open_inventory("mage")
	check("INV-UI-01",game.dialog.window.title=="キャラクターステータス" and game.pages.party_view.detail_uid=="mage" and inventory().owner_id=="mage" and game.dialog.body.find_children("*","Label",true,false).any(func(label):return label.text.begins_with(game.member_name("mage")+" /")),"status names its inventory owner")
	check("INV-UI-02",game.shop_uid=="guard" and game.pages.gear_id==selected and game.shop_slot==shop_slot,"face/status opening preserves purchase recipient, product and equipment slot")
	check("INV-UI-03",button("InventoryItem_potion")==null,"another character's and planned items are absent")
	await open_inventory("guard");inventory().pick("potion");inventory().choose("use")
	var before=await saved();await inventory().prepare("mage",null);await settle()
	check("INV-UI-04",inventory().quote.ownerId=="guard" and inventory().quote.targetId=="mage" and inventory().quote.count==1 and inventory().quote.after==56,"use confirmation names source, recipient, effect and consumption")
	inventory().confirmation.canceled.emit();await settle()
	check("INV-UI-05",JSON.stringify(await saved())==JSON.stringify(before),"cancel consumes nothing")
	inventory().choose("use");await inventory().prepare("mage",null);inventory().commit();inventory().commit();await settle()
	check("INV-UI-06",game.campaign().characters.guard.inventory.potion==2 and game.campaign().characters.mage.hp==56,"double confirmation consumes once and updates target")
	check("INV-UI-07",game.shop_uid=="guard" and game.pages.gear_id==selected and game.shop_slot==shop_slot and not game.pages.quote_pending and game.gear_preview.is_empty(),"item use preserves shop selection without reviving invalidated preview")
	inventory().pick("potion");inventory().choose("transfer");inventory().amount=1;await inventory().prepare("mage",null)
	inventory().confirmation.confirmed.emit();await settle()
	check("INV-UI-08",game.campaign().characters.guard.inventory.potion==1 and game.campaign().characters.mage.inventory.potion==1,"transfer updates both owners exactly once")
	await open_inventory("mage");inventory().pick("potion");inventory().choose("discard");await inventory().prepare(null,null)
	before=await saved();inventory().confirmation.canceled.emit();await settle()
	check("INV-UI-09",JSON.stringify(await saved())==JSON.stringify(before),"discard cancellation is unchanged")
	inventory().choose("discard");await inventory().prepare(null,null);inventory().confirmation.confirmed.emit();await settle()
	check("INV-UI-10",not game.campaign().characters.mage.inventory.has("potion") and game.campaign().characters.guard.inventory.potion==1,"confirmed discard removes only named owner's item")
	await open_inventory("guard");await inventory().prepare_unequip("guard","sword-wood","rightHand");inventory().confirmation.confirmed.emit();await settle()
	check("INV-UI-11",game.campaign().characters.guard.weapon=="empty-rightHand" and game.campaign().characters.guard.inventory["sword-wood"]==1,"unequip retains the item with its owner")
	inventory().pick("sword-wood");inventory().choose("equip");await inventory().prepare(null,"rightHand");inventory().confirmation.confirmed.emit();await settle()
	check("INV-UI-12",game.campaign().characters.guard.weapon=="sword-wood" and not game.campaign().characters.guard.inventory.has("sword-wood"),"owned gear equips without purchase or duplication")
	check("INV-UI-13",game.pages.gear_id==selected and game.shop_uid=="guard" and game.shop_slot==shop_slot,"equipment operations retain the purchase selection")
	DirAccess.make_dir_recursive_absolute(evidence)
	var report=FileAccess.open(evidence.path_join("inventory-ui.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(4):await process_frame
	quit(0 if failures.is_empty() else 1)
