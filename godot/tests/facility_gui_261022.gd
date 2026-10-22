extends "res://tests/inventory_header_261020.gd"
var request_id=0
func os_mouse(point: Vector2, action := "move", end := Vector2.ZERO):
	request_id+=1
	var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"id":request_id,"action":action,"x":point.x,"y":point.y,"end_x":end.x,"end_y":end.y}));f.close()
	var deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		if FileAccess.file_exists(evidence.path_join("response.json")):
			var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
			if response is Dictionary and response.get("id")==request_id:break
		await process_frame
	check(Time.get_ticks_msec()<deadline,"OS XTest mouse request acknowledged")
	await create_timer(.2).timeout;await settle()
func os_click(control):
	check(control!=null and control.is_visible_in_tree(),"OS click target visible")
	if control!=null:await os_mouse(control.get_global_rect().get_center()+Vector2(control.get_window().position),"click")
func snapshot(label):
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	check(image!=null and image.get_size()==root.size,"real rendered viewport "+label)
	image.save_png(evidence.path_join(label+".png"))
func floor_probe(point: Vector2,label: String,clicked: Array):
	var expected=str(game.board.unit_at(game.board.cell_at(point)).get("id",""))
	await os_mouse(point)
	check(game.board.hover_uid==expected and game.hud.person_box.get_meta("inspected_unit","")==expected,"OS hover floor occupant "+label)
	if expected.is_empty():check(game.board.hover_caption.is_empty(),"empty OS hover clears prediction "+label)
	clicked.clear();var cell=game.board.cell_at(point)
	await os_mouse(point,"click")
	check(clicked==([cell] if cell>=0 else []),"OS click floor cell "+label)
func run():
	create_timer(600).timeout.connect(func():print("FAIL GUI watchdog");quit(2))
	check(DisplayServer.get_name()!="headless","GUI renderer and display active")
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true;await settle()
	var seed=await saved();var art=game.pages.facility_art;var production=art.catalog.duplicate(true)
	var cases=[["east","shop","weapon"],["west","shop","armor"],["south","shop","item"],["north","shop","accessory"],["astaris","party","guild"],["astaris","inn","inn"],["astaris","map","departure_map"]]
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims;root.position=Vector2i.ZERO;await settle()
		for spec in cases:
			var scenario=seed.duplicate(true);scenario.state.location=spec[0];scenario.state.characters.guard.hp=1
			await game.update({"op":"campaign_load","data":scenario});game.navigate(spec[1]);await settle()
			var before=await saved()
			for variant in production[spec[2]]:
				art.catalog={spec[2]:[variant]};art.reset();game.render();await settle()
				await snapshot(spec[2]+"_"+variant.style+"_"+str(dims.x))
				var state=art.rng.state
				var back=node("GuildReturn" if spec[1]=="party" else "InnReturn" if spec[1]=="inn" else "TownReturn")
				await os_click(back);check(game.page=="hub" and art.visit_key.is_empty(),"OS return through real background "+spec[2]+variant.style)
				art.catalog=production.duplicate(true)
				game.navigate(spec[1]);await settle();check(art.rng.state!=state,"OS departure and revisit redraw "+spec[2]+variant.style)
			art.catalog=production.duplicate(true)
			if spec[0]=="east":
				var state=art.rng.state
				var product=node("Product_spear-wood");var receiver=node("PartyFace_guard")
				await os_mouse(product.get_global_rect().get_center(),"drag",receiver.get_global_rect().get_center())
				check(node("PurchaseDecline")!=null,"OS product drag opens purchase consent")
				if node("PurchaseDecline")!=null:await os_click(node("PurchaseDecline"))
				check(art.rng.state==state,"OS drag cancellation keeps visit")
				await os_click(node("ProductBuy_spear-wood"));check(node("PurchaseDecline")!=null,"OS shop purchase opens recipient/consent")
				if node("PurchaseDecline")!=null:await os_click(node("PurchaseDecline"))
				check(art.rng.state==state,"OS purchase cancellation keeps visit")
			if spec[1]=="map":
				var map=node("TownMap");var dest=map.buttons.keys().filter(func(id):return id!=map.current and id!=map.selected)[0]
				await os_click(map.buttons[dest]);check(node("TownMap").selected==dest,"OS map destination works over background")
			if spec[1]=="party":
				await os_click(node("GuildMember_guard"));check(game.pages.guild_view.chosen_id=="guard","OS guild member selects over background")
			if spec[1]=="inn":
				await os_click(node("InnStay"))
				var confirmations=game.find_children("*","ConfirmationDialog",true,false)
				check(confirmations.size()==1 and confirmations[0].visible,"OS inn consent opens over background")
				if not confirmations.is_empty():await os_click(confirmations[0].get_cancel_button())
			check(await saved()==before,"GUI inspection and cancellation preserve exact save and progress RNG")
	# Actual OS events travel through the window and Godot hit testing.
	await game.update({"op":"campaign_load","data":battle_fixture().guard});await settle();await game.choose_command("attack");await settle()
	game.board.cell_clicked.disconnect(game.on_cell);var clicked=[]
	game.board.cell_clicked.connect(func(pos):clicked.append(pos))
	var before=await saved();var occupied=int(game.state().units[0].pos);var empty=-1
	for p in range(50):
		if game.board.unit_at(p).is_empty() and game.board.project_cell(p).x>650 and game.board.project_cell(p).x<1000:empty=p;break
	check(empty>=0,"unobscured empty floor available")
	for dims in [Vector2i(1920,1080),Vector2i(1180,812)]:
		root.size=dims;await settle()
		for pitch in [.4,.7,1.1]:
			game.board.camera_pitch=pitch;game.board.update_camera();await settle()
			# Hide movable HUD windows only for unobscured board input probes.
			game.hud.left_panel.hide();game.hud.right_panel.hide()
			await floor_probe(game.board.project_cell(occupied),"occupied "+str(dims)+str(pitch),clicked)
			await floor_probe(game.board.project_cell(empty),"empty "+str(dims)+str(pitch),clicked)
		game.board.camera_pitch=.7;game.board.update_camera();await settle()
		var sprite=game.board.actors[game.state().units[0].id].sprite
		var full=Image.create(64,64,false,Image.FORMAT_RGBA8);full.fill(Color.WHITE)
		for p in [empty,occupied]:
			for u in game.state().units:
				if int(u.pos)!=p:sprite=game.board.actors[u.id].sprite;break
			sprite.global_position=game.board.point(p)+Vector3(0,.03,0)+game.board.world.camera.global_basis.z*.8;sprite.pixel_size=.03;sprite.texture=ImageTexture.create_from_image(full)
			await floor_probe(game.board.project_cell(p),"overlapping opaque image "+str(p),clicked)
		await snapshot("floor_overlap_"+str(dims.x))
	check(await saved()==before,"OS floor probes preserve campaign and progress RNG")
	var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
