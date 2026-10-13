extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
	for i in range(4):await process_frame
func node(name_: String):return game.find_child(name_,true,false)
func tap(name_: String):node(name_).pressed.emit();await settle()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func row_y():return node("ProductRow_greatsword-wood").global_position.y
func buy(id: String,uid: String):
	await tap("ProductBuy_"+id);await tap("PurchaseAgree");await tap("PurchaseRecipient_"+uid)
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.location="east";seed.state.gold=500;seed.state.characters.archer.inventory={"twin-bow":2}
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle()
	var shop=game.pages.shop_view;var y=row_y()
	check(node("ShopNoticeRegion").size.y==56 and node("ShopNotice").text.is_empty() and node("PurchasedInventory")==null,"empty fixed notice reserves 56px without inventory link")
	check(node("ProductSummary_undertow-sword").text=="ATK 26 / 通常射程1 / 付与：退き斬り" and node("ProductSummary_twin-bow").text=="ATK 25 / 通常射程3 / 付与：分け撃ち","adjacent real weapon summaries have exact values and skill names")
	check(node("ProductSummary_hammer-iron-1").text.contains("行動速度 -1") and node("ProductSummary_dagger-wood").text.contains("奇襲Lv1"),"summary preserves negative signs and equipment skill Lv")
	check(node("ProductSummary_undertow-sword").get_theme_font_size("font_size")>=18 and node("Product_undertow-sword").size.x==720,"FHD readable summary and bounded information width")
	var row=node("ProductRow_undertow-sword");var price_x=row.get_child(1).global_position.x;var buy_x=row.get_child(2).global_position.x
	check(row.get_child(2).size.x==130 and row.get_child(3).size.x==170 and buy_x<1000,"same-row buy/trial widths remain close to information")
	var item=game.data.campaign.shop.filter(func(g):return g.id=="undertow-sword")[0];var original=item.name;item.name=(original+"[長文検証]").repeat(10);game.render();await settle()
	row=node("ProductRow_undertow-sword")
	check(row.get_child(1).global_position.x==price_x and row.get_child(2).global_position.x==buy_x and node("ProductName_undertow-sword").clip_text and node("ProductSummary_undertow-sword").clip_text,"long names cannot push aligned action columns")
	check(node("Product_undertow-sword").heading==item.name and node("Product_undertow-sword").tooltip_text.contains("通常攻撃射程：1"),"existing hover retains full long name and actual details")
	item.name=original;game.render();await settle()
	var before=await saved();await tap("ProductBuy_undertow-sword");await tap("PurchaseDecline")
	check((await saved())==before and shop.transaction.is_empty(),"payment decline does not invent latest transaction")
	await buy("undertow-sword","guard")
	check(game.campaign().gold==400 and shop.transaction.ownerId=="guard" and not node("ShopNotice").text.contains("残金"),"purchase notice contains recipient/item/payment, current money stays in header")
	check(row_y()==y and node("ShopNoticeRegion").size.y==56 and node("PurchasedInventory").text=="ガロの所持品を見る","first purchase keeps list Y and adds named inventory link")
	before=await saved();await tap("PurchasedInventory")
	check(game.pages.party_view.detail_uid=="guard" and game.pages.party_view.detail_tab==3 and node("InventoryItem_undertow-sword")!=null,"one click opens actual recipient's inventory")
	check((await saved())==before and game.campaign().characters.guard.weapon==seed.state.characters.guard.weapon,"inventory link is pure; original equipment unchanged")
	await tap("StatusClose");check(row_y()==y,"closing linked inventory preserves shop list position")
	await buy("twin-bow","archer")
	check(game.campaign().gold==300 and shop.transaction.ownerId=="archer" and node("PurchasedInventory").text=="リノの所持品を見る" and row_y()==y,"second purchase updates owner without layout shift")
	await tap("PurchasedInventory");await tap("InventorySell_twin-bow")
	var inv=game.pages.party_view.inventory_view;inv.amount=2;inv.redraw();await settle();before=await saved()
	await tap("InventoryPrepareSale");check(inv.quote.count==2 and inv.quote.proceeds==200,"multiple-unit sale quote uses selected quantity")
	await tap("InventoryCancel")
	check(inv.stage=="targets" and inv.amount==2 and inv.item_id=="twin-bow" and inv.owner_id=="archer" and inv.quote.is_empty(),"sale cancel returns same owner/item/count to quantity and discards quote")
	check((await saved())==before and node("InventoryList").text=="所持品一覧へ","sale cancel is pure and quantity has explicit list exit")
	await tap("InventoryPrepareSale");await tap("StatusBack")
	check(inv.stage=="targets" and inv.amount==2 and inv.quote.is_empty(),"status Back matches sale cancel target and quantity")
	await tap("InventoryPrepareSale")
	var event=InputEventKey.new();event.pressed=true;event.keycode=KEY_ESCAPE;game.dialog.window.window_input.emit(event);await settle()
	check(game.modal_open() and inv.stage=="targets" and inv.amount==2 and inv.quote.is_empty(),"sale confirmation Escape returns to quantity without closing status")
	await tap("InventoryPrepareSale");check(inv.quote.count==2 and inv.quote.proceeds==200,"requote after back retrieves correct quantity and proceeds")
	await tap("InventoryCancel");await tap("StatusClose")
	check((await saved())==before and not game.modal_open(),"closing status after back never sells or revives confirmation")
	await tap("PurchasedInventory");await tap("InventorySell_twin-bow");await tap("InventoryPrepareSale");await tap("InventoryConfirm")
	check(game.campaign().gold==400 and game.campaign().characters.archer.inventory.get("twin-bow")==2,"normal single sale still updates actual owner and gold")
	check(inv.stage=="list" and inv.message=="双射の弓×1を売却 / 受取100G","inventory reports concrete successful sale")
	check(shop.transaction.kind=="sell" and node("PurchasedInventory")==null and node("ShopNotice").text.contains("リノの双射の弓×1を売却 / 受取100G") and not node("ShopNotice").text.contains("300G"),"latest sale replaces purchase notice and removes stale recipient link")
	await tap("StatusClose")
	check(row_y()==y and node("ShopNoticeRegion").size.y==56,"sale and status close keep product Y")
	var sale_notice=shop.transaction.duplicate(true);before=await saved()
	await tap("ProductTrial_undertow-sword");await tap("TrialRecipientCancel")
	check(shop.transaction==sale_notice and (await saved())==before,"trial recipient cancel does not change latest success")
	await tap("ProductTrial_undertow-sword");await tap("TrialRecipient_guard");await game.act("endTrial",[]);await settle()
	check(shop.transaction==sale_notice and (await saved())==before and row_y()==y,"trial roundtrip preserves latest sale notice and campaign")
	shop.message="結果不明の検査警告";shop.unknown=true;game.render();await settle()
	check(node("ShopNotice").text==shop.message and node("PurchasedInventory")==null and node("ShopNoticeRegion").size.y==56,"unknown warning is not replaced by success or inventory link")
	shop.message="";shop.unknown=false;game.render();await settle()
	await tap("PartyFace_guard");await tap("StatusTab_3");await tap("InventoryItem_undertow-sword");await tap("InventoryDiscard")
	await tap("InventoryPrepareDiscard");check(node("InventoryCancel").text=="取り消す","non-sale confirmation caption unchanged")
	await tap("InventoryCancel");check(inv.stage=="actions","non-sale cancel still returns original operation selection")
	game.dialog.close(false);seed.state.location="west";await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle()
	check(node("ProductSummary_armor-iron-2").text=="HP +55 / 行動速度 -1" and node("ProductSummary_armor-cloth").text=="補正なし","nonweapon summary preserves real positive/negative bonuses without invented stats")
	game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("polish-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
