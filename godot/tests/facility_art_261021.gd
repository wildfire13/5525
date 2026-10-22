extends "res://tests/inventory_header_261020.gd"
func run():
	create_timer(120).timeout.connect(func():print("FAIL facility artwork watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var art=game.pages.facility_art;var seed=await saved()
	check(art.catalog.is_empty(),"production manifest truthfully contains no undelivered materials")
	var entries=[]
	# Existing images are test fixtures only, never production facility materials.
	for style in art.STYLES:entries.append({"style":style,"path":"res://assets/towns/west_b.png"})
	var cases=[["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"],["astaris","map","departure_map"]]
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims
		for spec in cases:
			var saved_seed=seed.duplicate(true);saved_seed.state.location=spec[0]
			await game.update({"op":"campaign_load","data":saved_seed});game.navigate(spec[1]);await settle()
			art.catalog={};art.reset();game.render();await settle()
			check(node("FacilityStill")==null,"missing material preserves original UI "+str(spec))
			art.catalog[spec[2]]=entries.duplicate(true);art.reset();game.render();await settle()
			var before=await saved();var state=art.rng.state;var artwork=art.artwork.duplicate()
			check(art.visit_key==spec[0]+":"+spec[2] and node("FacilityStill")!=null,"mapped facility rendered "+str(spec)+str(dims))
			var image=node("FacilityStill");var foreground=node("FacilityForeground")
			check(image.mouse_filter==Control.MOUSE_FILTER_IGNORE and node("FacilityReadabilityShade").mouse_filter==Control.MOUSE_FILTER_IGNORE,"background layers ignore input")
			check(image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and image.get_parent().get_child_count()==3 and foreground.get_index()==2,"aspect ratio and foreground layer retained")
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(image.get_global_rect()),"background fits viewport")
			for i in range(3):game.render();await settle()
			check(art.rng.state==state and art.artwork==artwork,"repeated UI renders do not reroll")
			if spec[1]=="shop" and node("ShopSlotFilter")!=null:
				var filter=node("ShopSlotFilter");filter.item_selected.emit(0);await settle()
				check(art.rng.state==state and art.artwork==artwork,"shop filter keeps visit artwork")
			if spec[0]=="east" and dims==Vector2i(1920,1080):
				await game.pages.shop_view.confirm_purchase("spear-wood","mage");await settle();await click("PurchaseDecline")
				check(await saved()==before and art.rng.state==state,"purchase cancellation preserves campaign and artwork")
				await game.pages.shop_view.confirm_purchase("spear-wood","mage");await settle();await click("PurchaseAgree")
				check(game.campaign().characters.mage.inventory.get("spear-wood",0)==int(before.state.characters.mage.inventory.get("spear-wood",0))+1 and art.rng.state==state,"confirmed purchase works over fixed background")
				before=await saved()
			if spec[1]=="map":
				check(node("TownMap")!=null and node("DepartButton")!=null,"map controls remain available over background")
				var map=node("TownMap");var destination=map.buttons.keys().filter(func(id):return id!=map.current and id!=map.selected)[0]
				map.buttons[destination].pressed.emit();await settle()
				check(node("TownMap").selected==destination and art.rng.state==state,"destination selection works without reroll")
			game.navigate("hub");await settle();check(art.visit_key.is_empty() and art.texture==null,"leaving facility clears visit")
			var town_image=game.pages.hub_view.artwork.duplicate()
			game.navigate(spec[1]);await settle();check(art.rng.state!=state,"returning facility makes new random draw (same style allowed)")
			game.navigate("hub");await settle();check(game.pages.hub_view.artwork==town_image,"facility navigation preserves existing town still")
			check(await saved()==before,"visual visits preserve exact campaign and battle RNG state")
	art.catalog={"weapon":[{"style":"papercut","path":"res://assets/facilities/not-delivered.png"},{"style":"unknown","path":"res://assets/towns/west_b.png"}]}
	art.reset();art.sync("town","east","shop");check(art.texture==null,"missing paths and unsupported styles safely fall back")
	art.catalog={"weapon":entries};art.reset();art.sync("town","east","shop");art.sync("battle","east","shop")
	check(art.texture==null and art.visit_key.is_empty(),"battle and trial leave facility visit")
	art.sync("town","east","shop");game.pages.reset_context();check(art.texture==null and art.visit_key.is_empty(),"session reset clears visit")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
