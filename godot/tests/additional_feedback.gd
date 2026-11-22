extends "res://tests/ui_feedback2_20261016.gd"
func arrive_with_cargo(town):
	await game.act("depart",[town]);var arrival=await saved()
	arrival.state.phase="arrival";arrival.state.journey.phase="delivery";arrival.state.journey.stage=2;arrival.state.journey.hours=4
	arrival.state.journey.party=arrival.state.selected.map(func(id):return game.roster().filter(func(u):return u.id==id)[0].duplicate(true))
	var loaded=await game.update({"op":"campaign_load","data":arrival});await settle()
	check(loaded.get("ok",false),"arrival fixture accepts current roster in selected order")

func run():
	create_timer(100).timeout.connect(func():quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var tooltip=preload("res://equipment_tooltip.gd").new()
	var ether={"resource":"mp","amount":3,"battleRole":"job_porter","name":"エーテル"};var unchanged=ether.duplicate(true)
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
			await click("HubFacility_"+facility)
			var back=node("Header_board" if facility=="board" else "FacilityExit")
			check(back!=null and back.is_visible_in_tree(),"facility return available "+place.id+"/"+facility)
			if back!=null:
				back.pressed.emit();await settle()
			check(game.page=="hub" and hub.artwork==chosen,"same visit retains art "+place.id+"/"+facility)
		check(await saved()==before,"hub navigation preserves campaign "+place.id)
	# Stable visit selection is independent of the number of variants.
	hub.catalog.astaris.append({"path":"res://assets/ui_icons/icons64/inn.png","style":"test C"})
	await game.update({"op":"campaign_load","data":baseline});game.navigate("hub");await settle()
	var selected={}
	for i in range(40):hub.reset();hub.select_art("astaris");selected[hub.artwork.style]=true
	check(selected.size()==3,"art catalog supports additional variants without code changes")
	var q=game.campaign().board[0];await game.act("accept",[q.id,"character_yuno"]);await settle()
	game.pages.party_view.open_inventory("character_yuno");await settle()
	var cargo=game.campaign().activeQuest.cargoItemId
	var rows=game.find_children("*","Button",true,false).filter(func(button):return button.tooltip_text=="荷物")
	check(rows.size()==1,"porter inventory contains accepted cargo")
	if rows.size()==1:rows[0].pressed.emit();await settle()
	var discard=node("CharacterDiscard")
	check(game.pages.party_view.workspace.picked.get("id")==cargo and discard!=null and discard.disabled and discard.tooltip_text.contains("使用・売却・廃棄はできません"),"cargo selection explains its delivery restrictions")
	check(not game.find_children("*","Button",true,false).any(func(button):return button.text.ends_with("に使う")) and discard!=null and not discard.tooltip_text.contains("回復対象がいません"),"cargo offers no recovery target or recovery explanation")
	game.navigate("hub");await settle()
	await arrive_with_cargo(q.to)
	check(game.page=="hub" and game.campaign().activeQuest!=null and node("TownHub")!=null,"arrival opens hub without auto-delivering cargo")
	await click("HubFacility_weapon")
	check(not node("FacilityChoice_delivery").disabled,"recipient accepts cargo in the weapon shop")
	# Hand in at every distinct destination through its on-screen control.
	for route in [["astaris","west",0,"armor"],["astaris","south",1,"items"],["east","astaris",0,"guild"],["astaris","north",2,""],["astaris","east",0,"sluice-bell"]]:
		var start=baseline.duplicate(true)
		start.state.location=route[0];start.state.boardRound=route[2]
		await game.update({"op":"campaign_load","data":start});await settle()
		var special=route[3]=="sluice-bell"
		var offers=game.campaign().board.filter(func(offer):return offer.id=="sluice-bell" if special else offer.to==route[1] and not offer.get("scenario",false) and offer.id!="sluice-bell")
		check(not offers.is_empty(),"current offer for "+str(route))
		if offers.is_empty():continue
		await game.act("accept",[offers[0].id,"character_yuno"])
		await arrive_with_cargo(route[1])
		if route[3]=="" or special:
			check(node("HubDeliverCargo")!=null,"recipient has a local map handoff: "+str(route[1]))
			await click("HubDeliverCargo")
		else:
			check(node("HubDeliverCargo")==null,"facility recipient cannot be paid on the map: "+str(route[1]))
			await click("HubFacility_"+route[3])
			check(node("FacilityChoice_delivery")!=null and not node("FacilityChoice_delivery").disabled,"correct facility accepts the parcel: "+str(route[3]))
			await click("FacilityChoice_delivery")
		check(game.campaign().activeQuest==null and game.campaign().phase=="result","handoff completes at "+str(route))
	var fixtures=battle_fixture();await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
	await game.choose_command("action_item");await game.on_cell(int(game.hud.acting().pos));await settle()
	var prediction=game.hud.left_info.find_child("Inspect_hp",true,false)
	check(prediction.current==game.hud.acting().hp and prediction.projected>prediction.current,"I01 a healing preview changes the actor gauge")
	var before=await saved();var pending=game.pending;var chosen=game.chosen.duplicate()
	var enemy=game.state().units.filter(func(u):return u.side=="enemy")[0]
	game.hud.inspect_hover(enemy.id,game.board);await settle()
	check(node("InspectedPersonHeading").text=="参照" and game.hud.person_box.get_meta("inspected_unit","")==enemy.id and node("InspectedPersonHeading").global_position.y>node("ActionAvailability").global_position.y,"hover reference labelled after decision summary")
	check(game.pending==pending and game.chosen==chosen and await saved()==before,"hover never replaces confirmed target or changes save")
	var scroll=game.hud.right_panel.body.get_parent();scroll.scroll_vertical=100000;await frames()
	check(game.hud.right_panel.get_global_rect().encloses(node("BattleConfirm").get_global_rect()),"confirm and cancel remain pinned outside scroll")
	game.cancel();await settle();check(await saved()==before,"cancel still consumes no item or action")
	await game.update({"op":"campaign_load","data":fixtures.guard});await settle()
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
