extends "res://tests/combat_b_ui.gd"

func saved():
	return (await game.engine.request({"op":"campaign_save"})).data

func click_point(point: Vector2):
	check(root.get_visible_rect().has_point(point),"viewport input point is inside FHD")
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=point;event.global_position=point
		root.push_input(event,true)
		await process_frame
	await settle()

func click_action(key: String):
	var buttons=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")==key and b.is_visible_in_tree())
	check(buttons.size()==1 and not buttons[0].disabled,"visible enabled action: "+key)
	if buttons.size()==1 and not buttons[0].disabled:
		check(root.get_visible_rect().encloses(buttons[0].get_global_rect()),"action fits FHD: "+key)
		await click_point(buttons[0].get_global_rect().get_center())

func orbit(delta: Vector2):
	var board=game.board
	var start=board.get_global_rect().get_center()
	var yaw=board.camera_yaw
	var pitch=board.camera_pitch
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_MIDDLE;press.pressed=true
	press.position=start;press.global_position=start
	root.push_input(press,true);await process_frame
	var motion=InputEventMouseMotion.new()
	motion.position=start+delta;motion.global_position=motion.position
	motion.relative=delta;motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(motion,true);await process_frame
	var release=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_MIDDLE;release.position=motion.position;release.global_position=motion.position
	root.push_input(release,true);await settle()
	check(is_equal_approx(board.camera_yaw,yaw-delta.x*.008) and is_equal_approx(board.camera_pitch,clampf(pitch+delta.y*.008,.2,1.4)) and board.camera_drag==0,"viewport middle drag exercises orbit and pitch controls")

func verify_sprites(custom_id: String = "", custom_path: String = ""):
	for unit in game.state().units:
		var sprite=game.board.actors[unit.id].sprite
		var file="enemy/enemy_"+unit.image if unit.side=="enemy" else unit.image
		var path=custom_path if unit.id==custom_id else ProjectSettings.globalize_path("res://../native/assets/"+file)
		var source=Image.load_from_file(path)
		check(source!=null and sprite.texture!=null,"battle portrait exists for "+unit.id)
		if source!=null and sprite.texture!=null:
			source.generate_mipmaps()
			check(sprite.texture.get_image().get_data()==source.get_data(),"battle sprite uses the expected portrait for "+unit.id)
		check(not sprite.flip_h and sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED,"portrait faces its original direction for "+unit.id)

func run():
	create_timer(150).timeout.connect(func():print("FAIL display watchdog");quit(2))
	root.size=Vector2i(1920,1080)
	check(root.get_visible_rect().size==Vector2(1920,1080),"display test uses the real FHD viewport")
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true
	game.audio.fast_mode=true
	var result=[]
	var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/display_fixtures.cjs")],result)
	var profiles=JSON.parse_string("".join(result))
	check(code==0 and profiles is Array and not profiles.is_empty(),"current equipment profiles are available")
	if profiles is Array:
		for profile in profiles:
			check(game.pages.normal_reach(profile.stats)==profile.reach,"attack reach for "+profile.name)
			for distance in range(1,5):
				check(game.pages.normal_atk(profile.stats,distance)==profile.powers[distance-1],"attack at distance %d for %s" % [distance,profile.name])
	await game.act("depart",["east","convoy"])
	await game.act("travel",["safe"])
	await game.act("begin",[])
	await settle()
	verify_sprites()
	var actor=game.state().actor
	var replacement=game.roster().filter(func(member):return member.id!=actor)[0]
	var path=ProjectSettings.globalize_path("res://../native/assets/"+replacement.image)
	var before=FileAccess.get_file_as_bytes(path)
	game.portraits.assign(actor,{"png":Marshalls.raw_to_base64(before)})
	game.render()
	await settle()
	verify_sprites(actor,path)
	await game.choose_command("action_move")
	var moves=game.data.choices.action_move
	check(not moves.is_empty(),"current actor has a movement preview")
	if not moves.is_empty():
		var target=int(moves[0])
		var campaign_before=await saved()
		var ghost=game.board.ghost
		for delta in [Vector2(10,-8),Vector2(-35,20),Vector2(45,-12)]:
			await orbit(delta)
			var camera=Vector2(game.board.camera_yaw,game.board.camera_pitch)
			var point=game.board.project_cell(target)
			check(game.board.cell_at(point)==target,"custom portrait floor projection: "+str(camera))
			await click_point(game.board.global_position+point)
			check(game.pending==target and game.preview_ready,"viewport click selects custom portrait movement: "+str(camera))
			check(ghost.visible and not ghost.flip_h and ghost.modulate.a<1,"movement preview shows the translucent portrait")
			check(ghost.texture==game.board.actors[actor].sprite.texture,"preview uses the custom portrait of the acting member")
			check(await saved()==campaign_before,"custom portrait mouse preview preserves complete save")
			await shot("custom-portrait-preview-"+str(delta.x))
			await click_action("battle_cancel")
			check(game.pending==null and not ghost.visible and await saved()==campaign_before,"visible cancel clears preview and preserves complete save")
		await click_point(game.board.global_position+game.board.project_cell(target))
		check(game.pending==target and game.preview_ready and game.board.ghost.visible,"fresh viewport selection is ready before visible commit")
		var actions=int(game.state().actions)
		await click_action("battle_commit")
		await settle()
		check(int(game.state().actions)==actions+1 and game.hud.unit(actor).pos==target,"visible confirm commits custom portrait movement exactly once")
		check(game.pending==null and not ghost.visible,"committed movement clears the preview")
		await shot("custom-portrait-committed")
	check(FileAccess.get_file_as_bytes(path)==before,"custom portrait source is unchanged")
	game.closing=true
	await game.audio.finish_audio()
	game.engine.close_engine()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
