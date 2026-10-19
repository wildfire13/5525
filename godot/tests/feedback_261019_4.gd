extends "res://tests/feedback_261019_3.gd"
func run():
	create_timer(120).timeout.connect(func():print("FAIL feedback4 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.hours=142;seed.state.history.append("feedback4履歴保持")
	for resolution in [Vector2i(1920,1080),Vector2i(1364,1024)]:
		root.size=resolution;await settle()
		for place in ["astaris","east","west","south","north"]:
			await load_at(seed,place);game.navigate("hub");await settle()
			var name_=game.town_name(place)
			check(game.header.text==name_ and game.header.is_visible_in_tree() and node("TownFacilityHeading").text==name_+"の広場","town and square headings "+place+str(resolution))
			for page in (["board","map","inn","party"] if place=="astaris" else ["board","map","shop"]):
				game.navigate(page);await settle()
				check(game.header.text==name_ and game.header.is_visible_in_tree() and game.resource_header.visible,"persistent town and money "+place+page+str(resolution))
				if page=="board":check(labels().has("掲示板"),"board below town")
				if page=="inn":check(labels().has("宿屋"),"inn below town")
				if page=="party":check(node("PartyFacilityHeading").text.begins_with("ギルド"),"guild below town")
				if page=="shop":check(labels().has({"east":"武器店","west":"防具店","south":"道具店","north":"装飾品店"}[place]),"shop below town")
				if page=="map":
					var chart=node("TownMap");check(chart!=null and node("DepartButton")!=null,"map and depart remain")
					check(not labels().any(func(t):return t.begins_with("編成: ")),"map removes roster string")
					check(game.find_children("*","Button",true,false).filter(func(b):return not chart.is_ancestor_of(b) and b.text.trim_prefix("● ") in ["イース","ウエス","サウス","ノース"]).is_empty(),"map removes duplicate destination buttons")
					var destination=str(chart.available[-1]);chart.destination_selected.emit(destination);await settle()
					check(game.destination==destination and node("DepartButton").text==game.town_name(destination)+"へ出発","map selection still controls departure")
		await load_at(seed,"north");game.navigate("shop");await settle()
		var offered=game.pages.shop_view.offered();var names=offered.map(func(g):return g.name)
		check(offered.size()==5 and names.count("帰り路の指輪")==1 and not names.any(func(n):return n.contains("［装飾")),"one product per accessory")
		check(node("ShopSlotFilter").item_count==1 and node("ShopSlotFilter").get_item_text(0)=="商品リスト（すべて）","accessory all-only filter retained")
		game.pages.shop_view.select_slot("accessory2");await settle();check(game.pages.shop_view.offered().size()==5 and game.pages.shop_view.filter_slot=="all","legacy filter cannot hide accessories")
		var before=await saved();await click("ProductBuy_return-ring-1");await click("PurchaseDecline");check(await saved()==before,"accessory purchase cancellation preserves state")
		game.show_action_log();await settle()
		check(game.dialog.window.title=="行動ログ" and not labels().has("行動ログ"),"log title only in window titlebar")
		check(node("ActionLogHours").text=="ゲーム内経過時間:142時間" and node("ActionLogHistory").text.contains("feedback4履歴保持"),"explicit in-game time and preserved history")
		check(node("ActionLogSeparator") is HSeparator and node("ActionLogSeparator").get_index()>node("ActionLogHours").get_index() and node("ActionLogSeparator").get_index()<node("ActionLogHistory").get_index(),"separator between hours and history")
		game.dialog.close();await settle();check(await saved()==before,"navigation and log are read only")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
