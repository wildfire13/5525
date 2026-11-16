extends "res://tests/shop_rows_regression.gd"

# The purchase-plan UI was removed. Keep its transaction regressions on the
# current shop: separate recipients, sale-funded purchases and explicit consent.
func run():
	var evidence=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.to_lower()+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game()
	game.checks_fast=true;game.audio.fast_mode=true;seed=await saved()
	await load_at("east",120,{"hammer-wood":1})
	var before=await saved()
	await tap("RosterMember_"+SCOUT);await tap("Product_bow-wood-1")
	check(not exists("AddPurchasePlan") and button("ShopComparisonBuy").disabled,"current shop blocks unaffordable purchase without obsolete plan controls")
	await game.pages.shop_view.confirm_purchase("bow-wood-1");await settle()
	check(await saved()==before,"unaffordable purchase preserves the entire new-game save")
	await tap("RosterMember_"+MAGE);await tap("SaleItem_hammer-wood");await tap("FacilitySalePrepare")
	var sale=game.pages.shop_view.sale
	sale.confirmation.canceled.emit();await settle()
	check(await saved()==before and sale.owner_id==MAGE and sale.amount==1,"sale cancellation preserves the real recruit's item and funds")
	await tap("FacilitySalePrepare")
	var confirmation=sale.confirmation;confirmation.confirmed.emit();confirmation.confirmed.emit();await settle()
	check(game.campaign().gold==220 and not game.campaign().characters[MAGE].inventory.has("hammer-wood"),"sale funds purchases exactly once")
	await tap("RosterMember_"+GUARD);await tap("Product_staff-wood");await tap("ShopComparisonBuy")
	before=await saved();await tap("PurchaseDecline")
	check(await saved()==before,"purchase cancellation retains the completed sale")
	await tap("ShopComparisonBuy")
	var agree=button("PurchaseAgree");agree.pressed.emit();agree.pressed.emit();await settle()
	check(game.campaign().gold==150 and game.campaign().characters[GUARD].inventory.get("staff-wood",0)==1,"first recipient receives one purchased staff")
	await tap("RosterMember_"+SCOUT);await tap("Product_bow-wood-1");await tap("ShopComparisonBuy")
	agree=button("PurchaseAgree");agree.pressed.emit();agree.pressed.emit();await settle()
	check(game.campaign().gold==10 and game.campaign().characters[SCOUT].inventory.get("bow-wood-1",0)==1,"second recipient receives one purchased bow")
	check(game.campaign().characters[GUARD].weapon==seed.state.characters[GUARD].weapon and game.campaign().characters[SCOUT].weapon==seed.state.characters[SCOUT].weapon and game.campaign().characters[SCOUT].weapon=="dagger-wood","purchases preserve actual starting equipment without automatic equip")
	check(game.pages.shop_view.selected_owner()==SCOUT and game.pages.shop_view.stage=="S0" and not game.modal_open(),"completed purchases preserve the selected recruit and return to the workspace")
	var file=FileAccess.open(evidence.path_join("shop-plan-ui.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	game.closing=true;game.dialog.close(false);game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(row):return row.passed) else 1)
