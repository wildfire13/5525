extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(100).timeout.connect(func():print("FAIL feedback2 Oct17 watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var baseline=await saved();var seed=baseline.duplicate(true);seed.state.location="west"
	seed.state.characters.guard.inventory["sword-wood"]=1
	await game.update({"op":"campaign_load","data":seed});game.navigate("map");await settle()
	var map=node("TownMap");var current=map.buttons[map.current]
	check(current.disabled and current.get_theme_stylebox("disabled").border_color==Color("#fbbf24"),"map current town remains disabled with yellow frame")
	check(current.get_theme_stylebox("disabled")==current.get_theme_stylebox("normal") and current.get_theme_stylebox("pressed")==current.get_theme_stylebox("normal"),"map pressed/disabled styles preserve icon positions and appearance")
	check(map.buttons.values().all(func(b):return b.text.is_empty() and b.find_children("Icon_*","TextureRect",true,false).size()>=2),"town content uses place plus facility icons without location tags")
	check(not game.find_children("*","Label",true,false).any(func(n):return n.text.contains("武器はイース")),"redundant shop location sentence removed")
	check(map.event_markers.size()==16 and map.event_markers.all(func(m):return m.kind=="danger"),"eight routes display two current battle markers each")
	var original=await saved();map.route_events["astaris|east"]=["unknown","safe"];map.queue_redraw();await frames()
	check(map.event_markers.any(func(m):return m.color==map.EVENT_COLORS.unknown) and map.event_markers.any(func(m):return m.color==map.EVENT_COLORS.safe) and await saved()==original,"future event colors are display metadata only")
	game.navigate("shop");await settle()
	var trial=node("ProductTrial_armor-cloth")
	check(absf(trial.get_global_rect().end.x-1280)<28,"shop trial right edge near FHD two thirds")
	check(node("Product_armor-cloth").get_meta("ui_icon_id")=="equipment:armor-cloth","shop product uses individual equipment image")
	game.pages.party_view.open_detail("guard");await settle()
	check(node("StatusPortrait").tooltip_text=="クリックで画像変更","status portrait advertises image editing")
	var before=await saved();game.pages.party_view.open_portrait_preview(game.roster().filter(func(u):return u.id=="guard")[0]);await settle()
	check(node("StatusFullPortrait").size.y>=160 and node("StatusChangePortrait")!=null,"portrait opens full body with change button below")
	await click("StatusChangePortrait")
	var file_dialog=game.find_children("*","FileDialog",true,false)[0]
	check(file_dialog.file_mode==FileDialog.FILE_MODE_OPEN_FILE and file_dialog.filters[0].contains("*.png"),"image change opens existing image file picker")
	file_dialog.canceled.emit();await settle()
	check(await saved()==before and game.dialog.window.title=="ステータス","portrait close preserves save and status context")
	await click("StatusTab_3");await settle()
	check(node("InventoryItem_sword-wood").get_meta("ui_icon_id")=="equipment:sword-wood","personal inventory uses individual equipment reference")
	game.dialog.close();await settle()
	check(game.icons.equipment_paths.size()==42 and game.icons.gear({"id":"sword-wood","type":"sword"})=="sheet_one_handed_sword" and game.icons.slot("head")=="head","equipment mapping separated from category and slot icons")
	await game.update({"op":"campaign_load","data":baseline});game.navigate("map");await game.act("depart",["east","convoy"]);await game.act("travel",["safe"]);await settle()
	var positions=game.state().units.map(func(u):return u.pos)
	await click("DeploymentFormation_flank")
	check(game.state().units.map(func(u):return u.pos)==positions and game.state().formationKind=="flank" and game.find_children("*","ConfirmationDialog",true,false).is_empty(),"formation switch changes rules without touching placement or prompting")
	var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0];await game.on_cell(int(enemy.pos));await settle()
	check(game.hud.person_box.find_children("*","Label",true,false).any(func(n):return n.text.begins_with("DEF")) and game.hud.person_box.find_children("*","Button",true,false).is_empty(),"clicked deployment enemy exposes details directly")
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
	var description=node("BattleSkill_archer").tooltip_text
	check(description.begins_with("[スナイプ]") and description.contains("消費MP:") and description.contains("対象:") and description.contains("スキル効果:"),"skill tooltip follows requested four-part template")
	var tooltip=node("BattleSkill_archer")._make_custom_tooltip(description.repeat(8));root.add_child(tooltip);await frames()
	check(tooltip.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and tooltip.size.x<=520 and tooltip.size.y>50,"skill tooltip wraps lengthy text without ellipsis");tooltip.queue_free()
	var porter=fixtures.porter
	# Keep a legal save while filling all three basic formation cells.
	for pair in [["guard",23],["archer",12],["mage",32]]:
		var person=porter.state.battle.units.filter(func(u):return u.id==pair[0])[0]
		var other=porter.state.battle.units.filter(func(u):return u.id!=pair[0] and u.pos==pair[1])
		if not other.is_empty():other[0].pos=person.pos
		person.pos=pair[1]
	await game.update({"op":"campaign_load","data":porter});await settle();hud.open_skills();await settle()
	before=await saved();await click("BattleSkill_porter")
	check(game.pending=="porter" and node("BattleConsent")!=null and game.can_commit(),"self-target porter skips target picking into execute/cancel")
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
