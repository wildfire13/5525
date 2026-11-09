extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(100).timeout.connect(func():print("FAIL feedback2 Oct17 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var baseline=await saved();var seed=baseline.duplicate(true);seed.state.location="west"
	seed.state.characters.guard.inventory["sword-wood"]=1
	await game.update({"op":"campaign_load","data":seed});game.navigate("map");await settle()
	var map=node("TownMap");var current=map.buttons[map.current]
	check(current.disabled and current.get_theme_stylebox("disabled").bg_color==Color("#345c4e") and current.get_node("TownContents").get_child(2).text=="出発地","map current town remains disabled with distinct paper-palette fill and origin label")
	check(current.get_theme_stylebox("disabled")==current.get_theme_stylebox("normal") and current.get_theme_stylebox("pressed")==current.get_theme_stylebox("normal"),"map pressed/disabled styles preserve icon positions and appearance")
	check(map.buttons.values().all(func(b):return b.text.is_empty() and b.find_children("Icon_*","TextureRect",true,false).size()>=2),"town content uses place plus facility icons")
	check(not game.find_children("*","Label",true,false).any(func(n):return n.text.contains("武器はイース")),"redundant shop location sentence removed")
	check(map.route_events.is_empty() and map.event_markers.is_empty(),"undisclosed route events do not invent battle markers")
	var original=await saved();map.route_events["astaris|east"]=["unknown","safe"];map.queue_redraw();await frames()
	check(map.event_markers.size()==2 and map.event_markers.all(func(m):return m.route=="astaris|east") and map.event_markers.any(func(m):return m.color==map.EVENT_COLORS.unknown) and map.event_markers.any(func(m):return m.color==map.EVENT_COLORS.safe) and await saved()==original,"future event colors are display metadata only")
	await enter_facility("shop");await settle()
	var product=node("Product_armor-cloth")
	check(product.find_children("*","TextureRect",true,false).any(func(icon):return icon.get_meta("ui_icon_id","")=="approved:equipment:armor-cloth"),"shop product uses individual equipment image")
	var trial_before=await saved();await click("Product_armor-cloth")
	var comparison=node("ShopComparisonStats");var stock=node("ShopCatalog");var own=node("ShopInventory");var transaction=node("ShopTransaction")
	check(comparison!=null and not comparison.text.is_empty() and own.global_position.x<transaction.global_position.x and transaction.get_global_rect().end.x<=stock.global_position.x and transaction.get_global_rect().encloses(comparison.get_global_rect()) and not game.modal_open(),"shop trial is inline in central panel between inventory and catalog")
	var trial=node("ProductTrial_armor-cloth")
	check(await saved()==trial_before and node("ShopComparisonBuy")!=null and trial!=null and transaction.get_global_rect().encloses(trial.get_global_rect()),"shop comparison preserves complete save and retains contained trial and purchase buttons")
	await click("ProductTrial_armor-cloth")
	check(node("TrialRecipient_guard")!=null and game.dialog.window.title=="木人で試す人物" and await saved()==trial_before,"inline trial opens real recipient selection without changing save")
	await click("TrialRecipientCancel");check(await saved()==trial_before,"trial cancellation preserves full save")
	game.pages.party_view.open_detail("guard");await settle()
	check(node("StatusPortrait").tooltip_text=="クリックで画像変更","status portrait advertises image editing")
	var before=await saved();game.pages.party_view.open_portrait_preview(game.roster().filter(func(u):return u.id=="guard")[0]);await settle()
	check(node("StatusFullPortrait").size.y>=160 and node("StatusChangePortrait")!=null,"portrait opens full body with change button below")
	await click("StatusChangePortrait")
	var file_dialog=game.find_children("*","FileDialog",true,false)[0]
	check(file_dialog.file_mode==FileDialog.FILE_MODE_OPEN_FILE and file_dialog.filters[0].contains("*.png"),"image change opens existing image file picker")
	file_dialog.canceled.emit();await settle()
	check(await saved()==before and game.dialog.window.title=="キャラクターステータス","portrait close preserves save and status context")
	await all_inventory();await settle()
	check(node("OwnedEquipment_sword-wood").get_meta("ui_icon_id")=="approved:equipment:sword-wood","personal inventory uses individual equipment reference")
	game.dialog.close();await settle()
	var mapped_ids=game.icons.equipment_paths.keys();mapped_ids.sort()
	var adopted_ids=game.icons.approved.equipment.keys();adopted_ids.sort()
	check(mapped_ids.size()==47 and mapped_ids==adopted_ids and game.icons.gear({"id":"sword-wood","type":"sword"})=="sheet_one_handed_sword" and game.icons.slot("head")=="head","all 47 adopted equipment paths stay separate from category and slot icons")
	await game.update({"op":"campaign_load","data":baseline});game.navigate("map");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	var positions=game.state().units.map(func(u):return u.pos)
	check(node("DeploymentFormation_convoy").get_meta("selected") and not node("DeploymentFormation_flank").get_meta("selected"),"default formation uses shared selection")
	await click("DeploymentFormation_flank")
	check(node("DeploymentFormation_flank").get_meta("selected") and not node("DeploymentFormation_convoy").get_meta("selected"),"formation selection moves to the chosen preset")
	check(game.state().units.map(func(u):return u.pos)==positions and game.state().formationKind=="flank" and game.find_children("*","ConfirmationDialog",true,false).is_empty(),"formation switch changes rules without touching placement or prompting")
	var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0];await game.on_cell(int(enemy.pos));await settle()
	var sidebar=game.hud.right_panel.body
	check(game.hud.selected_enemy==enemy.id and sidebar.find_children("*","Label",true,false).any(func(n):return n.text==enemy.name) and sidebar.find_children("*","Label",true,false).any(func(n):return n.text=="HP %d/%d    MP %d/%d" % [enemy.hp,enemy.max,enemy.mp,enemy.maxMp]),"clicked deployment enemy exposes correct identity and resources in live sidebar")
	var detail=sidebar.find_children("*","Button",true,false).filter(func(b):return b.text=="能力・効果の詳細")[0]
	var inspected_save=await saved();detail.pressed.emit();await settle()
	check(game.dialog.window.title==enemy.name and game.dialog.body.find_children("*","Label",true,false).any(func(n):return n.text.begins_with("DEF")) and await saved()==inspected_save,"deployment enemy details expose real DEF without changing save")
	game.dialog.close();await settle()
	var fixtures=battle_fixture();await game.update({"op":"campaign_load","data":fixtures.archer});await settle()
	var hud=game.hud
	game.checks_fast=false;hud.choose_command("skill");await create_timer(.06).timeout
	check(node("BattleSkillListSlide").content.position.y<0,"opening list visibly travels from behind parent command")
	await create_timer(.25).timeout;await settle()
	check(node("BattleSkillListSlide").clip_contents and node("BattleSkillListSlide").content.position.y==0,"skill list reveals below clipped command edge")
	hud.choose_command("skill");await create_timer(.06).timeout
	check(node("BattleSkillListSlide")!=null and node("BattleSkillListSlide").content.position.y<0,"closing list travels behind parent before removal")
	await create_timer(.25).timeout;await settle();game.checks_fast=true;check(node("BattleSkillList")==null,"second skill command closes list")
	hud.choose_command("items");await settle();hud.choose_command("items");await settle();check(node("BattleItemList")==null,"second item command closes list")
	hud.choose_command("skill");await settle();hud.choose_command("attack");await settle();check(node("BattleSkillList")==null and node("BattleItemList")==null,"another command closes both lists")
	hud.choose_command("skill");await settle()
	var skill_button=node("BattleSkill_scout")
	var description=skill_button.tooltip_text
	check(description.begins_with("[奇襲Lv1]") and description.contains("消費MP:") and description.contains("対象:") and description.contains("スキル効果:"),"skill tooltip follows requested four-part template")
	var tooltip=skill_button._make_custom_tooltip(description.repeat(8));root.add_child(tooltip);await frames()
	check(tooltip.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and tooltip.size.x<=520 and tooltip.size.y>50,"skill tooltip wraps lengthy text without ellipsis");tooltip.queue_free()
	var porter=fixtures.porter
	# Keep a legal save while filling all three basic formation cells.
	# The Porter anchors the current three-cell formation at 22.
	for pair in [["guard",24],["archer",13],["mage",33]]:
		var person=porter.state.battle.units.filter(func(u):return u.id==pair[0])[0]
		var other=porter.state.battle.units.filter(func(u):return u.id!=pair[0] and u.pos==pair[1])
		if not other.is_empty():other[0].pos=person.pos
		person.pos=pair[1]
	await game.update({"op":"campaign_load","data":porter});await settle();hud.open_skills();await settle()
	before=await saved();await click("BattleSkill_porter")
	check(game.pending=="porter" and game.find_children("*","Button",true,false).any(func(b):return b.get_meta("ui_key","")=="battle_commit" and b.text.ends_with("を実行")) and game.can_commit(),"self-target porter skips target picking into execute/cancel")
	check(node("BattleSkill_porter").tooltip_text.contains("×1.75") and node("BattleSkill_porter").tooltip_text.contains("×0.65"),"porter tooltip retains real multipliers instead of example 25 percent")
	before=await saved();game.cancel();await settle();check(await saved()==before and not game.can_commit(),"self skill cancel preserves complete save")
	await click("BattleSkill_porter");var actions=int(game.state().actions);game.checks_fast=false;game.commit();game.commit()
	while hud.animation_trace.is_empty():await process_frame
	for tick in range(120):
		if is_instance_valid(hud.action_visual) and hud.action_visual.scale.x<1:break
		await process_frame
	check(is_instance_valid(hud.action_visual) and hud.action_visual.scale.x<1 and hud.action_visual.position.y>hud.left_panel.position.y,"confirmed command panel visibly shrinks toward first order card")
	await settle();game.checks_fast=true
	check(int(game.state().actions)==actions+1,"self skill repeated execution consumes one action")
	var trace=hud.animation_trace.filter(func(e):return e.stage!="command_open")
	check(trace.size()>=3 and trace[0].stage=="command_shrink" and trace[1].stage=="queue_slide" and trace[2].stage=="character_action" and trace[1].distance>180,"command shrink then one-card queue slide precedes character action")
	check(not is_instance_valid(hud.action_visual) and game.battle_header.visible,"presentation removes flight copy and restores live order")
	var f=FileAccess.open(evidence.path_join("feedback2-1017.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"animation_trace":trace},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
