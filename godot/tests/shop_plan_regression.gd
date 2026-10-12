extends SceneTree
var game
var checks: Array=[]
var failures: Array=[]
var evidence := ""
func _initialize():call_deferred("run")
func check(id: String,passed: bool,detail: String):
	checks.append({"id":id,"passed":passed,"detail":detail});print(("PASS " if passed else "FAIL ")+id+" "+detail)
	if not passed:failures.append(id)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker or plan().refreshing:await process_frame
func plan():return game.pages.shop_view.plan
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func find(name: String):return game.find_child(name,true,false)
func run():
	evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").simplify_path()
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("User data is not isolated");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="east";seed.state.gold=120;seed.state.characters.mage.inventory["hammer-wood"]=1
	await game.update({"op":"campaign_load","data":seed});game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
	await game.pages.shop_view.select_product("staff-wood");await settle()
	check("PLAN-UI-01",find("ShopProductsScroll").custom_minimum_size.x==520 and find("PaymentSummary").get_theme_font_size("font_size")==30,"FHD list allocation and payment hierarchy")
	find("AddPurchasePlan").pressed.emit();await settle();await game.pages.shop_view.select_member("archer");await settle();await game.pages.shop_view.select_product("bow-wood-1");await settle();find("AddPurchasePlan").pressed.emit();await settle()
	check("PLAN-UI-02",plan().draft().size()==2 and game.campaign().gold==120 and game.campaign().characters.archer.weapon=="bow-wood","two characters planned without purchase or inventory mutation")
	find("ShopMode_plan").pressed.emit();await settle()
	check("PLAN-UI-03",plan().quoted.cost==210 and plan().quoted.shortfall==90 and find("PlanCheckout").disabled,"shortfall shown and checkout prevented")
	var selected=game.pages.gear_id;var recipient=game.shop_uid;var entries=plan().entries().duplicate(true)
	game.pages.party_view.open_inventory("mage");await settle()
	check("PLAN-UI-04",plan().entries()==entries and game.shop_uid==recipient and game.pages.gear_id==selected,"status opens without changing plan or equip recipient")
	game.dialog.close();await settle();find("PlanGoSell").pressed.emit();await settle()
	var owner=find("SaleOwner");owner.select(2);owner.item_selected.emit(2);await settle();find("SaleItem_hammer-wood").pressed.emit();await settle()
	await plan().prepare_sale();await settle();var before=await saved();game.dialog.actions.get_child(0).pressed.emit();await settle()
	check("PLAN-UI-05",JSON.stringify(await saved())==JSON.stringify(before),"sale cancellation consumes nothing")
	await plan().prepare_sale();await settle();var confirm=game.dialog.actions.get_child(1);confirm.pressed.emit();confirm.pressed.emit();await settle()
	check("PLAN-UI-06",game.campaign().gold==220 and not game.campaign().characters.mage.inventory.has("hammer-wood") and plan().entries()==entries,"sale occurs once and keeps both planned purchases")
	find("SaleBackToPlan").pressed.emit();await settle()
	check("PLAN-UI-07",plan().quoted.afterGold==10 and plan().ready() and not find("PlanCheckout").disabled,"sale refreshes cash without asking unchanged rows to be reapproved")
	plan().confirm_plan();await settle();before=await saved();game.dialog.actions.get_child(0).pressed.emit();await settle()
	check("PLAN-UI-08",JSON.stringify(await saved())==JSON.stringify(before) and plan().entries()==entries,"checkout cancel retains plans and completed sale")
	plan().confirm_plan();await settle();confirm=game.dialog.actions.get_child(1);confirm.pressed.emit();confirm.pressed.emit();await settle()
	check("PLAN-UI-09",game.campaign().gold==10 and game.campaign().characters.guard.weapon=="staff-wood" and game.campaign().characters.archer.weapon=="bow-wood-1","atomic batch purchase occurs once")
	check("PLAN-UI-10",game.campaign().characters.guard.inventory["sword-wood"]==1 and game.campaign().characters.archer.inventory["bow-wood"]==1 and plan().draft().is_empty(),"old equipment retained by each owner and successful plan cleared")
	check("PLAN-UI-11",game.shop_uid==recipient and game.pages.gear_id==selected,"sale and checkout preserve shop recipient and candidate")
	var report=FileAccess.open(evidence.path_join("shop-plan-ui.json"),FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));report.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(4):await process_frame
	quit(0 if failures.is_empty() else 1)
