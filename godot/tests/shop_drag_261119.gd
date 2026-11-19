extends "res://tests/shop_polish_regression.gd"

func product(id: String) -> Dictionary:
	return {"kind":"shop_product","item":id,"connection":game.engine.connection_generation,"epoch":game.pages.epoch,"token":game.campaign().inventoryToken}
func pointer_drop(source: Control,target: Control,data: Dictionary):
	source.force_drag(data,null)
	var move=InputEventMouseMotion.new();move.position=target.get_global_rect().get_center();root.push_input(move)
	await process_frame
	var release=InputEventMouseButton.new();release.position=move.position;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;root.push_input(release)
	await settle()
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa.to_lower()+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.location="east";seed.state.gold=1000
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy")
	var shop=game.pages.shop_view
	await tap("RosterMember_"+GUARD);shop.set_inventory_tab("equipment");await settle()
	var before=await saved()
	await pointer_drop(node("Product_spear-wood"),node("ShopEquipped_rightHand"),product("spear-wood"))
	check(node("PurchaseAgree")!=null,"actual equipment drop opens consent")
	if node("PurchaseAgree")==null:quit(1);return
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(qa.path_join("shop-drag-consent.png"))
	check((await saved())==before,"drop and quote do not mutate")
	await tap("PurchaseDecline");check((await saved())==before,"cancel is pure")
	shop.drop_equipment(product("spear-wood"),"rightHand");await settle();await tap("PurchaseAgree")
	var after=await saved()
	check(after.state.characters[GUARD].weapon=="spear-wood" and after.state.gold==910 and after.state.characters[GUARD].inventory.get("sword-wood",0)==1,"single atomic buy equip retains old gear")
	before=after
	shop.drop_equipment(product("spear-wood"),"head");await settle()
	check(node("PurchaseAgree")==null and not shop.message.is_empty() and (await saved())==before,"wrong slot gives reason without purchase")
	shop.drop_equipment(product("bow-wood"),"rightHand");await settle()
	check(node("PurchaseAgree")==null and not shop.message.is_empty() and (await saved())==before,"two hand conflict gives reason without purchase")
	var stale=product("dagger-wood");stale.token="stale"
	check(not shop.can_drop_product(stale,GUARD),"stale inventory payload rejected")
	stale=product("dagger-wood");stale.connection-=1
	check(not shop.can_drop_product(stale,GUARD),"old connection payload rejected")
	shop.set_inventory_tab("inventory");await settle()
	await pointer_drop(node("Product_dagger-wood"),node("SaleItem_sword-wood"),product("dagger-wood"))
	check(node("PurchaseAgree")!=null,"actual product to inventory row drop opens consent")
	if node("PurchaseAgree")==null:quit(1);return
	await tap("PurchaseAgree")
	after=await saved()
	check(after.state.characters[GUARD].weapon=="spear-wood" and after.state.characters[GUARD].inventory.get("dagger-wood",0)==1,"inventory drop buys without equipping")
	var entry=shop.sale.entries().filter(func(item):return item.id=="dagger-wood")[0]
	var payload=game.pages.party_view.workspace.payload(entry,"transfer",null,GUARD)
	before=await saved()
	await pointer_drop(node("SaleItem_dagger-wood"),node("Product_spear-wood"),payload)
	check(node("FacilitySaleConfirmation")!=null and node("ShopCatalog").visible,"actual inventory to product drop opens sale receipt and keeps catalog")
	if node("FacilitySaleConfirmation")==null:quit(1);return
	shop.sale.confirmation.canceled.emit();shop.sale.confirmation.hide();await settle()
	check((await saved())==before,"sale cancellation is pure")
	shop.drop_sale(payload);await settle()
	var proceeds=int(shop.sale.quote.proceeds)
	shop.sale.confirmation.confirmed.emit();await settle()
	after=await saved()
	check(after.state.gold==before.state.gold+proceeds and after.state.characters[GUARD].inventory.get("dagger-wood",0)==0,"sale commits exactly once")
	check(not shop.can_drop_sale(payload),"committed sale payload cannot be replayed")
	var equipped=product("spear-wood");equipped.kind="character_transfer";equipped.owner=GUARD;equipped.action="transferEquipped"
	before=await saved();shop.drop_sale(equipped);await settle()
	check(not shop.message.is_empty() and (await saved())==before,"equipped item sale refused without unequipping")
	seed=before;seed.state.gold=1000;seed.state.characters[GUARD].inventory={"sword-wood":1,"ether":1}
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy");await tap("RosterMember_"+GUARD)
	before=await saved();shop.drop_inventory(product("dagger-wood"));await settle()
	check(node("PurchaseAgree")==null and not shop.message.is_empty() and (await saved())==before,"full inventory reason and no mutation")
	after=await saved()
	seed=after;seed.state.gold=0
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy");await tap("RosterMember_"+GUARD)
	before=await saved();shop.drop_inventory(product("spear-wood"));await settle()
	check(node("PurchaseAgree")==null and not shop.message.is_empty() and (await saved())==before,"insufficient funds reason and no mutation")
	seed=before;seed.state.location="west";seed.state.gold=1000
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy");await tap("RosterMember_"+GUARD)
	shop.set_inventory_tab("equipment");await settle()
	await pointer_drop(node("Product_cloth-head"),node("ShopEquipped_head"),product("cloth-head"))
	check(node("PurchaseAgree")!=null,"armor product drops onto the matching head slot")
	if node("PurchaseAgree")==null:quit(1);return
	await tap("PurchaseAgree");after=await saved()
	check(after.state.characters[GUARD].head=="cloth-head" and after.state.gold==970,"armor purchase equips exactly the selected slot")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(qa.path_join("shop-drag.png"))
	var file=FileAccess.open(qa.path_join("checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(row):return row.passed) else 1)
