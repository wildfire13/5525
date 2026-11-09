extends "res://tests/inventory_header_261020.gd"
## Synthetic, isolated NPC lifecycle/layout checks. Real rendering is separate QA.
# Two layout passes on each side of settle are sufficient for this node-geometry
# suite; settle still waits for engine requests, locks and presentation to finish.
func frames(count:=2):
	for i in range(count):await process_frame
func npc_layout(label: String):
	var viewport=Rect2(Vector2.ZERO,Vector2(root.size));var portrait=node("FacilityNpc")
	var entry=node("FacilityEntry");var choices=node("FacilityChoices");var stage=node("FacilityNpcStage");var art=node("FacilityEntryArt")
	check(entry!=null and choices!=null and stage!=null and art!=null and portrait!=null,"NPC entrance owns dedicated choices and portrait regions "+label)
	if entry==null or choices==null or stage==null or art==null or portrait==null:return
	check(viewport.encloses(choices.get_global_rect()) and choices.get_global_rect().end.x<=portrait.get_global_rect().position.x,"NPC entrance choices fit without portrait intersection "+label)
	check(stage.mouse_filter==Control.MOUSE_FILTER_IGNORE and art.mouse_filter==Control.MOUSE_FILTER_IGNORE and portrait.mouse_filter==Control.MOUSE_FILTER_IGNORE and portrait.focus_mode==Control.FOCUS_NONE,"NPC decoration cannot consume pointer or focus "+label)
	check(portrait.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and portrait.expand_mode==TextureRect.EXPAND_IGNORE_SIZE and portrait.texture.get_size()==Vector2(1024,1536) and is_equal_approx(portrait.size.x/portrait.size.y,2.0/3.0) and is_equal_approx(portrait.size.y,root.size.y*1.28) and portrait.position.y>0,"NPC enlarges unchanged original aspect with lower body outside viewport "+label)
	check(portrait.get_parent()==art and stage.is_ancestor_of(art) and entry.is_ancestor_of(stage) and not game.backdrop_layer.is_ancestor_of(portrait),"NPC belongs to entry lifecycle separately from cached backdrop "+label)
	check(node("FacilityStill")!=null and game.base.get_index()>game.backdrop_layer.get_index(),"NPC entrance retains backdrop below foreground controls "+label)
func service_layout(label: String):
	var viewport=Rect2(Vector2.ZERO,Vector2(root.size));var body=node("CampaignBody")
	check(node("FacilityEntry")==null and node("FacilityNpc")==null and node("FacilityNpcStage")==null and node("FacilityEntryArt")==null,"NPC enlarged entrance art leaves service working area "+label)
	check(body!=null and viewport.encloses(body.get_global_rect()) and node("FacilityStill")!=null,"NPC service retains contained workspace and facility backdrop "+label)
	if game.page=="party":
		var reserve=node("GuildReserveScroll");var comparison=node("GuildComparison");var actions=node("GuildActions")
		check(reserve!=null and comparison!=null and actions!=null and reserve.size.x>=240 and viewport.encloses(reserve.get_global_rect()) and viewport.encloses(comparison.get_global_rect()) and viewport.encloses(actions.get_global_rect()),"NPC guild retains readable reserve comparison and actions "+label)
	elif game.page=="shop":
		var products=node("ShopProductsScroll")
		check(products!=null and viewport.encloses(products.get_global_rect()),"NPC product list stays within service viewport "+label)
	elif game.page=="inn":
		var keeper=node("InnKeeper");var scroll=node("InnPartyScroll");var members=node("InnParty")
		check(keeper!=null and keeper.texture==game.pages.facility_art.npc.texture and keeper.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and viewport.encloses(keeper.get_global_rect()),"NPC inn uses same visit portrait in contained keeper column "+label)
		check(scroll!=null and members!=null and viewport.encloses(scroll.get_global_rect()) and members.get_global_rect().size.x<=scroll.size.x and node("InnActions").get_global_rect().end.y<=root.size.y,"NPC inn party grid and actions fit service region "+label)
func run():
	create_timer(180).timeout.connect(func():print("FAIL NPC watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated profile required");quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await preload("res://tests/current_historical_fixture.gd").install(game)
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	# Keep verified portraits resident while exercising 600 visit draws. Godot's
	# weak resource cache would otherwise decode PNGs on every reset; that tests
	# loader throughput rather than RNG/lifecycle and can exceed the runner limit.
	var resident_portraits=[]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/facility_npcs/manifest.json"));var total=0
	check(manifest is Array and manifest.size()==9,"NPC manifest registers six facility originals and three guild staff portraits")
	for entry in manifest:
		var path=str(entry.path);var bytes=FileAccess.get_file_as_bytes(path);total+=bytes.size();resident_portraits.append(load(path))
		var image=Image.new();var decoded=image.load_png_from_buffer(bytes)
		check(FileAccess.get_sha256(path)==entry.sha256 and decoded==OK and image.get_size()==Vector2i(entry.width,entry.height) and image.get_format()==Image.FORMAT_RGBA8,"NPC original SHA256 dimensions and RGBA "+path.get_file())
	check(total==18834299,"NPC six existing and three guild portrait PNG files retain exact byte count")
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
		if facility=="guild":
			var selected=isolated.selected_path.get_file();var after_draw=isolated.rng.state
			isolated.sync(facility)
			check(isolated.CATALOG.guild.has(selected) and isolated.rng.state==after_draw,"NPC guild portrait draws from catalog once and remains fixed within visit")
		else:
			check(isolated.selected_path==isolated.ROOT+facility+".png" and isolated.rng.state==state,"NPC fixed facility uses no random draw "+facility)
		isolated.reset()
	isolated.sync("departure_map");check(isolated.texture==null and isolated.selected_path.is_empty(),"NPC has no departure-map character")
	isolated.rng.seed=5525;var guild_counts={}
	for i in range(600):
		isolated.reset();isolated.sync("guild");guild_counts[isolated.selected_path.get_file()]=guild_counts.get(isolated.selected_path.get_file(),0)+1
	var fixed_guild=isolated.selected_path;isolated.sync("guild")
	check(guild_counts.size()==3 and guild_counts.values().all(func(n):return n>0) and fixed_guild==isolated.selected_path,"Guild draws all three portraits across visits and stays fixed within a visit")
	var cases=[["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"]]
	for dims in [Vector2i(1920,1080)]:
		root.size=dims
		for spec in cases:
			var scenario=seed.duplicate(true);scenario.state.location=spec[0]
			await game.update({"op":"campaign_load","data":scenario});game.navigate(spec[1]);await settle()
			var before=await saved();var path=art.npc.selected_path;var state=art.npc.rng.state
			check(art.npc.visit_key==spec[2] and art.npc.texture!=null and path.get_file() in art.npc.CATALOG[spec[2]],"NPC correctly assigned on facility entry "+str(spec)+str(dims.x))
			npc_layout(str(spec)+str(dims.x))
			await enter_facility(spec[1]);service_layout(str(spec)+str(dims.x))
			check(art.npc.selected_path==path and art.npc.rng.state==state and (await saved())==before,"NPC service selection preserves visit and exact save "+str(spec))
			game.pages.facility_entry.back();await settle();npc_layout("return "+str(spec))
			check(art.npc.selected_path==path and art.npc.rng.state==state and (await saved())==before,"NPC return to entrance preserves visit and exact save "+str(spec))
			await enter_facility(spec[1])
			for i in range(3):game.render();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==state,"NPC repeated renders retain same visit "+str(spec)+str(dims.x))
			game.pages.party_view.open_detail("guard");await settle();game.pages.party_view.portrait_pressed("archer");await settle();game.dialog.close();await settle()
			check(art.npc.selected_path==path and art.npc.rng.state==state and (await saved())==before,"NPC owner switching and details preserve NPC and exact save "+str(spec)+str(dims.x))
			game.navigate("hub");await settle()
			check(art.npc.selected_path.is_empty() and art.npc.texture==null and art.npc.visit_key.is_empty(),"NPC leaves with facility "+str(spec)+str(dims.x))
			await enter_facility(spec[1])
			var reentry_ok=false
			if spec[2]=="weapon":reentry_ok=art.npc.rng.state!=state
			elif spec[2]=="guild":reentry_ok=art.npc.rng.state!=state and art.npc.CATALOG.guild.has(art.npc.selected_path.get_file())
			else:reentry_ok=art.npc.rng.state==state and art.npc.selected_path==path
			check(reentry_ok and (await saved())==before,"NPC reentry redraws only random facilities and preserves game save "+str(spec)+str(dims.x))
		var east=seed.duplicate(true);east.state.location="east"
		await game.update({"op":"campaign_load","data":east});await enter_facility("shop")
		var path=art.npc.selected_path;var state=art.npc.rng.state;var before=await saved()
		await game.pages.shop_view.confirm_purchase("spear-wood","guard");await settle();await click("PurchaseDecline")
		check((await saved())==before and art.npc.selected_path==path and art.npc.rng.state==state,"NPC purchase cancellation keeps original visit "+str(dims.x))
		await game.pages.shop_view.confirm_purchase("spear-wood","guard");await settle()
		var agree=node("PurchaseAgree");agree.pressed.emit();agree.pressed.emit();await settle()
		check(int(game.campaign().gold)==410 and int(game.campaign().characters.guard.inventory["spear-wood"])==4 and art.npc.selected_path==path and art.npc.rng.state==state,"NPC actual purchase retains current keeper "+str(dims.x))
		var purchase_save=await saved()
		var sale=game.pages.shop_view.sale
		await click("RosterMember_guard");await click("SaleItem_spear-wood");await click("FacilitySalePrepare")
		sale.confirmation.canceled.emit();sale.confirmation.hide();await settle()
		check((await saved())==purchase_save and art.npc.selected_path==path and art.npc.rng.state==state,"NPC sale cancellation retains keeper "+str(dims.x))
		var quote=sale.quote.duplicate(true)
		await click("FacilitySalePrepare");await click("FacilitySaleConfirm")
		check(int(game.campaign().gold)==int(quote.afterGold) and int(game.campaign().characters.guard.inventory["spear-wood"])==3 and art.npc.selected_path==path and art.npc.rng.state==state,"NPC actual sale retains keeper and canonical result "+str(dims.x))
		game.dialog.close();await settle()
	await game.update({"op":"campaign_load","data":seed});game.navigate("map");await settle()
	check(node("FacilityNpc")==null and node("FacilityNpcStage")==null and art.npc.texture==null,"NPC does not reserve empty space on departure map")
	await enter_facility("party");art.sync("battle","astaris","party")
	check(art.npc.texture==null and art.npc.selected_path.is_empty(),"NPC combat transition clears decorative visit")
	art.sync("town","astaris","party");game.pages.reset_context()
	check(art.npc.texture==null and art.npc.selected_path.is_empty(),"NPC load/new-session context reset clears selected keeper")
	var shop_seed=seed.duplicate(true);shop_seed.state.location="east"
	await game.update({"op":"campaign_load","data":shop_seed});await enter_facility("shop")
	var keeper_rng=art.npc.rng.state
	var connection=game.engine.connection_generation;var lost=game.engine._disconnect("synthetic-npc-loss")
	game.handle_connection_loss(lost,connection);await settle()
	check(art.npc.selected_path.is_empty() and art.npc.texture==null and art.npc.rng.state==keeper_rng and node("FacilityNpc")==null,"NPC connection loss ends visit without immediate redraw or extra random selection")
	await game.reconnect_engine();await settle()
	check(game.page=="hub" and art.npc.selected_path.is_empty() and node("FacilityNpc")==null,"NPC reconnect bootstrap stays outside facilities until actual entry")
	check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"NPC QA keeps BGM voice and SE OFF")
	var f=FileAccess.open(evidence.path_join("facility-npc-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	quit(0 if checks.all(func(c):return c.passed) else 1)
