extends SceneTree

var game
var failed := false
var witnessed := {}
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

func inspect_drag(source: Control, id: String, label: String):
	var at=source.get_global_rect().get_center()
	var move=InputEventMouseMotion.new();move.position=at;root.push_input(move,true)
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=at;root.push_input(press,true)
	await process_frame
	for offset in [Vector2(0,25),Vector2(10,60)]:
		move=InputEventMouseMotion.new();move.position=at+offset;move.relative=offset;move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true)
		await process_frame
	check(root.gui_is_dragging(),id+" starts pointer drag")
	await capture(id,[label])
	var preview=get_first_node_in_group("ui_drag_preview") as Control
	check(is_instance_valid(preview),id+" has a visible preview")
	if not is_instance_valid(preview):
		root.gui_cancel_drag()
		return
	var before=preview.global_position
	var next=at+Vector2(-240 if at.x>root.size.x/2.0 else 240,-120 if at.y>root.size.y/2.0 else 120)
	move=InputEventMouseMotion.new();move.position=next;move.relative=next-at-Vector2(10,60);move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move,true)
	await capture(id+"-moved",[label])
	check(preview.global_position.distance_to(before)>50,id+" artwork follows the pointer")
	root.gui_cancel_drag()
	press.pressed=false;press.position=Vector2(-20,-20);root.push_input(press,true)
	await settle()
	check(not root.gui_is_dragging(),id+" cancels without drop")

func inspect_item_and_return(id: String):
	await button(id)
	var detail=game.find_child("SkillDetailsWindow",true,false)
	check(is_instance_valid(detail) and detail.visible,"item explanation opens from "+id)
	if is_instance_valid(detail):
		detail.finish()
		await settle()

func page(id: String):
	game.navigate(id)
	await settle()

func palette_error(button: Button) -> String:
	var role=button.theme_type_variation
	if role in [&"",&"FlatButton",&"FlatMenuButton"]:role=&"Button"
	for state in ["normal","hover","pressed","disabled","hover_pressed"]:
		var actual=button.get_theme_stylebox(state)
		var expected=game.campaign_theme.get_stylebox(state,role)
		if not actual is StyleBoxFlat or not expected is StyleBoxFlat or actual.bg_color!=expected.bg_color or actual.border_color!=expected.border_color:
			return "%s (%s, %s) %s background" % [button.get_path(),role,actual.get_class(),state]
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_hover_pressed_color"]:
		if button.get_theme_color(key)!=game.campaign_theme.get_color(key,role):
			return str(button.get_path())+" "+key
	return ""

func check_owners(id: String, window: Window, scopes: Dictionary):
	var scene=window
	if window is FileDialog:scene=window.get_vbox()
	var inspector=game.ui_labels
	if window==root:
		if game.loading_screen.active:scene=game.loading_screen
		elif game.results_view.active:scene=game.results_view
	var panels=[]
	var missing=[]
	var examined=0
	var palette_errors=[]
	for node in scene.find_children("*","Control",true,false):
		if node.get_window()!=window or not node.is_visible_in_tree() or node.is_queued_for_deletion():continue
		if node.name==&"UiRegionLabels" or node is Label and node.text.is_empty():continue
		if not (node is BaseButton or node is Label or node is RichTextLabel or node is Range or node is LineEdit or node is TextEdit or node is TextureRect or node is ColorRect or node is Panel or node is PanelContainer or node.has_method("_draw")):continue
		var rect=inspector.visible_box(node,window.get_visible_rect())
		if not rect.has_area():continue
		examined+=1
		if node is Button:
			var error=palette_error(node)
			if not error.is_empty():palette_errors.append(error)
		var owner=node
		while owner!=null and owner!=window:
			if scopes.has(owner) and (owner==node or owner.name not in [&"ResultsPanel",&"ResultBackground"] or node.name==&"ResultPaper"):break
			owner=owner.get_parent()
		if scopes.has(owner):continue
		# A panel behind its children or a label painted over its sibling can share
		# their surface. Check the whole rectangle, never just its center.
		if scopes.keys().any(func(s):return s.get_parent()==node.get_parent() and scopes[s].encloses(rect)):continue
		if node is PanelContainer:panels.append([node,rect]);continue
		missing.append(str(node.get_path()))
	check(palette_errors.is_empty(),id+" button palette "+str(palette_errors))
	for panel in panels:
		var pieces=[panel[1]]
		for scope in scopes:
			if not panel[0].is_ancestor_of(scope):continue
			var remaining=[]
			for piece in pieces:
				var cut=piece.intersection(scopes[scope])
				if not cut.has_area():remaining.append(piece);continue
				for part in [Rect2(piece.position,Vector2(piece.size.x,cut.position.y-piece.position.y)),Rect2(Vector2(piece.position.x,cut.end.y),Vector2(piece.size.x,piece.end.y-cut.end.y)),Rect2(Vector2(piece.position.x,cut.position.y),Vector2(cut.position.x-piece.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(piece.end.x-cut.end.x,cut.size.y))]:
					if part.has_area():remaining.append(part)
			pieces=remaining
		if not pieces.is_empty():missing.append(str(panel[0].get_path()))
	check(missing.is_empty(),"%s owners %d, missing %s" % [id,examined,missing])

var first_bounds := {}

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
		witnessed[names.back()]=true
		captions.append([caption,rect.position.x,rect.position.y])
		check(window.get_visible_rect().encloses(rect),"within " + id + " " + caption)
	# Measure the labeled controls in main-window coordinates, including child windows.
	var to_game=root.get_screen_transform().affine_inverse()*window.get_screen_transform()
	var cell=Vector2(root.size)/10
	var scopes={}
	var center=preload("res://screen_grid.gd").cell_rect(Vector2(root.size),0,1,10,8)
	for node in inspector.controls.get(window,[]):
		if not is_instance_valid(node) or not node.is_visible_in_tree() or node.is_queued_for_deletion():continue
		var key=str(node.get_meta("ui_region",node.name))
		var active=inspector.definitions[key].filter(func(region):return region.label in names)
		if active.is_empty():continue
		var visible_rect=inspector.region_box(node,window,active[0])
		if not visible_rect.has_area():continue
		if key!="DialogSurface" and node.name not in [&"TownStill",&"FacilityStill",&"BattleBoard",&"DialogueScreen",&"LoadingStill",&"ResultBackground",&"LoadingBackground",&"ResultsPanel"]:
			scopes[node]=visible_rect
		else:
			# A full-screen drawing owns itself, never other controls layered above it.
			scopes[node]=Rect2()
		var box=to_game*visible_rect
		if window==root:
			if key in ["CampaignHeader","BattleHeader","StatusFooter","BattleTurnFooter","DeploymentFooter"]:
				var row=9 if key in ["StatusFooter","BattleTurnFooter","DeploymentFooter"] else 0
				check(box==preload("res://screen_grid.gd").cell_rect(Vector2(root.size),0,row,10,1),id+" reserved row "+key)
			elif key not in ["BattleMenuRegion","BattleBoard","DeploymentInstructions","TownStill","FacilityStill","DialogueScreen","ResultBackground"] and not active[0].get("follows_target",false):
				check(center.encloses(box),id+" body inside middle eight rows "+key+" "+str(box))
		var aligned=box.position.is_equal_approx((box.position/cell).round()*cell) and box.end.is_equal_approx((box.end/cell).round()*cell)
		check(aligned,id+" grid "+key+" "+str(box))
		if not active[0].get("follows_target",false) and key!="ResultMembersScroll":
			var label=("window:" if window!=root else "")+active[0].label
			if not first_bounds.has(label):first_bounds[label]=[id,box]
			var first=first_bounds[label]
			check(box.is_equal_approx(first[1]),"%s fixed %s %s; %s %s" % [id,label,box,first[0],first[1]])
	check_owners(id,window,scopes)
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
	if game.data.is_empty():
		game.ui_labels.refresh()
		check(game.ui_labels.overlays[root].captions.size()==1 and game.ui_labels.overlays[root].captions[0][0]=="場面：起動","startup identifies the scene before campaign data arrives")
	while game.data.is_empty(): await process_frame
	game.checks_fast=true
	game.audio.fast_mode=true
	var initial=(await game.engine.request({"op":"campaign_save"})).data
	initial.state.characters.character_mirei.inventory={"potion":1}
	await game.update({"op":"campaign_load","data":initial})
	var inspector=game.ui_labels
	await capture("hub",["場面：ローカルマップ","ヘッダーナビ","拠点施設マップ","パーティ名簿"])
	var gold=game.find_child("HeaderGold",true,false)
	check(gold is Label and gold.is_visible_in_tree() and gold.text=="%d G" % int(game.campaign().gold),"town header shows the current gold balance")
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
		await capture(tab,["人物情報","装備・インベントリ切替"])
	var hover_skill=game.find_child("CharacterSkill_active_*",true,false)
	hover_skill.show_hover()
	await capture("skill-hover",["スキルホバー詳細"])
	hover_skill.close_hover()
	workspace.set_tab("equipment")
	await settle()
	var gear=game.find_child("CharacterSlot_upperBody",true,false)
	gear.show_hover()
	await capture("equipment-hover",["装備ホバー詳細"])
	gear.close_hover()
	var portrait_member=game.roster().filter(func(u):return u.id=="character_rio")[0]
	await game.import_portrait(ProjectSettings.globalize_path("res://../native/assets/characters/scout-human-female-01.png"),portrait_member.id)
	workspace.open_portrait(portrait_member)
	await settle()
	await capture("portrait-framing",["人物画像調整"],game.dialog.window)
	game.dialog.close()
	await settle()
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
	var merchant_seed=initial.duplicate(true)
	merchant_seed.state.location="east"
	await game.update({"op":"campaign_load","data":merchant_seed})
	await page("board")
	var porter=game.roster().filter(func(u):return u.job=="job_porter" and u.id in game.campaign().selected)[0].id
	await game.act("accept",["standalone-wheel",porter])
	merchant_seed=(await game.engine.request({"op":"campaign_save"})).data
	merchant_seed.state.location="south"
	merchant_seed.state.worldTime=15
	merchant_seed.state.hours=15
	await game.update({"op":"campaign_load","data":merchant_seed})
	await page("hub")
	await capture("merchant-hub",["受取人・待機"])
	await button("HubWaitForMerchant")
	var waiting=game.find_child("MerchantWaitConfirmation",true,false)
	await capture("merchant-wait",["確認メッセージ","通知・確認操作"],waiting)
	waiting.canceled.emit()
	await settle()
	await page("board")
	await capture("merchant-board",["受取人・待機"])
	await game.update({"op":"campaign_load","data":initial})
	await page("map")
	await capture("map",["ワールドマップ・経路操作"])
	await page("inn")
	await capture("inn-entry",["施設案内"])
	await button("FacilityChoice_inn")
	await capture("inn",["休息サービス","宿泊者一覧"])
	check(game.find_child("PartyRoster",true,false)==null,"inn guest list is the only party roster on the rest screen")
	await page("party")
	await capture("guild-entry",["パーティ編成案内","共通倉庫案内"])
	await button("FacilityChoice_guild")
	await capture("guild",["編成比較","控え名簿","同行者の比較欄","控えの比較欄"])
	var guild=game.pages.guild_view
	var card=game.find_child("GuildMember_*",true,false)
	var old_rect=card.get_global_rect()
	old_rect.position.y+=24
	guild.animate_swap({str(card.get_meta("member_id")):old_rect},guild.generation)
	for i in 4:await process_frame
	game.ui_labels.refresh()
	var animated=game.ui_labels.overlays[root].captions.any(func(e):return e[0].ends_with("編成交代演出"))
	check(animated,"guild animation has its own label")
	if animated:witnessed["編成交代演出"]=true
	await settle()
	game.pages.facility_entry.back()
	await button("FacilityChoice_warehouse")
	await capture("warehouse",["装備・インベントリ切替","倉庫台帳"])
	await button("WarehouseTab_inventory")
	await capture("warehouse-inventory",["インベントリ","倉庫台帳"])
	await inspect_item_and_return("WarehouseItem_character_potion")
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
	await inspect_drag(game.find_child("Product_undertow-sword",true,false),"drag-item","ドラッグ中の品物")
	await inspect_item_and_return("Product_undertow-sword")
	var filter=game.find_child("ShopSlotFilter",true,false)
	filter.show_popup()
	await capture("shop-filter",["選択候補一覧"])
	filter.get_popup().hide()
	await capture("shop",["装備・インベントリ切替","商品一覧","取引確認","現在の装備","装備候補"])
	var skill_button=game.find_child("ComparisonSkill_*",true,false)
	if skill_button!=null:
		skill_button.pressed.emit()
		await settle()
		var skill=game.find_child("SkillDetailsWindow",true,false)
		if skill!=null:
			await capture("skill-detail",["明細見出し","詳細タブ"],skill)
			skill.finish()
			await settle()
	var shop=game.pages.shop_view
	await inspect_item_and_return("Product_spear-wood")
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
	await inspect_item_and_return("SaleItem_sword-wood")
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
	await game.update({"op":"campaign_load","data":initial})
	await page("map")
	await game.act("depart",["east","convoy"])
	await capture("road",["旅程マップ切替","場面：街道"])
	await button("TravelMapToggle")
	await capture("road-expanded",["旅程マップ切替"])
	await button("TravelMapToggle")
	await game.act("travel",["safe"])
	await capture("deployment",["カメラ操作案内","メニュー呼び出し","場面：配置","戦場・配置"])
	await inspect_drag(game.find_child("PartyFace_character_mirei",true,false),"drag-member","ドラッグ中の人物")
	await game.act("begin",[])
	await capture("battle",["場面：戦闘","戦場・配置"])
	game.hud.capture_action_visual()
	await capture("command-flight",["戦闘コマンド演出"])
	game.hud.clear_action_visual()
	for side in ["ally","enemy"]:
		var member=game.state().units.filter(func(u):return u.id=="character_mirei" if side=="ally" else u.side=="enemy")[0]
		await game.hud.open_equipment_sheet(member.id)
		await capture("battle-gear-"+side,["装備","装備・インベントリ切替"],game.dialog.window)
		await button("BattleLoadoutTab_inventory")
		await capture("battle-items-"+side,["インベントリ"],game.dialog.window)
		if side=="ally":
			var item=game.dialog.window.find_child("BattleInventory",true,false).find_children("*","Button",true,false)[0]
			item.pressed.emit()
			await capture("battle-item-detail",["所持品の詳細"],game.dialog.window)
			var detail=game.find_child("SkillDetailsWindow",true,false)
			if is_instance_valid(detail):detail.finish()
			await settle()
		game.dialog.close()
		await settle()
	for cmd in ["action_attack","action_move","skill","item"]:
		if game.hud.buttons.has(cmd) and not game.hud.buttons[cmd].disabled:
			game.hud.buttons[cmd].pressed.emit()
			if cmd=="action_move" and not game.data.choices.action_move.is_empty():
				await game.on_cell(int(game.data.choices.action_move[0]))
				await settle()
				check(game.board.move_preview_caption()=="命中率：100％","valid move selected on the board")
			var expected=["場面：戦闘"]
			if cmd=="action_move" and not game.board.move_preview_caption().is_empty() and DisplayServer.get_name()!="headless":expected.append("盤面の行動予測")
			await capture("battle-"+cmd,expected)
			if cmd=="action_move" and DisplayServer.get_name()!="headless" and game.data.choices.action_move.size()>1:
				var first=int(game.data.choices.action_move[0])
				var first_rect=game.board.prediction_region.get_global_rect()
				var farthest=first
				var origin: Vector2=game.board.project_cell(first)
				var max_distance=0.0
				for tile in game.data.choices.action_move:
					var distance=origin.distance_squared_to(game.board.project_cell(int(tile)))
					if distance>max_distance:
						max_distance=distance
						farthest=int(tile)
				await game.on_cell(farthest)
				await capture("battle-move-retarget",expected)
				check(int(game.board.preview.destination)==farthest and game.board.prediction_region.get_global_rect()!=first_rect,"move prediction follows a different destination")
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
		await capture("camp",["旅程マップ切替","野営インベントリ操作","場面：野営地"])
		var rest=game.find_child("CampActions",true,false).find_children("*","Button",true,false).filter(func(b):return b.text=="休息する")[0]
		var motion=InputEventMouseMotion.new();motion.position=rest.get_global_rect().get_center();root.warp_mouse(motion.position);root.push_input(motion,true)
		await create_timer(1.1).timeout
		if DisplayServer.get_name()!="headless":await capture("native-hint",["操作ヒント"])
		await page("items")
		await capture("items",["場面：道具使用"])
		await game.update({"op":"campaign_load","data":cases.normal.arrival})
		await settle()
		check(game.campaign().get("phase")=="town","arrival is automatically completed before rendering")
		await game.update({"op":"campaign_load","data":cases.normal.ready})
		await game.act("completeQuest",[])
		await capture("complete",["場面：配達リザルト","結果操作"])
		game.results_view.advance()
		await settle()
		await game.update({"op":"campaign_load","data":cases.late.ready})
		await game.act("completeQuest",[])
		await capture("complete-late",["場面：配達リザルト","結果操作"])
		game.results_view.advance()
		await settle()
		await game.update({"op":"campaign_load","data":cases.no_preference})
		await capture("complete-without-preference",["場面：配達リザルト","結果操作"])
		game.results_view.advance()
		await settle()
		await game.update({"op":"campaign_load","data":cases.defeat})
		await game.act("finishBattle",[])
		await capture("result",["場面：旅の結果"])
	game.notice="ゲーム処理が停止しました。ゲームを起動し直してください。"
	game.show_engine_stop()
	await settle()
	await capture("stop",["停止理由","通知・確認操作"],game.stop_dialog)
	game.stop_dialog.hide();game.stop_dialog.queue_free()
	var token=game.loading_screen.begin("before")
	await capture("loading",["読み込み画像"])
	game.loading_screen.finish(token)
	game.load_dialog()
	await capture("file",["場面：ファイル選択","ファイル選択欄"])
	var picker=game.find_children("*","FileDialog",true,false)[0]
	check(picker.title.contains("ファイル選択欄"),"native file picker title names its region")
	picker.canceled.emit()
	await settle()
	var fallback=FileDialog.new()
	fallback.use_native_dialog=false
	fallback.access=FileDialog.ACCESS_USERDATA
	game.add_child(fallback)
	game.preferences.bind_window(fallback,"file_dialog",game.size,game.size*.85)
	fallback.popup()
	await capture("builtin-file",["ファイル一覧と入力欄"],fallback)
	fallback.hide();fallback.queue_free()
	if not frames.is_empty():
		var file=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(frames))
		file.close()
	if DisplayServer.get_name()!="headless":
		for region in inspector.CATALOG.data.regions+inspector.CATALOG.data.surfaces.values():
			check(witnessed.has(region.label),"observed catalog region "+str(region.label))
	game.closing=true
	await game.audio.finish_audio()
	game.engine.close_engine()
	game.queue_free()
	for i in 8: await process_frame
	quit(1 if failed else 0)
