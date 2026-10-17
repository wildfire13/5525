extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(100).timeout.connect(func():quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var tooltip=preload("res://equipment_tooltip.gd").new()
	var ether={"resource":"mp","amount":3,"battleRole":"porter","name":"エーテル"};var unchanged=ether.duplicate(true)
	tooltip.configure_entry({"name":"エーテル","kind":"consumable","definition":ether},{})
	check(tooltip.tooltip_text.contains("戦闘での使用条件：ポーター") and not tooltip.tooltip_text.contains("porter") and ether==unchanged,"I12 localizes porter display only without changing item definition")
	tooltip.free()
	var baseline=await saved();var hub=game.pages.hub_view
	# Existing images stand in for delivered backgrounds only in this test.
	for place in game.campaign().locations:
		hub.catalog[place.id]=[{"path":"res://assets/ui_icons/icons64/castle.png","style":"test A"},{"path":"res://assets/ui_icons/icons64/village.png","style":"test B"}]
		var seed=baseline.duplicate(true);seed.state.location=place.id
		await game.update({"op":"campaign_load","data":seed});game.navigate("hub");await settle()
		check(node("TownHub")!=null and node("TownStill").texture!=null,"hub image for "+place.id)
		check(game.find_children("HubFacility_*","Button",true,false).size()==place.facilities.size(),"only existing facilities for "+place.id)
		var chosen=hub.artwork.duplicate(true);var before=await saved()
		for facility in place.facilities:
			await click("HubFacility_"+facility);check(game.town_back.visible,"facility return available "+place.id+"/"+facility)
			game.town_back.pressed.emit();await settle()
			check(game.page=="hub" and hub.artwork==chosen,"same visit retains art "+place.id+"/"+facility)
		check(await saved()==before,"hub navigation preserves campaign "+place.id)
	# Stable visit selection is independent of the number of variants.
	hub.catalog.astaris.append({"path":"res://assets/ui_icons/icons64/inn.png","style":"test C"})
	await game.update({"op":"campaign_load","data":baseline});game.navigate("hub");await settle()
	var selected={}
	for i in range(40):hub.reset();hub.select_art("astaris");selected[hub.artwork.style]=true
	check(selected.size()==3,"art catalog supports additional variants without code changes")
	var q=game.campaign().board[0];await game.act("accept",[q.id,"porter"]);await settle()
	game.pages.party_view.open_detail("porter");await settle();await click("StatusTab_3")
	var cargo=game.campaign().activeQuest.cargoItemId
	game.pages.party_view.inventory_view.pick(cargo);await settle()
	check(node("InventoryUse").disabled and game.dialog.window.find_children("*","Label",true,false).any(func(n):return n.text.contains("依頼の荷物は使用できません")),"cargo has delivery-specific disabled use explanation")
	check(not game.dialog.window.find_children("*","Label",true,false).any(func(n):return n.text.contains("回復対象がいません")),"cargo never borrows recovery explanation")
	game.dialog.close()
	await game.act("depart",[q.to]);var arrival=await saved()
	arrival.state.phase="arrival";arrival.state.journey.phase="delivery";arrival.state.journey.stage=2;arrival.state.journey.hours=4
	arrival.state.journey.party=game.roster().filter(func(u):return game.campaign().selected.has(u.id)).duplicate(true)
	await game.update({"op":"campaign_load","data":arrival});await game.act("arrive");await settle()
	check(game.page=="hub" and game.campaign().activeQuest!=null and node("TownHub")!=null,"arrival opens hub without auto-delivering cargo")
	await click("HubFacility_board")
	check(node("QuestComplete")!=null and not node("QuestComplete").disabled,"explicit delivery remains available on board")
	var fixtures=battle_fixture();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	await game.choose_command("item");await game.on_cell(int(game.hud.acting().pos));await settle()
	var names=["TargetSummary","PredictionSummary","ActionCost","ActionAvailability"]
	var positions=names.map(func(n):return node(n).global_position.y)
	check(positions[0]<positions[1] and positions[1]<positions[2] and positions[2]<positions[3],"I01 target then HP then cost then availability")
	var before=await saved();var pending=game.pending;var chosen=game.chosen.duplicate()
	var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
	game.hud.inspect_hover(enemy.id,game.board);await settle()
	check(node("InspectedPersonHeading").text=="参照："+enemy.name and node("InspectedPersonHeading").global_position.y>node("ActionAvailability").global_position.y,"hover reference labelled after decision summary")
	check(game.pending==pending and game.chosen==chosen and await saved()==before,"hover never replaces confirmed target or changes save")
	var scroll=game.hud.right_panel.body.get_parent();scroll.scroll_vertical=100000;await frames()
	check(game.hud.right_panel.get_global_rect().encloses(node("BattleConfirm").get_global_rect()),"confirm and cancel remain pinned outside scroll")
	game.cancel();await settle();check(await saved()==before,"cancel still consumes no item or action")
	# JSON numbers are floats; Array.has(int) previously reported zero occupancy.
	game.data.formationSlots=JSON.parse_string('{"ally":[24,13,33],"enemy":[25,16,36]}')
	var template=enemy.duplicate(true)
	game.data.state.units=game.data.state.units.filter(func(u):return u.side!="enemy")
	for i in range(3):
		var u=template.duplicate(true);u.id="formation-test-"+str(i);u.pos=[25,16,36][i];u.hp=10;game.data.state.units.append(u)
	game.data.formed.enemy=true
	game.hud.toggle_details();await settle()
	check(game.dialog.window.find_children("*","Label",true,false).any(func(n):return n.text=="敵の条件マス 3/3"),"I04 JSON float slots count three living enemies")
	game.dialog.close();game.data.state.units[-1].hp=0;game.data.formed.enemy=false;game.hud.toggle_details();await settle()
	check(game.dialog.window.find_children("*","Label",true,false).any(func(n):return n.text=="敵の条件マス 2/3"),"I04 defeated occupant excluded")
	game.dialog.close();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	await game.publish_snapshot(evidence.path_join("toast-save.json"),await saved(),"進行")
	check(game.save_notice.visible and game.save_notice.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.notice.is_empty(),"I05 successful save shows nonblocking notice without persistent footer")
	var rect=game.save_notice.get_global_rect()
	check(absf(rect.get_center().x-root.size.x/2.0)<1 and rect.end.y<=game.hud.right_panel.global_position.y,"I05 notice centered above HUD")
	await create_timer(4.8).timeout;check(game.save_notice.visible and game.save_notice.modulate.a==1,"notice remains fully visible before five seconds")
	await create_timer(.4).timeout;check(game.save_notice.visible and game.save_notice.modulate.a<1,"notice fades only after five seconds")
	game.save_notice.display("new save");await create_timer(.4).timeout;check(game.save_notice.visible and game.save_notice.modulate.a==1,"new save cancels old fade")
	await create_timer(5.2).timeout;check(not game.save_notice.visible,"notice disappears after hold and fade")
	var f=FileAccess.open(evidence.path_join("additional-feedback.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
