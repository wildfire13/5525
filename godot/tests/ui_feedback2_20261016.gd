extends "res://tests/ui_feedback_20261016.gd"
func consent(yes: bool):
	var d=game.pages.party_view.inventory_view.confirmation
	if yes:d.confirmed.emit()
	else:d.canceled.emit()
	await settle()
func battle_fixture():
	var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")]),output,true,false)
	return JSON.parse_string("".join(output))
func run():
	create_timer(85).timeout.connect(func():print("FAIL feedback2 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.characters.guard.inventory={"potion":3,"spear-wood":2,"swift-boots":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	var p=game.pages.party_view;var inv=p.inventory_view
	p.open_detail("guard");await settle()
	var status=game.dialog.window;status.position=Vector2i(50,60);status.size=Vector2i(1000,800);await frames()
	check(node("OwnedEquipment_swift-boots").tooltip_text.contains("俊足"),"S1 item hover retains item details separately")
	node("OwnedEquipmentActions_swift-boots").focus_entered.emit();await settle()
	var hover=node("EquipmentHover")
	check(hover.visible and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(hover.position),Vector2(hover.size))),"S1 comparison stays within FHD (feedback3 placement)")
	var text=node("OwnedEquipmentComparison").text
	check(text.contains("俊足") and not text.contains("人物全体") and not text.contains("単品性能") and not text.contains("武器ATK") and not text.contains("+0"),"S2/3 comparison only changed effects without redundant headings")
	var q={"before":{"max":245,"maxMp":10,"speed":14,"def":0},"after":{"max":207,"maxMp":10,"speed":14,"def":0}}
	text=p.owned_equipment_view.comparison({"hp":144,"mp":10},{"equipSlots":[]},"upperBody",q)
	check(text.contains("-38") and not text.contains("MP") and not text.contains("現在HP") and not text.contains("DEF"),"S3 retains HP upper limit -38 and omits unchanged resources")
	var before=await saved();var scroll=game.dialog.body.get_parent();scroll.scroll_vertical=100000;await frames();var offset=scroll.scroll_vertical
	await click("OwnedEquipmentActions_swift-boots")
	check(is_instance_valid(inv.confirmation) and inv.confirmation.get_parent()==status and game.dialog.window==status and inv.confirmation!=status,"S4 equipment uses independent child confirmation")
	await consent(false)
	check(await saved()==before and p.detail_tab==0 and abs(scroll.scroll_vertical-offset)<=2,"S4 equipment NO preserves save and originating list scroll")
	await click("OwnedEquipmentActions_swift-boots");inv.confirmation.close_requested.emit();await settle()
	check(inv.stage!="confirm" and await saved()==before and p.detail_tab==0,"S4 closing equipment confirmation consumes nothing")
	await click("OwnedEquipmentActions_swift-boots")
	var d=inv.confirmation;d.confirmed.emit();d.confirmed.emit();await settle()
	var after=await saved()
	check(not after.state.characters.guard.inventory.has("swift-boots") and inv.stage=="list","S4 repeated YES equips exactly once")
	await all_inventory();await click("OwnedEquipment_potion");await click("InventoryDiscard");await click("InventoryPrepareDiscard")
	check(inv.confirmation.visible and inv.confirmation.get_parent()==status,"S4 discard uses independent confirmation")
	before=await saved();await consent(false);check(await saved()==before,"S4 discard NO preserves all inventory")
	await click("InventoryDiscard");await click("InventoryPrepareDiscard");await consent(true)
	check((await saved()).state.characters.guard.inventory.potion==2,"S4 discard YES removes exactly one")
	game.dialog.close();await settle();game.navigate("map");await settle()
	var map=node("TownMap")
	check(map.buttons[map.current].get_theme_stylebox("normal").bg_color==Color("#243c58"),"S5 current location is blue")
	check(map.buttons[map.selected].get_theme_stylebox("normal").bg_color==Color("#236044"),"S5 selected destination is green")
	check(map.buttons.values().filter(func(b):return b.text.contains("目的地") or b.text.contains("現在地")).is_empty(),"S5 map uses color without redundant location labels")
	check(map.buttons.values().filter(func(b):return b.name not in ["Town_"+map.current,"Town_"+map.selected]).all(func(b):return b.get_theme_stylebox("normal").bg_color==Color("#41464e")),"S5 all other towns gray")
	check(node("DepartButton").size.x<600 and node("DepartButton").get_theme_stylebox("normal").bg_color==Color("#236044"),"S5 departure button narrow and green")
	seed.state.location="west";await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle()
	check(game.resource_header.visible and game.gold_header.is_visible_in_tree(),"S7 shop gold uses common upper-right header")
	check(node("ShopSlotFilter").get_item_text(0)=="商品リスト（すべて）","S7 product heading retains filter (feedback3 layout)")
	check(game.find_children("ProductSummary_*","Label",true,false).is_empty(),"S6 no permanent performance descriptions")
	var product=node("Product_swift-boots");var price=node("ProductPrice_swift-boots")
	check(product.is_ancestor_of(price) and product.get_global_rect().encloses(price.get_global_rect()),"S6 price inside product right edge")
	check(product.tooltip_text.contains("俊足"),"S6 performance available on hover")
	check(not game.find_children("*","Label",true,false).any(func(label):return label.text.contains("購入した品は")),"S6 redundant recipient instruction removed")
	var original_shop=game.data.campaign.shop.duplicate(true)
	for item in game.data.campaign.shop:item.name="長い商品名の折り返し確認".repeat(16)
	game.render();await settle()
	product=node("Product_swift-boots");price=node("ProductPrice_swift-boots")
	check(product.get_global_rect().encloses(price.get_global_rect()) and product.size.y>80,"S6 long product names wrap without displacing price")
	game.data.campaign.shop=original_shop
	var fixture=battle_fixture();await game.update({"op":"campaign_load","data":fixture.guard});await settle()
	var hud=game.hud;hud.open_items();await settle()
	var list=node("BattleItemList");check(list.get_parent().get_parent()==hud.bottom_commands and list.get_parent().get_index()>hud.buttons.items.get_index() and list.get_parent().get_index()<hud.buttons.guard.get_index(),"S9 item list between item and guard commands")
	before=await saved();await click("BattleItem_potion");await game.on_cell(int(hud.acting().pos));await settle()
	check(node("BattleConsent")!=null and game.can_commit() and node("PredictionSummary")!=null,"S8/9 self item target shows prediction and execute consent")
	game.cancel();await settle();check(await saved()==before and not game.can_commit(),"S9 item cancellation consumes no stock or action")
	# Healer with missing HP, plus a full-HP self hover. Both use actual bridge predictions.
	var heal=fixture.guard.duplicate(true);heal.state.battle.actor="mage"
	for u in heal.state.battle.units:
		u.next=1000
		if u.id=="mage":u.next=1;u.hp=20
	check((await game.update({"op":"campaign_load","data":heal})).get("ok",false),"valid healer fixture");await settle();hud.open_skills();await settle()
	list=node("BattleSkillList");check(list.get_parent().get_parent()==hud.bottom_commands and list.get_parent().get_index()>hud.buttons.skill.get_index() and list.get_parent().get_index()<hud.buttons.items.get_index(),"S9 skill list between skill and item commands")
	check(not node("BattleSkill_mage").tooltip_text.is_empty(),"S9 skill descriptions on hover")
	var original_skills=game.data.skillset.duplicate(true)
	for i in range(40):game.data.skillset.append({"id":"long-"+str(i),"name":"長いスキル名".repeat(12)})
	game.render();await settle()
	check(node("BattleSkillList").get_child_count()>=41 and hud.left_panel.body.get_parent().get_v_scroll_bar().max_value>hud.left_panel.body.get_parent().size.y,"S9 many long skills scroll within saved actor window")
	game.data.skillset=original_skills;game.render();await settle()

	await click("BattleSkill_mage");await game.on_cell(int(hud.acting().pos));await settle()
	var prediction=await game.engine.request({"op":"hover_preview","kind":"skill","uid":"mage"})
	check(prediction.hover.accuracy==100 and prediction.hover.effectPreview.any(func(e):return e.id=="mage" and e.hp>0),"S8 self heal predicts recovery with 100 percent hit")
	check(node("BattleConsent")!=null and node("PredictionSummary")!=null and game.can_commit(),"S9 skill target click produces execute/cancel consent")
	before=await saved();game.cancel();await settle();check(await saved()==before and not game.can_commit(),"S9 skill cancel preserves MP HP inventory and action")
	await game.on_cell(int(hud.acting().pos));await settle();var action_count=int(game.state().actions)
	game.commit();game.commit();await settle();check(int(game.state().actions)==action_count+1,"S9 skill execution completes once through action guard")
	for u in heal.state.battle.units:
		if u.id=="mage":u.hp=u.max
	await game.update({"op":"campaign_load","data":heal});await settle();await game.select_skill("mage");await settle()
	prediction=await game.engine.request({"op":"hover_preview","kind":"skill","uid":"mage"})
	check(prediction.hover.fullHealth and prediction.hover.accuracy==100 and prediction.hover.status=="ready","S8 full HP self heal provides explicit zero-effect hover")
	check(not game.data.choices.skill.has("mage"),"S8 full HP hover does not enable wasteful execution")
	var f=FileAccess.open(evidence.path_join("ui-feedback2.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
