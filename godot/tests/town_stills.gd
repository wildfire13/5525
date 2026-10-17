extends "res://tests/ui_feedback2_20261016.gd"
func run():
	create_timer(90).timeout.connect(func():quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var baseline=await saved();var hub=game.pages.hub_view
	check(hub.catalog.size()==5,"five delivered town catalogs")
	for town in hub.catalog:
		var variants=hub.catalog[town]
		check(variants.size()==2,"two delivered variants: "+town)
		var seed=baseline.duplicate(true);seed.state.location=town
		await game.update({"op":"campaign_load","data":seed});game.navigate("hub");await settle()
		for variant in variants:
			hub.location=town;hub.artwork=variant.duplicate(true);game.render();await settle()
			var image=node("TownStill");var texture=image.texture
			check(texture!=null and texture.resource_path==variant.path and texture.get_width()==1672 and texture.get_height()==941,"actual texture loaded: "+variant.id)
			check(texture.get_image()!=null and not texture.get_image().is_empty(),"decoded pixel image available: "+variant.id)
			check(image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(image.get_global_rect()),"full aspect-preserved image within FHD: "+variant.id)
			check(node("TownArtStyle").text=="画風："+variant.style,"Japanese style label matches: "+variant.id)
			var buttons=game.find_children("HubFacility_*","Button",true,false).map(func(b):return b.name)
			for button in buttons:
				await click(button);game.town_back.pressed.emit();await settle()
				check(hub.artwork==variant and node("TownStill").texture.resource_path==variant.path,"facility return retains picture: "+variant.id+"/"+button)
		var seen={};hub.rng.seed=5525
		for i in range(32):hub.reset();hub.select_art(town);seen[hub.artwork.id]=true
		check(seen.size()==2,"random visits select both real variants: "+town)
		var rng_state=hub.rng.state;var selected=hub.artwork.duplicate(true)
		for i in range(5):hub.select_art(town)
		check(hub.rng.state==rng_state and hub.artwork==selected,"same visit does not reroll: "+town)
		check(await saved()==seed,"image selection and facilities do not alter campaign: "+town)
	var f=FileAccess.open(evidence.path_join("town-stills.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
