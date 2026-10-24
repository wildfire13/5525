extends "res://tests/inventory_header_261020.gd"
## Synthetic, isolated NPC lifecycle/layout checks. Real rendering is separate QA.
func npc_layout(label: String):
	var content=node("FacilityContent");var stage=node("FacilityNpcStage");var portrait=node("FacilityNpc")
	check(content!=null and stage!=null and portrait!=null,"NPC dedicated content and portrait regions "+label)
	if content==null or stage==null or portrait==null:return
	var view=Rect2(Vector2.ZERO,Vector2(root.size));var content_rect=content.get_global_rect();var stage_rect=stage.get_global_rect()
	check(view.encloses(content_rect) and view.encloses(stage_rect) and content_rect.end.x<=stage_rect.position.x,"NPC region and UI fit without intersection "+label)
	check(stage.mouse_filter==Control.MOUSE_FILTER_IGNORE and portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE and portrait.focus_mode==Control.FOCUS_NONE,"NPC decoration cannot consume pointer or focus "+label)
	check(portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and portrait.expand_mode==TextureRect.EXPAND_IGNORE_SIZE and portrait.texture.get_size()==Vector2(1024,1536),"NPC keeps complete original aspect and pixels "+label)
	var image=node("FacilityStill")
	check(image.get_parent().get_child_count()==3 and node("FacilityForeground").get_index()==2,"NPC preserves existing three backdrop layers "+label)
	var fit=true
	for control in content.find_children("*","Control",true,false):
		if not control.is_visible_in_tree():continue
		if control is BaseButton or control is ScrollContainer:
			if control.get_global_rect().end.x>stage_rect.position.x:fit=false
	check(fit,"NPC does not cover interactive UI or scroll regions "+label)
	if game.page=="party":
		check(node("GuildReserveScroll").size.x>=240 and node("GuildCurrentScroll").size.x>=240 and node("GuildOperations").get_global_rect().end.y<=root.size.y,"NPC preserves two readable guild columns and actions "+label)
		check(node("GuildRules").get_child(0).get_combined_minimum_size().y<=node("GuildRules").size.y,"NPC guild rule lines remain above member lists "+label)
		var readable=true
		for vitals in content.find_children("GuildVitals_*","Label",true,false):
			var width=vitals.get_theme_font("font").get_string_size(vitals.text,HORIZONTAL_ALIGNMENT_LEFT,-1,vitals.get_theme_font_size("font_size")).x
			if width>vitals.size.x:readable=false
		check(readable,"NPC guild HP MP and level text fit allocated rows "+label)
	elif game.page=="shop" and node("ShopProductsScroll")!=null:
		check(node("ShopProductsScroll").get_global_rect().end.x<=content_rect.end.x,"NPC product list stays within assigned UI width "+label)
	elif game.page=="inn":
		check(node("InnPartyScroll").size.x<=content.size.x and node("InnMember_guard").get_parent().custom_minimum_size.x==180,"NPC preserves inn card size with contained scrolling "+label)
func run():
	create_timer(180).timeout.connect(func():print("FAIL NPC watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facility_npcs/manifest.json"));var total=0
	check(manifest is Array and manifest.size()==7,"NPC manifest registers exactly seven supplied originals")
	for entry in manifest:
		var path=str(entry.path);var bytes=FileAccess.get_file_as_bytes(path);total+=bytes.size()
		var image=Image.new();var decoded=image.load_png_from_buffer(bytes)
		check(FileAccess.get_sha256(path)==entry.sha256 and decoded==OK and image.get_size()==Vector2i(entry.width,entry.height) and image.get_format()==Image.FORMAT_RGBA8,"NPC original SHA256 dimensions and RGBA "+path.get_file())
	check(total==13515244,"NPC original seven PNG files retain exact delivered total byte count")
	var art=game.pages.facility_art;var seed=await saved();seed.state.gold=500;seed.state.characters.guard.inventory={"spear-wood":3,"potion":2}
	var isolated=preload("res://facility_npc.gd").new();var expected=RandomNumberGenerator.new();isolated.rng.seed=5525;expected.seed=5525;var observed={};var exact=true
	var background_state=art.rng.state;var campaign_before=await saved()
	for i in range(32):
		isolated.sync("weapon");var expected_path=isolated.ROOT+str(isolated.CATALOG.weapon[expected.randi_range(0,1)])
		exact=exact and isolated.selected_path==expected_path and isolated.rng.state==expected.state;observed[isolated.selected_path]=true
		var state=isolated.rng.state;isolated.sync("weapon");exact=exact and isolated.rng.state==state;isolated.reset()
	check(exact and observed.size()==2,"NPC weapon uses exactly one independent equal two-way draw per entry, allowing repeats")
	check(art.rng.state==background_state and (await saved())==campaign_before,"NPC independent draws leave background and exact game save unchanged")
	for facility in ["armor","item","accessory","inn","guild"]:
		var state=isolated.rng.state;isolated.sync(facility)
		check(isolated.selected_path==isolated.ROOT+facility+".png" and isolated.rng.state==state,"NPC fixed facility uses no random draw "+facility)
		isolated.reset()
	isolated.sync("departure_map");check(isolated.texture==null and isolated.selected_path.is_empty(),"NPC has no departure-map character")
	var cases=[["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"]]
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims
		for spec in cases:
			var scenario=seed.duplicate(true);scenario.state.location=spec[0]
			await game.update({"op":"campaign_load","data":scenario});game.navigate(spec[1]);await settle()
			var before=await saved();var path=art.npc.selected_path;var state=art.npc.rng.state
			check(art.npc.visit_key==spec[2] and art.npc.texture!=null and path.get_file() in art.npc.CATALOG[spec[2]],"NPC correctly assigned on facility entry "+str(spec)+str(dims.x))
			npc_layout(str(spec)+str(dims.x))
			for i in range(3):game.render();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==state,"NPC repeated renders retain same visit "+str(spec)+str(dims.x))
			root.size=Vector2i(1180,812) if dims.x==1920 else Vector2i(1920,1080);await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==state,"NPC resize does not reroll "+str(spec)+str(dims.x))
			root.size=dims;await settle()
			game.pages.party_view.open_detail("guard");await settle();game.pages.party_view.portrait_pressed("archer");await settle();game.dialog.close();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==state and (await saved())==before,"NPC owner switching and details preserve NPC and exact save "+str(spec)+str(dims.x))
			game.navigate("hub");await settle()
			check(art.npc.selected_path.is_empty() and art.npc.texture==null and art.npc.visit_key.is_empty(),"NPC leaves with facility "+str(spec)+str(dims.x))
			game.navigate(spec[1]);await settle()
			check((art.npc.rng.state!=state if spec[2]=="weapon" else art.npc.rng.state==state and art.npc.selected_path==path) and (await saved())==before,"NPC reentry redraws weapon only and preserves game save "+str(spec)+str(dims.x))
		var east=seed.duplicate(true);east.state.location="east"
		await game.update({"op":"campaign_load","data":east});game.navigate("shop");await settle()
		var path=art.npc.selected_path;var state=art.npc.rng.state;var before=await saved()
		await game.pages.shop_view.confirm_purchase("spear-wood","guard");await settle();await click("PurchaseDecline")
		check((await saved())==before and art.npc.selected_path==path and art.npc.rng.state==state,"NPC purchase cancellation keeps original visit "+str(dims.x))
		await game.pages.shop_view.confirm_purchase("spear-wood","guard");await settle();await click("PurchaseAgree")
		check(int(game.campaign().gold)==410 and int(game.campaign().characters.guard.inventory["spear-wood"])==4 and art.npc.selected_path==path and art.npc.rng.state==state,"NPC actual purchase retains current keeper "+str(dims.x))
		game.pages.party_view.open_detail("guard");await settle();await click("OwnedInventorySell_spear-wood");await click("InventoryPrepareSale");await consent(false)
		check(art.npc.selected_path==path and art.npc.rng.state==state,"NPC sale cancellation retains keeper "+str(dims.x))
		await click("OwnedInventorySell_spear-wood");await click("InventoryPrepareSale");var quote=game.pages.party_view.inventory_view.quote.duplicate(true);await consent(true)
		check(int(game.campaign().gold)==int(quote.afterGold) and int(game.campaign().characters.guard.inventory["spear-wood"])==3 and art.npc.selected_path==path and art.npc.rng.state==state,"NPC actual sale retains keeper and canonical result "+str(dims.x))
		game.dialog.close();await settle()
	await game.update({"op":"campaign_load","data":seed});game.navigate("map");await settle()
	check(node("FacilityNpc")==null and node("FacilityNpcStage")==null and art.npc.texture==null,"NPC does not reserve empty space on departure map")
	game.navigate("party");await settle();art.sync("battle","astaris","party")
	check(art.npc.texture==null and art.npc.selected_path.is_empty(),"NPC combat transition clears decorative visit")
	art.sync("town","astaris","party");game.pages.reset_context()
	check(art.npc.texture==null and art.npc.selected_path.is_empty(),"NPC load/new-session context reset clears selected keeper")
	var shop_seed=seed.duplicate(true);shop_seed.state.location="east"
	await game.update({"op":"campaign_load","data":shop_seed});game.navigate("shop");await settle()
	var keeper=art.npc.selected_path;var keeper_rng=art.npc.rng.state;var save_before_compact=await saved()
	for compact in [Vector2i(1024,720),Vector2i(800,600)]:
		root.size=compact;await settle()
		check(node("FacilityNpcStage")==null and art.npc.selected_path==keeper and art.npc.rng.state==keeper_rng and (await saved())==save_before_compact,"NPC compact mode preserves existing UI and visit without squeezing controls "+str(compact))
	root.size=Vector2i(1180,812);await settle()
	check(node("FacilityNpcStage")!=null and art.npc.selected_path==keeper and art.npc.rng.state==keeper_rng,"NPC returns unchanged after compact resize")
	var connection=game.engine.connection_generation;var lost=game.engine._disconnect("synthetic-npc-loss")
	game.handle_connection_loss(lost,connection);await settle()
	check(art.npc.selected_path.is_empty() and art.npc.texture==null and art.npc.rng.state==keeper_rng and node("FacilityNpc")==null,"NPC connection loss ends visit without immediate redraw or extra random selection")
	await game.reconnect_engine();await settle()
	check(game.page=="hub" and art.npc.selected_path.is_empty() and node("FacilityNpc")==null,"NPC reconnect bootstrap stays outside facilities until actual entry")
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"NPC QA keeps BGM voice and SE OFF")
	var f=FileAccess.open(evidence.path_join("facility-npc-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
