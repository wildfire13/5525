extends "res://tests/ui_feedback_20261016.gd"
func battle_fixture():
	return preload("res://tests/ui_current_fixture.gd").generate("res://tests/inventory_battle_fixtures.cjs")
func product_price(product):
	var prices=product.find_children("*","Label",true,false).filter(func(label):return label.text.ends_with("G") and label.text.trim_suffix("G").is_valid_int())
	return prices[0] if prices.size()==1 else null
func run():
	create_timer(85).timeout.connect(func():print("FAIL feedback2 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.characters["character_mirei"].inventory={"potion":3,"spear-wood":2,"swift-boots":1}
	await game.update({"op":"campaign_load","data":seed});await settle()
	game.pages.party_view.open_inventory("character_mirei");await settle()
	var entry=game.campaign().inventoryByCharacter["character_mirei"].entries.filter(func(e):return e.id=="swift-boots")[0]
	var boots=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==entry.name)[0]
	boots.pressed.emit();await settle()
	var comparison=node("CharacterEquipmentComparison")
	var candidate=node("ShopComparisonProduct")
	check(candidate!=null and candidate.is_visible_in_tree() and candidate.text==entry.name and comparison.is_visible_in_tree() and comparison.text.begins_with("比較対象："+str(game.campaign().slots.feet)) and not comparison.text.contains("+0"),"S1/S2 selected boots show the comparison without unchanged bonuses")
	var q={"before":{"max":245,"maxMp":10,"speed":14,"def":0},"after":{"max":207,"maxMp":10,"speed":14,"def":0}}
	var text=game.pages.shop_view.comparison_view.comparison_text({"hp":144,"mp":10},{"equipSlots":[]},"upperBody",q)
	check(text.contains("-38") and not text.contains("MP") and not text.contains("現在HP") and not text.contains("DEF"),"S3 retains HP upper limit -38 and omits unchanged resources")
	var equip=node("CharacterEquip");equip.pressed.emit();equip.pressed.emit();await settle()
	check(not (await saved()).state.characters["character_mirei"].inventory.has("swift-boots"),"S4 repeated equip consumes exactly one pair of boots")
	entry=game.campaign().inventoryByCharacter["character_mirei"].entries.filter(func(e):return e.id=="potion")[0]
	var potion=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==entry.name)[0]
	potion.pressed.emit();await settle()
	await click("CharacterItemDetails")
	check(node("SkillDetailsBody").text.contains("HP"),"S5 owned potion details include its recovery effect")
	await click("SkillDetailsBack")
	var before=await saved();await click("CharacterDiscard")
	check(node("CharacterDiscardQuantity").value==1,"S4 discard defaults to one item")
	game.dialog.close();await settle();check(await saved()==before,"S4 discard cancel preserves all inventory")
	await click("CharacterDiscard");await click("CharacterDiscardConfirm")
	check((await saved()).state.characters["character_mirei"].inventory.potion==2,"S4 discard removes exactly one")
	game.navigate("map");await settle()
	var map=node("TownMap")
	check(map.buttons[map.current].disabled and map.buttons[map.current].get_theme_stylebox("disabled").bg_color==Color("#345c4e"),"S5 current location uses dark paper-palette fill and cannot be selected")
	check(map.buttons[map.selected].get_theme_stylebox("normal").border_color==Color("#37758a") and map.buttons[map.selected].get_theme_stylebox("normal").border_width_left==3,"S5 selected destination has distinct thick teal frame")
	check(map.buttons[map.current].get_node("TownContents").get_child(2).text=="出発地" and map.buttons[map.selected].get_node("TownContents").get_child(2).text=="目的地","S5 map state labels distinguish origin and destination")
	check(map.buttons.keys().filter(func(id):return id not in [map.current,map.selected,map.quest_destination]).all(func(id):return map.buttons[id].get_theme_stylebox("normal").bg_color==(Color("#e4eee0") if map.available.has(id) else Color("#d4d8d0")) and map.buttons[id].disabled==not map.available.has(id)),"S5 reachable and unavailable towns use distinct paper colors and availability")
	check(node("DepartButton").size.x<600 and node("DepartButton").get_theme_stylebox("normal").bg_color==Color("#236044"),"S5 departure button narrow and green")
	seed.state.location="west";await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
	var header=node("CampaignHeader");var gold_labels=header.find_children("*","Label",true,false).filter(func(label):return label.text==str(int(game.campaign().gold))+" G")
	check(header.is_visible_in_tree() and gold_labels.size()==1 and gold_labels[0].is_visible_in_tree() and gold_labels[0].global_position.x>root.size.x/2,"S7 shop gold uses visible common upper-right campaign header")
	check(node("ShopCatalog").is_ancestor_of(node("ShopSlotFilter")) and node("ShopSlotFilter").get_item_text(0)=="すべて" and node("ShopSlotFilter").get_item_metadata(0)=="all","S7 catalog retains all-products filter")
	check(game.find_children("ProductSummary_*","Label",true,false).is_empty(),"S6 no permanent performance descriptions")
	var product=node("Product_swift-boots");var price=product_price(product)
	check(product.is_ancestor_of(price) and product.get_global_rect().encloses(price.get_global_rect()),"S6 price inside product right edge")
	check(product.tooltip_text.contains("俊足"),"S6 product identity available on hover")
	before=await saved();await click("Product_swift-boots")
	check(node("ShopComparisonStats")!=null and not node("ShopComparisonStats").text.is_empty() and not game.modal_open() and await saved()==before,"S6 selecting product exposes inline performance without changing save")
	check(not game.find_children("*","Label",true,false).any(func(label):return label.text.contains("購入した品は")),"S6 redundant recipient instruction removed")
	var original_shop=game.data.campaign.shop.duplicate(true)
	for item in game.data.campaign.shop:item.name="長い商品名の折り返し確認".repeat(16)
	game.render();await settle()
	product=node("Product_swift-boots");price=product_price(product)
	var title=product.find_children("*","Label",true,false).filter(func(label):return label!=price)[0]
	check(product.get_global_rect().encloses(price.get_global_rect()) and title.clip_text and title.autowrap_mode==TextServer.AUTOWRAP_OFF and product.tooltip_text=="長い商品名の折り返し確認".repeat(16) and title.get_global_rect().end.x<=price.global_position.x and product.size.y<=80,"S6 long product name clips within row, retains full tooltip, and never displaces price")
	game.data.campaign.shop=original_shop
	var fixture=battle_fixture();await game.update({"op":"campaign_load","data":fixture.guard});await settle()
	var hud=game.hud;hud.open_items();await settle()
	var list=node("BattleItemList");check(list.get_parent().get_parent()==hud.bottom_commands and list.get_parent().get_index()>hud.buttons.items.get_index() and list.get_parent().get_index()<hud.buttons.action_defend.get_index(),"S9 item list between item and guard commands")
	before=await saved();await click("BattleItem_potion");await game.on_cell(int(hud.acting().pos));await settle()
	check(game.find_children("*","Button",true,false).any(func(b):return b.get_meta("ui_key","")=="battle_commit" and b.text=="実行") and game.can_commit() and game.hud.left_info.find_child("Inspect_hp",true,false).projected>game.hud.acting().hp,"S8/9 self item target shows prediction and execute consent")
	game.cancel();await settle();check(await saved()==before and not game.can_commit(),"S9 item cancellation consumes no stock or action")
	# Healer with missing HP, plus a full-HP self hover. Both use actual bridge predictions.
	var heal=fixture.guard.duplicate(true);heal.state.battle.actor="character_merina"
	for u in heal.state.battle.units:
		u.next=1000
		if u.id=="character_merina":u.next=1;u.hp=20
	check((await game.update({"op":"campaign_load","data":heal})).get("ok",false),"valid healer fixture");await settle();hud.open_skills();await settle()
	list=node("BattleSkillList");check(list.get_parent().get_parent()==hud.bottom_commands and list.get_parent().get_index()>hud.buttons.action_skill.get_index() and list.get_parent().get_index()<hud.buttons.items.get_index(),"S9 skill list between skill and item commands")
	check(not node("BattleSkill_skill_heal").tooltip_text.is_empty(),"S9 skill descriptions on hover")
	var original_skills=game.data.skillset.duplicate(true)
	for i in range(40):game.data.skillset.append({"id":"long-"+str(i),"name":"長いスキル名".repeat(12)})
	game.render();await settle()
	check(node("BattleSkillList").get_child_count()>=41 and hud.left_panel.body.get_parent().get_v_scroll_bar().max_value>hud.left_panel.body.get_parent().size.y,"S9 many long skills scroll within saved actor window")
	game.data.skillset=original_skills;game.render();await settle()

	await click("BattleSkill_skill_heal");await game.on_cell(int(hud.acting().pos));await settle()
	var prediction=await game.engine.request({"op":"hover_preview","kind":"action_skill","uid":"character_merina"})
	check(prediction.hover.accuracy==100 and prediction.hover.effectPreview.any(func(e):return e.id=="character_merina" and e.hp>0),"S8 self heal predicts recovery with 100 percent hit")
	check(game.find_children("*","Button",true,false).any(func(b):return b.get_meta("ui_key","")=="battle_commit" and b.text=="実行") and game.hud.left_info.find_child("Inspect_hp",true,false).projected>game.hud.acting().hp and game.can_commit(),"S9 skill target click produces execute/cancel consent")
	before=await saved();game.cancel();await settle();check(await saved()==before and not game.can_commit(),"S9 skill cancel preserves MP HP inventory and action")
	await game.on_cell(int(hud.acting().pos));await settle();var action_count=int(game.state().actions)
	game.commit();game.commit();await settle();check(int(game.state().actions)==action_count+1,"S9 skill execution completes once through action guard")
	for u in heal.state.battle.units:
		if u.id=="character_merina":u.hp=u.max
	await game.update({"op":"campaign_load","data":heal});await settle();await game.select_skill("skill_heal");await settle()
	prediction=await game.engine.request({"op":"hover_preview","kind":"action_skill","uid":"character_merina"})
	check(prediction.hover.fullHealth and prediction.hover.accuracy==100 and prediction.hover.status=="ready","S8 full HP self heal provides explicit zero-effect hover")
	check(not game.data.choices.action_skill.has("character_merina"),"S8 full HP hover does not enable wasteful execution")
	var f=FileAccess.open(evidence.path_join("ui-feedback2.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
