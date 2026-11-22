extends SceneTree
var game
var checks=[]
const GUARD="character_mirei"
const SCOUT="character_shion"
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func settle():
	for i in range(12):await process_frame
	while game.locked or game.engine.busy or game.presenting:await process_frame
	for i in range(4):await process_frame
func node(name_: String):return game.find_child(name_,true,false)
func tap(name_: String):node(name_).pressed.emit();await settle()
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func row_y():return node("Product_greatsword-wood").global_position.y
func buy(id: String,uid: String):
	await tap("RosterMember_"+uid);await tap("Product_"+id)
	await tap("ShopComparisonBuy")
	check(not game.modal_open() and game.save_notice.visible and game.save_notice.caption.text=="%sへ %s×1 / 支払%dG" % [game.member_name(uid),game.pages.shop_view.receipt.gear.name,int(game.pages.shop_view.receipt.cost)],"purchase completion shows recipient/item/count/payment without blocking")
func return_to_catalog():
	var buttons=node("ShopTransactionFooter").find_children("*","Button",true,false)
	for button in buttons:
		if button.text=="商品一覧へ":
			button.pressed.emit()
			return
	check(false,"sale detail has a return to catalog action")
func check_weapon_values(attack: int,reach: int):
	var labels=node("ShopTransaction").find_children("*","Label",true,false)
	check(labels.any(func(label):return label.text=="物理ATK：%d" % attack) and labels.any(func(label):return label.text=="武器射程：%d" % reach),"owned weapon details show attack %d and reach %d" % [attack,reach])
func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.location="east";seed.state.gold=500;seed.state.characters[SCOUT].inventory={"twin-bow":2}
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy")
	var shop=game.pages.shop_view;var y=row_y()
	check(node("ShopNotice")==null and shop.transaction.is_empty(),"shop starts without a transaction notice")
	await tap("RosterMember_"+GUARD)
	for spec in [["undertow-sword","skill_retreat_slash","退き斬り"],["twin-bow","skill_split_shot","分け撃ち"],["dagger-wood","skill_ambush","奇襲"]]:
		await tap("Product_"+spec[0])
		var skills=node("ShopComparisonSkills").find_children("ComparisonSkill_追加_"+spec[1]+"_*","Button",true,false)
		check(skills.size()==1 and skills[0].tooltip_text.contains(spec[2]) and skills[0].text=="Lv1","inline comparison shows the named skill and level for "+spec[0])
		check(node("ShopComparisonProduct").get_theme_font_size("font_size")>=18 and node("ShopTransactionFooter").is_ancestor_of(node("ShopComparisonBuy")) and node("ShopTransactionFooter").is_ancestor_of(node("ProductTrial_"+spec[0])),"comparison heading is readable and both actions stay in the footer")
	await tap("Product_hammer-iron-1")
	check(node("ShopComparisonStats").get_parsed_text().contains("(-1)"),"iron hammer comparison preserves the negative speed change")
	var before=await saved()
	await tap("Product_undertow-sword")
	check(await saved()==before and shop.transaction.is_empty(),"preview leaves the save and latest transaction unchanged")
	await buy("undertow-sword",GUARD)
	check(game.campaign().gold==400 and shop.transaction.ownerId==GUARD and shop.transaction.text==game.member_name(GUARD)+"へ 引き波の剣×1 / 支払100G","purchase notice names the recipient, item and cost")
	check(node("SaleItem_undertow-sword")!=null and game.campaign().characters[GUARD].weapon==seed.state.characters[GUARD].weapon and row_y()==y,"purchase appears in the recipient inventory without equipping or shifting the catalog")
	await tap("SaleItem_undertow-sword")
	check_weapon_values(26,1)
	return_to_catalog();await settle()
	await buy("twin-bow",SCOUT)
	check(game.campaign().gold==300 and shop.transaction.ownerId==SCOUT and node("SaleItem_twin-bow")!=null and row_y()==y,"second purchase updates the recipient without shifting the catalog")
	await tap("SaleItem_twin-bow")
	check_weapon_values(25,3)
	var sale=shop.sale
	node("FacilitySaleQuantity").value=2;await settle()
	before=await saved();await tap("FacilitySalePrepare")
	check(sale.stage=="confirm" and sale.quote.get("count")==2 and sale.quote.get("proceeds")==200,"sale receipt uses selected quantity and proceeds")
	sale.confirmation.canceled.emit();await settle()
	check(sale.stage=="selected" and sale.amount==2 and sale.item_id=="twin-bow" and sale.owner_id==SCOUT and await saved()==before,"sale cancellation preserves owner, item, quantity and full save")
	await tap("FacilitySalePrepare")
	check(sale.stage=="confirm" and sale.quote.get("proceeds")==200,"reopened receipt retains the two-unit proceeds")
	sale.confirmation.canceled.emit();await settle()
	node("FacilitySaleQuantity").value=1;await settle()
	await tap("FacilitySalePrepare");sale.confirmation.confirmed.emit();await settle()
	check(sale.stage=="list" and game.campaign().gold==400 and game.campaign().characters[SCOUT].inventory.get("twin-bow")==2,"single sale updates actual inventory and gold")
	check(shop.transaction.kind=="sell" and shop.transaction.text==game.member_name(SCOUT)+"の双射の弓×1を売却 / 受取100G","latest sale replaces the purchase notice with the actual proceeds")
	var sale_notice=shop.transaction.duplicate(true);before=await saved()
	return_to_catalog();await settle()
	check(row_y()==y,"returning from the sale preserves catalog position")
	await tap("Product_undertow-sword");await tap("ProductTrial_undertow-sword");await tap("TrialRecipientCancel")
	check(shop.transaction==sale_notice and await saved()==before,"trial recipient cancel preserves the last transaction and campaign")
	await tap("ProductTrial_undertow-sword");await tap("TrialRecipient_"+GUARD);await game.act("endTrial",[]);await settle()
	check(shop.transaction==sale_notice and await saved()==before and row_y()==y,"trial roundtrip preserves sale notice, campaign and catalog position")
	shop.message="結果不明の検査警告";shop.unknown=true;game.render();await settle()
	check(node("ShopNotice").text==shop.message and node("ShopComparisonBuy").disabled,"unresolved transaction shows warning and prevents purchase")
	seed.state.location="west";await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy");await tap("RosterMember_"+GUARD)
	await tap("Product_armor-iron-2")
	var stats=node("ShopComparisonStats").get_parsed_text()
	check(stats.contains("(+55)") and stats.contains("(-1)"),"armor comparison preserves positive HP and negative speed changes")
	await tap("Product_armor-cloth")
	check(node("ShopComparisonStats").get_parsed_text().contains("能力値の変化なし"),"plain armor comparison shows no invented bonus")
	await tap("Product_cloth-head")
	var panels=shop.comparison_view.panels
	var current=panels[0].find_children("*","Label",true,false)
	var candidate=panels[1].find_children("*","Label",true,false)
	check(not current.any(func(label):return label.text.contains("DEF：")) and candidate.any(func(label):return label.text=="物理DEF：1（↑1）"),"empty head slot has no defense stat and cloth head shows its own defense and delta")
	game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	var f=FileAccess.open(OS.get_environment("INVENTORY_QA_ROOT").path_join("polish-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	quit(0 if checks.all(func(c):return c.passed) else 1)
