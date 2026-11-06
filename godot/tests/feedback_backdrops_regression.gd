extends "res://tests/inventory_header_261020.gd"
## New visual layout contract; game state and visit randomness are unchanged.
func visual_contract(label: String):
	var viewport=Rect2(Vector2.ZERO,Vector2(root.size));var image=node("FacilityStill") if node("FacilityStill")!=null else node("TownStill")
	check(image!=null and image.get_global_rect()==viewport and image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"still fills game viewport without stretching "+label)
	check(game.backdrop_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.backdrop_layer.clip_contents and game.base.get_index()>game.backdrop_layer.get_index(),"decoration remains clipped and below interactive UI "+label)
	var header=node("CampaignHeader")
	check(header!=null and viewport.encloses(header.get_global_rect()) and node("Header_hub")!=null,"common navigation fits game viewport "+label)
	var money=header.find_children("*","Label",true,false).filter(func(item):return item.text==str(int(game.campaign().gold))+" G")
	var menu=header.find_children("*","Button",true,false).filter(func(item):return item.text=="メニュー")
	check(money.size()==1 and menu.size()==1 and money[0].get_global_rect().end.x<=menu[0].get_global_rect().position.x,"current money precedes common menu "+label)
	check(not game.top.visible and not game.location_bar.visible and node("TownFacilityHeading")==null,"old top and lower location band are replaced by B navigation "+label)
	var before=await saved();var face=node("RosterMember_guard")
	if face!=null:
		face.grab_focus();await frames()
		var hp=face.find_children("*","Label",true,false).filter(func(item):return item.text.begins_with("HP "))
		check(face.has_focus() and not face.disabled and hp.size()==1 and not game.footer.text.contains("ステータスを開く"),"roster focus retains visible HP without duplicate footer explanation "+label)
	else:
		check(game.pages.facility_entry.at_top(),"roster is omitted only on facility entry "+label)
		var exit_button=node("FacilityExit");check(exit_button!=null and not exit_button.disabled,"entry exit remains enabled "+label)
		if exit_button!=null:exit_button.grab_focus();await frames()
	check(await saved()==before,"visual focus cannot mutate saved campaign "+label)
func run():
	create_timer(180).timeout.connect(func():print("FAIL feedback backdrop watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
	for dims in [Vector2i(1920,1080)]:
		root.size=dims
		for spec in [["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"],["astaris","map","departure_map"],["astaris","hub",""]]:
			var scenario=seed.duplicate(true);scenario.state.location=spec[0]
			await game.update({"op":"campaign_load","data":scenario});game.navigate(spec[1]);await settle()
			await visual_contract(str(spec)+str(dims))
			var npc=node("FacilityNpc");var before=await saved();var art=game.pages.facility_art;var path=art.npc.selected_path;var random=art.npc.rng.state
			if spec[2] not in ["departure_map",""]:
				check(npc!=null and npc.get_parent().name=="FacilityEntryArt" and npc.size.y>root.size.y and npc.get_global_rect().end.y>root.size.y and is_equal_approx(npc.size.x/npc.size.y,2.0/3.0),"facility original enlarged with lower-body crop "+str(spec)+str(dims))
				check(npc!=null and npc.mouse_filter==Control.MOUSE_FILTER_IGNORE and npc.focus_mode==Control.FOCUS_NONE,"enlarged NPC cannot block UI inputs "+str(spec)+str(dims))
			else:check(npc==null,"no invented NPC for hub/map "+str(spec))
			game.render();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==random and await saved()==before,"rerender preserves visit and exact save "+str(spec)+str(dims))
			if spec[2] not in ["departure_map",""]:
				await enter_facility(spec[1]);await visual_contract("service "+str(spec))
				check(art.npc.selected_path==path and art.npc.rng.state==random and await saved()==before,"service entry preserves visit artwork and campaign "+str(spec))
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"backdrop verification keeps all audio OFF")
	var f=FileAccess.open(evidence.path_join("feedback-backdrops-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
