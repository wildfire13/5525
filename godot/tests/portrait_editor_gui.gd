extends "res://tests/mock_character_migration.gd"

func run():
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var fresh_path=OS.get_environment("PORTRAIT_QA_NEW")
	if fresh_path.is_empty():
		await game.new_game()
	else:
		var fresh=JSON.parse_string(FileAccess.get_file_as_string(fresh_path))
		var loaded=await game.update({"op":"campaign_load","data":fresh.result})
		check(loaded.get("ok",false),"load current-tree save-lab new")
	game.navigate("character");await settle()
	var member=game.roster().filter(func(u):return u.id=="character_rio")[0]
	game.pages.party_uid=member.id
	game.pages.party_view.workspace.set_tab("ability");await settle()
	var picture=game.find_child("CharacterPortrait",true,false)
	check(picture.texture.get_size()==Vector2(1024,1536),"default Rio retains original image resolution")
	print("PORTRAIT source=",picture.texture.get_size()," display=",picture.size," filter=",picture.texture_filter)
	await capture("default")
	await game.import_portrait(ProjectSettings.globalize_path("res://../native/assets/characters/scout-human-female-01.png"),member.id)
	await settle()
	var initial=game.portraits.metadata.duplicate(true)
	game.pages.party_view.workspace.open_portrait(member);await settle()
	var editor=game.find_child("PortraitFraming",true,false)
	check(editor!=null,"uploaded portrait exposes framing editor")
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	editor._gui_input(wheel)
	game.dialog.close();await settle()
	check(game.portraits.metadata==initial,"closing framing editor cancels changes")
	game.pages.party_view.workspace.open_portrait(member);await settle()
	editor=game.find_child("PortraitFraming",true,false)
	wheel.position=editor.get_global_rect().get_center()
	var viewport=editor.get_viewport()
	var hover=InputEventMouseMotion.new();hover.position=wheel.position;viewport.push_input(hover)
	viewport.push_input(wheel);await settle()
	check(editor.framing.zoom>1.0,"viewport wheel changes portrait zoom")
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=wheel.position
	viewport.push_input(press)
	var motion=InputEventMouseMotion.new();motion.position=wheel.position+Vector2(20,12);motion.relative=Vector2(20,12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(motion)
	press.pressed=false;press.position=motion.position;viewport.push_input(press);await settle()
	check(editor.framing.x<0 and editor.framing.y<0,"viewport left drag changes portrait position")
	var guide=Rect2(editor.global_position+editor.display_rect().position,editor.display_rect().size)
	check(root.get_visible_rect().encloses(guide),"actual display guide stays inside viewport")
	var help=game.find_child("PortraitFramingHelp",true,false)
	check(guide.encloses(help.get_global_rect()) and absf(help.get_global_rect().end.x-guide.end.x)<1 and absf(help.global_position.y-guide.position.y)<1,"help icon is at the guide's upper right")
	if DisplayServer.get_name()=="headless":
		help.grab_focus()
	else:
		var help_motion=InputEventMouseMotion.new();help_motion.position=help.get_global_rect().get_center()
		help_motion.global_position=help_motion.position
		viewport.warp_mouse(help_motion.position)
		viewport.push_input(help_motion,true)
	await settle()
	check(help.texture!=null and editor.hint.is_visible_in_tree() and editor.hint.text.contains("ホイール"),"adjustment instructions open through keyboard focus (headless) or pointer hover (display)")
	await capture("editor")
	var expected=editor.framing.duplicate(true)
	game.find_child("PortraitFramingApply",true,false).pressed.emit();await settle()
	check(game.portraits.metadata.characters[member.id].framing==expected,"apply persists framing in portrait metadata")
	var full=game.portraits.texture(member,false);var face=game.portraits.texture(member,true)
	check(full.get_size()==face.get_size(),"uploaded framing applies to full and face consumers")
	await capture("applied")
	var envelope=await game.engine.request({"op":"campaign_save"})
	envelope.data.nativePortraits=game.portraits.metadata.duplicate(true)
	var save_path=OS.get_environment("PORTRAIT_QA_SAVE")
	if save_path.is_empty():
		var scope=OS.get_environment("INVENTORY_QA_ROOT")
		if scope.is_empty():quit(2);return
		save_path=scope.path_join("portrait-framing-%d.json" % Time.get_ticks_usec())
	var written=await game.engine.request({"op":"godot_io","action":"write","path":save_path,"data":envelope.data})
	check(written.get("ok",false),"write portrait and framing to new save file")
	await game.new_game();await settle()
	await game.load_game(save_path);await settle()
	check(game.portraits.metadata.characters[member.id].framing==expected,"file reload restores portrait framing")
	check(game.portraits.texture(member,false).get_image().get_data()==full.get_image().get_data(),"file reload restores exact displayed portrait pixels")
	var restored=await game.engine.request({"op":"campaign_save"})
	check(restored.data.state==envelope.data.state,"portrait file roundtrip preserves game state")
	await game.close_game()
	quit(0 if failures.is_empty() else 1)

func capture(label):
	var folder=OS.get_environment("PORTRAIT_QA_CAPTURE")
	if folder.is_empty():return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
