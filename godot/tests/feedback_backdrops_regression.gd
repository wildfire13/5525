extends "res://tests/inventory_header_261020.gd"
## New visual layout contract; game state and visit randomness are unchanged.
func visual_contract(label: String):
	var viewport=Rect2(Vector2.ZERO,Vector2(root.size));var image=node("FacilityStill") if node("FacilityStill")!=null else node("TownStill")
	check(image!=null and image.get_global_rect()==viewport and image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"still fills game viewport without stretching "+label)
	check(game.backdrop_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE and game.backdrop_layer.clip_contents and game.base.get_index()>game.backdrop_layer.get_index(),"decoration remains clipped and below interactive UI "+label)
	check(game.location_bar.visible and viewport.encloses(game.location_bar.get_global_rect()) and game.location_label.text.begins_with(game.town_name(game.campaign().location)),"common lower location band identifies existing town "+label)
	var money=node("CommonGold");var menu=node("CommonMenuButton")
	check(money.text=="%dG" % game.campaign().gold and game.location_label.get_global_rect().end.x<=money.get_global_rect().position.x and money.get_global_rect().end.x<=menu.get_global_rect().position.x,"money and location ordered left/right with common menu clear "+label)
	check(not game.top.visible and node("TownFacilityHeading")==null,"old top/duplicate place heading removed "+label)
	var before=await saved();var face=node("PartyFace_guard");face.grab_focus();await frames()
	check(face.tooltip_text.contains("HP") and face.tooltip_text.contains("ステータスを開く") and face.get_meta("no_status_hint",false) and not game.footer.text.contains("ステータスを開く"),"face tooltip retained without duplicate footer explanation "+label)
	check(await saved()==before,"visual focus cannot mutate saved campaign "+label)
func run():
	create_timer(180).timeout.connect(func():print("FAIL feedback backdrop watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved()
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims
		for spec in [["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"],["astaris","map","departure_map"],["astaris","hub",""]]:
			var scenario=seed.duplicate(true);scenario.state.location=spec[0]
			await game.update({"op":"campaign_load","data":scenario});await enter_facility(spec[1]);await settle()
			await visual_contract(str(spec)+str(dims))
			var npc=node("FacilityNpc");var before=await saved();var art=game.pages.facility_art;var path=art.npc.selected_path;var random=art.npc.rng.state
			if spec[2] not in ["departure_map",""]:
				check(npc!=null and npc.get_parent()==game.backdrop_layer and npc.size.y>root.size.y and npc.get_global_rect().end.y>root.size.y and is_equal_approx(npc.size.x/npc.size.y,2.0/3.0),"facility original enlarged with lower-body crop "+str(spec)+str(dims))
				check(npc.mouse_filter==Control.MOUSE_FILTER_IGNORE and npc.focus_mode==Control.FOCUS_NONE,"enlarged NPC cannot block UI inputs "+str(spec)+str(dims))
			else:check(npc==null,"no invented NPC for hub/map "+str(spec))
			game.render();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==random and await saved()==before,"rerender preserves visit and exact save "+str(spec)+str(dims))
	var scenario=seed.duplicate(true);scenario.state.location="east";await game.update({"op":"campaign_load","data":scenario});await enter_facility("shop");await settle()
	var selected=game.pages.facility_art.npc.selected_path;var rng=game.pages.facility_art.npc.rng.state;var before=await saved()
	for dims in [Vector2i(960,540),Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims;await settle();await visual_contract("resized "+str(dims))
		check(game.pages.facility_art.npc.selected_path==selected and game.pages.facility_art.npc.rng.state==rng and await saved()==before,"resize preserves selected keeper and save "+str(dims))
		check((node("FacilityNpc")==null)==(dims.x<1120 or dims.y<720),"compact mode prioritizes existing controls while retaining visit "+str(dims))
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"backdrop verification keeps all audio OFF")
	var f=FileAccess.open(evidence.path_join("feedback-backdrops-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
