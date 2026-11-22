extends SceneTree

var game
var failed := false
var frames := {}
var output := OS.get_environment("UI_LABEL_EVIDENCE")

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	print(("PASS " if ok else "FAIL ") + message)
	failed = failed or not ok

func settle():
	for i in 6: await process_frame
	while game.locked or game.engine.busy or game.presenting: await process_frame
	await create_timer(0.28).timeout

func button(id: String):
	var node = game.find_child(id,true,false)
	if node is BaseButton: node.pressed.emit()
	else: check(false, "missing button " + id)
	await settle()

func page(id: String):
	game.navigate(id)
	await settle()

func capture(id: String, expected: Array, window: Window = null):
	await settle()
	var inspector = game.ui_labels
	inspector.refresh()
	if window == null: window = root
	var overlay = inspector.overlays[window]
	var names := []
	var captions := []
	for entry in overlay.captions:
		var rect: Rect2 = entry[1]
		var caption: String = entry[0]
		names.append(caption.trim_prefix(inspector.CATALOG.data.prefix))
		captions.append([caption,rect.position.x,rect.position.y])
		check(window.get_visible_rect().encloses(rect),"within " + id + " " + caption)
	for name_ in expected: check(name_ in names,id + " shows " + name_ + " alongside " + str(names))
	check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, id + " allows pointer through")
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var viewport = window.get_texture().get_image()
	viewport.save_png(output.path_join(id+".png"))
	overlay.hide()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	window.get_texture().get_image().save_webp(output.path_join(id+".webp"),true,.91)
	overlay.show()
	var targets := []
	var clickable=window.find_children("*","BaseButton",true,false)
	if window is ConfirmationDialog:
		for btn in [window.get_ok_button(),window.get_cancel_button()]:
			if not clickable.has(btn):clickable.append(btn)
	for control in clickable:
		if control.get_window()!=window or not control.is_visible_in_tree() or control.disabled: continue
		var box: Rect2 = inspector.visible_box(control, window.get_visible_rect())
		if box.has_area(): targets.append([str(control.name),str(control.text),box.position.x,box.position.y,box.size.x,box.size.y])
	frames[id]={"title":names[0].trim_prefix("場面："),"size":[viewport.get_width(),viewport.get_height()],"labels":captions,"buttons":targets}

func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/").to_lower()
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"):quit(2);return
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	while game.data.is_empty(): await process_frame
	game.checks_fast=true
	game.audio.fast_mode=true
	var initial=(await game.engine.request({"op":"campaign_save"})).data
	initial.state.characters.character_mirei.inventory={"potion":1}
	await game.update({"op":"campaign_load","data":initial})
	var inspector=game.ui_labels
	await capture("hub",["場面：ローカルマップ","ヘッダーナビ","拠点施設マップ","パーティ名簿"])
	game.save_notice.display("購入して装備しました")
	game.pages.party_view.workspace.toast("更新しました")
	await capture("notice",["上中央の緑通知","右下の所持品通知"])
	game.save_notice.dismiss()
	game.open_menu()
	await capture("menu",["共通メニュー項目","音量設定","拠点施設マップ"])
	var toggle=game.find_child("UiLabelSwitch",true,false)
	toggle.button_pressed=false
	check(not inspector.overlays[root].visible and not inspector.is_processing(),"menu switch hides all labels")
	toggle.button_pressed=true
	check(inspector.overlays[root].visible and inspector.is_processing(),"menu switch restores all labels")
	game.menu.hide()
	game.show_help()
	await settle()
	await capture("help",["明細本文","明細操作"],game.dialog.window)
	game.dialog.close()
	await settle()
	game.show_action_log()
	await settle()
	await capture("log",["行動ログ本文"],game.dialog.window)
	game.dialog.close()
	await settle()
	if game.debug_view.is_enabled():
		game.debug_view.open()
		await capture("debug",["開発状態","開発履歴","開発情報の操作"],game.debug_view.window)
		game.debug_view.window.hide()
	game.portrait_dialog()
	await settle()
	var chooser=game.find_child("PortraitChooser",true,false)
	await capture("portraits",["画像選択"],chooser)
	chooser.queue_free()
	await settle()
	await page("character")
	var workspace=game.pages.party_view.workspace
	for tab in ["equipment","inventory","ability","skills"]:
		if workspace.tab!=tab:workspace.set_tab(tab)
		await capture(tab,["人物情報"])
	await page("board")
	await capture("board",["クエスト一覧","クエスト詳細"])
	var board=game.pages.quest_board
	for quest in game.campaign().board:
		board.choose(str(quest.id))
		await capture("quest-"+str(quest.id),["クエスト詳細"])
	board.open_story(game.campaign().board.filter(func(q):return not q.get("story",[]).is_empty())[0] if game.campaign().board.any(func(q):return not q.get("story",[]).is_empty()) else game.campaign().board[0])
	await capture("story",["会話本文"])
	var story=board.dialogue
	while not story.choice_row.visible:story._advance()
	await capture("story-choice",["会話選択肢"])
	story._close()
	await settle()
	board.open_picker(str(game.campaign().board[0].id))
	await settle()
	await capture("porter",["荷物の担当"],game.dialog.window)
	game.dialog.close()
	await settle()
	await page("map")
	await capture("map",["ワールドマップ・経路操作"])
	await page("inn")
	await capture("inn-entry",["施設案内"])
	await button("FacilityChoice_inn")
	await capture("inn",["休息サービス"])
	await page("party")
	await capture("guild-entry",["パーティ編成案内","共通倉庫案内"])
	await button("FacilityChoice_guild")
	await capture("guild",["編成比較","控え名簿"])
	game.pages.facility_entry.back()
	await button("FacilityChoice_warehouse")
	await capture("warehouse",["倉庫台帳"])
	await button("WarehouseTab_inventory")
	await capture("warehouse-inventory",["インベントリ","倉庫台帳"])
	await button("WarehouseItem_character_potion")
	await capture("deposit",["インベントリ","選択アイテム","倉庫操作"])
	await button("WarehouseTransfer")
	var receipt=game.find_child("WarehouseDepositConfirmation",true,false)
	if receipt!=null:
		await capture("deposit-confirm",["通知・確認操作"],receipt)
		receipt.confirmed.emit()
		await settle()
		var amount=game.find_child("WarehouseQuantity_potion",true,false)
		if amount!=null:amount.value=1
		await capture("withdraw",["倉庫台帳"])
		await button("WarehouseTransfer")
	var seed=(await game.engine.request({"op":"campaign_save"})).data
	for town in ["west","north","south","east"]:
		var visit=seed.duplicate(true)
		visit.state.location=town
		await game.update({"op":"campaign_load","data":visit})
		await page("hub")
		await capture("hub-"+town,["拠点施設マップ"])
		await page("shop")
		await capture("entry-"+town,["施設案内"])
		await button("FacilityChoice_buy")
		game.pages.shop_view.set_inventory_tab("equipment")
		await capture("shop-"+town,["商品一覧","取引確認"])
	await button("Product_undertow-sword")
	await capture("shop",["商品一覧","取引確認","現在の装備","装備候補"])
	var skill_button=game.find_child("ComparisonSkill_*",true,false)
	if skill_button!=null:
		skill_button.pressed.emit()
		await settle()
		var skill=game.find_child("SkillDetailsWindow",true,false)
		if skill!=null:
			await capture("skill-detail",["詳細タブ"],skill)
			skill.finish()
			await settle()
	var shop=game.pages.shop_view
	await button("Product_spear-wood")
	await capture("shop-spear",["現在の装備","装備候補"])
	shop.drop_equipment({"kind":"shop_product","item":"spear-wood","connection":game.engine.connection_generation,"epoch":game.pages.epoch,"token":game.campaign().inventoryToken},"rightHand")
	await settle()
	if is_instance_valid(game.dialog.window):
		await capture("purchase",["明細本文","明細操作"],game.dialog.window)
		await button("PurchaseAgree")
		await capture("purchased",["上中央の緑通知"])
		game.save_notice.dismiss()
	else: check(false,"real purchase confirmation opened")
	shop.set_inventory_tab("inventory")
	await capture("shop-inventory",["インベントリ"])
	await button("SaleItem_sword-wood")
	game.save_notice.dismiss()
	await capture("sale",["インベントリ","取引操作"])
	await button("FacilitySalePrepare")
	var sale_dialog=game.find_child("FacilitySaleConfirmation",true,false)
	if sale_dialog!=null:
		await capture("sell-confirm",["通知・確認操作"],sale_dialog)
		sale_dialog.canceled.emit()
		await settle()
	await game.act("trial",["character_mirei","spear-wood","rightHand"])
	await capture("trial",["場面：木人試用"])
	await game.act("endTrial",[])
	await game.update({"op":"campaign_load","data":seed})
	await page("map")
	await game.act("depart",["east","convoy"])
	await capture("road",["場面：街道"])
	await game.act("travel",["safe"])
	await capture("deployment",["場面：配置","戦場・配置"])
	await game.act("begin",[])
	await capture("battle",["場面：戦闘","戦場・配置"])
	for cmd in ["action_attack","action_move","skill","item"]:
		if game.hud.buttons.has(cmd) and not game.hud.buttons[cmd].disabled:
			game.hud.buttons[cmd].pressed.emit()
			await capture("battle-"+cmd,["場面：戦闘"])
			game.hud.back_to_commands()
			await settle()
	await button("BattleHistory")
	if is_instance_valid(game.dialog.window):
		await capture("history",["明細本文"],game.dialog.window)
		game.dialog.close()
		await settle()
	await button("BattleOrderDetails")
	if is_instance_valid(game.dialog.window):
		await capture("order",["明細本文"],game.dialog.window)
		game.dialog.close()
		await settle()
	game.choose_command("action_defend")
	await capture("defend",["場面：戦闘"])
	var fixture_output=[]
	var result=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/results_fixtures.cjs")],fixture_output,true,false)
	check(result==0,"local current-version result fixtures")
	if result==0:
		var cases=JSON.parse_string("".join(fixture_output))
		await game.update({"op":"campaign_load","data":cases.victory})
		await game.act("finishBattle",[])
		await capture("victory",["結果・報酬","人物別結果"])
		game.results_view.advance()
		await settle()
		await page("map")
		await capture("camp",["場面：野営地"])
		await page("items")
		await capture("items",["場面：道具使用"])
		await game.update({"op":"campaign_load","data":cases.normal.ready})
		await game.act("completeQuest",[])
		await capture("complete",["場面：配達リザルト","結果操作"])
		game.results_view.advance()
		await settle()
		await game.update({"op":"campaign_load","data":cases.defeat})
		await game.act("finishBattle",[])
		await capture("result",["場面：旅の結果"])
	var token=game.loading_screen.begin("before")
	await capture("loading",["読み込み画像"])
	game.loading_screen.finish(token)
	if not frames.is_empty():
		var file=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(frames))
		file.close()
	game.closing=true
	await game.audio.finish_audio()
	game.engine.close_engine()
	game.queue_free()
	for i in 8: await process_frame
	quit(1 if failed else 0)
